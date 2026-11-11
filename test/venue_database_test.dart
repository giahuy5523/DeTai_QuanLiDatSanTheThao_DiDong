import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sportfield_booking/data/venue_repository.dart';
import 'package:sportfield_booking/models/venue.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

void main() {
  late Directory directory;
  late String databasePath;
  late DatabaseHelper helper;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('venue_database_test_');
    databasePath = '${directory.path}${Platform.pathSeparator}sport_venue_database.db';
    helper = DatabaseHelper.forTesting(factory: databaseFactoryFfi, path: databasePath);
  });

  tearDown(() async {
    await helper.close();
    await directory.delete(recursive: true);
  });

  test('creates v3 schema, primary/foreign keys, and repeat-safe seed data', () async {
    final db = await helper.database;
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    final tableNames = tableRows.map((row) => row['name'] as String).toSet();
    expect(tableNames, containsAll({
      'users', 'sport_types', 'venues', 'venue_images', 'venue_services',
      'venue_hours', 'time_slots', 'bookings', 'booking_services', 'payments',
      'promotions', 'promotion_usages', 'app_notifications', 'legacy_account_import',
    }));

    const primaryKeys = <String, String>{
      'users': 'user_id', 'sport_types': 'sport_type_id', 'venues': 'venue_id',
      'venue_images': 'image_id', 'venue_services': 'service_id',
      'venue_hours': 'venue_hour_id', 'time_slots': 'slot_id',
      'bookings': 'booking_id', 'booking_services': 'booking_service_id',
      'payments': 'payment_id', 'promotions': 'promo_id',
      'promotion_usages': 'usage_id', 'app_notifications': 'notification_id',
      'legacy_account_import': 'legacy_id',
    };
    for (final entry in primaryKeys.entries) {
      final columns = await db.rawQuery('PRAGMA table_info(${entry.key})');
      final primary = columns.where((row) => row['pk'] == 1).toList();
      expect(primary, hasLength(1), reason: '${entry.key} should have one primary key');
      expect(primary.single['name'], entry.value);
    }

    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
    final venueForeignKeys = await db.rawQuery('PRAGMA foreign_key_list(venues)');
    expect(venueForeignKeys.map((row) => row['table']), containsAll(['users', 'sport_types']));
    final imageForeignKeys = await db.rawQuery('PRAGMA foreign_key_list(venue_images)');
    expect(imageForeignKeys.map((row) => row['table']), contains('venues'));

    Future<int> count(DatabaseExecutor executor, String table) async =>
        (await executor.rawQuery('SELECT COUNT(*) AS count FROM $table'))
            .single['count']! as int;

    Future<(int, int, int)> seedCounts(DatabaseExecutor executor) async => (
      await count(executor, 'sport_types'),
      await count(executor, 'venues'),
      await count(executor, 'time_slots'),
    );

    final firstCounts = await seedCounts(db);
    expect(firstCounts, (5, 3, 9));
    await helper.close();
    helper = DatabaseHelper.forTesting(factory: databaseFactoryFfi, path: databasePath);
    final reopened = await helper.database;
    expect(await seedCounts(reopened), firstCounts);
  });

  test('venue CRUD, text search, sport and price filters, and approved status', () async {
    final repository = VenueRepository(databaseHelper: helper);
    final addedId = await repository.addVenue(
      venue: _venue(name: 'Phoenix Badminton', address: '45 Nguyen Trai', sportId: 2, price: 180000),
      description: 'Indoor courts', openTime: '07:00', closeTime: '23:00',
    );

    expect((await repository.getVenueById('$addedId'))?.name, 'Phoenix Badminton');
    expect((await repository.getVenues(query: 'phoenix')).map((v) => v.id), contains('$addedId'));
    expect((await repository.getVenues(query: 'Nguyen Trai')).map((v) => v.id), contains('$addedId'));
    expect((await repository.getVenues(sportTypeId: 2, minPrice: 150000, maxPrice: 200000))
      .map((v) => v.id), contains('$addedId'));
    expect((await repository.getVenues(sportTypeId: 1, maxPrice: 200000))
      .any((v) => v.id == '$addedId'), isFalse);

    final changed = (await repository.getVenueById('$addedId'))!.copyWith(
      name: 'Phoenix Arena', address: 'District 3', pricePerHour: 220000,
      imageUrls: ['/local/phoenix.jpg'],
    );
    expect(await repository.updateVenue(changed, description: 'Renovated'), 1);
    expect((await repository.getVenues(query: 'arena')).single.pricePerHour, 220000);
    expect(await repository.updateVenueStatus('$addedId', 'approved'), 1);
    expect((await repository.getVenues(status: 'approved')).map((v) => v.id), contains('$addedId'));
    expect(await repository.getVenueImagePaths('$addedId'), ['/local/phoenix.jpg']);
    expect(await repository.deleteVenue('$addedId'), 1);
    expect(await repository.getVenueById('$addedId'), isNull);
  });

  test('venue rows and image paths survive closing and reopening the database', () async {
    final repository = VenueRepository(databaseHelper: helper);
    final id = await repository.addVenue(
      venue: _venue(name: 'Persistent Venue', address: 'District 1', sportId: 1, price: 310000),
      description: 'Survives process restart', openTime: '06:00', closeTime: '22:00',
    );
    await repository.saveVenueImagePaths('$id', ['/data/venues/main.jpg', '/data/venues/side.jpg']);

    await helper.close();
    helper = DatabaseHelper.forTesting(factory: databaseFactoryFfi, path: databasePath);
    final reopenedRepository = VenueRepository(databaseHelper: helper);
    final restored = await reopenedRepository.getVenueById('$id');

    expect(restored?.name, 'Persistent Venue');
    expect(restored?.address, 'District 1');
    expect(restored?.imageUrls, ['/data/venues/main.jpg', '/data/venues/side.jpg']);
    expect(await reopenedRepository.getVenueImagePaths('$id'), restored?.imageUrls);
  });
}

Venue _venue({required String name, required String address, required int sportId, required double price}) => Venue(
  id: '', ownerId: '1', sportTypeId: sportId,
  sportType: switch (sportId) { 1 => 'Bóng đá mini', 2 => 'Cầu lông', 3 => 'Tennis', _ => 'Bóng rổ' },
  name: name, address: address, district: 'District 3', city: 'Ho Chi Minh City',
  pricePerHour: price, imageUrls: const [], latitude: 0, longitude: 0, status: 'pending',
);
