import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/account_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/utils/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SQLite Schema V3 & Migration Tests', () {
    test(
      'Tạo mới database với Schema V3 hoàn chỉnh và kiểm tra bảng, cột, indexes',
      () async {
        final db = await databaseFactory.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: DatabaseHelper.databaseVersion,
            onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: (db, version) => DatabaseHelper().createSchema(db),
          ),
        );

        // Kiểm tra trực tiếp database vừa được tạo.

        // Kiểm tra bảng payments có các cột refund
        expect(
          await DatabaseHelper.columnExists(db, 'payments', 'refundAmount'),
          isTrue,
        );
        expect(
          await DatabaseHelper.columnExists(db, 'payments', 'refundMethod'),
          isTrue,
        );
        expect(
          await DatabaseHelper.columnExists(db, 'payments', 'refundStatus'),
          isTrue,
        );
        expect(
          await DatabaseHelper.columnExists(db, 'payments', 'refundExpectedAt'),
          isTrue,
        );

        // Kiểm tra bảng booking_services có serviceName
        expect(
          await DatabaseHelper.columnExists(
            db,
            'booking_services',
            'serviceName',
          ),
          isTrue,
        );

        // Kiểm tra bảng promotion_usages
        final promoUsageInfo = await db.rawQuery(
          'PRAGMA table_info(promotion_usages)',
        );
        expect(promoUsageInfo.isNotEmpty, isTrue);
        expect(promoUsageInfo.any((c) => c['name'] == 'promotionId'), isTrue);
        expect(promoUsageInfo.any((c) => c['name'] == 'userId'), isTrue);
        expect(promoUsageInfo.any((c) => c['name'] == 'bookingId'), isTrue);
        expect(promoUsageInfo.any((c) => c['name'] == 'isReversed'), isTrue);

        // Kiểm tra bảng app_notifications
        final notifInfo = await db.rawQuery(
          'PRAGMA table_info(app_notifications)',
        );
        expect(notifInfo.isNotEmpty, isTrue);
        expect(notifInfo.any((c) => c['name'] == 'title'), isTrue);
        expect(notifInfo.any((c) => c['name'] == 'type'), isTrue);
        expect(notifInfo.any((c) => c['name'] == 'refundAmount'), isTrue);
        expect(notifInfo.any((c) => c['name'] == 'isRead'), isTrue);

        final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index'",
        );
        final indexNames = indexes.map((row) => row['name']).toSet();

        expect(indexNames, contains('idx_promo_usage_user'));
        expect(indexNames, contains('idx_promo_usage_booking'));
        expect(indexNames, contains('idx_notifications_user'));
        expect(indexNames, contains('idx_bookings_venue_date'));

        await db.close();
      },
    );

    test(
      'Nâng cấp an toàn từ V2 lên V3 không làm mất dữ liệu venues và payments cũ',
      () async {
        final dbName =
            'test_migrate_v2_to_v3_${DateTime.now().microsecondsSinceEpoch}.db';
        final path = p.join(await databaseFactory.getDatabasesPath(), dbName);

        // 1. Giả lập khởi tạo Database ở Version 2 (schema của Quốc Đạt)
        var testDb = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 2,
            onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: (db, version) async {
              // Tạo Users và Venues và Payments kiểu V2 (chưa có cột refund)
              await db.execute('''CREATE TABLE Users (
              user_id TEXT PRIMARY KEY, full_name TEXT NOT NULL,
              email TEXT NOT NULL COLLATE NOCASE UNIQUE, phone TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL, role TEXT NOT NULL, avatar_path TEXT,
              is_active INTEGER NOT NULL DEFAULT 1
            )''');
              await db.execute('''CREATE TABLE venues (
              id TEXT PRIMARY KEY, ownerId TEXT NOT NULL REFERENCES Users(user_id),
              sportType TEXT NOT NULL, name TEXT NOT NULL, address TEXT NOT NULL,
              pricePerHour REAL NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL,
              status TEXT NOT NULL DEFAULT 'approved', rating REAL NOT NULL DEFAULT 0
            )''');
              await db.execute('''CREATE TABLE promotions (
              id TEXT PRIMARY KEY, code TEXT NOT NULL UNIQUE,
              discountPercent REAL NOT NULL, expiryDate TEXT NOT NULL,
              isActive INTEGER NOT NULL DEFAULT 1, usedCount INTEGER NOT NULL DEFAULT 0
            )''');
              await db.execute('''CREATE TABLE bookings (
              id TEXT PRIMARY KEY, venueId TEXT NOT NULL REFERENCES venues(id),
              userId TEXT NOT NULL REFERENCES Users(user_id),
              date TEXT NOT NULL, startTime TEXT NOT NULL, endTime TEXT NOT NULL,
              totalPrice REAL NOT NULL, status TEXT NOT NULL DEFAULT 'confirmed',
              paymentStatus TEXT NOT NULL DEFAULT 'paid', createdAt TEXT NOT NULL
            )''');
              await db.execute('''CREATE TABLE booking_services (
              id TEXT PRIMARY KEY, bookingId TEXT NOT NULL REFERENCES bookings(id),
              serviceId TEXT NOT NULL, quantity INTEGER NOT NULL, unitPrice REAL NOT NULL,
              subtotal REAL NOT NULL
            )''');
              await db.execute('''CREATE TABLE payments (
              id TEXT PRIMARY KEY, bookingId TEXT NOT NULL REFERENCES bookings(id),
              method TEXT NOT NULL, amount REAL NOT NULL, status TEXT NOT NULL,
              createdAt TEXT NOT NULL
            )''');
            },
          ),
        );

        // Chèn dữ liệu mẫu vào V2
        await testDb.insert('Users', {
          'user_id': 'u1',
          'full_name': 'Nguyen Van A',
          'email': 'a@example.com',
          'phone': '0901234567',
          'password_hash': 'hash123',
          'role': 'customer',
        });
        await testDb.insert('venues', {
          'id': 'v1',
          'ownerId': 'u1',
          'sportType': 'Bóng đá',
          'name': 'Sân Bóng A',
          'address': '123 Đường A',
          'pricePerHour': 200000.0,
          'latitude': 10.1,
          'longitude': 106.1,
        });
        await testDb.insert('promotions', {
          'id': 'promo1',
          'code': 'TEST10',
          'discountPercent': 10.0,
          'expiryDate': '2026-12-31',
          'isActive': 1,
          'usedCount': 0,
        });
        await testDb.insert('bookings', {
          'id': 'b1',
          'venueId': 'v1',
          'userId': 'u1',
          'date': '2026-11-08',
          'startTime': '08:00',
          'endTime': '10:00',
          'totalPrice': 400000.0,
          'createdAt': '2026-11-08T08:00:00',
        });
        await testDb.insert('payments', {
          'id': 'p1',
          'bookingId': 'b1',
          'method': 'momo',
          'amount': 400000.0,
          'status': 'success',
          'createdAt': '2026-11-08T08:00:00',
        });
        await testDb.insert('booking_services', {
          'id': 'bs1',
          'bookingId': 'b1',
          'serviceId': 's1',
          'quantity': 2,
          'unitPrice': 15000.0,
          'subtotal': 30000.0,
        });

        await testDb.close();

        // 2. Mở lại với Version 3 bằng cách chạy logic upgrade V3
        testDb = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 3,
            onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
            onUpgrade: (db, oldVersion, newVersion) async {
              await DatabaseHelper().upgradeSchema(db, oldVersion);
            },
          ),
        );

        // 3. Kiểm tra dữ liệu cũ VẪN CÒN NGUYÊN VẸN
        final venues = await testDb.query('venues');
        expect(venues.length, equals(1));
        expect(venues.first['name'], equals('Sân Bóng A'));

        final payments = await testDb.query('payments');
        expect(payments.length, equals(1));
        expect(payments.first['amount'], equals(400000.0));
        expect(
          payments.first['refundAmount'],
          isNull,
        ); // Cột mới thêm có giá trị null cho dòng cũ

        // 4. Kiểm tra cập nhật trên cột mới
        await testDb.update(
          'payments',
          {'refundAmount': 400000.0, 'refundStatus': 'processing'},
          where: 'id = ?',
          whereArgs: ['p1'],
        );

        final updatedPayment = await testDb.query(
          'payments',
          where: 'id = ?',
          whereArgs: ['p1'],
        );
        expect(updatedPayment.first['refundAmount'], equals(400000.0));
        expect(updatedPayment.first['refundStatus'], equals('processing'));

        // 5. Kiểm tra chèn vào bảng mới promotion_usages và ràng buộc UNIQUE
        await testDb.insert('promotion_usages', {
          'id': 'pu1',
          'promotionId': 'promo1',
          'userId': 'u1',
          'bookingId': 'b1',
          'isReversed': 0,
          'createdAt': '2026-11-08T09:00:00',
        });

        // Insert trùng cặp (promotionId, userId, bookingId) phải ném ngoại lệ UNIQUE
        expect(
          () => testDb.insert('promotion_usages', {
            'id': 'pu2',
            'promotionId': 'promo1',
            'userId': 'u1',
            'bookingId': 'b1',
            'isReversed': 0,
            'createdAt': '2026-11-08T09:01:00',
          }),
          throwsA(isA<DatabaseException>()),
        );

        await testDb.close();
        await databaseFactory.deleteDatabase(path);
      },
    );

    test(
      'Nâng cấp V1 bảo toàn dịch vụ booking, lịch sân, giờ mở cửa và payment',
      () async {
        final dbName =
            'test_migrate_v1_to_v3_${DateTime.now().microsecondsSinceEpoch}.db';
        final path = p.join(await databaseFactory.getDatabasesPath(), dbName);

        var db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: (db, version) async {
              await db.execute('''CREATE TABLE users (
                id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL,
                phone TEXT NOT NULL, password TEXT NOT NULL, role TEXT,
                avatarPath TEXT
              )''');
              await db.execute('''CREATE TABLE Session (
                id INTEGER PRIMARY KEY CHECK(id = 1),
                user_id TEXT NOT NULL REFERENCES users(id),
                expires_at INTEGER NOT NULL
              )''');
              await db.execute('''CREATE TABLE sport_types (
                sportTypeId INTEGER PRIMARY KEY, name TEXT NOT NULL,
                description TEXT, icon TEXT
              )''');
              await db.execute('''CREATE TABLE venues (
                id TEXT PRIMARY KEY, ownerId TEXT NOT NULL REFERENCES users(id),
                sportTypeId INTEGER REFERENCES sport_types(sportTypeId),
                sportType TEXT NOT NULL, name TEXT NOT NULL, address TEXT NOT NULL,
                district TEXT, city TEXT, pricePerHour REAL NOT NULL,
                latitude REAL NOT NULL, longitude REAL NOT NULL,
                status TEXT NOT NULL, rating REAL NOT NULL
              )''');
              await db.execute('''CREATE TABLE venue_images (
                id TEXT PRIMARY KEY, venueId TEXT NOT NULL REFERENCES venues(id),
                imageUrl TEXT NOT NULL, isPrimary INTEGER NOT NULL,
                sortOrder INTEGER NOT NULL
              )''');
              await db.execute('''CREATE TABLE venue_services (
                id TEXT PRIMARY KEY, venueId TEXT NOT NULL REFERENCES venues(id),
                name TEXT NOT NULL, price REAL NOT NULL, unit TEXT NOT NULL
              )''');
              await db.execute('''CREATE TABLE promotions (
                id TEXT PRIMARY KEY, code TEXT NOT NULL, discountPercent REAL NOT NULL,
                expiryDate TEXT NOT NULL, isActive INTEGER NOT NULL, usedCount INTEGER NOT NULL
              )''');
              await db.execute('''CREATE TABLE bookings (
                id TEXT PRIMARY KEY, venueId TEXT NOT NULL REFERENCES venues(id),
                userId TEXT NOT NULL REFERENCES users(id), date TEXT NOT NULL,
                startTime TEXT NOT NULL, endTime TEXT NOT NULL, totalPrice REAL NOT NULL,
                originalAmount REAL NOT NULL, serviceAmount REAL NOT NULL,
                discountAmount REAL NOT NULL, status TEXT NOT NULL,
                paymentStatus TEXT NOT NULL, paymentId TEXT, promoId TEXT REFERENCES promotions(id),
                promotionCode TEXT, note TEXT, cancelReason TEXT, cancelledAt TEXT,
                createdAt TEXT NOT NULL
              )''');
              await db.execute('''CREATE TABLE booking_services (
                id TEXT PRIMARY KEY, bookingId TEXT NOT NULL REFERENCES bookings(id),
                serviceId TEXT NOT NULL REFERENCES venue_services(id),
                quantity INTEGER NOT NULL, unitPrice REAL NOT NULL, subtotal REAL NOT NULL
              )''');
              await db.execute('''CREATE TABLE payments (
                id TEXT PRIMARY KEY, bookingId TEXT NOT NULL REFERENCES bookings(id),
                method TEXT NOT NULL, amount REAL NOT NULL, status TEXT NOT NULL,
                transactionCode TEXT, paidAt TEXT, createdAt TEXT NOT NULL
              )''');
              await db.execute('''CREATE TABLE time_slots (
                id TEXT PRIMARY KEY, venueId TEXT NOT NULL REFERENCES venues(id),
                slotDate TEXT NOT NULL, startTime TEXT NOT NULL, endTime TEXT NOT NULL,
                price REAL NOT NULL, status TEXT NOT NULL
              )''');
              await db.execute('''CREATE TABLE venue_hours (
                venueId TEXT PRIMARY KEY REFERENCES venues(id),
                openHour INTEGER NOT NULL, closeHour INTEGER NOT NULL
              )''');
            },
          ),
        );

        await db.insert('users', {
          'id': 'owner1',
          'name': 'Legacy Owner',
          'email': 'owner@example.com',
          'phone': '0900000001',
          'password': 'legacy-password',
          'role': 'owner',
        });
        await db.insert('Session', {
          'id': 1,
          'user_id': 'owner1',
          'expires_at': DateTime.now()
              .add(const Duration(days: 10))
              .millisecondsSinceEpoch,
        });
        await db.insert('sport_types', {'sportTypeId': 1, 'name': 'Football'});
        await db.insert('venues', {
          'id': 'v1',
          'ownerId': 'owner1',
          'sportTypeId': 1,
          'sportType': 'Football',
          'name': 'Legacy Venue',
          'address': 'Old address',
          'pricePerHour': 200000.0,
          'latitude': 10.0,
          'longitude': 106.0,
          'status': 'approved',
          'rating': 4.5,
        });
        await db.insert('venue_images', {
          'id': 'img1',
          'venueId': 'v1',
          'imageUrl': 'legacy.jpg',
          'isPrimary': 1,
          'sortOrder': 0,
        });
        await db.insert('venue_services', {
          'id': 's1',
          'venueId': 'v1',
          'name': 'Water',
          'price': 10000.0,
          'unit': 'bottle',
        });
        await db.insert('promotions', {
          'id': 'promo1',
          'code': 'OLD10',
          'discountPercent': 10.0,
          'expiryDate': '2027-01-01',
          'isActive': 1,
          'usedCount': 1,
        });
        await db.insert('bookings', {
          'id': 'b1',
          'venueId': 'v1',
          'userId': 'owner1',
          'date': '2026-11-10',
          'startTime': '08:00',
          'endTime': '09:00',
          'totalPrice': 190000.0,
          'originalAmount': 200000.0,
          'serviceAmount': 10000.0,
          'discountAmount': 20000.0,
          'status': 'confirmed',
          'paymentStatus': 'paid',
          'promoId': 'promo1',
          'createdAt': '2026-11-10T08:00:00',
        });
        await db.insert('booking_services', {
          'id': 'bs1',
          'bookingId': 'b1',
          'serviceId': 's1',
          'quantity': 1,
          'unitPrice': 10000.0,
          'subtotal': 10000.0,
        });
        await db.insert('payments', {
          'id': 'p1',
          'bookingId': 'b1',
          'method': 'momo',
          'amount': 190000.0,
          'status': 'success',
          'createdAt': '2026-11-10T09:00:00',
        });
        await db.insert('time_slots', {
          'id': 'ts1',
          'venueId': 'v1',
          'slotDate': '2026-11-10',
          'startTime': '08:00',
          'endTime': '09:00',
          'price': 200000.0,
          'status': 'booked',
        });
        await db.insert('venue_hours', {
          'venueId': 'v1',
          'openHour': 6,
          'closeHour': 22,
        });
        await db.close();

        db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: DatabaseHelper.databaseVersion,
            onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
            onUpgrade: (db, oldVersion, newVersion) async {
              await DatabaseHelper().upgradeSchema(db, oldVersion);
            },
          ),
        );

        expect((await db.query('venues')).length, 1);
        expect((await db.query('Session')).single['user_id'], 'owner1');
        expect((await db.query('venue_images')).length, 1);
        expect((await db.query('venue_services')).length, 1);
        expect((await db.query('bookings')).length, 1);
        expect((await db.query('booking_services')).length, 1);
        expect((await db.query('payments')).length, 1);
        expect((await db.query('time_slots')).length, 1);
        expect((await db.query('venue_hours')).length, 1);
        expect(
          (await db.query('booking_services')).single['serviceName'],
          isNull,
        );
        expect((await db.query('payments')).single['refundAmount'], isNull);
        expect(
          (await db.query('legacy_account_import')).single['password'],
          'legacy-password',
        );

        // Kiểm tra không có bản ghi mồ côi sau migration V1 -> V3.
        final foreignKeyViolations = await db.rawQuery(
          'PRAGMA foreign_key_check',
        );
        expect(
          foreignKeyViolations,
          isEmpty,
          reason:
              'Migration V1 -> V3 tạo ra lỗi toàn vẹn khóa ngoại: '
              '$foreignKeyViolations',
        );

        // AccountRepository consumes the legacy staging table inside the
        // same shared database and hashes the old plaintext password.
        final accountRepository = await AccountRepository.open(
          seed: const [],
          database: db,
        );
        final migratedUser = (await db.query(
          'Users',
          where: 'user_id = ?',
          whereArgs: ['owner1'],
        )).single;
        expect(migratedUser['password_hash'], isNot('migration-pending'));
        expect(migratedUser['password_hash'], contains(':'));
        expect(
          await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='legacy_account_import'",
          ),
          isEmpty,
        );
        expect(
          (await accountRepository.login(
            'owner@example.com',
            'legacy-password',
          ))?.id,
          'owner1',
        );

        await db.close();
        await databaseFactory.deleteDatabase(path);
      },
    );

    test(
      'Kiểm tra importLegacyAccountDatabase không làm mất tài khoản và Session',
      () async {
        final legacyPath = p.join(
          await databaseFactory.getDatabasesPath(),
          'test_legacy_accounts_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final legacyDb = await databaseFactory.openDatabase(
          legacyPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''CREATE TABLE Users (
              user_id TEXT PRIMARY KEY, full_name TEXT NOT NULL,
              email TEXT NOT NULL COLLATE NOCASE UNIQUE, phone TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL, role TEXT NOT NULL, avatar_path TEXT,
              is_active INTEGER NOT NULL DEFAULT 1
            )''');
              await db.execute('''CREATE TABLE Session (
              id INTEGER PRIMARY KEY CHECK(id = 1),
              user_id TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
              expires_at INTEGER NOT NULL
            )''');
            },
          ),
        );

        await legacyDb.insert('Users', {
          'user_id': 'legacy_user_1',
          'full_name': 'Legacy User One',
          'email': 'legacy@example.com',
          'phone': '0987654321',
          'password_hash': 'secret_hash_legacy',
          'role': 'customer',
        });
        await legacyDb.insert('Users', {
          'user_id': 'existing_user',
          'full_name': 'Old Profile',
          'email': 'old-profile@example.com',
          'phone': '0987654322',
          'password_hash': 'old_hash',
          'role': 'customer',
        });

        await legacyDb.insert('Users', {
          'user_id': 'legacy_email_conflict',
          'full_name': 'Legacy Email Conflict',
          'email': ' CURRENT-EMAIL@example.com ',
          'phone': '0987654323',
          'password_hash': 'legacy_hash_email',
          'role': 'customer',
        });

        await legacyDb.insert('Users', {
          'user_id': 'legacy_phone_conflict',
          'full_name': 'Legacy Phone Conflict',
          'email': 'legacy-phone@example.com',
          'phone': '0911111112',
          'password_hash': 'legacy_hash_phone',
          'role': 'customer',
        });
        await legacyDb.insert('Session', {
          'id': 1,
          'user_id': 'legacy_user_1',
          'expires_at': DateTime.now()
              .add(const Duration(days: 15))
              .millisecondsSinceEpoch,
        });
        await legacyDb.close();

        // Target database
        final targetPath = p.join(
          await databaseFactory.getDatabasesPath(),
          'test_target_import_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final targetDb = await databaseFactory.openDatabase(
          targetPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''CREATE TABLE Users (
              user_id TEXT PRIMARY KEY, full_name TEXT NOT NULL,
              email TEXT NOT NULL COLLATE NOCASE UNIQUE, phone TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL, role TEXT NOT NULL, avatar_path TEXT,
              is_active INTEGER NOT NULL DEFAULT 1
            )''');
              await db.execute('''CREATE TABLE Session (
              id INTEGER PRIMARY KEY CHECK(id = 1),
              user_id TEXT NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
              expires_at INTEGER NOT NULL
            )''');
            },
          ),
        );

        // User cùng ID đã tồn tại trong DB chính phải được giữ nguyên.
        await targetDb.insert('Users', {
          'user_id': 'existing_user',
          'full_name': 'Current Profile',
          'email': 'current-profile@example.com',
          'phone': '0911111111',
          'password_hash': 'current_hash',
          'role': 'customer',
        });

        await targetDb.insert('Users', {
          'user_id': 'current_email_owner',
          'full_name': 'Current Email Owner',
          'email': 'current-email@example.com',
          'phone': '0911111113',
          'password_hash': 'current_hash',
          'role': 'customer',
        });

        await targetDb.insert('Users', {
          'user_id': 'current_phone_owner',
          'full_name': 'Current Phone Owner',
          'email': 'current-phone@example.com',
          'phone': '0911111112',
          'password_hash': 'current_hash',
          'role': 'customer',
        });

        // Thực hiện import
        await AccountRepository.importLegacyAccountDatabase(
          targetDb,
          legacyPath: legacyPath,
        );

        final existingUser = await targetDb.query(
          'Users',
          where: 'user_id = ?',
          whereArgs: ['existing_user'],
        );
        expect(existingUser.single['full_name'], 'Current Profile');

        // Existing real account must be preserved and its legacy collision recorded.
        final conflicts = await targetDb.query(
          'legacy_account_import_conflicts',
          where: 'user_id = ?',
          whereArgs: ['existing_user'],
        );
        expect(conflicts.length, 1);
        expect(conflicts.single['reason'], 'existing_user_id_conflict');

        final emailConflict = await targetDb.query(
          'legacy_account_import_conflicts',
          where: 'user_id = ?',
          whereArgs: ['legacy_email_conflict'],
        );

        expect(emailConflict.length, 1);
        expect(
          emailConflict.single['reason'],
          'email_conflict:current_email_owner',
        );

        final phoneConflict = await targetDb.query(
          'legacy_account_import_conflicts',
          where: 'user_id = ?',
          whereArgs: ['legacy_phone_conflict'],
        );

        expect(phoneConflict.length, 1);
        expect(
          phoneConflict.single['reason'],
          'phone_conflict:current_phone_owner',
        );

        final preservedEmailOwner = await targetDb.query(
          'Users',
          where: 'user_id = ?',
          whereArgs: ['current_email_owner'],
        );

        expect(preservedEmailOwner.single['full_name'], 'Current Email Owner');

        final preservedPhoneOwner = await targetDb.query(
          'Users',
          where: 'user_id = ?',
          whereArgs: ['current_phone_owner'],
        );

        expect(preservedPhoneOwner.single['full_name'], 'Current Phone Owner');

        final importedUsers = await targetDb.query(
          'Users',
          where: 'user_id = ?',
          whereArgs: ['legacy_user_1'],
        );
        expect(importedUsers.length, equals(1));
        expect(importedUsers.first['email'], equals('legacy@example.com'));
        expect(
          importedUsers.first['password_hash'],
          equals('secret_hash_legacy'),
        );

        final importedSession = await targetDb.query(
          'Session',
          where: 'id = 1',
        );
        expect(importedSession.length, equals(1));
        expect(importedSession.first['user_id'], equals('legacy_user_1'));

        // A second startup must not overwrite a locally edited account or
        // replace a newer, valid session with the legacy session.
        await targetDb.update(
          'Users',
          {'full_name': 'Edited In Main Database'},
          where: 'user_id = ?',
          whereArgs: ['legacy_user_1'],
        );
        await targetDb.insert('Users', {
          'user_id': 'current_user',
          'full_name': 'Current User',
          'email': 'current@example.com',
          'phone': '0912345678',
          'password_hash': 'current_hash',
          'role': 'customer',
        });
        await targetDb.insert('Session', {
          'id': 1,
          'user_id': 'current_user',
          'expires_at': DateTime.now()
              .add(const Duration(days: 20))
              .millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await AccountRepository.importLegacyAccountDatabase(
          targetDb,
          legacyPath: legacyPath,
        );

        final preservedUser = await targetDb.query(
          'Users',
          where: 'user_id = ?',
          whereArgs: ['legacy_user_1'],
        );
        expect(preservedUser.single['full_name'], 'Edited In Main Database');
        final preservedSession = await targetDb.query(
          'Session',
          where: 'id = 1',
        );
        expect(preservedSession.single['user_id'], 'current_user');

        final migrationMarker = await targetDb.query(
          'account_migrations',
          where: 'name = ?',
          whereArgs: ['standalone_accounts_v1'],
        );
        expect(migrationMarker.length, 1);

        await targetDb.close();
        await databaseFactory.deleteDatabase(targetPath);
        await databaseFactory.deleteDatabase(legacyPath);
      },
    );
    test(
      'Migration V1 rollback nếu schema Session cũ không tương thích',
      () async {
        final dbName =
            'test_migrate_v1_invalid_session_${DateTime.now().microsecondsSinceEpoch}.db';
        final path = p.join(await databaseFactory.getDatabasesPath(), dbName);
        final db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE users (
                  id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL,
                  phone TEXT NOT NULL, password TEXT NOT NULL, role TEXT
                )
              ''');
              await db.execute('''
                CREATE TABLE Session (
                  id INTEGER PRIMARY KEY, user_id TEXT NOT NULL
                )
              ''');
              await db.insert('users', {
                'id': 'u1',
                'name': 'Legacy User',
                'email': 'legacy@example.com',
                'phone': '0900000001',
                'password': 'legacy-password',
                'role': 'customer',
              });
              await db.insert('Session', {'id': 1, 'user_id': 'u1'});
            },
          ),
        );

        await expectLater(
          db.transaction((txn) => DatabaseHelper().upgradeSchema(txn, 1)),
          throwsA(isA<StateError>()),
        );

        expect((await db.query('users')).single['id'], 'u1');
        expect((await db.query('Session')).single['user_id'], 'u1');
        await db.close();
        await databaseFactory.deleteDatabase(path);
      },
    );

    test(
      'Migration V1 rollback rõ ràng khi role cũ không thuộc danh sách hỗ trợ',
      () async {
        final dbName =
            'test_migrate_v1_invalid_role_${DateTime.now().microsecondsSinceEpoch}.db';
        final path = p.join(await databaseFactory.getDatabasesPath(), dbName);
        final db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE users (
                  id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL,
                  phone TEXT NOT NULL, password TEXT NOT NULL, role TEXT
                )
              ''');
              await db.insert('users', {
                'id': 'u1',
                'name': 'Legacy User',
                'email': 'legacy@example.com',
                'phone': '0900000001',
                'password': 'legacy-password',
                'role': 'venue_manager',
              });
            },
          ),
        );

        await expectLater(
          db.transaction((txn) => DatabaseHelper().upgradeSchema(txn, 1)),
          throwsA(isA<StateError>()),
        );

        final preserved = await db.query('users');
        expect(preserved.single['id'], 'u1');
        expect(preserved.single['role'], 'venue_manager');
        await db.close();
        await databaseFactory.deleteDatabase(path);
      },
    );
  });
}
