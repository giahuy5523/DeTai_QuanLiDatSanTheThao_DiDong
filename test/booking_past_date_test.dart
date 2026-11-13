import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

/// Không cho đặt sân cho ngày đã qua; ngày hôm nay vẫn đặt được.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late Database db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('past_date_test_');
    db = await databaseFactory.openDatabase(
      '${tempDir.path}${Platform.pathSeparator}past_date.db',
      options: OpenDatabaseOptions(
        version: DatabaseHelper.databaseVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => DatabaseHelper().createSchema(db),
      ),
    );
    BookingRepository.setUseMockStoreForTesting(false);
    BookingRepository.setDatabaseForTesting(db);
    await _seedApprovedVenueAndCustomer(db);
  });

  tearDown(() async {
    BookingRepository.setDatabaseForTesting(null);
    BookingRepository.setUseMockStoreForTesting(false);
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Booking cashBooking({required String id, required DateTime date}) {
    return Booking(
      id: id,
      venueId: 'venue_1',
      userId: 'customer_1',
      date: date,
      startTime: '18:00',
      endTime: '19:00',
      totalPrice: 150000,
    );
  }

  test('từ chối đặt sân cho ngày đã qua và không ghi gì vào database', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    final result = await BookingRepository.processBookingPayment(
      booking: cashBooking(id: 'booking_qua_khu', date: yesterday),
      method: 'cash',
    );

    expect(result.isSuccess, isFalse);
    expect(result.failureReason, 'Không thể đặt sân cho ngày đã qua.');
    expect(await db.query('bookings'), isEmpty);
    expect(await db.query('payments'), isEmpty);
  });

  test('vẫn cho đặt sân cho ngày hôm nay', () async {
    final today = DateTime.now();

    final result = await BookingRepository.processBookingPayment(
      booking: cashBooking(id: 'booking_hom_nay', date: today),
      method: 'cash',
    );

    expect(result.isSuccess, isTrue);
    expect(await db.query('bookings'), hasLength(1));
  });
}

Future<void> _seedApprovedVenueAndCustomer(Database db) async {
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
}
