import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/data/account_service.dart';
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

    // Chẩn đoán: đăng nhập trực tiếp trên SQLite có trả về tài khoản không?
    final direct = await tester.runAsync(
      () => AccountService.login('customer@gmail.com', '123456'),
    );
    expect(direct, isNotNull, reason: 'AccountService.login trả về null trên SQLite');
    await tester.runAsync(() => AccountService.logout());

    await start(tester);

    await tester.enterText(find.byType(TextFormField).first, 'customer@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await press(tester, 'Đăng nhập');
    // Đăng nhập xong app còn đọc thêm dữ liệu từ SQLite trước khi chuyển màn.
    for (var i = 0; i < 200 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(
      find.text('Email hoặc mật khẩu không đúng.'),
      findsNothing,
      reason: 'Màn đăng nhập báo sai thông tin',
    );
    expect(
      find.text('Không thể đăng nhập. Vui lòng thử lại.'),
      findsNothing,
      reason: 'Màn đăng nhập báo lỗi hệ thống',
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
