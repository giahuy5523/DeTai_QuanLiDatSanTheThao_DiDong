import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/data/venue_repository.dart';
import 'package:sportfield_booking/screens/customer/home_screen.dart';

import 'test_helpers.dart';

/// Bước 1: luồng widget chạy trên SQLite thật, không dùng cache MockStore.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    BookingRepository.setUseMockStoreForTesting(false);
    VenueRepository.setUseMockStoreForTesting(false);
  });

  testWidgets('khách đăng nhập trên SQLite và vào trang chủ', (tester) async {
    await freshSqliteApp(tester);
    await start(tester);

    await tester.enterText(find.byType(TextFormField).first, 'customer@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await press(tester, 'Đăng nhập');
    await settleSqlite(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
