import 'package:flutter_test/flutter_test.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'sqlite_test_env.dart';

const _bookingId = 'owner-check';

/// Chỉ khách đặt đơn hoặc chủ sân của sân đó mới được hủy đơn.
void main() {
  late SqliteTestEnv env;

  setUp(() async {
    env = await SqliteTestEnv.open('cancel_owner_check');
    for (final u in [
      ['owner_1', 'Chủ sân 1', 'owner1@test.local', 'owner'],
      ['owner_2', 'Chủ sân 2', 'owner2@test.local', 'owner'],
      ['customer_1', 'Khách 1', 'c1@test.local', 'customer'],
      ['customer_2', 'Khách 2', 'c2@test.local', 'customer'],
    ]) {
      await env.db.insert('Users', {
        'user_id': u[0], 'full_name': u[1], 'email': u[2],
        'phone': '0900000000', 'password_hash': 'x', 'role': u[3],
      });
    }
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

  Future<String> statusOf() async {
    final rows = await env.db.query(
      'bookings', columns: ['status'], where: 'id = ?', whereArgs: [_bookingId],
    );
    return rows.single['status'] as String;
  }

  test('khách khác không hủy được đơn của người khác', () async {
    final reason = await BookingRepository.cancelBookingFailure(
      _bookingId,
      userId: 'customer_2',
    );
    expect(reason, 'Bạn không có quyền hủy đơn này.');
    expect(await statusOf(), 'confirmed');
  });

  test('chủ sân khác không hủy được đơn của sân không thuộc mình', () async {
    final reason = await BookingRepository.cancelBookingFailure(
      _bookingId,
      ownerId: 'owner_2',
    );
    expect(reason, 'Bạn không có quyền hủy đơn này.');
    expect(await statusOf(), 'confirmed');
  });

  test('khách đặt đơn hoặc chủ sân đúng hủy được đơn', () async {
    final reason = await BookingRepository.cancelBookingFailure(
      _bookingId,
      ownerId: 'owner_1',
    );
    expect(reason, isNull);
    expect(await statusOf(), 'cancelled');
  });
}
