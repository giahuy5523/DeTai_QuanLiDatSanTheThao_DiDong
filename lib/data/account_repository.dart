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
  int? _sessionExpiresAt;
  Duration? get sessionTimeRemaining {
    final expiresAt = _sessionExpiresAt;
    return expiresAt == null
        ? null
        : Duration(
            milliseconds: expiresAt - DateTime.now().millisecondsSinceEpoch,
          );
  }

  bool get isSessionExpired {
    final remaining = sessionTimeRemaining;
    return remaining != null && remaining <= Duration.zero;
  }

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

    await database.transaction((txn) async {
      final importTable = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='legacy_account_import'",
      );
      if (importTable.isEmpty) return;

      for (final row in await txn.query('legacy_account_import')) {
        final rawPassword = row['password'] as String? ?? '';
        final userId = row['user_id'] as String;
        final values = {
          'full_name': row['full_name'],
          'email': (row['email'] as String).trim().toLowerCase(),
          'phone': row['phone'],
          'password_hash': await _hash(rawPassword),
          'role': row['role'],
          'avatar_path': row['avatar_path'],
        };
        final updated = await txn.update(
          'Users',
          {
            'email': values['email'],
            'password_hash': values['password_hash'],
            'avatar_path': values['avatar_path'],
          },
          where: 'user_id = ? AND password_hash = ?',
          whereArgs: [userId, 'migration-pending'],
        );
        if (updated == 0) {
          await txn.insert('Users', {
            'user_id': userId,
            ...values,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await txn.execute('DROP TABLE legacy_account_import');
    });
    for (final user in seed) {
      final existing = await database.query(
        'Users',
        columns: ['user_id'],
        where: 'user_id = ?',
        whereArgs: [user.id],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      await database.insert('Users', {
        'user_id': user.id,
        'full_name': user.name,
        'email': user.email.trim().toLowerCase(),
        'phone': user.phone,
        'password_hash': await _hash(user.password),
        'role': user.role,
        'avatar_path': user.avatarPath,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Copies the former accounts.db before demo accounts are seeded.
  static Future<void> importLegacyAccountDatabase(
    Database target, {
    String? legacyPath,
  }) async {
    final factory = databaseFactory;
    final sourcePath =
        legacyPath ?? p.join(await factory.getDatabasesPath(), 'accounts.db');
    if (p.equals(sourcePath, target.path) ||
        !await factory.databaseExists(sourcePath)) {
      return;
    }

    await target.transaction((txn) async {
      await txn.execute('''CREATE TABLE IF NOT EXISTS account_migrations (
        name TEXT PRIMARY KEY
      )''');
      const migration = 'standalone_accounts_v1';
      final completed = await txn.query(
        'account_migrations',
        where: 'name = ?',
        whereArgs: [migration],
      );
      if (completed.isNotEmpty) return;

      await txn.execute(
        '''CREATE TABLE IF NOT EXISTS legacy_account_import_conflicts (
        user_id TEXT PRIMARY KEY,
        reason TEXT NOT NULL
      )''',
      );
      final source = await factory.openDatabase(
        sourcePath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        final tables = await source.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('Users', 'Session')",
        );
        final tableNames = tables.map((row) => row['name']).toSet();
        if (!tableNames.contains('Users')) return;
        final legacySession = tableNames.contains('Session')
            ? (await source.query(
                'Session',
                where: 'id = 1 AND expires_at > ?',
                whereArgs: [DateTime.now().millisecondsSinceEpoch],
              )).firstOrNull
            : null;

        for (final row in await source.query('Users')) {
          final user = {
            ...row,
            'email': (row['email'] as String).trim().toLowerCase(),
            'phone': (row['phone'] as String).trim(),
          };
          try {
            await txn.insert('Users', user);
          } on DatabaseException catch (error) {
            if (!error.isUniqueConstraintError()) rethrow;
            final String reason;
            if (error.isUniqueConstraintError('Users.user_id')) {
              reason = 'existing_user_id_conflict';
            } else {
              final field = error.isUniqueConstraintError('Users.email')
                  ? 'email'
                  : 'phone';
              final owners = await txn.query(
                'Users',
                columns: ['user_id'],
                where: '$field = ?',
                whereArgs: [user[field]],
                limit: 1,
              );
              reason = '${field}_conflict:${owners.firstOrNull?['user_id']}';
            }
            await txn.insert('legacy_account_import_conflicts', {
              'user_id': user['user_id'],
              'reason': reason,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            continue;
          }
          // An existing account may have logged out after an earlier import.
          if (legacySession != null &&
              legacySession['user_id'] == user['user_id'] &&
              user['is_active'] == 1) {
            await txn.insert(
              'Session',
              legacySession,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
        await txn.insert('account_migrations', {'name': migration});
      } finally {
        await source.close();
      }
    });
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
    final expiresAt = DateTime.now()
        .add(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await database.insert('Session', {
      'id': 1,
      'user_id': user.id,
      'expires_at': expiresAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _sessionExpiresAt = expiresAt;
    return user;
  }

  Future<AppUser?> restoreSession() async {
    final row = await database.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT u.*, s.expires_at FROM Users u JOIN Session s ON s.user_id = u.user_id
        WHERE s.id = 1 AND s.expires_at > ? AND u.is_active = 1
        ''',
        [DateTime.now().millisecondsSinceEpoch],
      );
      if (rows.isEmpty) await txn.delete('Session');
      return rows.firstOrNull;
    });
    _sessionExpiresAt = row?['expires_at'] as int?;
    return row == null ? null : _user(row);
  }

  Future<void> logout() async {
    await database.delete('Session');
    _sessionExpiresAt = null;
  }

  Future<void> deleteExpiredSession() async {
    await database.delete(
      'Session',
      where: 'expires_at <= ?',
      whereArgs: [DateTime.now().millisecondsSinceEpoch],
    );
  }

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
    final random = Random.secure();
    final values = {
      'full_name': user.name.trim(),
      'email': user.email.trim().toLowerCase(),
      'phone': user.phone.trim(),
      'password_hash': await _hash(user.password),
      'role': user.role,
    };
    while (true) {
      final id = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      try {
        await database.insert('Users', {'user_id': 'user_$id', ...values});
        return;
      } on DatabaseException catch (error) {
        if (error.isUniqueConstraintError('Users.email')) {
          throw ArgumentError('Email đã được sử dụng');
        }
        if (error.isUniqueConstraintError('Users.phone')) {
          throw ArgumentError('Số điện thoại đã được sử dụng.');
        }
        if (!error.isUniqueConstraintError('Users.user_id')) rethrow;
      }
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
