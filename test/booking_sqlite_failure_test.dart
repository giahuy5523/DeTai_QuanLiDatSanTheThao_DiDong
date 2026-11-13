import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/models/promotion.dart';

/// Khi SQLite lỗi, repository phải báo lỗi rõ ràng.
/// Không được trả thành công hoặc danh sách rỗng giả.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sqlite_failure_test_');
    BookingRepository.setUseMockStoreForTesting(false);
  });

  tearDown(() async {
    BookingRepository.setDatabaseForTesting(null);
    BookingRepository.setUseMockStoreForTesting(false);
    await tempDir.delete(recursive: true);
  });

  /// Mở rồi đóng một database, mọi truy vấn sau đó phải thất bại.
  Future<Database> closedDatabase() async {
    final db = await databaseFactory.openDatabase(
      '${tempDir.path}${Platform.pathSeparator}closed.db',
    );
    await db.close();
    return db;
  }

  test('hủy đơn báo lỗi SQLite thay vì trả về thành công', () async {
    BookingRepository.setDatabaseForTesting(await closedDatabase());

    await expectLater(
      BookingRepository.cancelBooking('booking_khong_ton_tai'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('đọc lịch sử đặt sân báo lỗi SQLite thay vì trả về danh sách rỗng', () async {
    BookingRepository.setDatabaseForTesting(await closedDatabase());

    await expectLater(
      BookingRepository.getBookingsForUser('user_bat_ky'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('tạo khuyến mãi báo lỗi SQLite thay vì trả về thành công', () async {
    BookingRepository.setDatabaseForTesting(await closedDatabase());

    final promo = Promotion(
      id: 'p_loi_db',
      code: 'LOIDB',
      discountPercent: 10,
      expiryDate: DateTime(2030),
    );

    await expectLater(
      BookingRepository.createPromotion(promo),
      throwsA(isA<DatabaseException>()),
    );
  });
}
