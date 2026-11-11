import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/data/booking_repository.dart' as data_repo;
import 'package:sportfield_booking/models/app_notification.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/models/promotion.dart';
import 'package:sportfield_booking/models/payment.dart';
import 'package:sportfield_booking/screens/customer/booking_detail_screen.dart';
import 'package:sportfield_booking/screens/customer/booking_history_screen.dart';
import 'package:sportfield_booking/screens/customer/notification_screen.dart';
import 'package:sportfield_booking/utils/app_routes.dart';
import 'package:sportfield_booking/utils/app_theme.dart';

void main() {
  setUpAll(() {
    data_repo.BookingRepository.setUseMockStoreForTesting(true);
  });

  tearDownAll(() {
    data_repo.BookingRepository.setUseMockStoreForTesting(false);
  });
  final originalBookings = List<Booking>.of(MockStore.bookings);
  final originalPayments = MockStore.payments
      .map((payment) => Map<String, dynamic>.of(payment))
      .toList();
  final originalPromotions = List<Promotion>.of(MockStore.promotions);
  final originalPromotionCounts = {
    for (final promotion in MockStore.promotions)
      promotion.id: promotion.usedCount,
  };
  final originalPromotionHistory = {
    for (final promotion in MockStore.promotions)
      promotion.id: promotion.usageHistory
          .map(
            (usage) => PromotionUsage(
              promotionId: usage.promotionId,
              userId: usage.userId,
              bookingId: usage.bookingId,
              isReversed: usage.isReversed,
            ),
          )
          .toList(),
  };
  final originalNotifications = List<AppNotification>.of(
    MockStore.notifications,
  );

  tearDown(() {
    MockStore.bookings
      ..clear()
      ..addAll(originalBookings);
    MockStore.payments
      ..clear()
      ..addAll(originalPayments);
    MockStore.promotions
      ..clear()
      ..addAll(originalPromotions);
    for (final promotion in MockStore.promotions) {
      promotion.usedCount = originalPromotionCounts[promotion.id] ?? 0;
      promotion.usageHistory
        ..clear()
        ..addAll(originalPromotionHistory[promotion.id] ?? const []);
    }
    MockStore.notifications
      ..clear()
      ..addAll(originalNotifications);
    MockStore.logout();
  });

  Booking futureBooking({
    required String id,
    required String userId,
    required DateTime date,
    String? promoId,
    String? promotionCode,
  }) => Booking(
    id: id,
    venueId: 'v1',
    userId: userId,
    date: date,
    startTime: '16:00',
    endTime: '17:00',
    originalAmount: 300000,
    serviceAmount: 60000,
    discountAmount: promoId == null ? 0 : 36000,
    totalPrice: promoId == null ? 360000 : 324000,
    promoId: promoId,
    promotionCode: promotionCode,
    serviceItems: [
      BookingServiceItem(
        serviceId: 's1',
        serviceName: 'Thuê áo bib (bộ 10 cái)',
        quantity: 2,
        unitPrice: 30000,
      ),
    ],
  );

  test('Customer cancellation requests refund once and releases slot', () {
    MockStore.login('customer@gmail.com', '123456');
    final promotion = Promotion(
      id: 'cancel-promo',
      code: 'CANCEL10',
      discountPercent: 10,
      expiryDate: DateTime.now().add(const Duration(days: 60)),
      usageLimit: 5,
      perUserLimit: 2,
    );
    MockStore.promotions.add(promotion);
    final date = DateTime.now().add(const Duration(days: 40));
    final booking = futureBooking(
      id: 'customer-cancel-${DateTime.now().microsecondsSinceEpoch}',
      userId: 'customer1',
      date: date,
      promoId: promotion.id,
      promotionCode: promotion.code,
    );
    expect(MockStore.confirmBooking(booking, 'momo'), isTrue);
    expect(promotion.usedCount, 1);

    expect(BookingController.cancelBooking(booking.id), isTrue);
    expect(booking.status, 'cancelled');
    expect(booking.paymentStatus, 'paid');
    expect(MockStore.paymentOfBooking(booking.id)?['status'], 'success');
    expect(
      MockStore.paymentOfBooking(booking.id)?['refundStatus'],
      'processing',
    );
    expect(MockStore.paymentOfBooking(booking.id)?['refundAmount'], 324000);
    expect(promotion.usedCount, 0);
    expect(
      MockStore.notifications
          .where((item) => item.bookingId == booking.id)
          .map((item) => item.type),
      [
        AppNotificationType.bookingCancelled,
        AppNotificationType.refundProcessing,
      ],
    );
    expect(
      MockStore.isRangeAvailable(booking.venueId, date, '16:00', '17:00'),
      isTrue,
    );

    expect(BookingController.cancelBooking(booking.id), isFalse);
    expect(MockStore.completeRefund(booking.id), isTrue);
    expect(MockStore.completeRefund(booking.id), isFalse);
    expect(MockStore.failRefund(booking.id), isFalse);
    expect(booking.paymentStatus, 'refunded');
    expect(MockStore.paymentOfBooking(booking.id)?['status'], 'refunded');
    expect(
      MockStore.notifications
          .where((item) => item.bookingId == booking.id)
          .where((item) => item.type == AppNotificationType.refundSucceeded)
          .length,
      1,
    );
    expect(promotion.usedCount, 0);
  });

  test('Owner cancellation uses shared refund flow and records failure', () {
    MockStore.login('owner@gmail.com', '123456');
    final date = DateTime.now().add(const Duration(days: 41));
    final booking = futureBooking(
      id: 'owner-cancel-${DateTime.now().microsecondsSinceEpoch}',
      userId: 'customer2',
      date: date,
    );
    expect(MockStore.confirmBooking(booking, 'momo'), isTrue);
    expect(
      MockStore.cancelBooking(booking.id, cancelReason: 'Chủ sân hủy lịch đặt'),
      isTrue,
    );
    expect(booking.status, 'cancelled');
    expect(
      MockStore.paymentOfBooking(booking.id)?['refundStatus'],
      'processing',
    );
    expect(MockStore.failRefund(booking.id), isTrue);
    expect(booking.paymentStatus, 'paid');
    expect(MockStore.paymentOfBooking(booking.id)?['status'], 'success');
    expect(MockStore.paymentOfBooking(booking.id)?['refundStatus'], 'failed');
    expect(MockStore.completeRefund(booking.id), isFalse);
    expect(
      MockStore.notifications
          .where((item) => item.bookingId == booking.id)
          .map((item) => item.type),
      [
        AppNotificationType.bookingCancelled,
        AppNotificationType.refundProcessing,
        AppNotificationType.refundFailed,
      ],
    );
  });

  test('Read notifications update unread count and read state', () {
    final notification = AppNotification(
      id: 'read-test',
      userId: 'customer1',
      bookingId: 'booking-test',
      title: 'Booking bị hủy',
      content: 'Booking đã bị hủy.',
      createdAt: DateTime.now(),
      type: AppNotificationType.bookingCancelled,
    );
    MockStore.notifications.add(notification);
    expect(MockStore.unreadNotificationCount('customer1'), 1);
    expect(MockStore.markNotificationRead(notification.id), isTrue);
    expect(notification.isRead, isTrue);
    expect(MockStore.unreadNotificationCount('customer1'), 0);
    expect(MockStore.markNotificationRead(notification.id), isFalse);
  });

  test(
    'Legacy paid booking refunds its sole valid payment without payment ID',
    () {
      final booking =
          futureBooking(
              id: 'legacy-payment-link-${DateTime.now().microsecondsSinceEpoch}',
              userId: 'customer1',
              date: DateTime.now().add(const Duration(days: 48)),
            )
            ..status = 'confirmed'
            ..paymentStatus = 'paid';
      final payment = <String, dynamic>{
        'id': 'legacy-payment-${DateTime.now().microsecondsSinceEpoch}',
        'bookingId': booking.id,
        'method': 'momo',
        'amount': booking.totalPrice,
        'status': 'success',
      };
      MockStore.bookings.add(booking);
      MockStore.payments.add(payment);

      expect(MockStore.cancelBooking(booking.id), isTrue);
      expect(booking.paymentId, isNull);
      expect(booking.status, 'cancelled');
      expect(payment['refundStatus'], 'processing');
      expect(MockStore.completeRefund(booking.id), isTrue);
      expect(booking.paymentStatus, 'refunded');
      expect(payment['status'], 'refunded');
    },
  );

  test('Legacy cancellation rejects multiple valid payment matches', () {
    final booking =
        futureBooking(
            id: 'legacy-multiple-payments-${DateTime.now().microsecondsSinceEpoch}',
            userId: 'customer1',
            date: DateTime.now().add(const Duration(days: 49)),
          )
          ..status = 'confirmed'
          ..paymentStatus = 'paid';
    final payments = [
      for (var index = 0; index < 2; index++)
        <String, dynamic>{
          'id': 'legacy-attempt-$index-${booking.id}',
          'bookingId': booking.id,
          'amount': booking.totalPrice,
          'status': 'success',
        },
    ];
    MockStore.bookings.add(booking);
    MockStore.payments.addAll(payments);
    final notificationCount = MockStore.notifications.length;

    expect(MockStore.cancelBooking(booking.id), isFalse);
    expect(MockStore.lastCancellationError, contains('nhiều'));
    expect(booking.status, 'confirmed');
    expect(booking.cancelledAt, isNull);
    expect(
      payments.every((payment) => payment['refundStatus'] == null),
      isTrue,
    );
    expect(MockStore.notifications.length, notificationCount);
  });

  test('Legacy cancellation rejects invalid payment matches', () {
    for (final paymentFields in [
      <String, dynamic>{'status': 'failed', 'amount': 360000},
      <String, dynamic>{'status': 'success', 'amount': '360000'},
    ]) {
      final booking =
          futureBooking(
              id: 'legacy-invalid-payment-${DateTime.now().microsecondsSinceEpoch}-${paymentFields['status']}',
              userId: 'customer1',
              date: DateTime.now().add(const Duration(days: 50)),
            )
            ..status = 'confirmed'
            ..paymentStatus = 'paid';
      final payment = <String, dynamic>{
        'id': 'invalid-${booking.id}',
        'bookingId': booking.id,
        ...paymentFields,
      };
      MockStore.bookings.add(booking);
      MockStore.payments.add(payment);

      expect(MockStore.cancelBooking(booking.id), isFalse);
      expect(MockStore.lastCancellationError, contains('payment'));
      expect(booking.status, 'confirmed');
      expect(payment['refundStatus'], isNull);
    }
  });

  test('Refund resolution rejects ambiguous legacy payment matches', () {
    final booking =
        futureBooking(
            id: 'legacy-ambiguous-refund-${DateTime.now().microsecondsSinceEpoch}',
            userId: 'customer1',
            date: DateTime.now().add(const Duration(days: 51)),
          )
          ..status = 'cancelled'
          ..paymentStatus = 'paid';
    final payments = [
      for (var index = 0; index < 2; index++)
        <String, dynamic>{
          'id': 'legacy-refund-attempt-$index-${booking.id}',
          'bookingId': booking.id,
          'amount': booking.totalPrice,
          'status': 'success',
          'refundAmount': booking.totalPrice,
          'refundStatus': 'processing',
        },
    ];
    MockStore.bookings.add(booking);
    MockStore.payments.addAll(payments);

    expect(MockStore.completeRefund(booking.id), isFalse);
    expect(booking.paymentStatus, 'paid');
    expect(payments.every((payment) => payment['status'] == 'success'), isTrue);
    expect(
      payments.every((payment) => payment['refundStatus'] == 'processing'),
      isTrue,
    );
  });

  test('Cancellation rejects successful payment when booking is unpaid', () {
    final promotion = Promotion(
      id: 'unaffected-promo',
      code: 'UNAFF',
      discountPercent: 10,
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      usedCount: 1,
      usageHistory: [
        PromotionUsage(
          promotionId: 'unaffected-promo',
          userId: 'customer1',
          bookingId: 'inconsistent-success-unpaid',
        ),
      ],
    );
    final booking = futureBooking(
      id: 'inconsistent-success-unpaid',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 46)),
      promoId: promotion.id,
      promotionCode: promotion.code,
    )..status = 'confirmed';
    MockStore.bookings.add(booking);
    MockStore.promotions.add(promotion);
    final successfulPayment = {
      'id': 'successful-but-unpaid',
      'bookingId': booking.id,
      'status': 'success',
      'amount': booking.totalPrice,
    };
    MockStore.payments.add(successfulPayment);
    final beforeNotifications = MockStore.notifications.length;

    expect(MockStore.cancelBooking(booking.id), isFalse);
    expect(
      MockStore.lastCancellationError,
      'Dữ liệu thanh toán không nhất quán.',
    );
    expect(booking.status, 'confirmed');
    expect(booking.cancelledAt, isNull);
    expect(successfulPayment['refundStatus'], isNull);
    expect(promotion.usedCount, 1);
    expect(promotion.usageHistory.single.isReversed, isFalse);
    expect(MockStore.notifications.length, beforeNotifications);
    expect(
      MockStore.isRangeAvailable(
        booking.venueId,
        booking.date,
        '16:00',
        '17:00',
      ),
      isFalse,
    );
  });

  test('Payment ID lookup never substitutes a different attempt', () {
    final booking = futureBooking(
      id: 'missing-linked-payment',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 47)),
    )..paymentId = 'missing-id';
    MockStore.bookings.add(booking);
    MockStore.payments.add({
      'id': 'other-attempt',
      'bookingId': booking.id,
      'method': 'momo',
      'amount': booking.totalPrice,
      'status': 'success',
    });
    expect(MockStore.paymentRecordForBooking(booking.id), isNull);
  });

  test(
    'Malformed and missing payment status/amount parse safely as unknown',
    () {
      final missingStatus = Payment.fromMap({
        'id': 'missing-status',
        'bookingId': 'b1',
        'method': 'momo',
        'amount': 100,
      });
      final malformed = Payment.fromMap({
        'id': 'bad-amount',
        'bookingId': 'b2',
        'method': 'momo',
        'amount': '100',
        'status': 'success',
        'refundAmount': double.infinity,
      });
      expect(missingStatus.status, 'unknown');
      expect(missingStatus.amount, 100);
      expect(malformed.status, 'success');
      expect(malformed.amount, isNull);
      expect(malformed.refundAmount, isNull);
      for (final invalidAmount in [-1, double.nan, double.infinity, '100']) {
        final parsed = Payment.fromMap({
          'id': 'invalid-amount',
          'bookingId': 'b3',
          'method': 'momo',
          'amount': invalidAmount,
          'status': 'pending',
        });
        expect(parsed.amount, isNull);
      }
    },
  );

  test('Online payment failure creates a payment-failed notification', () {
    final booking = futureBooking(
      id: 'payment-failure-notification',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 48)),
    );
    final result = MockStore.processBookingPayment(
      booking: booking,
      method: 'momo',
      simulateFailure: true,
    );
    expect(result.isSuccess, isFalse);
    final related = MockStore.notifications
        .where((notification) => notification.bookingId == booking.id)
        .toList();
    expect(related.map((item) => item.type), [
      AppNotificationType.paymentFailed,
    ]);
  });

  testWidgets('Notification for a missing booking stays unread', (
    tester,
  ) async {
    MockStore.login('customer@gmail.com', '123456');
    final notification = AppNotification(
      id: 'notification-missing-booking',
      userId: 'customer1',
      bookingId: 'deleted-booking',
      title: 'Thông báo booking cũ',
      content: 'Booking không còn tồn tại.',
      createdAt: DateTime.now(),
      type: AppNotificationType.bookingCancelled,
    );
    MockStore.notifications.add(notification);
    await tester.pumpWidget(
      MaterialApp(routes: AppRoutes.routes, home: const NotificationScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(notification.title));
    await tester.pumpAndSettle();
    expect(notification.isRead, isFalse);
    expect(find.text('Chi tiết booking'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Booking detail shows snapshot and exact invoice totals', (
    tester,
  ) async {
    final date = DateTime.now().add(const Duration(days: 42));
    final booking = futureBooking(
      id: 'detail-${DateTime.now().microsecondsSinceEpoch}',
      userId: 'customer1',
      date: date,
      promoId: 'promo-snapshot',
      promotionCode: 'TENOFF',
    );
    booking.paymentId = 'detail-payment';
    booking.status = 'cancelled';
    booking.paymentStatus = 'paid';
    MockStore.bookings.add(booking);
    MockStore.payments.add({
      'id': 'detail-payment',
      'bookingId': booking.id,
      'method': 'momo',
      'amount': 324000,
      'status': 'success',
      'transactionCode': 'TX-DETAIL',
      'refundAmount': 324000,
      'refundStatus': 'processing',
      'paidAt': DateTime(2026, 11, 1, 12),
      'createdAt': DateTime(2026, 11, 1, 11),
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BookingDetailScreen(bookingId: booking.id),
      ),
    );
    expect(find.text('Sân bóng đá Thành Công'), findsOneWidget);
    expect(find.text('12 Lý Thường Kiệt, Phường 14'), findsOneWidget);
    expect(find.text('Bóng đá'), findsOneWidget);
    expect(find.text('Đã hủy'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Thuê áo bib (bộ 10 cái)'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Thuê áo bib (bộ 10 cái)'), findsOneWidget);
    expect(find.text('Số lượng'), findsOneWidget);
    expect(find.text('Đơn giá'), findsOneWidget);
    expect(find.text('Thành tiền'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('30000 đ'), findsOneWidget);
    expect(find.text('60000 đ'), findsAtLeastNWidgets(1));
    expect(find.text('360000 đ'), findsOneWidget);
    expect(find.text('300000 đ'), findsOneWidget);
    expect(find.text('60000 đ'), findsAtLeastNWidgets(1));
    expect(find.text('36000 đ'), findsOneWidget);
    expect(find.text('324000 đ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('TX-DETAIL'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('TX-DETAIL'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.text('1/11/2026 11:00'), findsOneWidget);
    expect(find.text('1/11/2026 12:00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Đang xử lý'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Đang xử lý'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Legacy booking without service snapshot renders missing data', (
    tester,
  ) async {
    final booking = Booking(
      id: 'legacy-detail',
      venueId: 'v1',
      userId: 'customer1',
      date: DateTime.now().subtract(const Duration(days: 3)),
      startTime: '08:00',
      endTime: '09:00',
      totalPrice: 120000,
      selectedServiceIds: const ['removed-service'],
    );
    MockStore.bookings.add(booking);
    await tester.pumpWidget(
      MaterialApp(home: BookingDetailScreen(bookingId: booking.id)),
    );
    await tester.scrollUntilVisible(
      find.textContaining('Không có dữ liệu dịch vụ tại thời điểm đặt.'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Không có dữ liệu dịch vụ tại thời điểm đặt.'),
      findsOneWidget,
    );
    expect(find.text('Không có dữ liệu'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Booking detail uses the saved service name, not live catalog', (
    tester,
  ) async {
    const longServiceName =
        'Thuê trang phục thi đấu và phụ kiện thể thao cao cấp theo bộ';
    final booking = Booking(
      id: 'saved-service-name',
      venueId: 'v1',
      userId: 'customer1',
      date: DateTime.now().subtract(const Duration(days: 4)),
      startTime: '08:00',
      endTime: '09:00',
      originalAmount: 300000,
      serviceAmount: 30000,
      discountAmount: 0,
      totalPrice: 330000,
      serviceItems: [
        BookingServiceItem(
          serviceId: 'removed-from-catalog',
          serviceName: longServiceName,
          quantity: 1,
          unitPrice: 30000,
        ),
      ],
    );
    MockStore.bookings.add(booking);
    await tester.pumpWidget(
      MaterialApp(home: BookingDetailScreen(bookingId: booking.id)),
    );
    await tester.scrollUntilVisible(
      find.text(longServiceName),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(longServiceName), findsOneWidget);
    expect(find.text('Số lượng'), findsOneWidget);
    expect(find.text('Đơn giá'), findsOneWidget);
    expect(find.text('Thành tiền'), findsOneWidget);
    expect(find.text('Dịch vụ removed-from-catalog'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Booking detail warns when invoice breakdown disagrees', (
    tester,
  ) async {
    final booking = Booking(
      id: 'bad-invoice-snapshot',
      venueId: 'v1',
      userId: 'customer1',
      date: DateTime.now().subtract(const Duration(days: 5)),
      startTime: '08:00',
      endTime: '09:00',
      originalAmount: 300000,
      serviceAmount: 30000,
      discountAmount: 0,
      totalPrice: 400000,
      serviceItems: const [],
    );
    MockStore.bookings.add(booking);
    await tester.pumpWidget(
      MaterialApp(home: BookingDetailScreen(bookingId: booking.id)),
    );
    await tester.scrollUntilVisible(
      find.textContaining('Cảnh báo:'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Cảnh báo:'), findsOneWidget);
    expect(find.text('400000 đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Malformed payment amount does not hide booking detail', (
    tester,
  ) async {
    final booking = futureBooking(
      id: 'malformed-payment-amount',
      userId: 'customer1',
      date: DateTime.now().subtract(const Duration(days: 6)),
    )..paymentId = 'malformed-payment';
    MockStore.bookings.add(booking);
    MockStore.payments.add({
      'id': 'malformed-payment',
      'bookingId': booking.id,
      'method': 'momo',
      'amount': 'wrong-type',
    });
    await tester.pumpWidget(
      MaterialApp(home: BookingDetailScreen(bookingId: booking.id)),
    );
    expect(find.text('Chi tiết booking'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Không xác định'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Không xác định'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping a booking in history opens its detail', (tester) async {
    MockStore.login('customer@gmail.com', '123456');
    final booking = futureBooking(
      id: 'history-open-detail',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 44)),
    );
    MockStore.bookings.add(booking);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        routes: AppRoutes.routes,
        home: const BookingHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final bookingLabel = find.text(
      '${booking.date.day}/${booking.date.month}/${booking.date.year} • 16:00 - 17:00',
    );
    await tester.ensureVisible(bookingLabel);
    await tester.tap(bookingLabel);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết booking'), findsOneWidget);
    expect(find.text(booking.id), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notification tap opens related booking and marks it read', (
    tester,
  ) async {
    MockStore.login('customer@gmail.com', '123456');
    final booking = futureBooking(
      id: 'notification-detail',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 43)),
    );
    MockStore.bookings.add(booking);
    final notification = AppNotification(
      id: 'open-detail-notification',
      userId: 'customer1',
      bookingId: booking.id,
      title: 'Booking đã bị hủy',
      content: 'Booking ${booking.id} đã được hủy.',
      createdAt: DateTime.now(),
      type: AppNotificationType.bookingCancelled,
    );
    MockStore.notifications.add(notification);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        routes: AppRoutes.routes,
        home: const NotificationScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(notification.title));
    await tester.pumpAndSettle();
    expect(notification.isRead, isTrue);
    expect(find.text('Chi tiết booking'), findsOneWidget);
    expect(find.text(booking.id), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
