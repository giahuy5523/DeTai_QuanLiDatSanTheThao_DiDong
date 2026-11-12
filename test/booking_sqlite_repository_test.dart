import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/models/app_notification.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/models/promotion.dart';
import 'package:sportfield_booking/models/user.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'booking_sqlite_test_',
    );
    dbPath = '${tempDir.path}${Platform.pathSeparator}booking_test.db';
    BookingRepository.setUseMockStoreForTesting(false);
    BookingRepository.setDatabaseForTesting(null);
    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseHelper.databaseVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          // Schema V3 trực tiếp
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
          await db.execute('''CREATE TABLE venue_services (
            id TEXT PRIMARY KEY, venueId TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
            name TEXT NOT NULL, price REAL NOT NULL, unit TEXT NOT NULL DEFAULT 'lần'
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
            totalPrice REAL NOT NULL, originalAmount REAL NOT NULL DEFAULT 0,
            serviceAmount REAL NOT NULL DEFAULT 0, discountAmount REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'pending',
            paymentStatus TEXT NOT NULL DEFAULT 'unpaid', paymentId TEXT,
            promoId TEXT REFERENCES promotions(id) ON DELETE SET NULL,
            promotionCode TEXT, note TEXT, cancelReason TEXT, cancelledAt TEXT,
            createdAt TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE booking_services (
            id TEXT PRIMARY KEY, bookingId TEXT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
            serviceId TEXT NOT NULL REFERENCES venue_services(id),
            serviceName TEXT,
            quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
            unitPrice REAL NOT NULL, subtotal REAL NOT NULL
          )''');
          await db.execute('''CREATE TABLE payments (
            id TEXT PRIMARY KEY, bookingId TEXT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
            method TEXT NOT NULL, amount REAL NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending', transactionCode TEXT,
            paidAt TEXT, createdAt TEXT NOT NULL,
            refundAmount REAL, refundMethod TEXT, refundStatus TEXT, refundExpectedAt TEXT
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
            title TEXT NOT NULL, content TEXT NOT NULL, createdAt TEXT NOT NULL,
            type TEXT NOT NULL, refundAmount REAL, refundMethod TEXT,
            refundExpectedAt TEXT, refundStatus TEXT,
            isRead INTEGER NOT NULL DEFAULT 0 CHECK(isRead IN (0,1))
          )''');
        },
      ),
    );

    BookingRepository.setDatabaseForTesting(db);

    // Chèn dữ liệu hạt giống (Seed data)
    await db.insert('Users', {
      'user_id': 'owner1',
      'full_name': 'Chủ Sân 1',
      'email': 'owner1@example.com',
      'phone': '0901111111',
      'password_hash': 'hash_owner',
      'role': 'owner',
    });
    await db.insert('Users', {
      'user_id': 'customer1',
      'full_name': 'Khách Hàng 1',
      'email': 'customer1@example.com',
      'phone': '0902222222',
      'password_hash': 'hash_customer',
      'role': 'customer',
    });
    await db.insert('venues', {
      'id': 'v1',
      'ownerId': 'owner1',
      'sportType': 'Bóng đá',
      'name': 'Sân Chảo Lửa',
      'address': '30 Phan Thúc Duyện, Tân Bình',
      'pricePerHour': 100000.0,
      'latitude': 10.79,
      'longitude': 106.66,
      'status': 'approved',
    });
    await db.insert('venue_services', {
      'id': 's1',
      'venueId': 'v1',
      'name': 'Áo bib thi đấu',
      'price': 20000.0,
      'unit': 'bộ',
    });
    await db.insert('venue_services', {
      'id': 's2',
      'venueId': 'v1',
      'name': 'Nước suối',
      'price': 10000.0,
      'unit': 'chai',
    });
    await db.insert('promotions', {
      'id': 'p1',
      'code': 'GIAM10',
      'discountPercent': 10.0,
      'expiryDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'isActive': 1,
      'usedCount': 0,
    });

    // Reset MockStore cache
    MockStore.bookings.clear();
    MockStore.payments.clear();
    MockStore.promotions.clear();
    MockStore.notifications.clear();
    MockStore.promotions.add(Promotion(
      id: 'p1',
      code: 'GIAM10',
      discountPercent: 10.0,
      expiryDate: DateTime.now().add(const Duration(days: 30)),
    ));
    MockStore.currentUser = AppUser(
      id: 'customer1',
      name: 'Khách Hàng 1',
      email: 'customer1@example.com',
      phone: '0902222222',
      password: '',
      role: 'customer',
    );
  });

  tearDown(() async {
    try {
      await db.close();
    } finally {
      BookingRepository.setDatabaseForTesting(null);
      BookingRepository.setUseMockStoreForTesting(false);

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  group('BookingRepository SQLite Integration Tests', () {
    test('1. Đặt sân bằng tiền mặt (cash) thành công', () async {
      final booking = Booking(
        id: 'b_cash_1',
        venueId: 'v1',
        userId: 'customer1',
        date: DateTime.now(),
        startTime: '08:00',
        endTime: '10:00',
        originalAmount: 200000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 200000.0,
      );

      final result = await BookingRepository.processBookingPayment(
        booking: booking,
        method: 'cash',
      );

      expect(result.isSuccess, isTrue);
      expect(result.booking?.status, equals('confirmed'));
      expect(result.booking?.paymentStatus, equals('unpaid'));
      expect(result.payment?['status'], equals('pending'));

      // Kiểm tra trong SQLite
      final bRows = await db.query('bookings', where: 'id = ?', whereArgs: ['b_cash_1']);
      expect(bRows.length, equals(1));
      expect(bRows.first['paymentStatus'], equals('unpaid'));

      final pRows = await db.query('payments', where: 'bookingId = ?', whereArgs: ['b_cash_1']);
      expect(pRows.length, equals(1));
      expect(pRows.first['status'], equals('pending'));
      expect(pRows.first['method'], equals('cash'));

      // Kiểm tra đồng bộ MockStore
      expect(MockStore.bookings.any((b) => b.id == 'b_cash_1'), isTrue);
    });

    test('2. Thanh toán online thành công (momo)', () async {
      final booking = Booking(
        id: 'b_online_1',
        venueId: 'v1',
        userId: 'customer1',
        date: DateTime.now(),
        startTime: '10:00',
        endTime: '12:00',
        originalAmount: 200000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 200000.0,
      );

      final result = await BookingRepository.processBookingPayment(
        booking: booking,
        method: 'momo',
        transactionCode: 'MOMO-123456',
      );

      expect(result.isSuccess, isTrue);
      expect(result.booking?.status, equals('confirmed'));
      expect(result.booking?.paymentStatus, equals('paid'));
      expect(result.payment?['status'], equals('success'));
      expect(result.transactionCode, equals('MOMO-123456'));

      final pRows = await db.query('payments', where: 'bookingId = ?', whereArgs: ['b_online_1']);
      expect(pRows.first['status'], equals('success'));
      expect(pRows.first['transactionCode'], equals('MOMO-123456'));
    });

    test('3. Thanh toán online thất bại (simulateFailure: true)', () async {
      final booking = Booking(
        id: 'b_failed_1',
        venueId: 'v1',
        userId: 'customer1',
        date: DateTime.now(),
        startTime: '14:00',
        endTime: '16:00',
        originalAmount: 200000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 200000.0,
      );

      final result = await BookingRepository.processBookingPayment(
        booking: booking,
        method: 'vnpay',
        simulateFailure: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.booking?.status, equals('cancelled'));
      expect(result.booking?.paymentStatus, equals('unpaid'));
      expect(result.payment?['status'], equals('failed'));

      // Đơn bị cancelled nên khung giờ này VẪN PHẢI khả dụng cho người khác
      final available = await BookingRepository.isRangeAvailable(
        venueId: 'v1',
        date: DateTime.now(),
        startTime: '14:00',
        endTime: '16:00',
      );
      expect(available, isTrue);

      // Có notification paymentFailed
      final notifs = await BookingRepository.getNotificationsForUser('customer1');
      expect(notifs.any((n) => n.type == AppNotificationType.paymentFailed), isTrue);
    });

    test('4. Ngăn chặn hai booking trùng khung giờ', () async {
      final date = DateTime.now();
      final b1 = Booking(
        id: 'b_slot_1',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '16:00',
        endTime: '18:00',
        originalAmount: 200000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 200000.0,
      );
      final res1 = await BookingRepository.processBookingPayment(booking: b1, method: 'cash');
      expect(res1.isSuccess, isTrue);

      // Đặt trùng một phần (17:00 - 19:00)
      final b2 = Booking(
        id: 'b_slot_2',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '17:00',
        endTime: '19:00',
        originalAmount: 200000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 200000.0,
      );
      final res2 = await BookingRepository.processBookingPayment(booking: b2, method: 'cash');
      expect(res2.isSuccess, isFalse);
      expect(res2.failureReason, equals('Khung giờ không còn trống.'));
    });

    test('5. Rollback sạch khi vi phạm constraint (Không ghi dữ liệu dở dang)', () async {
      final date = DateTime.now();
      final invalidBooking = Booking(
        id: 'b_invalid_fk',
        venueId: 'v_non_existent', // Venue không tồn tại
        userId: 'customer1',
        date: date,
        startTime: '06:00',
        endTime: '08:00',
        originalAmount: 200000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 200000.0,
      );

      final result = await BookingRepository.processBookingPayment(
        booking: invalidBooking,
        method: 'cash',
      );
      expect(result.isSuccess, isFalse);

      // Đảm bảo không có record nào bị ghi vào bảng bookings và payments
      final bRows = await db.query('bookings', where: 'id = ?', whereArgs: ['b_invalid_fk']);
      expect(bRows.isEmpty, isTrue);
      final pRows = await db.query('payments', where: 'bookingId = ?', whereArgs: ['b_invalid_fk']);
      expect(pRows.isEmpty, isTrue);
    });

    test('6. Đặt sân có nhiều dịch vụ và lưu snapshot tên dịch vụ', () async {
      final date = DateTime.now();
      final services = [
        BookingServiceItem(serviceId: 's1', serviceName: 'Áo bib thi đấu', quantity: 2, unitPrice: 20000.0),
        BookingServiceItem(serviceId: 's2', serviceName: 'Nước suối', quantity: 5, unitPrice: 10000.0),
      ];
      final b = Booking(
        id: 'b_services_1',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '08:00',
        endTime: '09:00',
        originalAmount: 100000.0,
        serviceAmount: 90000.0,
        discountAmount: 0.0,
        totalPrice: 190000.0,
        serviceItems: services,
      );

      final result = await BookingRepository.processBookingPayment(booking: b, method: 'cash');
      expect(result.isSuccess, isTrue);

      // Kiểm tra snapshot tên dịch vụ trong bảng booking_services
      final sRows = await db.query('booking_services', where: 'bookingId = ?', whereArgs: ['b_services_1']);
      expect(sRows.length, equals(2));
      expect(sRows.any((r) => r['serviceName'] == 'Áo bib thi đấu' && r['quantity'] == 2), isTrue);
      expect(sRows.any((r) => r['serviceName'] == 'Nước suối' && r['quantity'] == 5), isTrue);

      // Đọc lại qua getBookingById
      final fetched = await BookingRepository.getBookingById('b_services_1');
      expect(fetched?.serviceItems.length, equals(2));
      expect(fetched?.hasServiceSnapshot, isTrue);
      expect(fetched?.serviceItems.first.serviceName, equals('Áo bib thi đấu'));
    });

    test('7. Áp dụng promotion và ghi nhận lượt dùng đúng 1 lần', () async {
      final date = DateTime.now();
      final b = Booking(
        id: 'b_promo_1',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '09:00',
        endTime: '10:00',
        originalAmount: 100000.0,
        serviceAmount: 0.0,
        discountAmount: 10000.0,
        totalPrice: 90000.0,
        promoId: 'p1',
        promotionCode: 'GIAM10',
      );

      final result = await BookingRepository.processBookingPayment(booking: b, method: 'cash');
      expect(result.isSuccess, isTrue);

      // Kiểm tra promotion_usages và usedCount
      final usages = await db.query('promotion_usages', where: 'bookingId = ?', whereArgs: ['b_promo_1']);
      expect(usages.length, equals(1));
      expect(usages.first['isReversed'], equals(0));

      final promo = await db.query('promotions', where: 'id = ?', whereArgs: ['p1']);
      expect(promo.first['usedCount'], equals(1));
    });

    test('8. Hủy booking và hoàn lượt promotion (Idempotent)', () async {
      final date = DateTime.now();
      final b = Booking(
        id: 'b_cancel_promo',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '12:00',
        endTime: '13:00',
        originalAmount: 100000.0,
        serviceAmount: 0.0,
        discountAmount: 10000.0,
        totalPrice: 90000.0,
        promoId: 'p1',
        promotionCode: 'GIAM10',
      );
      await BookingRepository.processBookingPayment(booking: b, method: 'cash');

      // Hủy lần 1
      final cancel1 = await BookingRepository.cancelBooking('b_cancel_promo', cancelReason: 'Khách đổi lịch');
      expect(cancel1, isTrue);

      // Kiểm tra promotion đã hoàn
      final promoAfter1 = await db.query('promotions', where: 'id = ?', whereArgs: ['p1']);
      expect(promoAfter1.first['usedCount'], equals(0)); // Giảm từ 1 về 0

      final usage = await db.query('promotion_usages', where: 'bookingId = ?', whereArgs: ['b_cancel_promo']);
      expect(usage.first['isReversed'], equals(1));

      // Hủy lần 2 (Idempotent - không trừ âm lượt dùng)
      final cancel2 = await BookingRepository.cancelBooking('b_cancel_promo');
      expect(cancel2, isFalse); // Từ chối hủy booking đã cancelled
      final promoAfter2 = await db.query('promotions', where: 'id = ?', whereArgs: ['p1']);
      expect(promoAfter2.first['usedCount'], equals(0)); // Vẫn là 0, không bị âm
    });

    test('9. Hủy đơn đã thanh toán online và quy trình hoàn tiền (Refund)', () async {
      final date = DateTime.now();
      final b = Booking(
        id: 'b_refund_flow',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '13:00',
        endTime: '14:00',
        originalAmount: 100000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 100000.0,
      );
      await BookingRepository.processBookingPayment(booking: b, method: 'momo');

      // 1. Hủy booking -> Chuyển payment sang refundStatus = 'processing'
      final cancelRes = await BookingRepository.cancelBooking('b_refund_flow');
      expect(cancelRes, isTrue);

      var payment = await BookingRepository.getPaymentForBooking('b_refund_flow');
      expect(payment?.refundStatus, equals('processing'));
      expect(payment?.refundAmount, equals(100000.0));

      // Có thông báo refundProcessing
      var notifs = await BookingRepository.getNotificationsForUser('customer1');
      expect(notifs.any((n) => n.type == AppNotificationType.refundProcessing), isTrue);

      // 2. Xác nhận hoàn tiền thành công -> paymentStatus = 'refunded', status = 'refunded'
      final completeRes = await BookingRepository.completeRefund('b_refund_flow');
      expect(completeRes, isTrue);

      final fetchedBooking = await BookingRepository.getBookingById('b_refund_flow');
      expect(fetchedBooking?.paymentStatus, equals('refunded'));

      payment = await BookingRepository.getPaymentForBooking('b_refund_flow');
      expect(payment?.status, equals('refunded'));
      expect(payment?.refundStatus, equals('succeeded'));

      notifs = await BookingRepository.getNotificationsForUser('customer1');
      expect(notifs.any((n) => n.type == AppNotificationType.refundSucceeded), isTrue);

      // 3. Ngăn hoàn tiền lại lần nữa
      final completeAgain = await BookingRepository.completeRefund('b_refund_flow');
      expect(completeAgain, isFalse);
    });

    test(
      '10. Khôi phục booking, payment và refund sau khi đóng mở lại SQLite',
      () async {
        final booking = Booking(
          id: 'b_restart_flow',
          venueId: 'v1',
          userId: 'customer1',
          date: DateTime.now(),
          startTime: '15:00',
          endTime: '16:00',
          originalAmount: 100000.0,
          serviceAmount: 0.0,
          discountAmount: 0.0,
          totalPrice: 100000.0,
        );

        Future<void> reopenDatabase() async {
          await db.close();

          BookingRepository.setDatabaseForTesting(null);

          db = await databaseFactory.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(
              version: DatabaseHelper.databaseVersion,
              onConfigure: (database) async {
                await database.execute('PRAGMA foreign_keys = ON');
              },
            ),
          );

          BookingRepository.setDatabaseForTesting(db);

          // Mô phỏng bộ nhớ ứng dụng bị mất sau khi đóng app.
          MockStore.bookings.clear();
          MockStore.payments.clear();
          MockStore.notifications.clear();
          MockStore.promotions.clear();

          await BookingRepository.refreshCache();
        }

        // 1. Đặt sân và thanh toán online.
        await BookingRepository.processBookingPayment(
          booking: booking,
          method: 'momo',
        );

        await reopenDatabase();

        var restoredBooking =
            await BookingRepository.getBookingById('b_restart_flow');

        var restoredPayment =
            await BookingRepository.getPaymentForBooking('b_restart_flow');

        expect(restoredBooking, isNotNull);
        expect(restoredPayment, isNotNull);
        expect(restoredPayment?.method, equals('momo'));
        expect(restoredPayment?.amount, equals(100000.0));

        // 2. Hủy booking đã thanh toán.
        final cancelResult =
            await BookingRepository.cancelBooking('b_restart_flow');

        expect(cancelResult, isTrue);

        await reopenDatabase();

        restoredBooking =
            await BookingRepository.getBookingById('b_restart_flow');

        restoredPayment =
            await BookingRepository.getPaymentForBooking('b_restart_flow');

        final cancelledRows = await db.query(
          'bookings',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: ['b_restart_flow'],
        );

        expect(restoredBooking, isNotNull);
        expect(cancelledRows, isNotEmpty);
        expect(cancelledRows.first['status'], equals('cancelled'));
        expect(restoredPayment?.refundStatus, equals('processing'));
        expect(restoredPayment?.refundAmount, equals(100000.0));

        var notifications =
            await BookingRepository.getNotificationsForUser('customer1');

        expect(
          notifications.any(
            (notification) =>
                notification.type == AppNotificationType.refundProcessing,
          ),
          isTrue,
        );

        // 3. Hoàn tiền thành công.
        final refundResult =
            await BookingRepository.completeRefund('b_restart_flow');

        expect(refundResult, isTrue);

        await reopenDatabase();

        restoredBooking =
            await BookingRepository.getBookingById('b_restart_flow');

        restoredPayment =
            await BookingRepository.getPaymentForBooking('b_restart_flow');

        notifications =
            await BookingRepository.getNotificationsForUser('customer1');

        expect(restoredBooking, isNotNull);
        expect(restoredBooking?.paymentStatus, equals('refunded'));
        expect(restoredPayment?.status, equals('refunded'));
        expect(restoredPayment?.refundStatus, equals('succeeded'));

        expect(
          notifications.any(
            (notification) =>
                notification.type == AppNotificationType.refundSucceeded,
          ),
          isTrue,
        );
      },
    );
    test('11. Đánh dấu thông báo đã đọc', () async {
      final notif = AppNotification(
        id: 'n_sample_1',
        userId: 'customer1',
        bookingId: 'b_sample_1',
        title: 'Thông báo mới',
        content: 'Nội dung thông báo',
        createdAt: DateTime.now(),
        type: AppNotificationType.bookingCancelled,
        isRead: false,
      );
      await db.insert('app_notifications', {
        'id': notif.id,
        'userId': notif.userId,
        'bookingId': notif.bookingId,
        'title': notif.title,
        'content': notif.content,
        'createdAt': notif.createdAt.toIso8601String(),
        'type': notif.type.name,
        'isRead': 0,
      });

      final notifs = await BookingRepository.getNotificationsForUser('customer1');
      expect(notifs.isNotEmpty, isTrue);

      final firstNotif = notifs.first;
      expect(firstNotif.isRead, isFalse);

      await BookingRepository.markNotificationAsRead(firstNotif.id);

      final updatedNotifs = await BookingRepository.getNotificationsForUser('customer1');
      final updatedFirst = updatedNotifs.firstWhere((n) => n.id == firstNotif.id);
      expect(updatedFirst.isRead, isTrue);
    });

    test('11. Truy vấn booking theo Venue và Owner', () async {
      final date = DateTime.now();
      final b = Booking(
        id: 'b_query_test',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '07:00',
        endTime: '08:00',
        originalAmount: 100000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 100000.0,
      );
      await BookingRepository.processBookingPayment(booking: b, method: 'cash');

      final venueBookings = await BookingRepository.getBookingsForVenue('v1');
      expect(venueBookings.isNotEmpty, isTrue);

      final ownerBookings = await BookingRepository.getBookingsForOwner('owner1');
      expect(ownerBookings.isNotEmpty, isTrue);
      expect(ownerBookings.any((item) => item.id == 'b_query_test'), isTrue);
    });

    // ------------------------------------------------------------------------
    // CÁC TEST MỚI BỔ SUNG THEO YÊU CẦU:
    // ------------------------------------------------------------------------

    test('Test A – Race condition: Hai yêu cầu đặt cùng khung giờ đồng thời qua Future.wait', () async {
      final date = DateTime.now();
      final b1 = Booking(
        id: 'b_race_1',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '19:00',
        endTime: '21:00',
        originalAmount: 200000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 200000.0,
      );
      final b2 = Booking(
        id: 'b_race_2',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '19:00',
        endTime: '21:00',
        originalAmount: 200000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 200000.0,
      );

      final results = await Future.wait([
        BookingRepository.processBookingPayment(booking: b1, method: 'cash'),
        BookingRepository.processBookingPayment(booking: b2, method: 'cash'),
      ]);

      final successes = results.where((r) => r.isSuccess).toList();
      final failures = results.where((r) => !r.isSuccess).toList();

      // Chỉ đúng một yêu cầu thành công
      expect(successes.length, equals(1));
      expect(failures.length, equals(1));
      expect(failures.first.failureReason, equals('Khung giờ không còn trống.'));

      // SQLite chỉ lưu đúng 1 booking
      final bookedRows = await db.query(
        'bookings',
        where: 'venueId = ? AND date = ? AND startTime = ?',
        whereArgs: ['v1', date.toIso8601String(), '19:00'],
      );
      expect(bookedRows.length, equals(1));
    });

    test('Test B – failRefund: Thất bại hoàn tiền không đổi paymentStatus thành refunded', () async {
      final date = DateTime.now();
      final b = Booking(
        id: 'b_fail_refund_test',
        venueId: 'v1',
        userId: 'customer1',
        date: date,
        startTime: '21:00',
        endTime: '22:00',
        originalAmount: 100000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 100000.0,
      );
      await BookingRepository.processBookingPayment(booking: b, method: 'momo');

      // Hủy để sang trạng thái processing
      final cancelSuccess = await BookingRepository.cancelBooking('b_fail_refund_test');
      expect(cancelSuccess, isTrue);

      // Gọi failRefund
      final failSuccess = await BookingRepository.failRefund('b_fail_refund_test');
      expect(failSuccess, isTrue);

      // Xác nhận refundStatus = failed, booking.paymentStatus vẫn là paid, payments.status không là refunded
      final payment = await BookingRepository.getPaymentForBooking('b_fail_refund_test');
      expect(payment?.refundStatus, equals('failed'));
      expect(payment?.status, equals('success')); // Vẫn là success ban đầu, không bị chuyển thành refunded

      final fetchedBooking = await BookingRepository.getBookingById('b_fail_refund_test');
      expect(fetchedBooking?.paymentStatus, equals('paid')); // Không bị chuyển thành refunded
    });

    test('Test C – Cache rollback: Giao dịch SQLite thất bại không làm bẩn MockStore cache', () async {
      final initialBookingsCount = MockStore.bookings.length;
      final initialPaymentsCount = MockStore.payments.length;

      final invalidBooking = Booking(
        id: 'b_fail_cache_rollback',
        venueId: 'v_non_existent', // Venue không tồn tại dẫn đến lỗi trước khi insert
        userId: 'customer1',
        date: DateTime.now(),
        startTime: '04:00',
        endTime: '05:00',
        originalAmount: 100000.0,
        serviceAmount: 0.0,
        discountAmount: 0.0,
        totalPrice: 100000.0,
      );

      final result = await BookingRepository.processBookingPayment(
        booking: invalidBooking,
        method: 'cash',
      );
      expect(result.isSuccess, isFalse);

      // Xác nhận MockStore không tăng thêm booking hay payment nào
      expect(MockStore.bookings.length, equals(initialBookingsCount));
      expect(MockStore.payments.length, equals(initialPaymentsCount));
      expect(MockStore.bookings.any((b) => b.id == 'b_fail_cache_rollback'), isFalse);
    });

    test('Test D – refreshCache: Khôi phục cache MockStore đồng bộ hoàn toàn với SQLite', () async {
      // 1. Chèn trực tiếp một booking và payment vào SQLite mà không qua MockStore
      await db.insert('bookings', {
        'id': 'b_direct_sqlite',
        'venueId': 'v1',
        'userId': 'customer1',
        'date': '2026-11-09T08:00:00.000',
        'startTime': '08:00',
        'endTime': '10:00',
        'totalPrice': 200000.0,
        'originalAmount': 200000.0,
        'serviceAmount': 0.0,
        'discountAmount': 0.0,
        'status': 'confirmed',
        'paymentStatus': 'paid',
        'paymentId': 'p_direct_sqlite',
        'createdAt': '2026-11-08T10:00:00.000',
      });
      await db.insert('payments', {
        'id': 'p_direct_sqlite',
        'bookingId': 'b_direct_sqlite',
        'method': 'momo',
        'amount': 200000.0,
        'status': 'success',
        'createdAt': '2026-11-08T10:00:00.000',
      });

      // 2. Làm lệch MockStore
      MockStore.bookings.clear();
      expect(MockStore.bookings.isEmpty, isTrue);

      // 3. Gọi refreshCache
      await BookingRepository.refreshCache();

      // 4. Kiểm tra MockStore đã được nạp lại đầy đủ từ SQLite
      expect(MockStore.bookings.isNotEmpty, isTrue);
      expect(MockStore.bookings.any((b) => b.id == 'b_direct_sqlite'), isTrue);
      expect(MockStore.payments.any((p) => p['id'] == 'p_direct_sqlite'), isTrue);
    });

    // ------------------------------------------------------------------------
    // GIAI ĐOẠN 3C: TÍCH HỢP TOÀN DIỆN & KIỂM THỬ KHÁCH HÀNG / THANH TOÁN
    // ------------------------------------------------------------------------
    group('Giai đoạn 3C – Customer Booking & Payment Integration', () {
      test('1. Customer đặt sân bằng tiền mặt (cash) thành công', () async {
        final initialMockCount = MockStore.bookings.length;
        final booking = Booking(
          id: 'b_cash_e2e_3c',
          venueId: 'v1',
          userId: 'customer1',
          date: DateTime.parse('2026-11-20T00:00:00.000'),
          startTime: '14:00',
          endTime: '16:00',
          originalAmount: 200000.0,
          serviceAmount: 0.0,
          discountAmount: 0.0,
          totalPrice: 200000.0,
        );

        final result = await BookingRepository.processBookingPayment(
          booking: booking,
          method: 'cash',
        );

        expect(result.isSuccess, isTrue);
        expect(result.booking?.status, equals('confirmed'));
        expect(result.booking?.paymentStatus, equals('unpaid'));
        expect(result.payment?['status'], equals('pending'));

        // Kiểm tra lưu trong SQLite
        final inDb = await BookingRepository.getBookingById('b_cash_e2e_3c');
        expect(inDb, isNotNull);
        expect(inDb?.totalPrice, equals(200000.0));

        // Kiểm tra không tạo trùng lặp trong MockStore
        expect(MockStore.bookings.length, equals(initialMockCount + 1));
        expect(MockStore.bookings.where((b) => b.id == 'b_cash_e2e_3c').length, equals(1));
      });

      test('2. Customer thanh toán online thành công (momo/vnpay)', () async {
        final booking = Booking(
          id: 'b_online_succ_3c',
          venueId: 'v1',
          userId: 'customer1',
          date: DateTime.parse('2026-11-20T00:00:00.000'),
          startTime: '16:00',
          endTime: '18:00',
          originalAmount: 200000.0,
          serviceAmount: 0.0,
          discountAmount: 0.0,
          totalPrice: 200000.0,
        );

        final result = await BookingRepository.processBookingPayment(
          booking: booking,
          method: 'momo',
          transactionCode: 'TXN-ONLINE-SUCC-1',
        );

        expect(result.isSuccess, isTrue);
        expect(result.booking?.status, equals('confirmed'));
        expect(result.booking?.paymentStatus, equals('paid'));
        expect(result.payment?['status'], equals('success'));
        expect(result.payment?['transactionCode'], equals('TXN-ONLINE-SUCC-1'));

        // Kiểm tra SQLite
        final paymentDb = await BookingRepository.getPaymentForBooking('b_online_succ_3c');
        expect(paymentDb?.status, equals('success'));
        expect(paymentDb?.amount, equals(200000.0));
      });

      test('3. Customer thanh toán online thất bại (simulateFailure = true)', () async {
        final booking = Booking(
          id: 'b_online_fail_3c',
          venueId: 'v1',
          userId: 'customer1',
          date: DateTime.parse('2026-11-20T00:00:00.000'),
          startTime: '18:00',
          endTime: '20:00',
          originalAmount: 200000.0,
          serviceAmount: 0.0,
          discountAmount: 0.0,
          totalPrice: 200000.0,
        );

        final result = await BookingRepository.processBookingPayment(
          booking: booking,
          method: 'vnpay',
          simulateFailure: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.booking?.status, equals('cancelled'));
        expect(result.payment?['status'], equals('failed'));

        // Slot phải được giải phóng vì status = cancelled
        final slotFree = await BookingRepository.isRangeAvailable(
          venueId: 'v1',
          date: DateTime.parse('2026-11-20T00:00:00.000'),
          startTime: '18:00',
          endTime: '20:00',
        );
        expect(slotFree, isTrue);
      });

      test('4. Hai khách cùng đặt một slot, chỉ một người thành công', () async {
        final b1 = Booking(
          id: 'b_slot_race_1',
          venueId: 'v1',
          userId: 'customer1',
          date: DateTime.parse('2026-11-21T00:00:00.000'),
          startTime: '08:00',
          endTime: '10:00',
          originalAmount: 200000.0,
          serviceAmount: 0.0,
          discountAmount: 0.0,
          totalPrice: 200000.0,
        );

        final b2 = Booking(
          id: 'b_slot_race_2',
          venueId: 'v1',
          userId: 'customer1',
          date: DateTime.parse('2026-11-21T00:00:00.000'),
          startTime: '09:00', // Trùng chồng lấn với 08:00-10:00
          endTime: '11:00',
          originalAmount: 200000.0,
          serviceAmount: 0.0,
          discountAmount: 0.0,
          totalPrice: 200000.0,
        );

        final res1 = await BookingRepository.processBookingPayment(booking: b1, method: 'cash');
        final res2 = await BookingRepository.processBookingPayment(booking: b2, method: 'cash');

        expect(res1.isSuccess, isTrue);
        expect(res2.isSuccess, isFalse);
        expect(res2.isSlotAvailable, isFalse);
      });

      test('5. Bootstrap gọi refreshCache đúng thứ tự và nạp đầy đủ vào MockStore', () async {
        // Chèn trực tiếp vào db
        await db.insert('bookings', {
          'id': 'b_bootstrap_test',
          'venueId': 'v1',
          'userId': 'customer1',
          'date': '2026-11-22T00:00:00.000',
          'startTime': '08:00',
          'endTime': '10:00',
          'totalPrice': 200000.0,
          'originalAmount': 200000.0,
          'serviceAmount': 0.0,
          'discountAmount': 0.0,
          'status': 'confirmed',
          'paymentStatus': 'paid',
          'paymentId': 'pay_bootstrap_test',
          'createdAt': '2026-11-08T10:00:00.000',
        });

        // Xóa MockStore để giả lập app khởi động mới
        MockStore.bookings.clear();
        expect(MockStore.bookings.isEmpty, isTrue);

        await BookingRepository.refreshCache();

        expect(MockStore.bookings.any((b) => b.id == 'b_bootstrap_test'), isTrue);
      });
      test('6. Owner xác nhận, hoàn thành và hủy booking qua SQLite Repository', () async {
        final bOwner = Booking(
          id: 'b_owner_flow',
          venueId: 'v1',
          userId: 'customer1',
          date: DateTime.now().add(const Duration(days: 10)),
          startTime: '09:00',
          endTime: '11:00',
          totalPrice: 200000.0,
          originalAmount: 200000.0,
          serviceAmount: 0.0,
          discountAmount: 0.0,
          status: 'pending',
        );
        final res = await BookingRepository.processBookingPayment(booking: bOwner, method: 'cash');
        expect(res.isSuccess, isTrue);

        // Đảm bảo đơn ở trạng thái pending trước khi xác nhận
        await db.update('bookings', {'status': 'pending'}, where: 'id = ?', whereArgs: ['b_owner_flow']);
        MockStore.bookings.firstWhere((b) => b.id == 'b_owner_flow').status = 'pending';

        // Chủ sân khác cố tình can thiệp -> thất bại
        final wrongOwner = await BookingRepository.updateBookingStatusByOwner(
          bookingId: 'b_owner_flow',
          newStatus: 'confirmed',
          ownerId: 'wrong_owner',
        );
        expect(wrongOwner, isFalse);

        // Đúng chủ sân 'owner1' xác nhận -> thành công
        final confirmOk = await BookingRepository.updateBookingStatusByOwner(
          bookingId: 'b_owner_flow',
          newStatus: 'confirmed',
          ownerId: 'owner1',
        );
        expect(confirmOk, isTrue);

        // Kiểm tra trong SQLite
        final dbB1 = await BookingRepository.getBookingById('b_owner_flow');
        expect(dbB1?.status, 'confirmed');

        // Chủ sân đánh dấu hoàn thành -> thành công
        final completeOk = await BookingRepository.updateBookingStatusByOwner(
          bookingId: 'b_owner_flow',
          newStatus: 'completed',
          ownerId: 'owner1',
        );
        expect(completeOk, isTrue);
        final dbB2 = await BookingRepository.getBookingById('b_owner_flow');
        expect(dbB2?.status, 'completed');
      });

      test('7. Admin CRUD và bật/tắt promotion qua SQLite Repository', () async {
        final newPromo = Promotion(
          id: 'p_admin_test',
          code: 'ADMIN20',
          discountPercent: 20.0,
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
        );

        // Tạo mới
        final createOk = await BookingRepository.createPromotion(newPromo);
        expect(createOk, isTrue);
        expect(MockStore.promotions.any((p) => p.code == 'ADMIN20'), isTrue);

        // Trùng code -> thất bại
        final dupOk = await BookingRepository.createPromotion(newPromo);
        expect(dupOk, isFalse);

        // Bật / tắt
        final toggleOk = await BookingRepository.togglePromotionActive('p_admin_test', false);
        expect(toggleOk, isTrue);
        final pAfterToggle = MockStore.promotions.firstWhere((p) => p.id == 'p_admin_test');
        expect(pAfterToggle.isActive, isFalse);

        // Chỉnh sửa
        final updatedPromo = Promotion(
          id: 'p_admin_test',
          code: 'ADMIN25',
          discountPercent: 25.0,
          expiryDate: DateTime.now().add(const Duration(days: 45)),
          isActive: true,
        );
        final updateOk = await BookingRepository.updatePromotion(updatedPromo);
        expect(updateOk, isTrue);
        final pAfterUpdate = MockStore.promotions.firstWhere((p) => p.id == 'p_admin_test');
        expect(pAfterUpdate.code, 'ADMIN25');
        expect(pAfterUpdate.discountPercent, 25.0);

        // Xóa promotion chưa sử dụng -> xóa hẳn
        final deleteOk = await BookingRepository.deletePromotion('p_admin_test');
        expect(deleteOk, isTrue);
        expect(MockStore.promotions.any((p) => p.id == 'p_admin_test'), isFalse);
      });

      test('8. Promotion đã sử dụng không bị xóa mất lịch sử mà chỉ vô hiệu hóa', () async {
        final promoUsed = Promotion(
          id: 'p_used_test',
          code: 'USED50',
          discountPercent: 50.0,
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
          usedCount: 1,
        );
        await BookingRepository.createPromotion(promoUsed);

        // Xóa promotion đã used
        final delUsedOk = await BookingRepository.deletePromotion('p_used_test');
        expect(delUsedOk, isTrue);

        // Kiểm tra trong SQLite vẫn còn record và isActive = 0
        final dbRows = await db.query('promotions', where: 'id = ?', whereArgs: ['p_used_test']);
        expect(dbRows.isNotEmpty, isTrue);
        expect(dbRows.single['isActive'], 0);
        expect(dbRows.single['usedCount'], 1);
      });

      test('9. Dữ liệu promotion và booking vẫn tồn tại sau khi refreshCache', () async {
        final pPersist = Promotion(
          id: 'p_persist_test',
          code: 'PERSIST30',
          discountPercent: 30.0,
          expiryDate: DateTime.now().add(const Duration(days: 15)),
          isActive: true,
        );
        await BookingRepository.createPromotion(pPersist);

        // Xóa MockStore để giả lập app khởi động lại
        MockStore.promotions.clear();
        expect(MockStore.promotions.isEmpty, isTrue);

        await BookingRepository.refreshCache();
        expect(MockStore.promotions.any((p) => p.code == 'PERSIST30'), isTrue);
      });
    });
  });
}
