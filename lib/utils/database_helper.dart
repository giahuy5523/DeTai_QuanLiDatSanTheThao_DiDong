import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// The application's single SQLite database for accounts, venues, bookings, and payments.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper _instance = DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  static const databaseName = 'sport_venue_database.db';
  static const int databaseVersion = 3;
  static Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), databaseName);
    return openDatabase(
      path,
      version: databaseVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) => upgradeSchema(db, oldVersion),
    );
  }

  /// Helper kiểm tra xem cột đã tồn tại trong bảng hay chưa qua PRAGMA table_info
  static Future<bool> columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any(
      (row) => (row['name'] as String).toLowerCase() == column.toLowerCase(),
    );
  }

  /// Tạo schema mới, dùng chung cho production và migration tests.
  Future<void> createSchema(DatabaseExecutor db) async {
    await _createSchema(db);
  }

  /// Chạy migration thực tế theo version.
  Future<void> upgradeSchema(DatabaseExecutor db, int oldVersion) async {
    if (oldVersion < 2) await _upgradeToV2(db);
    if (oldVersion < 3) await _upgradeToV3(db);
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE Users (
      user_id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      email TEXT NOT NULL COLLATE NOCASE UNIQUE,
      phone TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('customer','owner','admin')),
      avatar_path TEXT,
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
    )''');
    await db.execute('''CREATE TABLE Session (
      id INTEGER PRIMARY KEY CHECK(id = 1),
      user_id TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE sport_types (
      sportTypeId INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL,
      description TEXT, icon TEXT
    )''');
    await db.execute('''CREATE TABLE venues (
      id TEXT PRIMARY KEY,
      ownerId TEXT NOT NULL REFERENCES Users(user_id),
      sportTypeId INTEGER REFERENCES sport_types(sportTypeId),
      sportType TEXT NOT NULL, name TEXT NOT NULL, address TEXT NOT NULL,
      district TEXT, city TEXT, pricePerHour REAL NOT NULL,
      latitude REAL NOT NULL, longitude REAL NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending', rating REAL NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE venue_images (
      id TEXT PRIMARY KEY,
      venueId TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
      imageUrl TEXT NOT NULL, isPrimary INTEGER NOT NULL DEFAULT 0,
      sortOrder INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE venue_services (
      id TEXT PRIMARY KEY,
      venueId TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
      name TEXT NOT NULL, price REAL NOT NULL, unit TEXT NOT NULL DEFAULT 'lần'
    )''');
    await db.execute('''CREATE TABLE promotions (
      id TEXT PRIMARY KEY, code TEXT NOT NULL UNIQUE,
      discountPercent REAL NOT NULL, expiryDate TEXT NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1, usedCount INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE bookings (
      id TEXT PRIMARY KEY,
      venueId TEXT NOT NULL REFERENCES venues(id),
      userId TEXT NOT NULL REFERENCES Users(user_id),
      date TEXT NOT NULL, startTime TEXT NOT NULL, endTime TEXT NOT NULL,
      totalPrice REAL NOT NULL, originalAmount REAL NOT NULL DEFAULT 0,
      serviceAmount REAL NOT NULL DEFAULT 0, discountAmount REAL NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'pending',
      paymentStatus TEXT NOT NULL DEFAULT 'unpaid', paymentId TEXT,
      promoId TEXT REFERENCES promotions(id) ON DELETE SET NULL,
      promotionCode TEXT, note TEXT, cancelReason TEXT, cancelledAt TEXT,
      createdAt TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE booking_services (
      id TEXT PRIMARY KEY,
      bookingId TEXT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
      serviceId TEXT NOT NULL REFERENCES venue_services(id),
      serviceName TEXT,
      quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
      unitPrice REAL NOT NULL, subtotal REAL NOT NULL
    )''');
    await db.execute('''CREATE TABLE payments (
      id TEXT PRIMARY KEY,
      bookingId TEXT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
      method TEXT NOT NULL, amount REAL NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending', transactionCode TEXT,
      paidAt TEXT, createdAt TEXT NOT NULL,
      refundAmount REAL, refundMethod TEXT,
      refundStatus TEXT, refundExpectedAt TEXT
    )''');
    await db.execute('''CREATE TABLE time_slots (
      id TEXT PRIMARY KEY,
      venueId TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
      slotDate TEXT NOT NULL, startTime TEXT NOT NULL, endTime TEXT NOT NULL,
      price REAL NOT NULL, status TEXT NOT NULL DEFAULT 'available',
      UNIQUE(venueId, slotDate, startTime, endTime)
    )''');
    await db.execute('''CREATE TABLE venue_hours (
      venueId TEXT PRIMARY KEY REFERENCES venues(id) ON DELETE CASCADE,
      openHour INTEGER NOT NULL DEFAULT 6, closeHour INTEGER NOT NULL DEFAULT 22
    )''');
    await db.execute('''CREATE TABLE promotion_usages (
      id TEXT PRIMARY KEY,
      promotionId TEXT NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
      userId TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
      bookingId TEXT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
      isReversed INTEGER NOT NULL DEFAULT 0 CHECK(isReversed IN (0,1)),
      createdAt TEXT NOT NULL,
      UNIQUE(promotionId, userId, bookingId)
    )''');
    await db.execute('''CREATE TABLE app_notifications (
      id TEXT PRIMARY KEY,
      userId TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
      bookingId TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      type TEXT NOT NULL,
      refundAmount REAL,
      refundMethod TEXT,
      refundExpectedAt TEXT,
      refundStatus TEXT,
      isRead INTEGER NOT NULL DEFAULT 0 CHECK(isRead IN (0,1))
    )''');

    await db.execute('CREATE INDEX idx_venues_owner ON venues(ownerId)');
    await db.execute(
      'CREATE INDEX idx_bookings_user_date ON bookings(userId, date)',
    );
    await db.execute(
      'CREATE INDEX idx_bookings_venue_date ON bookings(venueId, date)',
    );
    await db.execute(
      'CREATE INDEX idx_payments_booking ON payments(bookingId)',
    );
    await db.execute(
      'CREATE INDEX idx_services_venue ON venue_services(venueId)',
    );
    await db.execute(
      'CREATE INDEX idx_promo_usage_user ON promotion_usages(userId, promotionId)',
    );
    await db.execute(
      'CREATE INDEX idx_promo_usage_booking ON promotion_usages(bookingId)',
    );
    await db.execute(
      'CREATE INDEX idx_notifications_user ON app_notifications(userId)',
    );
  }

  /// Migrates the original schema while preserving every known V2 business
  /// table, including dependent rows. Child tables are removed before parents
  /// so PRAGMA foreign_keys can remain enabled throughout the migration.
  Future<void> _upgradeToV2(DatabaseExecutor txn) async {
    const businessTables = <String>[
      'sport_types',
      'venues',
      'venue_images',
      'venue_services',
      'promotions',
      'bookings',
      'booking_services',
      'payments',
      'time_slots',
      'venue_hours',
    ];

    final preserved = <String, List<Map<String, Object?>>>{};
    for (final table in businessTables) {
      final exists = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?",
        [table.toLowerCase()],
      );
      preserved[table] = exists.isEmpty
          ? <Map<String, Object?>>[]
          : await txn.query(table);
    }
    final sessionExists = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='session'",
    );
    if (sessionExists.isNotEmpty) {
      final sessionColumns = (await txn.rawQuery('PRAGMA table_info(Session)'))
          .map((row) => row['name'] as String)
          .toSet();
      if (!sessionColumns.containsAll({'id', 'user_id', 'expires_at'})) {
        throw StateError(
          'Schema Session V1 không tương thích (cần id/user_id/expires_at); '
          'migration đã được rollback để bảo toàn phiên đăng nhập cũ.',
        );
      }
      preserved['Session'] = await txn.query('Session');
    } else {
      preserved['Session'] = <Map<String, Object?>>[];
    }

    // V1's plain-text account table used `users`, not the current Users schema.
    final usersTable = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='users'",
    );
    if (usersTable.isNotEmpty) {
      await txn.execute(
        'ALTER TABLE "${usersTable.single['name']}" RENAME TO legacy_users_v1',
      );
    }

    // Drop dependent tables first to prevent cascades from deleting rows.
    const dropOrder = <String>[
      'Session',
      'booking_services',
      'payments',
      'time_slots',
      'venue_hours',
      'venue_images',
      'venue_services',
      'bookings',
      'venues',
      'promotions',
      'sport_types',
    ];
    for (final table in dropOrder) {
      await txn.execute('DROP TABLE IF EXISTS $table');
    }

    await _createSchemaV2(txn);

    await txn.execute('''CREATE TABLE IF NOT EXISTS legacy_account_import (
      user_id TEXT PRIMARY KEY, full_name TEXT NOT NULL, email TEXT NOT NULL,
      phone TEXT NOT NULL, password TEXT NOT NULL, role TEXT NOT NULL,
      avatar_path TEXT
    )''');

    final legacy = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='legacy_users_v1'",
    );
    if (legacy.isNotEmpty) {
      final columns = (await txn.rawQuery(
        'PRAGMA table_info(legacy_users_v1)',
      )).map((row) => row['name'] as String).toSet();
      final rows = await txn.query('legacy_users_v1');

      if (columns.containsAll({'id', 'name', 'email', 'phone', 'password'})) {
        // Original plain-text V1 accounts are converted by AccountRepository
        // after the database schema upgrade, using PBKDF2 before login.
        for (final row in rows) {
          final id = row['id']?.toString();
          final name = row['name']?.toString();
          final email = row['email']?.toString();
          final phone = row['phone']?.toString();
          final password = row['password']?.toString();
          if ([id, name, email, phone, password].any(
            (value) => value == null || value.isEmpty,
          )) {
            throw StateError(
              'Không thể migrate users V1: thiếu id/name/email/phone/password.',
            );
          }
          final role = (row['role']?.toString() ?? 'customer')
              .trim()
              .toLowerCase();
          if (!const {'customer', 'owner', 'admin'}.contains(role)) {
            throw StateError(
              'Role V1 không hợp lệ cho user_id=$id: "$role". '
              'Migration đã được rollback; cần ánh xạ role theo nghiệp vụ.',
            );
          }
          final avatar = row['avatarPath']?.toString();
          await txn.insert('legacy_account_import', {
            'user_id': id,
            'full_name': name,
            'email': email,
            'phone': phone,
            'password': password,
            'role': role,
            'avatar_path': avatar,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          await txn.insert('Users', {
            'user_id': id,
            'full_name': name,
            'email': email,
            'phone': phone,
            'password_hash': 'migration-pending',
            'role': role,
            'avatar_path': avatar,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      } else if (columns.containsAll({
        'user_id',
        'full_name',
        'email',
        'phone',
        'password_hash',
        'role',
      })) {
        // Also tolerate a V1 database that already used the account schema.
        for (final row in rows) {
          final role = row['role']?.toString().trim().toLowerCase() ?? '';
          if (!const {'customer', 'owner', 'admin'}.contains(role)) {
            throw StateError(
              'Role V1 không hợp lệ cho user_id=${row['user_id']}: "$role". '
              'Migration đã được rollback; cần ánh xạ role theo nghiệp vụ.',
            );
          }
          await txn.insert('Users', {
            'user_id': row['user_id'],
            'full_name': row['full_name'],
            'email': row['email'],
            'phone': row['phone'],
            'password_hash': row['password_hash'],
            'role': role,
            'avatar_path': columns.contains('avatar_path')
                ? row['avatar_path']
                : null,
            'is_active': columns.contains('is_active')
                ? row['is_active']
                : 1,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      } else {
        throw StateError(
          'Schema users V1 không nhận diện được; migration đã được rollback để bảo toàn dữ liệu.',
        );
      }
      await txn.execute('DROP TABLE legacy_users_v1');
    }

    // Restore parents before children. If a required legacy value cannot be
    // represented in V2, insertion fails and SQLite rolls the whole migration
    // back instead of silently dropping the affected row.
    const restoreOrder = <String>[
      'sport_types',
      'Session',
      'venues',
      'venue_images',
      'venue_services',
      'promotions',
      'bookings',
      'booking_services',
      'payments',
      'time_slots',
      'venue_hours',
    ];
    for (final table in restoreOrder) {
      final rows = preserved[table]!;
      if (rows.isEmpty) continue;
      final info = await txn.rawQuery('PRAGMA table_info($table)');
      final columns = info.map((row) => row['name'] as String).toSet();
      for (final row in rows) {
        final compatibleRow = Map<String, Object?>.fromEntries(
          row.entries.where((entry) => columns.contains(entry.key)),
        );
        await txn.insert(
          table,
          compatibleRow,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    }
  }

  Future<void> _createSchemaV2(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE Users (
      user_id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      email TEXT NOT NULL COLLATE NOCASE UNIQUE,
      phone TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('customer','owner','admin')),
      avatar_path TEXT,
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
    )''');
    await db.execute('''CREATE TABLE Session (
      id INTEGER PRIMARY KEY CHECK(id = 1),
      user_id TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE sport_types (
      sportTypeId INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL,
      description TEXT, icon TEXT
    )''');
    await db.execute('''CREATE TABLE venues (
      id TEXT PRIMARY KEY,
      ownerId TEXT NOT NULL REFERENCES Users(user_id),
      sportTypeId INTEGER REFERENCES sport_types(sportTypeId),
      sportType TEXT NOT NULL, name TEXT NOT NULL, address TEXT NOT NULL,
      district TEXT, city TEXT, pricePerHour REAL NOT NULL,
      latitude REAL NOT NULL, longitude REAL NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending', rating REAL NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE venue_images (
      id TEXT PRIMARY KEY,
      venueId TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
      imageUrl TEXT NOT NULL, isPrimary INTEGER NOT NULL DEFAULT 0,
      sortOrder INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE venue_services (
      id TEXT PRIMARY KEY,
      venueId TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
      name TEXT NOT NULL, price REAL NOT NULL, unit TEXT NOT NULL DEFAULT 'lần'
    )''');
    await db.execute('''CREATE TABLE promotions (
      id TEXT PRIMARY KEY, code TEXT NOT NULL UNIQUE,
      discountPercent REAL NOT NULL, expiryDate TEXT NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1, usedCount INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE bookings (
      id TEXT PRIMARY KEY,
      venueId TEXT NOT NULL REFERENCES venues(id),
      userId TEXT NOT NULL REFERENCES Users(user_id),
      date TEXT NOT NULL, startTime TEXT NOT NULL, endTime TEXT NOT NULL,
      totalPrice REAL NOT NULL, originalAmount REAL NOT NULL DEFAULT 0,
      serviceAmount REAL NOT NULL DEFAULT 0, discountAmount REAL NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'pending',
      paymentStatus TEXT NOT NULL DEFAULT 'unpaid', paymentId TEXT,
      promoId TEXT REFERENCES promotions(id) ON DELETE SET NULL,
      promotionCode TEXT, note TEXT, cancelReason TEXT, cancelledAt TEXT,
      createdAt TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE booking_services (
      id TEXT PRIMARY KEY,
      bookingId TEXT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
      serviceId TEXT NOT NULL REFERENCES venue_services(id),
      quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
      unitPrice REAL NOT NULL, subtotal REAL NOT NULL
    )''');
    await db.execute('''CREATE TABLE payments (
      id TEXT PRIMARY KEY,
      bookingId TEXT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
      method TEXT NOT NULL, amount REAL NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending', transactionCode TEXT,
      paidAt TEXT, createdAt TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE time_slots (
      id TEXT PRIMARY KEY,
      venueId TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
      slotDate TEXT NOT NULL, startTime TEXT NOT NULL, endTime TEXT NOT NULL,
      price REAL NOT NULL, status TEXT NOT NULL DEFAULT 'available',
      UNIQUE(venueId, slotDate, startTime, endTime)
    )''');
    await db.execute('''CREATE TABLE venue_hours (
      venueId TEXT PRIMARY KEY REFERENCES venues(id) ON DELETE CASCADE,
      openHour INTEGER NOT NULL DEFAULT 6, closeHour INTEGER NOT NULL DEFAULT 22
    )''');
    await db.execute('CREATE INDEX idx_venues_owner ON venues(ownerId)');
    await db.execute(
      'CREATE INDEX idx_bookings_user_date ON bookings(userId, date)',
    );
    await db.execute(
      'CREATE INDEX idx_bookings_venue_date ON bookings(venueId, date)',
    );
    await db.execute(
      'CREATE INDEX idx_payments_booking ON payments(bookingId)',
    );
    await db.execute(
      'CREATE INDEX idx_services_venue ON venue_services(venueId)',
    );
  }

  /// Version 3: Bổ sung an toàn các cột refund, serviceName và các bảng mới
  /// Tuyệt đối KHÔNG DROP TABLE, kiểm tra cột trước ALTER TABLE
  Future<void> _upgradeToV3(DatabaseExecutor db) async {
    // 1. Cột refund trong payments
    if (!await columnExists(db, 'payments', 'refundAmount')) {
      await db.execute('ALTER TABLE payments ADD COLUMN refundAmount REAL');
    }
    if (!await columnExists(db, 'payments', 'refundMethod')) {
      await db.execute('ALTER TABLE payments ADD COLUMN refundMethod TEXT');
    }
    if (!await columnExists(db, 'payments', 'refundStatus')) {
      await db.execute('ALTER TABLE payments ADD COLUMN refundStatus TEXT');
    }
    if (!await columnExists(db, 'payments', 'refundExpectedAt')) {
      await db.execute('ALTER TABLE payments ADD COLUMN refundExpectedAt TEXT');
    }

    // 2. Cột serviceName trong booking_services
    if (!await columnExists(db, 'booking_services', 'serviceName')) {
      await db.execute(
        'ALTER TABLE booking_services ADD COLUMN serviceName TEXT',
      );
    }

    // 3. Bảng promotion_usages
    await db.execute('''CREATE TABLE IF NOT EXISTS promotion_usages (
      id TEXT PRIMARY KEY,
      promotionId TEXT NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
      userId TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
      bookingId TEXT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
      isReversed INTEGER NOT NULL DEFAULT 0 CHECK(isReversed IN (0,1)),
      createdAt TEXT NOT NULL,
      UNIQUE(promotionId, userId, bookingId)
    )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_promo_usage_user ON promotion_usages(userId, promotionId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_promo_usage_booking ON promotion_usages(bookingId)',
    );

    // 4. Bảng app_notifications
    await db.execute('''CREATE TABLE IF NOT EXISTS app_notifications (
      id TEXT PRIMARY KEY,
      userId TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
      bookingId TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      type TEXT NOT NULL,
      refundAmount REAL,
      refundMethod TEXT,
      refundExpectedAt TEXT,
      refundStatus TEXT,
      isRead INTEGER NOT NULL DEFAULT 0 CHECK(isRead IN (0,1))
    )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_user ON app_notifications(userId)',
    );
  }
}
