import 'package:sqflite/sqflite.dart';

import '../models/service.dart';
import '../models/venue.dart';
import '../utils/database_helper.dart';
import 'mock_store.dart';
import 'venue_image_storage.dart';

/// SQLite access for venue discovery and owner venue management.
class VenueRepository {
  VenueRepository._();

  static Database? _database;
  static bool _useMockStoreForTesting = false;

  static void setUseMockStoreForTesting(bool value) {
    _useMockStoreForTesting = value;
  }

  static bool get isInitialized => _database != null;

  static Future<void> initialize(Database database) async {
    _database = database;
    await refreshCache();
  }

  static Future<Database> get _db async =>
      _database ??= await DatabaseHelper().database;

  static Future<List<Venue>> loadVenues({
    bool approvedOnly = false,
    String? ownerId,
  }) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <Object?>[];
    if (approvedOnly) {
      conditions.add('status = ?');
      args.add('approved');
    }
    if (ownerId != null) {
      conditions.add('ownerId = ?');
      args.add(ownerId);
    }
    final rows = await db.query(
      'venues',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name COLLATE NOCASE',
    );
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row['id'] as String).toList();
    final imageRows = await db.query(
      'venue_images',
      where: 'venueId IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'sortOrder, id',
    );
    final images = <String, List<String>>{};
    for (final row in imageRows) {
      (images[row['venueId'] as String] ??= []).add(row['imageUrl'] as String);
    }
    return rows
        .map(
          (row) => Venue(
            id: row['id'] as String,
            ownerId: row['ownerId'] as String,
            sportTypeId: row['sportTypeId'] as int?,
            sportType: row['sportType'] as String,
            name: row['name'] as String,
            address: row['address'] as String,
            district: row['district'] as String?,
            city: row['city'] as String?,
            pricePerHour: (row['pricePerHour'] as num).toDouble(),
            imageUrls: images[row['id']] ?? const [],
            latitude: (row['latitude'] as num).toDouble(),
            longitude: (row['longitude'] as num).toDouble(),
            status: row['status'] as String,
            rating: (row['rating'] as num).toDouble(),
          ),
        )
        .toList();
  }

  static Future<List<Map<String, Object?>>> loadSportTypes() async =>
      (await _db).query('sport_types', orderBy: 'sportTypeId');

  static Future<int?> sportTypeIdFor(String name) async {
    final rows = await (await _db).query(
      'sport_types',
      columns: ['sportTypeId'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['sportTypeId'] as int;
  }

  static Future<List<VenueService>> loadServicesFor(String venueId) async {
    final rows = await (await _db).query(
      'venue_services',
      where: 'venueId = ?',
      whereArgs: [venueId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows
        .map(
          (row) => VenueService(
            id: row['id'] as String,
            venueId: row['venueId'] as String,
            name: row['name'] as String,
            price: (row['price'] as num).toDouble(),
            unit: row['unit'] as String,
          ),
        )
        .toList();
  }

  static Future<void> saveService(VenueService service) async {
    if (_useMockStoreForTesting) {
      final services = MockStore.servicesByVenue[service.venueId] ??= [];
      final index = services.indexWhere((item) => item.id == service.id);

      if (index < 0) {
        services.add(service);
      } else {
        services[index] = service;
      }
      return;
    }
    final db = await _db;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'venue_services',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [service.id],
        limit: 1,
      );

      final values = <String, Object?>{
        'venueId': service.venueId,
        'name': service.name,
        'price': service.price,
        'unit': service.unit,
      };

      if (existing.isEmpty) {
        await txn.insert('venue_services', {'id': service.id, ...values});
      } else {
        await txn.update(
          'venue_services',
          values,
          where: 'id = ?',
          whereArgs: [service.id],
        );
      }
    });

    await refreshCache();
  }

  static Future<void> deleteService(String serviceId) async {
    if (_useMockStoreForTesting) {
      List<VenueService>? matchingServices;
      for (final services in MockStore.servicesByVenue.values) {
        if (services.any((item) => item.id == serviceId)) {
          matchingServices = services;
          break;
        }
      }

      if (matchingServices == null) {
        throw StateError('Không tìm thấy dịch vụ cần xóa.');
      }

      matchingServices.removeWhere((item) => item.id == serviceId);
      return;
    }
    final db = await _db;

    await db.transaction((txn) async {
      final references = await txn.query(
        'booking_services',
        columns: ['id'],
        where: 'serviceId = ?',
        whereArgs: [serviceId],
        limit: 1,
      );

      if (references.isNotEmpty) {
        throw StateError(
          'Không thể xóa dịch vụ đã được sử dụng trong đơn đặt sân.',
        );
      }

      final deleted = await txn.delete(
        'venue_services',
        where: 'id = ?',
        whereArgs: [serviceId],
      );

      if (deleted == 0) {
        throw StateError('Không tìm thấy dịch vụ cần xóa.');
      }
    });

    await refreshCache();
  }

  static Future<void> refreshCache() async {
    final db = await _db;
    final venues = await loadVenues();
    final imageRows = await db.query('venue_images', orderBy: 'sortOrder, id');
    final cachedImages = <Map<String, dynamic>>[];
    for (final row in imageRows) {
      final venueId = row['venueId'] as String;
      final url = row['imageUrl'] as String;
      cachedImages.add({
        'id': row['id'],
        'venueId': venueId,
        'imageUrl': url,
        'isPrimary': row['isPrimary'] == 1,
        'sortOrder': row['sortOrder'],
      });
    }

    final sports = await loadSportTypes();
    final services = await db.query(
      'venue_services',
      orderBy: 'name COLLATE NOCASE',
    );
    MockStore.venues
      ..clear()
      ..addAll(venues);
    MockStore.venueImages
      ..clear()
      ..addAll(cachedImages);
    MockStore.sportTypes
      ..clear()
      ..addAll(
        sports.map(
          (row) => {
            'id': row['sportTypeId'],
            'name': row['name'],
            'description': row['description'],
          },
        ),
      );
    MockStore.servicesByVenue.clear();
    for (final row in services) {
      final venueId = row['venueId'] as String;
      (MockStore.servicesByVenue[venueId] ??= []).add(
        VenueService(
          id: row['id'] as String,
          venueId: venueId,
          name: row['name'] as String,
          price: (row['price'] as num).toDouble(),
          unit: row['unit'] as String,
        ),
      );
    }
  }

  static Future<void> saveVenue(Venue venue) async {
    final db = await _db;
    final imageUrls = await Future.wait(
      venue.imageUrls.map(VenueImageStorage.persist),
    );
    await db.transaction((txn) async {
      if (venue.sportTypeId != null) {
        await txn.insert('sport_types', {
          'sportTypeId': venue.sportTypeId,
          'name': venue.sportType,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      final values = <String, Object?>{
        'ownerId': venue.ownerId,
        'sportTypeId': venue.sportTypeId,
        'sportType': venue.sportType,
        'name': venue.name,
        'address': venue.address,
        'district': venue.district,
        'city': venue.city,
        'pricePerHour': venue.pricePerHour,
        'latitude': venue.latitude,
        'longitude': venue.longitude,
        'status': venue.status,
        'rating': venue.rating,
      };
      final found = await txn.query(
        'venues',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [venue.id],
      );
      if (found.isEmpty) {
        await txn.insert('venues', {'id': venue.id, ...values});
      } else {
        await txn.update(
          'venues',
          values,
          where: 'id = ?',
          whereArgs: [venue.id],
        );
      }

      await txn.delete(
        'venue_images',
        where: 'venueId = ?',
        whereArgs: [venue.id],
      );
      for (var index = 0; index < imageUrls.length; index++) {
        await txn.insert('venue_images', {
          'id': 'img_${venue.id}_$index',
          'venueId': venue.id,
          'imageUrl': imageUrls[index],
          'isPrimary': index == 0 ? 1 : 0,
          'sortOrder': index + 1,
        });
      }
      await txn.insert('venue_hours', {
        'venueId': venue.id,
        'openHour': MockStore.hoursOf(venue.id)[0],
        'closeHour': MockStore.hoursOf(venue.id)[1],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
    await refreshCache();
  }

  static Future<void> updateStatus(String venueId, String status) async {
    final db = await _db;
    final count = await db.update(
      'venues',
      {'status': status},
      where: 'id = ?',
      whereArgs: [venueId],
    );
    if (count == 0) throw StateError('Không tìm thấy sân cần cập nhật.');
    await refreshCache();
  }

  static Future<int> todayBookingCountForOwner(String ownerId) async {
    final db = await _db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM bookings b JOIN venues v ON v.id = b.venueId
      WHERE v.ownerId = ? AND b.date >= ? AND b.date < ?
    ''',
      [ownerId, start, end],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  static Future<List<Map<String, Object?>>> loadAvailableSlots(
    String venueId,
    DateTime date,
  ) async {
    final db = await _db;
    final venues = await db.query(
      'venues',
      columns: ['pricePerHour', 'status'],
      where: 'id = ?',
      whereArgs: [venueId],
      limit: 1,
    );
    if (venues.isEmpty || venues.single['status'] != 'approved') {
      return const [];
    }
    final hoursRows = await db.query(
      'venue_hours',
      where: 'venueId = ?',
      whereArgs: [venueId],
      limit: 1,
    );
    final openHour = hoursRows.isEmpty
        ? 6
        : hoursRows.single['openHour'] as int;
    final closeHour = hoursRows.isEmpty
        ? 22
        : hoursRows.single['closeHour'] as int;
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final bookings = await db.query(
      'bookings',
      columns: ['startTime', 'endTime'],
      where: "venueId = ? AND status != 'cancelled' AND date >= ? AND date < ?",
      whereArgs: [
        venueId,
        dayStart.toIso8601String(),
        dayEnd.toIso8601String(),
      ],
    );
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final slots = <Map<String, Object?>>[];
    for (var hour = openHour; hour < closeHour; hour++) {
      final start = hour * 60;
      final end = start + 60;
      final booked = bookings.any((booking) {
        final bookingStart = _minutes(booking['startTime'] as String);
        final bookingEnd = _minutes(booking['endTime'] as String);
        return bookingStart < end && bookingEnd > start;
      });
      final past = isToday && start <= now.hour * 60 + now.minute;
      slots.add({
        'venueId': venueId,
        'date': date,
        'startTime': '${hour.toString().padLeft(2, '0')}:00',
        'endTime': '${(hour + 1).toString().padLeft(2, '0')}:00',
        'price': venues.single['pricePerHour'],
        'status': booked ? 'booked' : (past ? 'blocked' : 'available'),
      });
    }
    return slots;
  }

  static int _minutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return -1;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return -1;
    return hour * 60 + minute;
  }
}
