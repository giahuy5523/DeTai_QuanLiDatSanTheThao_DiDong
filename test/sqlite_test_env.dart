import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/data/venue_repository.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

/// SQLite thật cho test: schema v3, khóa ngoại bật, không dùng cache MockStore.
class SqliteTestEnv {
  SqliteTestEnv._(this.db, this.dir);

  final Database db;
  final Directory dir;

  static Future<SqliteTestEnv> open(String name) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('sqlite_env_');
    final db = await databaseFactory.openDatabase(
      '${dir.path}${Platform.pathSeparator}$name.db',
      options: OpenDatabaseOptions(
        version: DatabaseHelper.databaseVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => DatabaseHelper().createSchema(db),
      ),
    );
    BookingRepository.setUseMockStoreForTesting(false);
    BookingRepository.setDatabaseForTesting(db);
    VenueRepository.setUseMockStoreForTesting(false);
    await VenueRepository.initialize(db);
    return SqliteTestEnv._(db, dir);
  }

  Future<void> close() async {
    BookingRepository.setDatabaseForTesting(null);
    await db.close();
    await dir.delete(recursive: true);
  }
}
