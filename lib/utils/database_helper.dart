import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

/// SQLite database shared by venue, booking, promotion and notification data.
class DatabaseHelper {
  DatabaseHelper._() : _factory = null, _path = null;
  static final DatabaseHelper instance = DatabaseHelper._();

  @visibleForTesting
  DatabaseHelper.forTesting({required DatabaseFactory factory, required String path})
    : _factory = factory,
      _path = path;

  static const databaseName = 'sport_venue_database.db';
  static const databaseVersion = 3;
  final DatabaseFactory? _factory;
  final String? _path;
  Database? _database;

  Future<Database> get database async {
    final cached = _database;
    if (cached != null && cached.isOpen) return cached;
    final factory = _factory ?? databaseFactory;
    final dbPath = _path ?? path.join(await factory.getDatabasesPath(), databaseName);
    try {
      _database = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) async {
            await _createSchema(db);
            await _seed(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await _upgrade(db, oldVersion, newVersion);
          },
          onOpen: (db) async {
            try {
              await _seed(db);
            } catch (error, stack) {
              debugPrint('[DatabaseHelper] Startup seed failed: $error\n$stack');
              rethrow;
            }
          }
        ),
      );
      return _database!;
    } catch (error, stack) {
      debugPrint('[DatabaseHelper] Open database failed: $error\n$stack');
      rethrow;
    }
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    final statements = <String>[
      '''CREATE TABLE IF NOT EXISTS users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE, phone TEXT UNIQUE, password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'customer' CHECK(role IN ('customer','owner','admin')),
        avatar_url TEXT, is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''',
      '''CREATE TABLE IF NOT EXISTS sport_types (
        sport_type_id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE,
        description TEXT, icon TEXT)''',
      '''CREATE TABLE IF NOT EXISTS venues (
        venue_id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_id INTEGER NOT NULL REFERENCES users(user_id),
        sport_type_id INTEGER NOT NULL REFERENCES sport_types(sport_type_id),
        name TEXT NOT NULL, address TEXT NOT NULL, district TEXT, city TEXT,
        description TEXT, price_per_hour REAL NOT NULL CHECK(price_per_hour >= 0),
        open_time TEXT NOT NULL, close_time TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
        reject_reason TEXT, reviewed_by INTEGER REFERENCES users(user_id), reviewed_at TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''',
      '''CREATE TABLE IF NOT EXISTS venue_images (
        image_id INTEGER PRIMARY KEY AUTOINCREMENT,
        venue_id INTEGER NOT NULL REFERENCES venues(venue_id) ON DELETE CASCADE,
        image_url TEXT NOT NULL, is_primary INTEGER NOT NULL DEFAULT 0 CHECK(is_primary IN (0,1)),
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK(sort_order >= 0),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''',
      '''CREATE TABLE IF NOT EXISTS venue_services (
        service_id INTEGER PRIMARY KEY AUTOINCREMENT,
        venue_id INTEGER NOT NULL REFERENCES venues(venue_id) ON DELETE CASCADE,
        name TEXT NOT NULL, description TEXT, unit TEXT NOT NULL DEFAULT 'lượt',
        price REAL NOT NULL CHECK(price >= 0),
        status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive')))''',
      '''CREATE TABLE IF NOT EXISTS venue_hours (
        venue_hour_id INTEGER PRIMARY KEY AUTOINCREMENT,
        venue_id INTEGER NOT NULL REFERENCES venues(venue_id) ON DELETE CASCADE,
        day_of_week INTEGER NOT NULL CHECK(day_of_week BETWEEN 1 AND 7),
        open_time TEXT NOT NULL, close_time TEXT NOT NULL, is_closed INTEGER NOT NULL DEFAULT 0,
        UNIQUE(venue_id, day_of_week))''',
      '''CREATE TABLE IF NOT EXISTS time_slots (
        slot_id INTEGER PRIMARY KEY AUTOINCREMENT,
        venue_id INTEGER NOT NULL REFERENCES venues(venue_id) ON DELETE CASCADE,
        slot_date TEXT NOT NULL, start_time TEXT NOT NULL, end_time TEXT NOT NULL,
        price REAL NOT NULL, status TEXT NOT NULL DEFAULT 'available'
          CHECK(status IN ('available','booked','blocked')),
        UNIQUE(venue_id, slot_date, start_time))''',
      '''CREATE TABLE IF NOT EXISTS bookings (
        booking_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(user_id),
        slot_id INTEGER NOT NULL REFERENCES time_slots(slot_id),
        promo_id INTEGER REFERENCES promotions(promo_id), original_amount REAL NOT NULL,
        service_amount REAL NOT NULL DEFAULT 0 CHECK(service_amount >= 0),
        discount_amount REAL NOT NULL DEFAULT 0, total_amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','confirmed','cancelled','completed')),
        payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK(payment_status IN ('unpaid','paid','refunded')),
        note TEXT, cancel_reason TEXT, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        cancelled_at TEXT, CHECK(total_amount = original_amount + service_amount - discount_amount))''',
      '''CREATE TABLE IF NOT EXISTS booking_services (
        booking_service_id INTEGER PRIMARY KEY AUTOINCREMENT,
        booking_id INTEGER NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
        service_id INTEGER NOT NULL REFERENCES venue_services(service_id), quantity INTEGER NOT NULL CHECK(quantity > 0),
        unit_price REAL NOT NULL CHECK(unit_price >= 0), subtotal REAL NOT NULL CHECK(subtotal = quantity * unit_price))''',
      '''CREATE TABLE IF NOT EXISTS payments (
        payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        booking_id INTEGER NOT NULL REFERENCES bookings(booking_id),
        method TEXT NOT NULL CHECK(method IN ('cash','momo','vnpay','bank_transfer')),
        amount REAL NOT NULL, status TEXT NOT NULL DEFAULT 'pending'
          CHECK(status IN ('pending','success','failed','refunded')),
        transaction_code TEXT UNIQUE, paid_at TEXT, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''',
      '''CREATE TABLE IF NOT EXISTS promotions (
        promo_id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, description TEXT,
        discount_percent REAL NOT NULL CHECK(discount_percent BETWEEN 1 AND 100),
        max_discount_amount REAL, min_order_amount REAL NOT NULL DEFAULT 0,
        start_date TEXT NOT NULL, end_date TEXT NOT NULL, usage_limit INTEGER,
        used_count INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'active'
          CHECK(status IN ('active','inactive')), created_by INTEGER REFERENCES users(user_id))''',
      '''CREATE TABLE IF NOT EXISTS promotion_usages (
        usage_id INTEGER PRIMARY KEY AUTOINCREMENT,
        promo_id INTEGER NOT NULL REFERENCES promotions(promo_id),
        user_id INTEGER NOT NULL REFERENCES users(user_id),
        booking_id INTEGER NOT NULL REFERENCES bookings(booking_id), used_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(promo_id, booking_id))''',
      '''CREATE TABLE IF NOT EXISTS app_notifications (
        notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        title TEXT NOT NULL, body TEXT NOT NULL, type TEXT, related_id INTEGER,
        is_read INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''',
      '''CREATE TABLE IF NOT EXISTS legacy_account_import (
        legacy_id TEXT PRIMARY KEY, user_id INTEGER REFERENCES users(user_id),
        imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, source TEXT, status TEXT NOT NULL DEFAULT 'imported')''',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_venue_images_primary ON venue_images(venue_id) WHERE is_primary = 1',
      'CREATE INDEX IF NOT EXISTS idx_venue_images_venue_order ON venue_images(venue_id, sort_order)',
      'CREATE INDEX IF NOT EXISTS idx_venue_services_venue ON venue_services(venue_id)',
      'CREATE INDEX IF NOT EXISTS idx_booking_services_booking ON booking_services(booking_id)',
      'CREATE INDEX IF NOT EXISTS idx_slots_venue_date ON time_slots(venue_id, slot_date)',
      'CREATE INDEX IF NOT EXISTS idx_bookings_user ON bookings(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments(booking_id)',
    ];
    for (final sql in statements) {
      await db.execute(sql);
    }
  }

  /// Additive migrations: IF NOT EXISTS preserves every existing user and booking row.
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    try {
      await db.transaction((txn) async {
        // Earlier app builds had account-only databases and may have partial schemas.
        // Create missing v3 structures without dropping or rebuilding existing tables.
        final oldServices = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=lower(?)",
          ['Services'],
        );
        final newServices = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=lower(?)",
          ['venue_services'],
        );
        if (oldServices.isNotEmpty && newServices.isEmpty) {
          await txn.execute('ALTER TABLE Services RENAME TO venue_services');
        }
        await _createSchema(txn);
        if (oldVersion < 3) await _seed(txn);
      });
    } catch (error, stack) {
      debugPrint('[DatabaseHelper] Migration $oldVersion->$newVersion failed: $error\n$stack');
      rethrow;
    }
  }

  Future<void> _seed(DatabaseExecutor db) async {
    const sports = [
      (1, 'Bóng đá mini', 'Sân cỏ nhân tạo 5-7 người', 'soccer'),
      (2, 'Cầu lông', 'Sân cầu lông trong nhà', 'badminton'),
      (3, 'Tennis', 'Sân tennis', 'tennis'),
      (4, 'Bóng rổ', 'Sân bóng rổ', 'basketball'),
      (5, 'Pickleball', 'Sân pickleball', 'pickleball'),
    ];
    for (final row in sports) {
      await db.insert('sport_types', {
        'sport_type_id': row.$1, 'name': row.$2, 'description': row.$3, 'icon': row.$4,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // A disabled local owner provides the FK parent for demo venues; it cannot sign in.
    var owners = await db.query('users', columns: ['user_id'], where: 'role = ?', whereArgs: ['owner'], limit: 1);
    if (owners.isEmpty) {
      await db.insert('users', {
        'full_name': 'Tài khoản dữ liệu mẫu',
        'email': 'seed-owner@invalid.local',
        'password_hash': 'disabled-seed-account',
        'role': 'owner',
        'is_active': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      owners = await db.query('users', columns: ['user_id'], where: 'role = ?', whereArgs: ['owner'], limit: 1);
    }
    if (owners.isEmpty) return;
    final ownerId = owners.first['user_id'];
    const samples = [
      (1, 'Sân bóng Thống Nhất', '12 Lê Văn Việt', 300000.0, 1),
      (2, 'Sân cầu lông Tân Bình', '88 Cộng Hòa', 120000.0, 2),
      (3, 'Tennis Thảo Điền', '7 Xuân Thủy', 250000.0, 3),
    ];
    for (final sample in samples) {
      var venueId = sample.$1;
      final found = await db.query('venues', columns: ['venue_id'], where: 'name = ?', whereArgs: [sample.$2], limit: 1);
      if (found.isEmpty) {
        await db.insert('venues', {
          'venue_id': sample.$1, 'owner_id': ownerId, 'sport_type_id': sample.$5,
          'name': sample.$2, 'address': sample.$3, 'city': 'TP.HCM',
          'price_per_hour': sample.$4, 'open_time': '06:00', 'close_time': '22:00', 'status': 'approved',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      // Resolve by natural key in case a user row already occupied the sample ID.
      final resolved = await db.query('venues', columns: ['venue_id'],
        where: 'name = ?', whereArgs: [sample.$2], limit: 1);
      if (resolved.isEmpty) continue;
      venueId = resolved.first['venue_id'] as int;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      for (var hour = 6; hour < 9; hour++) {
        final start = '${hour.toString().padLeft(2, '0')}:00';
        final end = '${(hour + 1).toString().padLeft(2, '0')}:00';
        await db.insert('time_slots', {
          'venue_id': venueId, 'slot_date': today, 'start_time': start, 'end_time': end,
          'price': sample.$4, 'status': 'available',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    debugPrint('[DatabaseHelper] Seed completed (duplicate-safe).');
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) await db.close();
  }
}
