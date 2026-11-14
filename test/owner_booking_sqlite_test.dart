import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'sqlite_test_env.dart';

const _ownerId = 'owner_1';
const _customerId = 'customer_1';
const _venueId = 'venue_1';
const _bookingId = 'owner-regression';
const _promoId = 'promo_san10';

/// Chủ sân xác nhận, hoàn thành, hủy và hoàn tiền trên SQLite thật.
void main() {
  late SqliteTestEnv env;

  setUp(() async {
    env = await SqliteTestEnv.open('owner_booking');
    await _seed(env.db);
  });

  tearDown(() async {
    await env.close();
  });

  Booking promoBooking() => Booking(
    id: _bookingId,
    venueId: _venueId,
    userId: _customerId,
    date: DateTime.now().add(const Duration(days: 2)),
    startTime: '18:00',
    endTime: '19:00',
    totalPrice: 135000,
    originalAmount: 150000,
    serviceAmount: 0,
    discountAmount: 15000,
    promoId: _promoId,
    promotionCode: 'SAN10',
    note: 'Giữ ghi chú',
  );

  Future<Map<String, Object?>> bookingRow() async =>
      (await env.db.query(
        'bookings',
        where: 'id = ?',
        whereArgs: [_bookingId],
      )).single;

  Future<Map<String, Object?>> paymentRow() async =>
      (await env.db.query(
        'payments',
        where: 'bookingId = ?',
        whereArgs: [_bookingId],
      )).single;

  /// Đơn vừa được thanh toán sẽ ở trạng thái confirmed; các test chủ sân
  /// cần bắt đầu từ pending để kiểm tra việc chuyển trạng thái.
  Future<void> markPending() async {
    await env.db.update(
      'bookings',
      {'status': 'pending'},
      where: 'id = ?',
      whereArgs: [_bookingId],
    );
  }

  Future<int> promoUsed() async =>
      (await env.db.query(
            'promotions',
            columns: ['usedCount'],
            where: 'id = ?',
            whereArgs: [_promoId],
          )).single['usedCount']
          as int;

  test('đơn có khuyến mãi: đã trả và tăng số lần dùng mã lên 1', () async {
    final result = await BookingRepository.processBookingPayment(
      booking: promoBooking(),
      method: 'momo',
    );

    expect(result.isSuccess, isTrue);
    expect((await bookingRow())['paymentStatus'], 'paid');
    expect((await paymentRow())['status'], 'success');
    expect(await promoUsed(), 1);
  });

  test('chủ sân xác nhận rồi hoàn thành, giữ nguyên tiền và ghi chú', () async {
    await BookingRepository.processBookingPayment(
      booking: promoBooking(),
      method: 'momo',
    );
    await markPending();

    expect(
      await BookingRepository.updateBookingStatusByOwner(
        bookingId: _bookingId,
        newStatus: 'confirmed',
        ownerId: _ownerId,
      ),
      isTrue,
    );
    expect((await bookingRow())['status'], 'confirmed');

    expect(
      await BookingRepository.updateBookingStatusByOwner(
        bookingId: _bookingId,
        newStatus: 'completed',
        ownerId: _ownerId,
      ),
      isTrue,
    );
    final row = await bookingRow();
    expect(row['status'], 'completed');
    expect(row['paymentStatus'], 'paid');
    expect(row['originalAmount'], 150000);
    expect(row['discountAmount'], 15000);
    expect(row['note'], 'Giữ ghi chú');
    expect(await promoUsed(), 1);
  });

  test('người không sở hữu sân không đổi được trạng thái đơn', () async {
    await BookingRepository.processBookingPayment(
      booking: promoBooking(),
      method: 'momo',
    );
    await markPending();

    expect(
      await BookingRepository.updateBookingStatusByOwner(
        bookingId: _bookingId,
        newStatus: 'confirmed',
        ownerId: _customerId,
      ),
      isFalse,
    );
    expect((await bookingRow())['status'], 'pending');
  });

  test('hủy đơn đã trả: hoàn tiền đang xử lý, trả lại lượt dùng mã, hoàn tất một lần', () async {
    await BookingRepository.processBookingPayment(
      booking: promoBooking(),
      method: 'momo',
    );

    expect(await BookingRepository.cancelBooking(_bookingId), isTrue);
    final row = await bookingRow();
    expect(row['status'], 'cancelled');
    expect(row['paymentStatus'], 'paid');
    expect((await paymentRow())['refundStatus'], 'processing');
    expect(await promoUsed(), 0);

    expect(await BookingRepository.completeRefund(_bookingId), isTrue);
    expect((await paymentRow())['refundStatus'], 'succeeded');
    expect((await paymentRow())['status'], 'refunded');
    expect((await bookingRow())['paymentStatus'], 'refunded');

    expect(await BookingRepository.completeRefund(_bookingId), isFalse);
    expect(await BookingRepository.cancelBooking(_bookingId), isFalse);
    expect(await promoUsed(), 0);
  });
}

Future<void> _seed(Database db) async {
  await db.insert('Users', {
    'user_id': _ownerId,
    'full_name': 'Chủ sân',
    'email': 'owner@test.local',
    'phone': '0900000001',
    'password_hash': 'x',
    'role': 'owner',
  });
  await db.insert('Users', {
    'user_id': _customerId,
    'full_name': 'Khách',
    'email': 'customer@test.local',
    'phone': '0900000002',
    'password_hash': 'x',
    'role': 'customer',
  });
  await db.insert('venues', {
    'id': _venueId,
    'ownerId': _ownerId,
    'sportType': 'football',
    'name': 'Sân 1',
    'address': 'Quận 1',
    'pricePerHour': 150000,
    'latitude': 10.0,
    'longitude': 106.0,
    'status': 'approved',
  });
  await db.insert('promotions', {
    'id': _promoId,
    'code': 'SAN10',
    'discountPercent': 10,
    'expiryDate': DateTime(2030).toIso8601String(),
    'isActive': 1,
    'usedCount': 0,
  });
}
