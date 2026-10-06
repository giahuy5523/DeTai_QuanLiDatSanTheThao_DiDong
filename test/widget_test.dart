import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/main.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/screens/auth/login_screen.dart';
import 'package:sportfield_booking/screens/auth/register_screen.dart';
import 'package:sportfield_booking/screens/customer/home_screen.dart';
import 'package:sportfield_booking/screens/owner/manage_venue_screen.dart';
import 'package:sportfield_booking/screens/admin/statistics_screen.dart';

Future<void> start(WidgetTester tester) async {
  await tester.pumpWidget(const SportFieldBookingApp());
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  final button = find.widgetWithText(ElevatedButton, text);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> registerForm(WidgetTester tester,
    {String email = 'new@gmail.com',
    String phone = '0912345678',
    String password = 'abcdef',
    String confirmation = 'abcdef'}) async {
  await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
  await tester.pumpAndSettle();
  final fields = find.byType(TextFormField);
  final values = ['Gia Huy', email, phone, password, confirmation];
  for (var i = 0; i < values.length; i++) {
    await tester.ensureVisible(fields.at(i));
    await tester.enterText(fields.at(i), values[i]);
  }
}

void main() {
  final originalUsers = List.of(MockStore.users);
  setUp(() {
    MockStore.users
      ..clear()
      ..addAll(originalUsers);
    MockStore.logout();
  });
  tearDown(() {
    MockStore.users
      ..clear()
      ..addAll(originalUsers);
    MockStore.logout();
  });

  for (final role in ['customer', 'owner', 'admin']) {
    testWidgets('$role logs in to the correct screen', (tester) async {
      await start(tester);
      await tester.enterText(find.byType(TextFormField).first,
          ' ${role.toUpperCase()}@GMAIL.COM ');
      await press(tester, 'Đăng nhập');
      final screen = role == 'customer'
          ? HomeScreen
          : role == 'owner'
              ? ManageVenueScreen
              : StatisticsScreen;
      expect(find.byType(screen), findsOneWidget);
      expect(MockStore.currentUser?.role, role);
      expect(tester.takeException(), isNull);
    });
  }

  for (final email in ['customer@gmail.com', 'missing@gmail.com']) {
    testWidgets('Rejects invalid credentials for $email', (tester) async {
      await start(tester);
      await tester.enterText(find.byType(TextFormField).first, email);
      await tester.enterText(find.byType(TextFormField).last, 'wrong123');
      await press(tester, 'Đăng nhập');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
      expect(MockStore.currentUser, isNull);
    });
  }

  testWidgets('Login validates email and short password and toggles visibility',
      (tester) async {
    await start(tester);
    await tester.enterText(find.byType(TextFormField).first, 'a@');
    await tester.enterText(find.byType(TextFormField).last, '123');
    await press(tester, 'Đăng nhập');
    expect(find.text('Nhập email hợp lệ'), findsOneWidget);
    expect(find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse);
    expect(MockStore.currentUser, isNull);
  });

  for (final role in ['customer', 'owner']) {
    testWidgets('Register $role then log in and log out', (tester) async {
      await start(tester);
      await registerForm(tester, email: ' NEW@GMAIL.COM ');
      if (role == 'owner') {
        final dropdown = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chủ sân').last);
        await tester.pumpAndSettle();
      }
      await press(tester, 'Tạo tài khoản');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(RegisterScreen), findsNothing);
      expect(MockStore.users.length, originalUsers.length + 1);
      expect(MockStore.findUserByEmail('new@gmail.com')?.role, role);
      expect(MockStore.currentUser, isNull);
      await tester.enterText(find.byType(TextFormField).last, 'abcdef');
      await press(tester, 'Đăng nhập');
      expect(MockStore.currentUser?.email, 'new@gmail.com');
      if (role == 'customer') {
        await tester.tap(find.byIcon(Icons.receipt_long));
        await tester.pumpAndSettle();
        expect(find.text('Chưa có đơn đặt sân.'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();
        expect(find.text('Gia Huy'), findsOneWidget);
        final logout = find.text('Đăng xuất');
        await tester.ensureVisible(logout);
        await tester.tap(logout);
      } else {
        expect(find.text('Sân bóng đá Thành Công'), findsNothing);
        await tester.tap(find.byTooltip('Đăng xuất'));
      }
      await tester.pumpAndSettle();
      expect(MockStore.currentUser, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Registration rejects duplicate email without adding user',
      (tester) async {
    await start(tester);
    await registerForm(tester, email: ' CUSTOMER@GMAIL.COM ');
    await press(tester, 'Tạo tài khoản');
    expect(find.text('Email đã được sử dụng'), findsOneWidget);
    expect(MockStore.users.length, originalUsers.length);
  });

  testWidgets('Registration rejects invalid phone and mismatched password',
      (tester) async {
    await start(tester);
    await registerForm(tester, phone: 'abc', confirmation: 'different');
    await press(tester, 'Tạo tài khoản');
    expect(find.text('Số điện thoại gồm 10 chữ số, bắt đầu bằng 0'),
        findsOneWidget);
    expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
    expect(MockStore.users.length, originalUsers.length);
  });

  testWidgets('Registration rejects invalid email and weak password',
      (tester) async {
    await start(tester);
    await registerForm(tester,
        email: 'invalid@', password: '   ', confirmation: '   ');
    await press(tester, 'Tạo tài khoản');
    expect(find.text('Nhập email hợp lệ'), findsOneWidget);
    expect(find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);
    expect(MockStore.users.length, originalUsers.length);
  });

  testWidgets('Admin logout clears the session and returns to login',
      (tester) async {
    await start(tester);
    await tester.enterText(find.byType(TextFormField).first, 'admin@gmail.com');
    await press(tester, 'Đăng nhập');
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(MockStore.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login and registration fit a small mobile screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await start(tester);
    await registerForm(tester);
    await press(tester, 'Tạo tài khoản');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Empty registration is rejected and admin registration is unavailable',
      (tester) async {
    await start(tester);
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    await press(tester, 'Tạo tài khoản');
    expect(find.text('Không được để trống'), findsOneWidget);
    expect(MockStore.users.length, originalUsers.length);
    final dropdown = tester
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    expect(dropdown.items!.map((item) => item.value), ['customer', 'owner']);
    expect(tester.takeException(), isNull);
  });
}
