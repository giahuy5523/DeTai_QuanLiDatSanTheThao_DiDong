import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import '../utils/auth_validation.dart';

/// Account-only database. Existing venue/booking IDs remain unchanged.
class AccountRepository {
  AccountRepository(this.database);
  final Database database;
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  );

  static Future<AccountRepository> open({
    required List<AppUser> seed,
    DatabaseFactory? factory,
    String? path,
    Database? database,
  }) async {
    if (database != null) {
      final repository = AccountRepository(database);
      await repository._ensureSharedSchemaAndSeed(seed);
      return repository;
    }
    final driver = factory ?? databaseFactory;
    final location = path ?? '${await driver.getDatabasesPath()}/accounts.db';
    final db = await driver.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE Users (
          user_id TEXT PRIMARY KEY, full_name TEXT NOT NULL,
          email TEXT NOT NULL COLLATE NOCASE UNIQUE,
          phone TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL,
          role TEXT NOT NULL CHECK(role IN ('customer','owner','admin')),
          avatar_path TEXT,
          is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
        )''');
          await db.execute('''CREATE TABLE Session (
          id INTEGER PRIMARY KEY CHECK(id = 1),
          user_id TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
          expires_at INTEGER NOT NULL
        )''');
          for (final user in seed) {
            await db.insert('Users', {
              'user_id': user.id,
              'full_name': user.name,
              'email': user.email.trim().toLowerCase(),
              'phone': user.phone,
              'password_hash': await _hash(user.password),
              'role': user.role,
              'avatar_path': user.avatarPath,
            });
          }
        },
      ),
    );
    return AccountRepository(db);
  }

  /// Reuses the app database and imports any old DatabaseHelper accounts.
  Future<void> _ensureSharedSchemaAndSeed(List<AppUser> seed) async {
    await database.execute('PRAGMA foreign_keys = ON');
    await database.execute('''CREATE TABLE IF NOT EXISTS Users (
      user_id TEXT PRIMARY KEY, full_name TEXT NOT NULL,
      email TEXT NOT NULL COLLATE NOCASE UNIQUE, phone TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('customer','owner','admin')),
      avatar_path TEXT,
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
    )''');
    await database.execute('''CREATE TABLE IF NOT EXISTS Session (
      id INTEGER PRIMARY KEY CHECK(id = 1),
      user_id TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL
    )''');

    final importTable = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='legacy_account_import'",
    );
    if (importTable.isNotEmpty) {
      await database.transaction((txn) async {
        final legacyUsers = await txn.query('legacy_account_import');
        for (final row in legacyUsers) {
          final rawPassword = row['password'] as String? ?? '';
          final userId = row['user_id'] as String;
          final existing = await txn.query(
            'Users',
            columns: ['password_hash'],
            where: 'user_id = ?',
            whereArgs: [userId],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            // Only finish the V1 plaintext-password conversion for the
            // explicit migration placeholder. Never overwrite a real account.
            if (existing.single['password_hash'] == 'migration-pending') {
              try {
                await txn.update(
                  'Users',
                  {
                    'full_name': row['full_name'],
                    'email': (row['email'] as String).trim().toLowerCase(),
                    'phone': row['phone'],
                    'password_hash': await _hash(rawPassword),
                    'role': row['role'],
                    'avatar_path': row['avatar_path'],
                  },
                  where: 'user_id = ?',
                  whereArgs: [userId],
                );
              } on DatabaseException catch (error) {
                if (!error.isUniqueConstraintError()) rethrow;
                continue;
              }
            }
            await txn.delete(
              'legacy_account_import',
              where: 'user_id = ?',
              whereArgs: [userId],
            );
            continue;
          }

          try {
            await txn.insert('Users', {
              'user_id': userId,
              'full_name': row['full_name'],
              'email': (row['email'] as String).trim().toLowerCase(),
              'phone': row['phone'],
              'password_hash': await _hash(rawPassword),
              'role': row['role'],
              'avatar_path': row['avatar_path'],
            });
            await txn.delete(
              'legacy_account_import',
              where: 'user_id = ?',
              whereArgs: [userId],
            );
          } on DatabaseException catch (error) {
            // Keep the legacy row for recovery; a unique email/phone collision
            // must not be silently discarded or overwrite another account.
            if (!error.isUniqueConstraintError()) rethrow;
          }
        }

        final remaining = await txn.query('legacy_account_import', limit: 1);
        if (remaining.isEmpty) {
          await txn.execute('DROP TABLE legacy_account_import');
        }
      });
    }

    await database.transaction((txn) async {
      for (final user in seed) {
        final existing = await txn.query(
          'Users',
          columns: ['user_id'],
          where: 'user_id = ?',
          whereArgs: [user.id],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        await txn.insert(
          'Users',
          {
            'user_id': user.id,
            'full_name': user.name,
            'email': user.email.trim().toLowerCase(),
            'phone': user.phone,
            'password_hash': await _hash(user.password),
            'role': user.role,
            'avatar_path': user.avatarPath,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// One-time, non-destructive import from the former `accounts.db` file.
  /// Existing target accounts and valid target sessions always take priority.
  static Future<void> importLegacyAccountDatabase(Database target) async {
    const migrationKey = 'legacy_accounts_db_v1_imported';
    final factory = databaseFactory;
    final migrationTable = await target.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='app_migrations'",
    );
    if (migrationTable.isNotEmpty) {
      final completed = await target.query(
        'app_migrations',
        columns: ['migration_key'],
        where: 'migration_key = ?',
        whereArgs: [migrationKey],
        limit: 1,
      );
      if (completed.isNotEmpty) return;
    }

    final sourcePath = p.join(await factory.getDatabasesPath(), 'accounts.db');
    if (!await factory.databaseExists(sourcePath)) return;

    final source = await factory.openDatabase(
      sourcePath,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final tables = await source.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='Users'",
      );
      if (tables.isEmpty) return;

      final userColumns = (await source.rawQuery('PRAGMA table_info(Users)'))
          .map((row) => row['name'] as String)
          .toSet();
      const requiredColumns = {
        'user_id',
        'full_name',
        'email',
        'phone',
        'password_hash',
        'role',
      };
      if (!userColumns.containsAll(requiredColumns)) {
        throw FormatException(
          'Schema Users trong accounts.db không tương thích; chưa thực hiện import.',
        );
      }

      final sourceUsers = await source.query('Users');
      final sessionTable = await source.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='Session'",
      );
      final sourceSessions = sessionTable.isEmpty
          ? <Map<String, Object?>>[]
          : await source.query('Session');

      await target.transaction((txn) async {
        await txn.execute('''CREATE TABLE IF NOT EXISTS app_migrations (
          migration_key TEXT PRIMARY KEY,
          completed_at INTEGER NOT NULL
        )''');
        await txn.execute('''CREATE TABLE IF NOT EXISTS legacy_account_import_conflicts (
          user_id TEXT PRIMARY KEY,
          reason TEXT NOT NULL,
          recorded_at INTEGER NOT NULL
        )''');

        final completed = await txn.query(
          'app_migrations',
          where: 'migration_key = ?',
          whereArgs: [migrationKey],
          limit: 1,
        );
        if (completed.isNotEmpty) return;

        final now = DateTime.now().millisecondsSinceEpoch;
        for (final user in sourceUsers) {
          final userId = user['user_id']?.toString();
          if (userId == null || userId.isEmpty) {
            throw FormatException('accounts.db có user_id rỗng; import bị hủy.');
          }

          final existingById = await txn.query(
            'Users',
            columns: ['user_id', 'password_hash'],
            where: 'user_id = ?',
            whereArgs: [userId],
            limit: 1,
          );
          if (existingById.isNotEmpty) {
            // A V1 migration placeholder is not a usable account. Prefer the
            // PBKDF2 hash and profile from accounts.db, but never replace a
            // normal account already stored in the shared database.
            if (existingById.single['password_hash'] == 'migration-pending') {
              try {
                await txn.update(
                  'Users',
                  {
                    'full_name': user['full_name'],
                    'email': (user['email'] as String).trim().toLowerCase(),
                    'phone': user['phone'],
                    'password_hash': user['password_hash'],
                    'role': user['role'],
                    'avatar_path': userColumns.contains('avatar_path')
                        ? user['avatar_path']
                        : null,
                    'is_active': userColumns.contains('is_active')
                        ? user['is_active']
                        : 1,
                  },
                  where: 'user_id = ?',
                  whereArgs: [userId],
                );
              } on DatabaseException catch (error) {
                if (!error.isUniqueConstraintError()) rethrow;
                await txn.insert(
                  'legacy_account_import_conflicts',
                  {
                    'user_id': userId,
                    'reason': 'v1_placeholder_conflict',
                    'recorded_at': now,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
            continue;
          }

          try {
            await txn.insert('Users', {
              'user_id': userId,
              'full_name': user['full_name'],
              'email': (user['email'] as String).trim().toLowerCase(),
              'phone': user['phone'],
              'password_hash': user['password_hash'],
              'role': user['role'],
              'avatar_path': userColumns.contains('avatar_path')
                  ? user['avatar_path']
                  : null,
              'is_active': userColumns.contains('is_active')
                  ? user['is_active']
                  : 1,
            });
          } on DatabaseException catch (error) {
            if (!error.isUniqueConstraintError()) rethrow;
            final emailOwner = await txn.query(
              'Users',
              columns: ['user_id'],
              where: 'email = ? COLLATE NOCASE',
              whereArgs: [user['email']],
              limit: 1,
            );
            final phoneOwner = await txn.query(
              'Users',
              columns: ['user_id'],
              where: 'phone = ?',
              whereArgs: [user['phone']],
              limit: 1,
            );
            final reason = emailOwner.isNotEmpty
                ? "email_conflict:${emailOwner.single['user_id']}"
                : "phone_conflict:${phoneOwner.isNotEmpty ? phoneOwner.single['user_id'] : 'unknown'}";
            await txn.insert(
              'legacy_account_import_conflicts',
              {
                'user_id': userId,
                'reason': reason,
                'recorded_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // Do not replace a still-valid session already belonging to this app.
        final validTargetSession = await txn.rawQuery(
          'SELECT id FROM Session WHERE id = 1 AND expires_at > ? LIMIT 1',
          [now],
        );
        if (validTargetSession.isEmpty) {
          await txn.delete('Session', where: 'id = 1');
          for (final session in sourceSessions) {
            final expiry = session['expires_at'];
            if (expiry is! int || expiry <= now) continue;
            final user = await txn.query(
              'Users',
              columns: ['user_id'],
              where: 'user_id = ?',
              whereArgs: [session['user_id']],
              limit: 1,
            );
            if (user.isEmpty) continue;
            await txn.insert('Session', {
              'id': 1,
              'user_id': session['user_id'],
              'expires_at': expiry,
            });
            break;
          }
        }

        await txn.insert('app_migrations', {
          'migration_key': migrationKey,
          'completed_at': now,
        });
      });
    } finally {
      await source.close();
    }
  }

  static Future<String> _hash(String password, {List<int>? salt}) async {
    final nonce =
        salt ?? List.generate(16, (_) => Random.secure().nextInt(256));
    final key = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: nonce,
    );
    return '${base64Encode(nonce)}:${base64Encode(await key.extractBytes())}';
  }

  AppUser _user(Map<String, Object?> row) => AppUser(
    id: row['user_id'] as String,
    name: row['full_name'] as String,
    email: row['email'] as String,
    phone: row['phone'] as String,
    password: '',
    role: row['role'] as String,
    avatarPath: row['avatar_path'] as String?,
  );

  Future<List<AppUser>> allUsers() async => (await database.query(
    'Users',
    where: 'is_active = 1',
  )).map(_user).toList();

  Future<AppUser?> login(String email, String password) async {
    final rows = await database.query(
      'Users',
      where: 'email = ? AND is_active = 1',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final stored = rows.single['password_hash'] as String;
    final candidate = await _hash(
      password,
      salt: base64Decode(stored.split(':').first),
    );
    var mismatch = stored.length ^ candidate.length;
    for (var i = 0; i < stored.length && i < candidate.length; i++) {
      mismatch |= stored.codeUnitAt(i) ^ candidate.codeUnitAt(i);
    }
    if (mismatch != 0) return null;
    final user = _user(rows.single);
    await database.insert('Session', {
      'id': 1,
      'user_id': user.id,
      'expires_at': DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return user;
  }

  Future<AppUser?> restoreSession() async {
    final rows = await database.rawQuery(
      '''
      SELECT u.* FROM Users u JOIN Session s ON s.user_id = u.user_id
      WHERE s.id = 1 AND s.expires_at > ? AND u.is_active = 1
    ''',
      [DateTime.now().millisecondsSinceEpoch],
    );
    if (rows.isNotEmpty) return _user(rows.single);
    await logout();
    return null;
  }

  Future<void> logout() => database.delete('Session').then((_) {});

  Future<void> register(AppUser user) async {
    if (!{'customer', 'owner'}.contains(user.role)) {
      throw ArgumentError('Không được tự đăng ký tài khoản quản trị.');
    }
    final error =
        AuthValidation.email(user.email) ??
        AuthValidation.phone(user.phone) ??
        AuthValidation.password(user.password);
    if (error != null || user.name.trim().isEmpty) {
      throw ArgumentError(error ?? 'Họ tên không được để trống.');
    }
    try {
      await database.insert('Users', {
        'user_id': user.id,
        'full_name': user.name.trim(),
        'email': user.email.trim().toLowerCase(),
        'phone': user.phone.trim(),
        'password_hash': await _hash(user.password),
        'role': user.role,
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw ArgumentError('Email hoặc số điện thoại đã được sử dụng.');
      }
      rethrow;
    }
  }

  Future<AppUser?> updateProfile({
    required String userId,
    required String name,
    required String phone,
    required String? avatarPath,
  }) async {
    final error = AuthValidation.phone(phone);
    if (name.trim().isEmpty || error != null) {
      throw ArgumentError(error ?? 'Họ tên không được để trống.');
    }
    return database.transaction((txn) async {
      final session = await txn.query(
        'Session',
        where: 'id = 1 AND user_id = ? AND expires_at > ?',
        whereArgs: [userId, DateTime.now().millisecondsSinceEpoch],
      );
      if (session.isEmpty) return null;
      try {
        final count = await txn.update(
          'Users',
          {
            'full_name': name.trim(),
            'phone': phone.trim(),
            'avatar_path': avatarPath,
          },
          where: 'user_id = ? AND is_active = 1',
          whereArgs: [userId],
        );
        if (count == 0) return null;
      } on DatabaseException catch (error) {
        if (error.isUniqueConstraintError()) {
          throw ArgumentError('Số điện thoại đã được sử dụng.');
        }
        rethrow;
      }
      return _user(
        (await txn.query(
          'Users',
          where: 'user_id = ?',
          whereArgs: [userId],
        )).single,
      );
    });
  }
}
