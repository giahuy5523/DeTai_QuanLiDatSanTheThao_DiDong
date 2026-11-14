import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/account_repository.dart';
import 'package:sportfield_booking/data/account_service.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/main.dart';
import 'package:sportfield_booking/screens/admin/admin_drawer.dart';
import 'package:sportfield_booking/screens/auth/login_screen.dart';
import 'package:sportfield_booking/utils/app_routes.dart';
import 'package:sqflite/sqflite.dart';

class _UnusedDatabase extends Fake implements Database {}

class _ControlledRepository extends AccountRepository {
  _ControlledRepository() : super(_UnusedDatabase());

  late final pendingLogout = Completer<void>();
  int logoutCalls = 0;
  bool expired = false;
  DateTime? deadline;
  int expiryCleanupCalls = 0;

  @override
  Duration? get sessionTimeRemaining => deadline?.difference(DateTime.now());

  @override
  bool get isSessionExpired => expired || super.isSessionExpired;

  @override
  Future<void> deleteExpiredSession() async => expiryCleanupCalls++;

  @override
  Future<void> logout() {
    logoutCalls++;
    return pendingLogout.future;
  }
}

void main() {
  late _ControlledRepository repository;

  setUp(() {
    repository = _ControlledRepository();
    AccountService.repository = repository;
  });

  tearDown(() {
    AccountService.repository = null;
    MockStore.logout();
  });

  testWidgets('admin logout survives closing the drawer while SQLite is busy', (
    tester,
  ) async {
    MockStore.login('admin@gmail.com', '123456');
    final scaffold = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffold,
          drawer: const AdminDrawer(selectedIndex: 0),
        ),
        routes: {AppRoutes.login: (_) => const LoginScreen()},
      ),
    );
    scaffold.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.tap(find.text('Đăng xuất'));
    expect(repository.logoutCalls, 1);
    expect(MockStore.currentUser?.role, 'admin');

    scaffold.currentState!.closeDrawer();
    await tester.pumpAndSettle();
    repository.pendingLogout.complete();
    await tester.pumpAndSettle();

    expect(MockStore.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
      isFalse,
    );
  });

  testWidgets('a protected route clears an expired in-memory session', (
    tester,
  ) async {
    MockStore.login('customer@gmail.com', '123456');
    repository.expired = true;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Previous screen')),
        routes: AppRoutes.routes,
      ),
    );

    navigator.currentState!.pushNamed(AppRoutes.profile);
    await tester.pumpAndSettle();

    expect(MockStore.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
    expect(repository.expiryCleanupCalls, 1);
  });

  testWidgets('returning to the foreground clears an expired session', (
    tester,
  ) async {
    MockStore.login('customer@gmail.com', '123456');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SportFieldBookingApp());
    final navigator = Navigator.of(tester.element(find.byType(LoginScreen)));
    navigator.pushNamed(AppRoutes.register);
    await tester.pumpAndSettle();
    expect(navigator.canPop(), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    repository.expired = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(MockStore.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(navigator.canPop(), isFalse);
    expect(repository.expiryCleanupCalls, 1);
  });

  testWidgets('a session expires while the app stays in the foreground', (
    tester,
  ) async {
    MockStore.login('customer@gmail.com', '123456');
    repository.deadline = DateTime.now().add(const Duration(seconds: 1));
    await tester.pumpWidget(const SportFieldBookingApp());
    final navigator = Navigator.of(tester.element(find.byType(LoginScreen)));
    navigator.pushNamed(AppRoutes.register);
    await tester.pumpAndSettle();

    repository.expired = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(MockStore.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(navigator.canPop(), isFalse);
    expect(repository.expiryCleanupCalls, 1);
  });
}
