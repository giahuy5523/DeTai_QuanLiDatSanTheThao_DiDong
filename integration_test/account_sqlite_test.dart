import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sportfield_booking/data/account_repository.dart';
import 'package:sportfield_booking/data/account_service.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/main.dart';
import 'package:sportfield_booking/models/user.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android SQLite registration profile restart and logout', (
    tester,
  ) async {
    final path = '${await getDatabasesPath()}/account_integration_test.db';
    AccountRepository? repository;
    final seeds = List<AppUser>.of(MockStore.users);
    try {
      await tester.runAsync(() async {
        await deleteDatabase(path);
        repository = await AccountRepository.open(seed: seeds, path: path);
        AccountService.repository = repository;
        final user = AppUser(
          id: 'android-account',
          name: 'Gia Huy Android',
          email: 'android-check@example.com',
          phone: '0987654321',
          password: 'android-test-password',
        );
        await AccountService.register(user);
        final loggedIn = await AccountService.login(user.email, user.password);
        expect(loggedIn?.id, user.id);
      });
      await tester.pumpWidget(const SportFieldBookingApp(restoreSession: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tài khoản').last);
      await tester.pumpAndSettle();
      expect(find.text('Thông tin cá nhân'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Gia Huy SQLite');
      final save = find.widgetWithText(ElevatedButton, 'Lưu thay đổi');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();
      expect(MockStore.currentUser?.name, 'Gia Huy SQLite');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await repository!.database.close();
        MockStore.currentUser = null;
        repository = await AccountRepository.open(seed: seeds, path: path);
        AccountService.repository = repository;
        MockStore.currentUser = await repository!.restoreSession();
      });
      await tester.pumpWidget(const SportFieldBookingApp(restoreSession: true));
      await tester.pumpAndSettle();
      expect(MockStore.currentUser?.name, 'Gia Huy SQLite');
      await tester.runAsync(() async {
        await AccountService.logout();
        await repository!.database.close();
        repository = await AccountRepository.open(seed: seeds, path: path);
        expect(await repository!.restoreSession(), isNull);
      });
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await repository?.database.close();
        await deleteDatabase(path);
      });
      AccountService.repository = null;
      MockStore.currentUser = null;
      MockStore.users
        ..clear()
        ..addAll(seeds);
    }
  });
}
