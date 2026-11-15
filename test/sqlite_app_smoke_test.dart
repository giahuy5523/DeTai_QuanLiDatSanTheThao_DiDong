import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/data/account_service.dart';
import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/data/venue_repository.dart';

/// Khởi động ứng dụng thật trên SQLite: đăng nhập và đọc sân từ database,
/// không dùng cache MockStore làm nguồn dữ liệu.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    BookingRepository.setUseMockStoreForTesting(false);
    VenueRepository.setUseMockStoreForTesting(false);
  });

  test('khởi động trên SQLite: đăng nhập được và có sân trong database', () async {
    await AccountService.initialize();

    final user = await AccountService.login('customer@gmail.com', '123456');
    expect(user, isNotNull);
    expect(user!.role, 'customer');

    final venues = await VenueRepository.loadVenues();
    expect(venues, isNotEmpty);
  });
}
