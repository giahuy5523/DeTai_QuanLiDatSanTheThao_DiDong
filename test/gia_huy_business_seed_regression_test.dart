import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/account_service.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'fresh startup seeds samples and later startups preserve deletions',
    () async {
      final directory = await Directory.systemTemp.createTemp('business_seed_');
      databaseFactory = databaseFactoryFfi;
      await databaseFactoryFfi.setDatabasesPath(directory.path);
      addTearDown(() async {
        await AccountService.repository?.database.close();
        AccountService.repository = null;
        await directory.delete(recursive: true);
      });

      await AccountService.initialize();
      final db = AccountService.repository!.database;
      final promotion = MockStore.promotions.first;
      final serviceRow = (await db.rawQuery('''
      SELECT id, venueId FROM venue_services AS s
      WHERE NOT EXISTS (
        SELECT 1 FROM booking_services AS b WHERE b.serviceId = s.id
      )
      LIMIT 1
    ''')).single;
      final venueId = serviceRow['venueId'] as String;
      final service = MockStore.servicesByVenue[venueId]!.singleWhere(
        (item) => item.id == serviceRow['id'],
      );

      expect(
        await db.delete(
          'promotions',
          where: 'id = ?',
          whereArgs: [promotion.id],
        ),
        1,
      );
      expect(
        await db.delete(
          'venue_services',
          where: 'id = ?',
          whereArgs: [service.id],
        ),
        1,
      );

      Future<void> expectSamplesStayDeleted() async {
        await AccountService.initialize();
        expect(
          MockStore.promotions.map((item) => item.id),
          isNot(contains(promotion.id)),
        );
        expect(
          MockStore.servicesByVenue[venueId]?.map((item) => item.id) ?? [],
          isNot(contains(service.id)),
        );
      }

      await expectSamplesStayDeleted();

      // Simulate a pre-marker v2/v3 database and a fresh process's demo cache.
      await db.execute('DROP TABLE business_seed');
      MockStore.promotions.add(promotion);
      (MockStore.servicesByVenue[venueId] ??= []).add(service);
      await expectSamplesStayDeleted();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
