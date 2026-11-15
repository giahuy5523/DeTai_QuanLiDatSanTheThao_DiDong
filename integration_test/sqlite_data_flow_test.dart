import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

/// Chạy trên thiết bị Android: đặt → thanh toán → hủy → hoàn tiền
/// bằng SQLite thật của thiết bị (không dùng sqflite_ffi).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const bookingId = 'device-flow';
  const promoId = 'device_promo_san10';

  testWidgets('đặt, thanh toán, hủy và hoàn tiền trên SQLite thiết bị', (tester) async {
    await tester.runAsync(() async {
      await DatabaseHelper.resetForTesting();
      final db = await DatabaseHelper().database;
      await db.insert('Users', {
        'user_id': 'device_owner', 'full_name': 'Chủ sân', 'email': 'dev_owner@test.local',
        'phone': '0900000011', 'password_hash': 'x', 'role': 'owner',
      });
      await db.insert('Users', {
        'user_id': 'device_customer', 'full_name': 'Khách', 'email': 'dev_customer@test.local',
        'phone': '0900000012', 'password_hash': 'x', 'role': 'customer',
      });
      await db.insert('venues', {
        'id': 'device_venue', 'ownerId': 'device_owner', 'sportType': 'football', 'name': 'Sân thiết bị',
        'address': 'Quận 1', 'pricePerHour': 150000, 'latitude': 10.0, 'longitude': 106.0, 'status': 'approved',
      });
      await db.insert('promotions', {
        'id': promoId, 'code': 'SAN10', 'discountPercent': 10,
        'expiryDate': DateTime(2030).toIso8601String(), 'isActive': 1, 'usedCount': 0,
      });

      final booked = await BookingRepository.processBookingPayment(
        booking: Booking(
          id: bookingId,
          venueId: 'device_venue',
          userId: 'device_customer',
          date: DateTime.now().add(const Duration(days: 1)),
          startTime: '18:00',
          endTime: '19:00',
          totalPrice: 135000,
          originalAmount: 150000,
          serviceAmount: 0,
          discountAmount: 15000,
          promoId: promoId,
          promotionCode: 'SAN10',
        ),
        method: 'momo',
      );
      expect(booked.isSuccess, isTrue);

      final used = await db.query('promotions', columns: ['usedCount'], where: 'id = ?', whereArgs: [promoId]);
      expect(used.single['usedCount'], 1);

      expect(await BookingRepository.cancelBookingFailure(bookingId), isNull);
      final cancelled = await db.query('bookings', where: 'id = ?', whereArgs: [bookingId]);
      expect(cancelled.single['status'], 'cancelled');
      final afterCancel = await db.query('promotions', columns: ['usedCount'], where: 'id = ?', whereArgs: [promoId]);
      expect(afterCancel.single['usedCount'], 0);

      final refund = await db.query('payments', where: 'bookingId = ?', whereArgs: [bookingId]);
      expect(refund.single['refundStatus'], 'processing');

      expect(await BookingRepository.completeRefund(bookingId), isTrue);
      expect(await BookingRepository.completeRefund(bookingId), isFalse);
      final done = await db.query('payments', where: 'bookingId = ?', whereArgs: [bookingId]);
      expect(done.single['refundStatus'], 'succeeded');
    });
  });
}
