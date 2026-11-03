import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sportfield_booking/data/account_repository.dart';
import 'package:sportfield_booking/models/user.dart';

void main() {
  sqfliteFfiInit();
  test(
    'SQLite accounts survive reopen, protect roles and clear sessions',
    () async {
      final directory = await Directory.systemTemp.createTemp('accounts_test_');
      final path = '${directory.path}/accounts.db';
      AccountRepository? repo;
      final user = AppUser(
        id: 'customer1',
        name: 'Gia Huy',
        email: 'huy@example.com',
        phone: '0900000001',
        password: 'test-password',
      );
      try {
        repo = await AccountRepository.open(
          seed: [],
          factory: databaseFactoryFfi,
          path: path,
        );
        await repo.register(user);
        final raw = (await repo.database.query('Users')).single;
        expect(raw['password_hash'], isNot(user.password));
        expect(raw['password_hash'].toString(), isNot(contains(user.password)));
        expect(await repo.login(user.email, 'incorrect'), isNull);
        expect(
          (await repo.login(' HUY@EXAMPLE.COM ', user.password))?.id,
          user.id,
        );
        await repo.updateProfile(
          userId: user.id,
          name: 'Huy đã sửa',
          phone: '0912345678',
          avatarPath: '/app/avatars/portrait.png',
        );
        await repo.database.close();
        repo = await AccountRepository.open(
          seed: [],
          factory: databaseFactoryFfi,
          path: path,
        );
        final restored = await repo.restoreSession();
        expect(restored?.name, 'Huy đã sửa');
        expect(restored?.phone, '0912345678');
        expect(restored?.avatarPath, '/app/avatars/portrait.png');
        expect(restored?.password, isEmpty);
        await expectLater(repo.register(user), throwsArgumentError);
        await expectLater(
          repo.register(
            AppUser(
              id: 'admin-new',
              name: 'Admin',
              email: 'admin@example.com',
              phone: '0999999999',
              password: 'test-password',
              role: 'admin',
            ),
          ),
          throwsArgumentError,
        );
        await repo.logout();
        await repo.database.close();
        repo = await AccountRepository.open(
          seed: [],
          factory: databaseFactoryFfi,
          path: path,
        );
        expect(await repo.restoreSession(), isNull);
        expect(
          await repo.updateProfile(
            userId: user.id,
            name: 'Unauthorized',
            phone: '0912345678',
            avatarPath: null,
          ),
          isNull,
        );
        await repo.login(user.email, user.password);
        await repo.database.update('Session', {'expires_at': 0});
        expect(await repo.restoreSession(), isNull);
        await repo.login(user.email, user.password);
        await repo.database.update('Users', {'is_active': 0});
        expect(await repo.restoreSession(), isNull);
        expect(await repo.login(user.email, user.password), isNull);
      } finally {
        await repo?.database.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
