import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sportfield_booking/data/account_service.dart';
import 'package:sportfield_booking/main.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

/// Test trên SQLite thật: database sạch, rồi khởi tạo dữ liệu ứng dụng.
/// Gọi trước `start`. Các lời gọi I/O phải chạy trong `runAsync`.
Future<void> freshSqliteApp(WidgetTester tester) async {
  await tester.runAsync(() async {
    await DatabaseHelper.resetForTesting();
    await AccountService.initialize();
  });
}

/// Chờ các thao tác SQLite (I/O thật) xong, rồi dựng lại khung hình.
Future<void> settleSqlite(WidgetTester tester, {int rounds = 20}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> start(WidgetTester tester) async {
  await tester.pumpWidget(const SportFieldBookingApp());
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  final candidates = find.ancestor(
    of: find.text(
      text == 'Đăng nhập' || text == 'Tạo tài khoản'
          ? text.toUpperCase()
          : text,
    ),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  final button = find.byType(Dialog).evaluate().isNotEmpty
      ? find.descendant(of: find.byType(Dialog).last, matching: candidates)
      : candidates;
  if (button.evaluate().isEmpty &&
      find.byType(Scrollable).evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      button,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }

  expect(
    button,
    findsOneWidget,
    reason: 'Không tìm thấy ElevatedButton có text "$text".',
  );

  // Close the IME before calculating the final tap position. On a real
  // Android device the keyboard changes the available viewport and can cover
  // a button that was visible before the keyboard animation completed.
  // Dismiss any previous SnackBar that may cover the target button.
  final messenger = ScaffoldMessenger.maybeOf(tester.element(button));
  messenger?.hideCurrentSnackBar();
  await tester.pumpAndSettle();

  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();

  // Keep hit-test warnings enabled: a missed tap is a test failure, not a
  // condition to suppress.
  await tester.tap(button);
  await tester.pumpAndSettle();
  if (text == 'Gửi duyệt' && find.text('Xong').evaluate().isNotEmpty) {
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  expect(
    finder,
    findsOneWidget,
    reason: 'Không tìm thấy widget cần tap: $finder',
  );

  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> chooseFutureDate(WidgetTester tester) async {
  await tapVisible(tester, find.text('Nhấn để chọn ngày khác'));

  final dialogFinder = find.byType(DatePickerDialog);
  expect(dialogFinder, findsOneWidget);

  final editButton = find.descendant(
    of: dialogFinder,
    matching: find.byIcon(Icons.edit_outlined),
  );
  expect(editButton, findsOneWidget);

  await tester.tap(editButton);
  await tester.pumpAndSettle();

  final dateField = find.descendant(
    of: dialogFinder,
    matching: find.byType(TextFormField),
  );
  expect(dateField, findsOneWidget);

  final dialogContext = tester.element(dialogFinder);
  final target = DateTime.now().add(const Duration(days: 7));

  await tester.enterText(
    dateField,
    MaterialLocalizations.of(dialogContext).formatCompactDate(target),
  );
  await tester.pumpAndSettle();

  final okButton = find.descendant(
    of: dialogFinder,
    matching: find.widgetWithText(TextButton, 'OK'),
  );
  expect(okButton, findsOneWidget);

  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(okButton);
  await tester.pumpAndSettle();
  await tester.tap(okButton);
  await tester.pumpAndSettle();
}
