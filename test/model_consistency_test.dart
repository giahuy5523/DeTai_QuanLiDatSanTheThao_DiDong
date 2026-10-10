import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/models/payment.dart';
import 'package:sportfield_booking/models/sport_type.dart';
import 'package:sportfield_booking/models/venue.dart';

void main() {
  final initialBookings = List<Booking>.of(MockStore.bookings);
  final initialPayments = List<Map<String, dynamic>>.of(MockStore.payments);

  tearDown(() {
    MockStore.bookings
      ..clear()
      ..addAll(initialBookings);
    MockStore.payments
      ..clear()
      ..addAll(initialPayments);
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
