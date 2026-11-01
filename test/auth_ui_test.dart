import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'test_helpers.dart';

void main() {
  testWidgets(
    'Auth starts empty and phone tab preserves separate identifiers',
    (tester) async {
      MockStore.logout();
      await start(tester);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      await tester.enterText(
        find.byType(TextFormField).first,
        'customer@gmail.com',
      );
      await tapVisible(tester, find.text('Số điện thoại'));
      expect(find.text('Số điện thoại của bạn?'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '0912345678');
      await press(tester, 'Đăng nhập');
      expect(MockStore.currentUser, isNull);
      expect(
        find.text('Chức năng sẽ được tích hợp trong giai đoạn backend'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Email'));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'customer@gmail.com',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Deferred auth buttons explain backend status without creating a session',
    (tester) async {
      MockStore.logout();
      await start(tester);
      for (final label in [
        'Quên mật khẩu?',
        'Đăng nhập với sinh trắc học',
        'Đăng nhập với Google',
        'Đăng nhập với Apple',
      ]) {
        await tapVisible(tester, find.text(label));
        expect(
          find.text('Chức năng sẽ được tích hợp trong giai đoạn backend'),
          findsOneWidget,
        );
        expect(MockStore.currentUser, isNull);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Six banners auto advance, wrap, swipe and pause in background', (
    tester,
  ) async {
    await start(tester);
    expect(find.bySemanticsLabel('Ảnh sân 1 trên 6'), findsOneWidget);
    for (var index = 1; index <= 6; index++) {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Ảnh sân ${index % 6 + 1} trên 6'),
        findsOneWidget,
      );
    }
    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ảnh sân 2 trên 6'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 8));
    expect(find.bySemanticsLabel('Ảnh sân 2 trên 6'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ảnh sân 3 trên 6'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
