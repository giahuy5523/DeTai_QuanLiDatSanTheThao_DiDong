import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

/// Các trường hợp lỗi của luồng đặt sân chạy trên thiết bị với SQLite thật.
/// Không đi qua giao diện: kiểm tra trực tiếp kết quả repository và database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Chạy thao tác I/O thật (database) trong môi trường test của thiết bị.
  Future<T> io<T>(WidgetTester tester, Future<T> Function() action) async {
    final result = await tester.runAsync(action);
    return result as T;
  }

  /// Database sạch, có chủ sân, khách, một sân đã duyệt, khuyến mãi còn hạn và đã hết hạn.
  Future<void> seed(WidgetTester tester) async {
    await io(tester, () async {
      await DatabaseHelper.resetForTesting();
      final db = await DatabaseHelper().database;
      // Kết nối cũ đã đóng sau reset: trỏ repository tới database mới.
      BookingRepository.setDatabaseForTesting(db);
      await db.insert('Users', {
        'user_id': 'e_owner', 'full_name': 'Chủ sân', 'email': 'e_owner@test.local',
        'phone': '0900000021', 'password_hash': 'x', 'role': 'owner',
      });
      await db.insert('Users', {
        'user_id': 'e_customer', 'full_name': 'Khách A', 'email': 'e_a@test.local',
        'phone': '0900000022', 'password_hash': 'x', 'role': 'customer',
      });
      await db.insert('Users', {
        'user_id': 'e_customer2', 'full_name': 'Khách B', 'email': 'e_b@test.local',
        'phone': '0900000023', 'password_hash': 'x', 'role': 'customer',
      });
      await db.insert('venues', {
        'id': 'e_venue', 'ownerId': 'e_owner', 'sportType': 'football', 'name': 'Sân lỗi',
        'address': 'Quận 1', 'pricePerHour': 150000, 'latitude': 10.0, 'longitude': 106.0,
        'status': 'approved',
      });
      await db.insert('promotions', {
        'id': 'e_promo_ok', 'code': 'SAN10', 'discountPercent': 10,
        'expiryDate': DateTime(2030).toIso8601String(), 'isActive': 1, 'usedCount': 0,
      });
      await db.insert('promotions', {
        'id': 'e_promo_het_han', 'code': 'HETHAN', 'discountPercent': 10,
        'expiryDate': DateTime(2020).toIso8601String(), 'isActive': 1, 'usedCount': 0,
      });
    });
  }

  Booking bookingFor({
    required String id,
    required String userId,
    String startTime = '18:00',
    String endTime = '19:00',
    String? promoId,
    String? promotionCode,
  }) {
    final hasPromo = promoId != null;
    return Booking(
      id: id,
      venueId: 'e_venue',
      userId: userId,
      date: DateTime.now().add(const Duration(days: 7)),
      startTime: startTime,
      endTime: endTime,
      totalPrice: hasPromo ? 135000 : 150000,
      originalAmount: 150000,
      serviceAmount: 0,
      discountAmount: hasPromo ? 15000 : 0,
      promoId: promoId,
      promotionCode: promotionCode,
    );
  }

  Future<List<Map<String, Object?>>> rows(
    WidgetTester tester,
    String table,
    String where,
    List<Object?> args,
  ) async {
    return io(tester, () async {
      final db = await DatabaseHelper().database;
      return db.query(table, where: where, whereArgs: args);
    });
  }

  testWidgets('đặt trùng khung giờ: người thứ hai bị từ chối', (tester) async {
    await seed(tester);
    final first = await io(tester, () => BookingRepository.processBookingPayment(
          booking: bookingFor(id: 'e_b1', userId: 'e_customer'),
          method: 'cash',
        ));
    expect(first.isSuccess, isTrue);

    final second = await io(tester, () => BookingRepository.processBookingPayment(
          booking: bookingFor(id: 'e_b2', userId: 'e_customer2'),
          method: 'cash',
        ));
    expect(second.isSuccess, isFalse);
    expect(second.isSlotAvailable, isFalse);
    expect(await rows(tester, 'bookings', 'id = ?', ['e_b2']), isEmpty);
  });

  testWidgets('mã khuyến mãi hết hạn: đặt bị từ chối, không ghi đơn', (tester) async {
    await seed(tester);
    final result = await io(tester, () => BookingRepository.processBookingPayment(
          booking: bookingFor(
            id: 'e_b3',
            userId: 'e_customer',
            promoId: 'e_promo_het_han',
            promotionCode: 'HETHAN',
          ),
          method: 'momo',
        ));
    expect(result.isSuccess, isFalse);
    expect(result.failureReason, 'Mã khuyến mãi đã hết hạn.');
    expect(await rows(tester, 'bookings', 'id = ?', ['e_b3']), isEmpty);
  });

  testWidgets('thanh toán thất bại: đơn bị hủy và giờ được trả lại', (tester) async {
    await seed(tester);
    final failed = await io(tester, () => BookingRepository.processBookingPayment(
          booking: bookingFor(id: 'e_b4', userId: 'e_customer'),
          method: 'momo',
          simulateFailure: true,
        ));
    expect(failed.isSuccess, isFalse);
    final row = await rows(tester, 'bookings', 'id = ?', ['e_b4']);
    expect(row.single['status'], 'cancelled');

    // Khung giờ không còn bị giữ: người khác đặt được ngay.
    final next = await io(tester, () => BookingRepository.processBookingPayment(
          booking: bookingFor(id: 'e_b5', userId: 'e_customer2'),
          method: 'cash',
        ));
    expect(next.isSuccess, isTrue);
  });

  testWidgets('hủy đơn còn dưới 2 giờ: bị từ chối với lý do rõ ràng', (tester) async {
    await seed(tester);
    await io(tester, () => BookingRepository.processBookingPayment(
          booking: bookingFor(id: 'e_b6', userId: 'e_customer'),
          method: 'cash',
        ));
    // Đưa đơn về sát giờ bắt đầu (đã qua đầu ngày hôm nay).
    await io(tester, () async {
      final db = await DatabaseHelper().database;
      await db.update(
        'bookings',
        {'date': DateTime.now().toIso8601String(), 'startTime': '00:00'},
        where: 'id = ?',
        whereArgs: ['e_b6'],
      );
    });

    final reason = await io(tester, () => BookingRepository.cancelBookingFailure('e_b6'));
    expect(reason, isNotNull);
    expect(reason, contains('2 giờ'));
    final row = await rows(tester, 'bookings', 'id = ?', ['e_b6']);
    expect(row.single['status'], 'confirmed');
  });

  testWidgets('hoàn tiền hai lần: chỉ xác nhận được một lần', (tester) async {
    await seed(tester);
    await io(tester, () => BookingRepository.processBookingPayment(
          booking: bookingFor(id: 'e_b7', userId: 'e_customer', promoId: 'e_promo_ok', promotionCode: 'SAN10'),
          method: 'momo',
        ));
    expect(await io(tester, () => BookingRepository.cancelBooking('e_b7')), isTrue);

    expect(await io(tester, () => BookingRepository.completeRefund('e_b7')), isTrue);
    expect(await io(tester, () => BookingRepository.completeRefund('e_b7')), isFalse);
    final pay = await rows(tester, 'payments', 'bookingId = ?', ['e_b7']);
    expect(pay.single['refundStatus'], 'succeeded');
  });
}
