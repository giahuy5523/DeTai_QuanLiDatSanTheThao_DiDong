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
  test('SQLite records legacy email and phone conflicts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'legacy_conflicts_test_',
    );
    final path = '${directory.path}/accounts.db';
    AccountRepository? repo;

    final existingUsers = [
      AppUser(
        id: 'existing-email',
        name: 'Email owner',
        email: 'email-owner@example.test',
        phone: '0900000001',
        password: 'test-password',
      ),
      AppUser(
        id: 'existing-phone',
        name: 'Phone owner',
        email: 'phone-owner@example.test',
        phone: '0900000002',
        password: 'test-password',
      ),
      AppUser(
        id: 'existing-both-email',
        name: 'Both email owner',
        email: 'both-email@example.test',
        phone: '0900000003',
        password: 'test-password',
      ),
      AppUser(
        id: 'existing-both-phone',
        name: 'Both phone owner',
        email: 'both-phone@example.test',
        phone: '0900000004',
        password: 'test-password',
      ),
    ];

    final legacyRows = [
      {
        'user_id': 'legacy-email',
        'full_name': 'Legacy email conflict',
        'email': 'EMAIL-OWNER@example.test',
        'phone': '0911111111',
        'password': 'legacy-password',
        'role': 'customer',
        'avatar_path': null,
      },
      {
        'user_id': 'legacy-phone',
        'full_name': 'Legacy phone conflict',
        'email': 'legacy-phone@example.test',
        'phone': '0900000002',
        'password': 'legacy-password',
        'role': 'customer',
        'avatar_path': null,
      },
      {
        'user_id': 'legacy-both',
        'full_name': 'Legacy both conflicts',
        'email': 'both-email@example.test',
        'phone': '0900000004',
        'password': 'legacy-password',
        'role': 'customer',
        'avatar_path': null,
      },
    ];

    try {
      // Tạo database và các tài khoản đang tồn tại.
      repo = await AccountRepository.open(
        seed: [],
        factory: databaseFactoryFfi,
        path: path,
      );

      for (final user in existingUsers) {
        await repo.register(user);
      }

      await repo.database.close();
      repo = null;

      // Tạo bảng staging theo đúng schema V1 migration.
      final rawDatabase = await databaseFactoryFfi.openDatabase(path);
      try {
        await rawDatabase.execute('''
            CREATE TABLE legacy_account_import (
              user_id TEXT PRIMARY KEY,
              full_name TEXT NOT NULL,
              email TEXT NOT NULL,
              phone TEXT NOT NULL,
              password TEXT NOT NULL,
              role TEXT NOT NULL,
              avatar_path TEXT
            )
          ''');

        for (final row in legacyRows) {
          await rawDatabase.insert('legacy_account_import', row);
        }
      } finally {
        await rawDatabase.close();
      }

      // Mở lại repository để xử lý các dòng legacy.
      repo = await AccountRepository.open(
        seed: [],
        factory: databaseFactoryFfi,
        path: path,
      );

      final conflicts = await repo.database.query(
        'legacy_account_import_conflicts',
        orderBy: 'user_id',
      );

      final reasons = {
        for (final conflict in conflicts)
          conflict['user_id']: conflict['reason'],
      };

      expect(reasons['legacy-email'], 'email_conflict:existing-email');
      expect(reasons['legacy-phone'], 'phone_conflict:existing-phone');
      expect(reasons['legacy-both'], 'email_conflict:existing-both-email');

      // Không được xóa các dòng legacy chưa import được.
      var remaining = await repo.database.query(
        'legacy_account_import',
        orderBy: 'user_id',
      );

      expect(remaining.map((row) => row['user_id']).toSet(), {
        'legacy-email',
        'legacy-phone',
        'legacy-both',
      });

      // Mở lại lần nữa: dữ liệu và trạng thái xung đột vẫn phải tồn tại.
      await repo.database.close();
      repo = await AccountRepository.open(
        seed: [],
        factory: databaseFactoryFfi,
        path: path,
      );

      remaining = await repo.database.query('legacy_account_import');
      expect(remaining, hasLength(3));

      final repeatedConflicts = await repo.database.query(
        'legacy_account_import_conflicts',
      );
      expect(repeatedConflicts, hasLength(3));

      final existing = await repo.database.query(
        'Users',
        where: 'user_id IN (?, ?, ?, ?)',
        whereArgs: [
          'existing-email',
          'existing-phone',
          'existing-both-email',
          'existing-both-phone',
        ],
      );
      expect(existing, hasLength(4));
    } finally {
      await repo?.database.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
