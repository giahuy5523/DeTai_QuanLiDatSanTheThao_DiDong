import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/screens/customer/booking_history_screen.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/models/payment.dart';
import 'package:sportfield_booking/models/promotion.dart';
import 'package:sportfield_booking/models/sport_type.dart';
import 'package:sportfield_booking/models/venue.dart';

void main() {
  final initialBookings = List<Booking>.of(MockStore.bookings);
  final initialPayments = List<Map<String, dynamic>>.of(MockStore.payments);
  final initialNotifications = List.of(MockStore.notifications);
  final initialPromotions = List.of(MockStore.promotions);

  final initialPromotionUsedCounts = {
    for (final promotion in MockStore.promotions)
      promotion.id: promotion.usedCount,
  };
  final initialPromotionHistory = {
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
  tearDown(() {
    MockStore.bookings
      ..clear()
      ..addAll(initialBookings);
    MockStore.payments
      ..clear()
      ..addAll(initialPayments);
    MockStore.notifications
      ..clear()
      ..addAll(initialNotifications);
    MockStore.promotions
      ..clear()
      ..addAll(initialPromotions);

    for (final promotion in MockStore.promotions) {
      final initialCount = initialPromotionUsedCounts[promotion.id];
      if (initialCount != null) {
        promotion.usedCount = initialCount;
      }
      promotion.usageHistory
        ..clear()
        ..addAll(initialPromotionHistory[promotion.id] ?? const []);
    }
  });

  test('SportType IDs match venue IDs and the search filter', () {
    expect(SportType.mockList().map((s) => s.sportTypeId).toList(), [1, 2, 3]);
    expect(MockStore.sportTypeIdFor('Bóng đá'), 1);
    expect(MockStore.sportTypeIdFor('Cầu lông'), 2);
    expect(MockStore.sportTypeIdFor('Tennis'), 3);
    expect(MockStore.sportTypeIdFor('Pickleball'), 5);
    expect(MockStore.sportTypeIdFor('Không có'), isNull);
    for (final venue in Venue.mockList()) {
      expect(
        MockStore.sportTypes.any((type) => type['id'] == venue.sportTypeId),
        isTrue,
      );
    }
  });

  test('Payment model records amount and defaults to pending', () {
    final payment = Payment(
      paymentId: 'pay-test',
      bookingId: 'book-test',
      method: 'momo',
      amount: 120000,
    );
    expect(payment.bookingId, 'book-test');
    expect(payment.amount, 120000);
    expect(payment.status, 'pending');
    expect(payment.transactionCode, isNull);
    expect(payment.paidAt, isNull);
  });

  test('Payment lookup keeps attempts and prefers latest success', () {
    MockStore.payments.addAll([
      {'id': 'attempt1', 'bookingId': 'booking-many', 'status': 'failed'},
      {'id': 'attempt2', 'bookingId': 'booking-many', 'status': 'success'},
      {'id': 'attempt3', 'bookingId': 'booking-many', 'status': 'failed'},
      {'id': 'attempt4', 'bookingId': 'booking-many', 'status': 'success'},
    ]);
    expect(MockStore.paymentsOfBooking('booking-many').length, 4);
    expect(MockStore.paymentOfBooking('booking-many')?['id'], 'attempt4');
    expect(MockStore.paymentOfBooking('does-not-exist'), isNull);
  });

  Booking futureBooking(String id) => Booking(
    id: id,
    venueId: 'v1',
    userId: 'customer1',
    date: DateTime.now().add(const Duration(days: 30)),
    startTime: '17:00',
    endTime: '18:00',
    totalPrice: 300000,
  );

  Booking promoBooking(
    String id,
    String userId,
    String promoId,
    String code, {
    String startTime = '17:00',
  }) => Booking(
    id: id,
    venueId: 'v1',
    userId: userId,
    date: DateTime.now().add(const Duration(days: 30)),
    startTime: startTime,
    endTime:
        '${(int.parse(startTime.substring(0, 2)) + 1).toString().padLeft(2, '0')}:00',
    originalAmount: 300000,
    discountAmount: 30000,
    totalPrice: 270000,
    promoId: promoId,
    promotionCode: code,
  );

  test('Promotion enforces total quota and records cross-user usage', () {
    final promo = Promotion(
      id: 'quota-${DateTime.now().microsecondsSinceEpoch}',
      code: 'QUOTA',
      discountPercent: 10,
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      usageLimit: 2,
      perUserLimit: 3,
    );
    MockStore.promotions.add(promo);

    expect(
      MockStore.confirmBooking(
        promoBooking('q1', 'customer1', promo.id, promo.code),
        'cash',
      ),
      isTrue,
    );
    expect(
      MockStore.confirmBooking(
        promoBooking(
          'q2',
          'customer1',
          promo.id,
          promo.code,
          startTime: '18:00',
        ),
        'cash',
      ),
      isTrue,
    );
    expect(
      MockStore.confirmBooking(
        promoBooking(
          'q3',
          'customer2',
          promo.id,
          promo.code,
          startTime: '19:00',
        ),
        'cash',
      ),
      isFalse,
    );
    expect(promo.usedCount, 2);
    expect(promo.usageHistory.map((usage) => usage.userId), [
      'customer1',
      'customer1',
    ]);
    expect(promo.usageHistory.map((usage) => usage.bookingId), ['q1', 'q2']);
    expect(promo.usedCount, 2);
    expect(
      MockStore.confirmBooking(
        promoBooking('q1', 'customer1', promo.id, promo.code),
        'cash',
      ),
      isFalse,
    );
    expect(promo.usageHistory.length, 2);
  });

  test('Promotion enforces per-user quota while allowing another user', () {
    final promo = Promotion(
      id: 'user-quota-${DateTime.now().microsecondsSinceEpoch}',
      code: 'USERQ',
      discountPercent: 10,
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      usageLimit: 5,
      perUserLimit: 1,
    );
    MockStore.promotions.add(promo);
    expect(
      MockStore.confirmBooking(
        promoBooking('uq1', 'customer1', promo.id, promo.code),
        'cash',
      ),
      isTrue,
    );
    expect(
      MockStore.confirmBooking(
        promoBooking(
          'uq2',
          'customer1',
          promo.id,
          promo.code,
          startTime: '18:00',
        ),
        'cash',
      ),
      isFalse,
    );
    expect(
      MockStore.confirmBooking(
        promoBooking(
          'uq3',
          'customer2',
          promo.id,
          promo.code,
          startTime: '19:00',
        ),
        'cash',
      ),
      isTrue,
    );
    expect(promo.usedCount, 2);
    expect(promo.usageHistory.map((usage) => usage.userId), [
      'customer1',
      'customer2',
    ]);
  });

  test('Customer and owner cancellation restore only recorded usage once', () {
    final promo = Promotion(
      id: 'cancel-quota-${DateTime.now().microsecondsSinceEpoch}',
      code: 'CANCELQ',
      discountPercent: 10,
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      usageLimit: 5,
      perUserLimit: 2,
    );
    MockStore.promotions.add(promo);
    final customerBooking = promoBooking(
      'cancel-customer',
      'customer1',
      promo.id,
      promo.code,
    );
    final ownerBooking = promoBooking(
      'cancel-owner',
      'customer2',
      promo.id,
      promo.code,
      startTime: '18:00',
    );
    expect(MockStore.confirmBooking(customerBooking, 'cash'), isTrue);
    expect(MockStore.confirmBooking(ownerBooking, 'cash'), isTrue);
    expect(promo.usedCount, 2);

    expect(BookingController.cancelBooking(customerBooking.id), isTrue);
    expect(promo.usedCount, 1);
    expect(
      MockStore.cancelBooking(
        ownerBooking.id,
        cancelReason: 'Owner cancellation',
      ),
      isTrue,
    );
    expect(promo.usedCount, 0);
    expect(MockStore.cancelBooking(ownerBooking.id), isFalse);
    expect(promo.usedCount, 0);
    expect(promo.usageHistory.every((usage) => usage.isReversed), isTrue);
  });

  test(
    'Cancellation without a recorded promotion use does not change usage',
    () {
      final promo = Promotion(
        id: 'legacy-${DateTime.now().microsecondsSinceEpoch}',
        code: 'LEGACY',
        discountPercent: 10,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        usedCount: 1,
      );
      MockStore.promotions.add(promo);
      final booking = promoBooking(
        'legacy-booking',
        'customer1',
        promo.id,
        promo.code,
      );
      booking.status = 'confirmed';
      MockStore.bookings.add(booking);
      expect(MockStore.cancelBooking(booking.id), isTrue);
      expect(promo.usedCount, 1);
    },
  );
  test('Cancellation rejects paid booking when payment is missing', () {
    final booking = futureBooking(
      'paid-without-payment-${DateTime.now().microsecondsSinceEpoch}',
    );
    booking.status = 'confirmed';
    booking.paymentStatus = 'paid';
    MockStore.bookings.add(booking);

    final result = MockStoreBookingCancel.cancelBooking(booking.id);

    expect(result, isNull);
    expect(booking.status, 'confirmed');
    expect(booking.paymentStatus, 'paid');
    expect(booking.cancelledAt, isNull);
    expect(MockStore.paymentOfBooking(booking.id), isNull);
  });

  test('Cancellation rejects paid booking when payment failed', () {
    final booking = futureBooking(
      'paid-with-failed-payment-${DateTime.now().microsecondsSinceEpoch}',
    );
    booking.status = 'confirmed';
    booking.paymentStatus = 'paid';
    MockStore.bookings.add(booking);

    final payment = <String, dynamic>{
      'id': 'failed-${DateTime.now().microsecondsSinceEpoch}',
      'bookingId': booking.id,
      'status': 'failed',
      'amount': booking.totalPrice,
    };
    MockStore.payments.add(payment);

    final result = MockStoreBookingCancel.cancelBooking(booking.id);

    expect(result, isNull);
    expect(booking.status, 'confirmed');
    expect(booking.paymentStatus, 'paid');
    expect(booking.cancelledAt, isNull);
    expect(payment['status'], 'failed');
  });

  test('Cancellation rejects malformed successful payment amount safely', () {
    final booking = futureBooking(
      'paid-with-malformed-amount-${DateTime.now().microsecondsSinceEpoch}',
    );
    booking.status = 'confirmed';
    booking.paymentStatus = 'paid';
    booking.paymentId = 'malformed-amount-payment';
    MockStore.bookings.add(booking);
    final payment = <String, dynamic>{
      'id': booking.paymentId,
      'bookingId': booking.id,
      'status': 'success',
      'amount': '300000',
    };
    MockStore.payments.add(payment);

    expect(MockStoreBookingCancel.cancelBooking(booking.id), isNull);
    expect(MockStore.cancelBooking(booking.id), isFalse);
    expect(booking.status, 'confirmed');
    expect(booking.paymentStatus, 'paid');
    expect(payment['status'], 'success');
    expect(booking.cancelledAt, isNull);
  });

  test('Simulated online payment stores ID and paid status', () {
    final booking = futureBooking('model-payment-online');
    expect(MockStore.confirmBooking(booking, 'momo'), isTrue);
    final payment = MockStore.payments.last;
    expect(booking.paymentId, payment['id']);
    expect(payment['bookingId'], booking.id);
    expect(payment['status'], 'success');
    expect(payment['amount'], 300000);
    expect(booking.paymentStatus, 'paid');
  });

  test('processBookingPayment rejects invalid promotion amounts', () {
    final promo = MockStore.promotions.firstWhere((p) => p.code == 'SAN10');
    final bookingCount = MockStore.bookings.length;
    final paymentCount = MockStore.payments.length;
    final usedCount = promo.usedCount;

    final invalidBookings = [
      Booking(
        id: 'invalid-nan-${DateTime.now().microsecondsSinceEpoch}',
        venueId: 'v1',
        userId: 'customer1',
        date: DateTime.now().add(const Duration(days: 30)),
        startTime: '17:00',
        endTime: '18:00',
        totalPrice: double.nan,
        originalAmount: 300000,
        discountAmount: 30000,
        promoId: promo.id,
        promotionCode: promo.code,
      ),
      Booking(
        id: 'invalid-discount-${DateTime.now().microsecondsSinceEpoch}',
        venueId: 'v1',
        userId: 'customer1',
        date: DateTime.now().add(const Duration(days: 30)),
        startTime: '18:00',
        endTime: '19:00',
        totalPrice: 250000,
        originalAmount: 300000,
        discountAmount: 10000,
        promoId: promo.id,
        promotionCode: promo.code,
      ),
      Booking(
        id: 'invalid-promo-id-${DateTime.now().microsecondsSinceEpoch}',
        venueId: 'v1',
        userId: 'customer1',
        date: DateTime.now().add(const Duration(days: 30)),
        startTime: '19:00',
        endTime: '20:00',
        totalPrice: 270000,
        originalAmount: 300000,
        discountAmount: 30000,
        promoId: 'wrong-promo-id',
        promotionCode: promo.code,
      ),
    ];

    for (final booking in invalidBookings) {
      final result = MockStore.processBookingPayment(
        booking: booking,
        method: 'momo',
      );
      expect(result.isSuccess, isFalse);
    }

    expect(MockStore.bookings.length, bookingCount);
    expect(MockStore.payments.length, paymentCount);
    expect(promo.usedCount, usedCount);
  });

  test('Failed online payment does not consume promotion usage', () {
    final promo = MockStore.promotions.firstWhere((p) => p.code == 'SAN10');
    final usedCount = promo.usedCount;
    final booking = Booking(
      id: 'failed-promo-${DateTime.now().microsecondsSinceEpoch}',
      venueId: 'v1',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 30)),
      startTime: '17:00',
      endTime: '18:00',
      totalPrice: 270000,
      originalAmount: 300000,
      discountAmount: 30000,
      promoId: promo.id,
      promotionCode: promo.code,
    );

    final result = MockStore.processBookingPayment(
      booking: booking,
      method: 'momo',
      simulateFailure: true,
    );

    expect(result.isSuccess, isFalse);
    expect(booking.status, 'cancelled');
    expect(booking.paymentStatus, 'unpaid');
    expect(promo.usedCount, usedCount);
    expect(
      promo.usageHistory.any((usage) => usage.bookingId == booking.id),
      isFalse,
    );
    expect(MockStore.paymentOfBooking(booking.id)?['status'], 'failed');
  });

  test('Cancelling a promotion booking twice decrements usage only once', () {
    final promo = MockStore.promotions.firstWhere((p) => p.code == 'SAN10');
    final booking = Booking(
      id: 'cancel-promo-${DateTime.now().microsecondsSinceEpoch}',
      venueId: 'v1',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 30)),
      startTime: '17:00',
      endTime: '18:00',
      totalPrice: 270000,
      originalAmount: 300000,
      discountAmount: 30000,
      promoId: promo.id,
      promotionCode: promo.code,
    );

    expect(MockStore.confirmBooking(booking, 'cash'), isTrue);
    final countAfterBooking = promo.usedCount;

    expect(MockStore.cancelBooking(booking.id), isTrue);
    expect(promo.usedCount, countAfterBooking - 1);

    expect(MockStore.cancelBooking(booking.id), isFalse);
    expect(promo.usedCount, countAfterBooking - 1);
  });
  test('BookingController cancellation decrements promo usage once', () {
    final promo = MockStore.promotions.firstWhere((p) => p.code == 'SAN10');

    final booking = Booking(
      id:
          'controller-cancel-promo-'
          '${DateTime.now().microsecondsSinceEpoch}',
      venueId: 'v1',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 30)),
      startTime: '17:00',
      endTime: '18:00',
      totalPrice: 270000,
      originalAmount: 300000,
      discountAmount: 30000,
      promoId: promo.id,
      promotionCode: promo.code,
    );

    expect(MockStore.confirmBooking(booking, 'cash'), isTrue);
    final countAfterBooking = promo.usedCount;

    expect(BookingController.cancelBooking(booking.id), isTrue);
    expect(booking.status, 'cancelled');
    expect(promo.usedCount, countAfterBooking - 1);

    expect(BookingController.cancelBooking(booking.id), isFalse);
    expect(promo.usedCount, countAfterBooking - 1);
  });
  test('Cash booking stays unpaid with a pending payment record', () {
    final booking = futureBooking('model-payment-cash');
    expect(MockStore.confirmBooking(booking, 'cash'), isTrue);
    final payment = MockStore.payments.last;
    expect(booking.paymentId, payment['id']);
    expect(payment['bookingId'], booking.id);
    expect(payment['status'], 'pending');
    expect(booking.paymentStatus, 'unpaid');
  });

  test(
    'Payment rejects court amount that does not match venue rate and duration',
    () {
      final booking = Booking(
        id: 'wrong-court-amount-${DateTime.now().microsecondsSinceEpoch}',
        venueId: 'v1',
        userId: 'customer1',
        date: DateTime.now().add(const Duration(days: 30)),
        startTime: '17:00',
        endTime: '19:00',
        originalAmount: 300000,
        totalPrice: 300000,
      );
      final bookingCount = MockStore.bookings.length;
      final paymentCount = MockStore.payments.length;

      final result = MockStore.processBookingPayment(
        booking: booking,
        method: 'momo',
      );

      expect(result.isSuccess, isFalse);
      expect(MockStore.bookings.length, bookingCount);
      expect(MockStore.payments.length, paymentCount);
    },
  );

  test('Payment rejects a payment ID already linked to another booking', () {
    final booking = Booking(
      id: 'duplicate-payment-id-${DateTime.now().microsecondsSinceEpoch}',
      venueId: 'v1',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 30)),
      startTime: '17:00',
      endTime: '18:00',
      totalPrice: 300000,
      paymentId: 'pay1',
    );
    final bookingCount = MockStore.bookings.length;
    final paymentCount = MockStore.payments.length;

    final result = MockStore.processBookingPayment(
      booking: booking,
      method: 'momo',
    );

    expect(result.isSuccess, isFalse);
    expect(MockStore.bookings.length, bookingCount);
    expect(MockStore.payments.length, paymentCount);
  });

  test(
    'Service quantities are stored and drive the validated service total',
    () {
      final item = BookingServiceItem(
        serviceId: 's1',
        quantity: 3,
        unitPrice: 30000,
      );
      final booking = Booking(
        id: 'service-quantity-${DateTime.now().microsecondsSinceEpoch}',
        venueId: 'v1',
        userId: 'customer1',
        date: DateTime.now().add(const Duration(days: 30)),
        startTime: '17:00',
        endTime: '18:00',
        originalAmount: 300000,
        serviceAmount: 90000,
        totalPrice: 390000,
        serviceItems: [item],
      );

      expect(MockStore.confirmBooking(booking, 'cash'), isTrue);
      expect(booking.serviceItems.single.quantity, 3);
      expect(booking.serviceItems.single.subtotal, 90000);
      expect(MockStore.payments.last['amount'], 390000);
    },
  );

  test(
    'Service payment rejects a total inconsistent with quantity details',
    () {
      final booking = Booking(
        id: 'bad-service-total-${DateTime.now().microsecondsSinceEpoch}',
        venueId: 'v1',
        userId: 'customer1',
        date: DateTime.now().add(const Duration(days: 30)),
        startTime: '17:00',
        endTime: '18:00',
        originalAmount: 300000,
        serviceAmount: 80000,
        totalPrice: 380000,
        serviceItems: [
          BookingServiceItem(serviceId: 's1', quantity: 3, unitPrice: 30000),
        ],
      );
      final bookingCount = MockStore.bookings.length;
      final paymentCount = MockStore.payments.length;

      expect(MockStore.confirmBooking(booking, 'momo'), isFalse);
      expect(MockStore.bookings.length, bookingCount);
      expect(MockStore.payments.length, paymentCount);
    },
  );
}
