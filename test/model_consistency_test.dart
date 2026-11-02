import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/screens/customer/booking_history_screen.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/models/payment.dart';
import 'package:sportfield_booking/models/sport_type.dart';
import 'package:sportfield_booking/models/venue.dart';

void main() {
  final initialBookings = List<Booking>.of(MockStore.bookings);
  final initialPayments = List<Map<String, dynamic>>.of(MockStore.payments);

  final initialPromotionUsedCounts = {
    for (final promotion in MockStore.promotions)
      promotion.id: promotion.usedCount,
  };
  tearDown(() {
    MockStore.bookings
      ..clear()
      ..addAll(initialBookings);
    MockStore.payments
      ..clear()
      ..addAll(initialPayments);

    for (final promotion in MockStore.promotions) {
      final initialCount = initialPromotionUsedCounts[promotion.id];
      if (initialCount != null) {
        promotion.usedCount = initialCount;
      }
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
  test('Cancellation rejects paid booking when payment is missing', () {
    final booking = futureBooking(
      'paid-without-payment-${DateTime.now().microsecondsSinceEpoch}',
    );
    booking.status = 'confirmed';
    booking.paymentStatus = 'paid';
    MockStore.bookings.add(booking);

    final result = BookingRepository.cancelBooking(booking.id);

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

    final result = BookingRepository.cancelBooking(booking.id);

    expect(result, isNull);
    expect(booking.status, 'confirmed');
    expect(booking.paymentStatus, 'paid');
    expect(booking.cancelledAt, isNull);
    expect(payment['status'], 'failed');
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
}
