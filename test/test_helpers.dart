import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
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
