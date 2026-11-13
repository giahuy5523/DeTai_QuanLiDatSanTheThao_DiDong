import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/account_service.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/models/user.dart';
import 'mock_accounts.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('Login shows only email and password', (tester) async {
    await start(tester);

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(2));
    expect(fields.first.keyboardType, TextInputType.emailAddress);
    expect(fields.last.obscureText, isTrue);
    expect(fields.map((field) => field.controller!.text), ['', '']);
    expect(find.text('Email'), findsOneWidget);
    for (final label in [
      'Số điện thoại',
      'Quên mật khẩu?',
      'Đăng nhập với sinh trắc học',
      'Đăng nhập với Google',
      'Đăng nhập với Apple',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });

  testWidgets('Login rejects a phone number even with a valid password', (
    tester,
  ) async {
    MockStore.logout();
    await start(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '0901234567');
    await tester.enterText(fields.last, '123456');
    await press(tester, 'Đăng nhập');

    expect(find.text('Nhập email hợp lệ'), findsOneWidget);
    expect(find.text('Không thể đăng nhập. Vui lòng thử lại.'), findsNothing);
    expect(MockStore.currentUser, isNull);
  });

  testWidgets(
    'Login rejects a short password and lets the user show or hide it',
    (tester) async {
      await start(tester);
      final fields = find.byType(TextFormField);
      final password = find.byType(TextField).last;
      await tester.enterText(fields.first, 'customer@gmail.com');
      await tester.enterText(fields.last, '12345');
      await press(tester, 'Đăng nhập');
      expect(find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);

      await tapVisible(tester, find.byTooltip('Hiện mật khẩu'));
      expect(tester.widget<TextField>(password).obscureText, isFalse);
      await tapVisible(tester, find.byTooltip('Ẩn mật khẩu'));
      expect(tester.widget<TextField>(password).obscureText, isTrue);
      expect(tester.widget<TextField>(password).controller!.text, '12345');
    },
  );

  testWidgets('Login reports incorrect credentials and allows retry', (
    tester,
  ) async {
    useMockAccounts();
    MockStore.logout();
    addTearDown(MockStore.logout);
    await start(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'customer@gmail.com');
    await tester.enterText(fields.last, 'wrong-password');
    await press(tester, 'Đăng nhập');
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
    expect(MockStore.currentUser, isNull);

    await tester.enterText(fields.last, '123456');
    await press(tester, 'Đăng nhập');
    expect(MockStore.currentUser?.role, 'customer');
    expect(find.text('ĐĂNG NHẬP'), findsNothing);
  });

  testWidgets('Login refuses valid demo credentials without SQLite', (
    tester,
  ) async {
    MockStore.logout();
    await start(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      'customer@gmail.com',
    );
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await press(tester, 'Đăng nhập');

    expect(MockStore.currentUser, isNull);
    expect(find.text('Không thể đăng nhập. Vui lòng thử lại.'), findsOneWidget);
    expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
  });

  test('Account mutations fail closed without SQLite', () async {
    final originalUsers = List.of(MockStore.users);
    final user = MockStore.login('customer@gmail.com', '123456')!;
    addTearDown(() {
      MockStore.logout();
      MockStore.users
        ..clear()
        ..addAll(originalUsers);
    });
    final unavailable = throwsA(isA<StateError>());
    final newUser = AppUser(
      id: 'unavailable',
      name: 'SQLite unavailable',
      email: 'unavailable@gmail.com',
      phone: '0901234567',
      password: '123456',
    );

    await expectLater(AccountService.register(newUser), unavailable);
    await expectLater(
      AccountService.updateProfile(
        userId: user.id,
        name: 'Updated name',
        phone: user.phone,
        avatarPath: null,
      ),
      unavailable,
    );
    await expectLater(AccountService.logout(), unavailable);
    expect(MockStore.users, originalUsers);
    expect(MockStore.currentUser, same(user));
  });

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
