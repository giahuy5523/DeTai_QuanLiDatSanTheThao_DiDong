import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sportfield_booking/main.dart';

Future<void> start(WidgetTester tester) async {
  await tester.pumpWidget(const SportFieldBookingApp());
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  final button = find.widgetWithText(
    ElevatedButton,
    text == 'Đăng nhập' || text == 'Tạo tài khoản' ? text.toUpperCase() : text,
  );

  expect(
    button,
    findsOneWidget,
    reason: 'Không tìm thấy ElevatedButton có text "$text".',
  );

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
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
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final dialog = tester.element(find.byType(DatePickerDialog));
  final target = DateTime.now().add(const Duration(days: 7));
  await tester.enterText(
    find.byType(TextFormField),
    MaterialLocalizations.of(dialog).formatCompactDate(target),
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
