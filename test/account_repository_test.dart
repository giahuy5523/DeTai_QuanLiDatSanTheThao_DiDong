import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sportfield_booking/data/account_repository.dart';
import 'package:sportfield_booking/models/user.dart';

void main() {
  sqfliteFfiInit();
  test(
    'SQLite rejects duplicate phones and cross-account profile writes',
    () async {
      final seed = [
        for (final (index, role) in ['customer', 'owner', 'admin'].indexed)
          AppUser(
            id: role,
            name: role,
            email: '$role@example.test',
            phone: '090000000${index + 1}',
            password: 'test-password',
            role: role,
          ),
      ];
      final repo = await AccountRepository.open(
        seed: seed,
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      try {
        for (final user in seed) {
          expect(
            (await repo.login(user.email, user.password))?.role,
            user.role,
          );
          expect((await repo.restoreSession())?.id, user.id);
        }
        await repo.login(seed.first.email, seed.first.password);
        await expectLater(
          repo.register(
            AppUser(
              id: 'duplicate-phone',
              name: 'Other',
              email: 'other@example.test',
              phone: seed.first.phone,
              password: 'test-password',
            ),
          ),
          throwsArgumentError,
        );
        await expectLater(
          repo.updateProfile(
            userId: 'customer',
            name: 'Changed',
            phone: seed[1].phone,
            avatarPath: '/new.png',
          ),
          throwsArgumentError,
        );
        final unchanged = await repo.restoreSession();
        expect(unchanged?.name, 'customer');
        expect(unchanged?.phone, seed.first.phone);
        expect(unchanged?.avatarPath, isNull);
        expect(
          await repo.updateProfile(
            userId: 'owner',
            name: 'Unauthorized',
            phone: '0912345678',
            avatarPath: null,
          ),
          isNull,
        );
        final owner = (await repo.allUsers()).singleWhere(
          (u) => u.id == 'owner',
        );
        expect(owner.name, 'owner');
        expect(owner.phone, seed[1].phone);
        await repo.database.update(
          'Users',
          {
            'password_hash':
                'AAECAwQFBgcICQoLDA0ODw==:aLUC1xz1FP2qzjEX2wi6iZPxG5S3xXancrLDx+9d6V4=',
          },
          where: 'user_id = ?',
          whereArgs: ['customer'],
        );
        expect(
          (await repo.login(seed.first.email, 'Mật-khẩu-kiểm-thử-2026'))?.id,
          'customer',
        );
      } finally {
        await repo.database.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
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
        final userId = raw['user_id'] as String;
        expect(userId, isNot(user.id));
        final accounts = repo;
        await Future.wait([
          for (final (email, phone) in [
            ('second@example.com', '0900000002'),
            ('third@example.com', '0900000003'),
          ])
            accounts.register(
              AppUser(
                id: user.id,
                name: 'New customer',
                email: email,
                phone: phone,
                password: user.password,
              ),
            ),
        ]);
        expect(
          (await repo.allUsers()).map((account) => account.id).toSet(),
          hasLength(3),
        );
        expect(raw['password_hash'], isNot(user.password));
        expect(raw['password_hash'].toString(), isNot(contains(user.password)));
        expect(await repo.login(user.email, 'incorrect'), isNull);
        expect(
          (await repo.login(' HUY@EXAMPLE.COM ', user.password))?.id,
          userId,
        );
        await repo.updateProfile(
          userId: userId,
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
        await expectLater(
          repo.register(
            AppUser(
              id: user.id,
              name: user.name,
              email: ' HUY@EXAMPLE.COM ',
              phone: '0900000004',
              password: user.password,
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'Email đã được sử dụng',
            ),
          ),
        );
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
            userId: userId,
            name: 'Unauthorized',
            phone: '0912345678',
            avatarPath: null,
          ),
          isNull,
        );
        await repo.login(user.email, user.password);
        await repo.deleteExpiredSession();
        expect((await repo.restoreSession())?.id, userId);
        await repo.database.update('Session', {'expires_at': 0});
        await repo.deleteExpiredSession();
        expect(await repo.database.query('Session'), isEmpty);
        expect(await repo.restoreSession(), isNull);
        await repo.login(user.email, user.password);
        await repo.database.update(
          'Users',
          {'is_active': 0},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
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
