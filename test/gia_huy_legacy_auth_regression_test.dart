import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sportfield_booking/data/account_repository.dart';

void main() {
  sqfliteFfiInit();

  test(
    'legacy import runs once and preserves later profile edits and logout',
    () async {
      final directory = await Directory.systemTemp.createTemp('legacy_auth_');
      databaseFactory = databaseFactoryFfi;
      await databaseFactoryFfi.setDatabasesPath(directory.path);
      var legacy = await AccountRepository.open(seed: []);
      final targetPath = p.join(directory.path, 'shared.db');
      var target = await AccountRepository.open(seed: [], path: targetPath);
      addTearDown(() async {
        if (legacy.database.isOpen) await legacy.database.close();
        if (target.database.isOpen) await target.database.close();
        await directory.delete(recursive: true);
      });

      const userId = 'legacy-customer';
      await legacy.database.insert('Users', {
        'user_id': userId,
        'full_name': 'Legacy name',
        'email': 'legacy@example.test',
        'phone': '0900000001',
        'password_hash': 'legacy-hash',
        'role': 'customer',
      });
      await legacy.database.insert('Session', {
        'id': 1,
        'user_id': userId,
        'expires_at': DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
      });
      await legacy.database.close();

      await target.database.execute('''
        CREATE TRIGGER reject_session_import BEFORE INSERT ON Session
        BEGIN SELECT RAISE(ABORT, 'test interruption'); END
      ''');
      await expectLater(
        AccountRepository.importLegacyAccountDatabase(target.database),
        throwsA(isA<DatabaseException>()),
      );
      expect(await target.allUsers(), isEmpty);
      await target.database.execute('DROP TRIGGER reject_session_import');

      await AccountRepository.importLegacyAccountDatabase(target.database);
      expect((await target.restoreSession())?.id, userId);
      expect(
        (await target.updateProfile(
          userId: userId,
          name: 'New name',
          phone: '0912345678',
          avatarPath: '/avatars/new.png',
        ))?.name,
        'New name',
      );
      await target.logout();
      await target.database.close();

      legacy = await AccountRepository.open(seed: []);
      await legacy.database.insert('Users', {
        'user_id': 'legacy-added-later',
        'full_name': 'Should not be imported',
        'email': 'later@example.test',
        'phone': '0900000002',
        'password_hash': 'legacy-hash',
        'role': 'customer',
      });
      await legacy.database.close();

      target = await AccountRepository.open(seed: [], path: targetPath);
      await AccountRepository.importLegacyAccountDatabase(target.database);
      expect(await target.restoreSession(), isNull);
      final profile = (await target.allUsers()).single;
      expect(profile.name, 'New name');
      expect(profile.phone, '0912345678');
      expect(profile.avatarPath, '/avatars/new.png');
    },
  );
}
