import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import '../utils/auth_validation.dart';

/// Account data access through the application's shared SQLite database.
class AccountRepository {
  AccountRepository(this.database);
  final Database database;
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  );

  /// Mở repository trên kết nối SQLite dùng chung do DatabaseHelper cung cấp.
  ///
  /// factory + path chỉ dành cho unit test tạo database cô lập; ứng dụng thật
  /// phải truyền database từ DatabaseHelper và không được tự mở accounts.db.
  static Future<AccountRepository> open({
    required List<AppUser> seed,
    Database? database,
    DatabaseFactory? factory,
    String? path,
  }) async {
    if (database != null) {
      final repository = AccountRepository(database);
      await repository._ensureSharedSchemaAndSeed(seed);
      return repository;
    }

    if (factory == null || path == null || path.trim().isEmpty) {
      throw ArgumentError(
        'AccountRepository phải nhận Database dùng chung từ DatabaseHelper. '
        'factory/path chỉ được cung cấp trong unit test.',
      );
    }

    final db = await factory.openDatabase(
      path,
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
        },
      ),
    );
    final repository = AccountRepository(db);
    await repository._ensureSharedSchemaAndSeed(seed);
    return repository;
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

    await database.execute('''
      CREATE TABLE IF NOT EXISTS legacy_account_import_conflicts (
        user_id TEXT PRIMARY KEY,
        reason TEXT NOT NULL,
        recorded_at INTEGER NOT NULL
      )
    ''');
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

                await txn.insert('legacy_account_import_conflicts', {
                  'user_id': userId,
                  'reason': 'v1_placeholder_conflict',
                  'recorded_at': DateTime.now().millisecondsSinceEpoch,
                }, conflictAlgorithm: ConflictAlgorithm.replace);
                continue;
              }
            } else {
              // A real account with this ID already exists. Preserve it.
              await txn.insert('legacy_account_import_conflicts', {
                'user_id': userId,
                'reason': 'existing_user_id_conflict',
                'recorded_at': DateTime.now().millisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
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
            if (!error.isUniqueConstraintError()) rethrow;

            final normalizedEmail = (row['email'] as String)
                .trim()
                .toLowerCase();
            final legacyPhone = row['phone'] as String;

            final emailOwner = await txn.query(
              'Users',
              columns: ['user_id'],
              where: 'email = ?',
              whereArgs: [normalizedEmail],
              limit: 1,
            );

            final phoneOwner = await txn.query(
              'Users',
              columns: ['user_id'],
              where: 'phone = ?',
              whereArgs: [legacyPhone],
              limit: 1,
            );

            final String reason;
            if (emailOwner.isNotEmpty) {
              reason = 'email_conflict:${emailOwner.single['user_id']}';
            } else if (phoneOwner.isNotEmpty) {
              reason = 'phone_conflict:${phoneOwner.single['user_id']}';
            } else {
              reason = 'unique_constraint_conflict';
            }

            await txn.insert('legacy_account_import_conflicts', {
              'user_id': userId,
              'reason': reason,
              'recorded_at': DateTime.now().millisecondsSinceEpoch,
            }, conflictAlgorithm: ConflictAlgorithm.replace);

            // Giữ legacy row để có thể xử lý thủ công sau này.
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
        await txn.insert('Users', {
          'user_id': user.id,
          'full_name': user.name,
          'email': user.email.trim().toLowerCase(),
          'phone': user.phone,
          'password_hash': await _hash(user.password),
          'role': user.role,
          'avatar_path': user.avatarPath,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
