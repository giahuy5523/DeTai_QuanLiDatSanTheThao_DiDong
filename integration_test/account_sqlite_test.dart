import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
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
    expect(
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 600000, bits: 256),
      isA<FlutterPbkdf2>(),
      reason: 'Android must use native PBKDF2',
    );
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
          password: 'Mật-khẩu-kiểm-thử-2026',
        );
        await AccountService.register(user);
        // Fixed PBKDF2 fixture verifies compatibility with existing Dart hashes.
        await repository!.database.update(
          'Users',
          {
            'password_hash':
                'AAECAwQFBgcICQoLDA0ODw==:aLUC1xz1FP2qzjEX2wi6iZPxG5S3xXancrLDx+9d6V4=',
          },
          where: 'user_id = ?',
          whereArgs: [user.id],
        );
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
