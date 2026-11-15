import 'package:flutter_test/flutter_test.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'sqlite_test_env.dart';

const _bookingId = 'cancel-reason';

/// Hủy thất bại phải nêu rõ lý do, không chỉ trả về "không thành công".
void main() {
  late SqliteTestEnv env;

  setUp(() async {
    env = await SqliteTestEnv.open('cancel_reason');
    await env.db.insert('Users', {
      'user_id': 'owner_1', 'full_name': 'Chủ sân', 'email': 'owner@test.local',
      'phone': '0900000001', 'password_hash': 'x', 'role': 'owner',
    });
    await env.db.insert('Users', {
      'user_id': 'customer_1', 'full_name': 'Khách', 'email': 'customer@test.local',
      'phone': '0900000002', 'password_hash': 'x', 'role': 'customer',
    });
    await env.db.insert('venues', {
      'id': 'venue_1', 'ownerId': 'owner_1', 'sportType': 'football', 'name': 'Sân 1',
      'address': 'Quận 1', 'pricePerHour': 150000, 'latitude': 10.0,
      'longitude': 106.0, 'status': 'approved',
    });
    await BookingRepository.processBookingPayment(
      booking: Booking(
        id: _bookingId,
        venueId: 'venue_1',
        userId: 'customer_1',
        date: DateTime.now().add(const Duration(days: 1)),
        startTime: '18:00',
        endTime: '19:00',
        totalPrice: 150000,
      ),
      method: 'cash',
    );
  });

  tearDown(() async {
    await env.close();
  });

  test('hủy thành công trả về null', () async {
    expect(await BookingRepository.cancelBookingFailure(_bookingId), isNull);
  });

  test('quá gần giờ bắt đầu: lý do nêu rõ thời hạn 2 giờ', () async {
    await env.db.update(
      'bookings',
      {'date': DateTime.now().toIso8601String(), 'startTime': '00:00'},
      where: 'id = ?',
      whereArgs: [_bookingId],
    );

    final reason = await BookingRepository.cancelBookingFailure(_bookingId);
    expect(reason, isNotNull);
    expect(reason, contains('2 giờ'));
  });

  test('đơn đã hủy: lý do nêu trạng thái hiện tại', () async {
    expect(await BookingRepository.cancelBookingFailure(_bookingId), isNull);

    final reason = await BookingRepository.cancelBookingFailure(_bookingId);
    expect(reason, isNotNull);
    expect(reason, contains('cancelled'));
  });
}
