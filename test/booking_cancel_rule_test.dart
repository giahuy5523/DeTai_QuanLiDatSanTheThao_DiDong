import 'package:flutter_test/flutter_test.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'sqlite_test_env.dart';

const _bookingId = 'cancel-rule';

/// Quy tắc hủy: chỉ hủy khi còn ít nhất 2 giờ trước giờ bắt đầu.
void main() {
  late SqliteTestEnv env;

  setUp(() async {
    env = await SqliteTestEnv.open('cancel_rule');
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
  });

  tearDown(() async {
    await env.close();
  });

  Future<void> bookTomorrow() async {
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
  }

  test('hủy đơn còn hơn 2 giờ trước giờ bắt đầu: được hủy', () async {
    await bookTomorrow();

    expect(await BookingRepository.cancelBooking(_bookingId), isTrue);
    final row = (await env.db.query(
      'bookings', where: 'id = ?', whereArgs: [_bookingId],
    )).single;
    expect(row['status'], 'cancelled');
  });

  test('hủy đơn đã bắt đầu hoặc sắp bắt đầu: không được hủy', () async {
    await bookTomorrow();
    // Đưa đơn về đầu ngày hôm nay, tức đã bắt đầu.
    await env.db.update(
      'bookings',
      {'date': DateTime.now().toIso8601String(), 'startTime': '00:00'},
      where: 'id = ?',
      whereArgs: [_bookingId],
    );

    expect(await BookingRepository.cancelBooking(_bookingId), isFalse);
    final row = (await env.db.query(
      'bookings', where: 'id = ?', whereArgs: [_bookingId],
    )).single;
    expect(row['status'], 'confirmed');
  });
}
