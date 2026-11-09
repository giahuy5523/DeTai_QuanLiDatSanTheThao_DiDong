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

  /// Version 1 used an incompatible, plain-text `users` table.
  /// Giữ nguyên logic migration V2 gốc của Quốc Đạt.
  Future<void> _upgradeToV2(DatabaseExecutor txn) async {
    final preserved = <String, List<Map<String, Object?>>>{};
    for (final table in [
      'sport_types',
      'venues',
      'venue_images',
      'venue_services',
      'promotions',
      'bookings',
      'payments',
    ]) {
      try {
        preserved[table] = await txn.query(table);
      } on DatabaseException {
        preserved[table] = [];
      }
    }
    final existing = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='users'",
    );
    if (existing.isNotEmpty) {
      await txn.execute('ALTER TABLE users RENAME TO legacy_users_v1');
    }
    for (final table in [
      'venue_images',
      'venue_services',
      'payments',
      'bookings',
      'venues',
      'promotions',
      'sport_types',
    ]) {
      await txn.execute('DROP TABLE IF EXISTS $table');
    }
    // Tạo cấu trúc cơ bản V2
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
      final rows = await txn.query('legacy_users_v1');
      for (final row in rows) {
        await txn.insert('legacy_account_import', {
          'user_id': row['id'],
          'full_name': row['name'],
          'email': row['email'],
          'phone': row['phone'],
          'password': row['password'],
          'role': row['role'] ?? 'customer',
          'avatar_path': row['avatarPath'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert('Users', {
          'user_id': row['id'],
          'full_name': row['name'],
          'email': row['email'],
          'phone': row['phone'],
          'password_hash': 'migration-pending',
          'role': row['role'] ?? 'customer',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.execute('DROP TABLE legacy_users_v1');
    }
    for (final table in [
      'sport_types',
      'venues',
      'venue_images',
      'venue_services',
      'promotions',
      'bookings',
      'payments',
    ]) {
      for (final row in preserved[table]!) {
        await txn.insert(
          table,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
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
