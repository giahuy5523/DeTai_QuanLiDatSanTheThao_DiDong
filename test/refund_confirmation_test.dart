import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

/// Admin xác nhận kết quả hoàn tiền mô phỏng trên SQLite thật.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late Database db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('refund_confirm_test_');
    db = await databaseFactory.openDatabase(
      '${tempDir.path}${Platform.pathSeparator}refund.db',
      options: OpenDatabaseOptions(
        version: DatabaseHelper.databaseVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => DatabaseHelper().createSchema(db),
      ),
    );
    BookingRepository.setUseMockStoreForTesting(false);
    BookingRepository.setDatabaseForTesting(db);
    await _seedCancelledPaidBooking(db);
  });

  tearDown(() async {
    BookingRepository.setDatabaseForTesting(null);
    BookingRepository.setUseMockStoreForTesting(false);
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('liệt kê khoản hoàn tiền đang chờ xử lý', () async {
    final pending = await BookingRepository.getPendingRefunds();

    expect(pending, hasLength(1));
    expect(pending.single.bookingId, 'booking_1');
    expect(pending.single.userId, 'customer_1');
    expect(pending.single.refundAmount, 150000);
  });

  test('hoàn tất hoàn tiền một lần; bấm lần hai không đổi gì', () async {
    expect(await BookingRepository.completeRefund('booking_1'), isTrue);
    expect(await BookingRepository.completeRefund('booking_1'), isFalse);

    final payment = (await db.query(
      'payments',
      where: 'bookingId = ?',
      whereArgs: ['booking_1'],
    )).single;
    expect(payment['refundStatus'], 'succeeded');
    expect(payment['status'], 'refunded');

    final booking = (await db.query(
      'bookings',
      where: 'id = ?',
      whereArgs: ['booking_1'],
    )).single;
    expect(booking['paymentStatus'], 'refunded');

    expect(await BookingRepository.getPendingRefunds(), isEmpty);
  });

  test('đánh dấu hoàn tiền thất bại và giữ nguyên đã thanh toán', () async {
    expect(await BookingRepository.failRefund('booking_1'), isTrue);

    final payment = (await db.query(
      'payments',
      where: 'bookingId = ?',
      whereArgs: ['booking_1'],
    )).single;
    expect(payment['refundStatus'], 'failed');

    final booking = (await db.query(
      'bookings',
      where: 'id = ?',
      whereArgs: ['booking_1'],
    )).single;
    expect(booking['paymentStatus'], 'paid');

    expect(await BookingRepository.getPendingRefunds(), isEmpty);
  });
}

/// Một khách đã thanh toán online, rồi hủy: có một khoản hoàn tiền đang xử lý.
Future<void> _seedCancelledPaidBooking(Database db) async {
  await db.insert('Users', {
    'user_id': 'owner_1',
    'full_name': 'Chủ sân',
    'email': 'owner@test.local',
    'phone': '0900000001',
    'password_hash': 'x',
    'role': 'owner',
  });
  await db.insert('Users', {
    'user_id': 'customer_1',
    'full_name': 'Khách',
    'email': 'customer@test.local',
    'phone': '0900000002',
    'password_hash': 'x',
    'role': 'customer',
  });
  await db.insert('venues', {
    'id': 'venue_1',
    'ownerId': 'owner_1',
    'sportType': 'football',
    'name': 'Sân 1',
    'address': 'Quận 1',
    'pricePerHour': 150000,
    'latitude': 10.0,
    'longitude': 106.0,
    'status': 'approved',
  });
  await db.insert('bookings', {
    'id': 'booking_1',
    'venueId': 'venue_1',
    'userId': 'customer_1',
    'date': '2026-11-20T00:00:00.000',
    'startTime': '18:00',
    'endTime': '19:00',
    'totalPrice': 150000,
    'originalAmount': 150000,
    'serviceAmount': 0,
    'discountAmount': 0,
    'status': 'cancelled',
    'paymentStatus': 'paid',
    'paymentId': 'pay_1',
    'cancelReason': 'Khách hủy',
    'cancelledAt': '2026-11-12T10:00:00.000',
    'createdAt': '2026-11-11T10:00:00.000',
  });
  await db.insert('payments', {
    'id': 'pay_1',
    'bookingId': 'booking_1',
    'method': 'momo',
    'amount': 150000,
    'status': 'success',
    'transactionCode': 'TXN123456',
    'paidAt': '2026-11-11T10:00:00.000',
    'createdAt': '2026-11-11T10:00:00.000',
    'refundAmount': 150000,
    'refundStatus': 'processing',
  });
}
