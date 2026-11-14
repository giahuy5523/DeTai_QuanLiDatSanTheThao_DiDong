import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sportfield_booking/data/account_service.dart';
import 'package:sportfield_booking/main.dart';
import 'package:sportfield_booking/screens/customer/home_screen.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

/// Chạy trên thiết bị hoặc emulator: khách đăng nhập trên SQLite thật
/// và vào trang chủ. Thiết bị có I/O thật nên không cần fake async.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('khách đăng nhập trên SQLite thật và vào trang chủ', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await DatabaseHelper.resetForTesting();
      await AccountService.initialize();
    });

    await tester.pumpWidget(const SportFieldBookingApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'customer@gmail.com',
    );
    await tester.enterText(find.byType(TextFormField).last, '123456');
    final loginButton = find.ancestor(
      of: find.text('ĐĂNG NHẬP'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    await tester.tap(loginButton);
    await tester.pump();

    // Đăng nhập và đọc dữ liệu từ SQLite thật, rồi mới chuyển màn.
    for (var i = 0; i < 200 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
