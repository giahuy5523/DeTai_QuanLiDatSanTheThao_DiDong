import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/venue.dart';
import '../utils/database_helper.dart';

/// CRUD and image-path persistence for sport venues.
class VenueRepository {
  VenueRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<List<Venue>> getVenues({
    String? status,
    int? ownerId,
    String? query,
    int? sportTypeId,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final clauses = <String>[];
      final args = <Object?>[];
      if (status != null) { clauses.add('v.status = ?'); args.add(status); }
      if (ownerId != null) { clauses.add('v.owner_id = ?'); args.add(ownerId); }
      final normalizedQuery = query?.trim();
      if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
        clauses.add('(v.name LIKE ? COLLATE NOCASE OR v.address LIKE ? COLLATE NOCASE OR v.district LIKE ? COLLATE NOCASE OR v.city LIKE ? COLLATE NOCASE)');
        final pattern = '%$normalizedQuery%';
        args.addAll([pattern, pattern, pattern, pattern]);
      }
      if (sportTypeId != null) { clauses.add('v.sport_type_id = ?'); args.add(sportTypeId); }
      if (minPrice != null) { clauses.add('v.price_per_hour >= ?'); args.add(minPrice); }
      if (maxPrice != null) { clauses.add('v.price_per_hour <= ?'); args.add(maxPrice); }
      final rows = await db.rawQuery('''
        SELECT v.*, s.name AS sport_name,
          (SELECT GROUP_CONCAT(image_url, char(31)) FROM
            (SELECT image_url FROM venue_images vi WHERE vi.venue_id = v.venue_id
             ORDER BY vi.is_primary DESC, vi.sort_order ASC, vi.image_id ASC)) AS image_paths
        FROM venues v JOIN sport_types s ON s.sport_type_id = v.sport_type_id
        ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
        ORDER BY v.created_at DESC, v.venue_id DESC
      ''', args);
      return rows.map(_fromRow).toList(growable: false);
    } catch (error, stack) {
      debugPrint('[VenueRepository] getVenues failed: $error\n$stack');
      rethrow;
    }
  }

  Future<Venue?> getVenueById(String id) async {
    try {
      final rows = await getVenues();
      for (final venue in rows) { if (venue.id == id) return venue; }
      return null;
    } catch (error, stack) {
      debugPrint('[VenueRepository] getVenueById($id) failed: $error\n$stack');
      rethrow;
    }
  }

  Future<int> addVenue({required Venue venue, required String description,
    required String openTime, required String closeTime}) async {
    try {
      final db = await _databaseHelper.database;
      return await db.transaction((txn) async {
        final id = await txn.insert('venues', _venueValues(venue,
          description: description, openTime: openTime, closeTime: closeTime));
        await _replaceImages(txn, id, venue.imageUrls);
        debugPrint('[VenueRepository] Added venue id=$id');
        return id;
      });
    } catch (error, stack) {
      debugPrint('[VenueRepository] addVenue failed: $error\n$stack');
      rethrow;
    }
  }

  Future<int> updateVenue(Venue venue, {String? description, String? openTime,
    String? closeTime, bool updateImages = true}) async {
    try {
      final id = int.parse(venue.id);
      final db = await _databaseHelper.database;
      return await db.transaction((txn) async {
        final values = _venueValues(venue,
          description: description, openTime: openTime, closeTime: closeTime);
        values.remove('open_time');
        values.remove('close_time');
        values.remove('description');
        if (openTime != null) values['open_time'] = openTime;
        if (closeTime != null) values['close_time'] = closeTime;
        if (description != null) values['description'] = description;
        final changed = await txn.update('venues', values,
          where: 'venue_id = ?', whereArgs: [id]);
        if (changed > 0 && updateImages) await _replaceImages(txn, id, venue.imageUrls);
        debugPrint('[VenueRepository] Updated venue id=$id, rows=$changed');
        return changed;
      });
    } catch (error, stack) {
      debugPrint('[VenueRepository] updateVenue(${venue.id}) failed: $error\n$stack');
      rethrow;
    }
  }

  Future<int> deleteVenue(String id) async {
    try {
      final db = await _databaseHelper.database;
      final changed = await db.delete('venues', where: 'venue_id = ?', whereArgs: [int.parse(id)]);
      debugPrint('[VenueRepository] Deleted venue id=$id, rows=$changed');
      return changed;
    } catch (error, stack) {
      debugPrint('[VenueRepository] deleteVenue($id) failed: $error\n$stack');
      rethrow;
    }
  }

  Future<int> updateVenueStatus(String id, String status, {String? reason,
    int? reviewedBy}) async {
    if (!{'pending', 'approved', 'rejected'}.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Must be pending, approved, or rejected.');
    }
    try {
      final db = await _databaseHelper.database;
      final changed = await db.update('venues', {
        'status': status,
        'reject_reason': status == 'rejected' ? reason : null,
        'reviewed_by': reviewedBy,
        'reviewed_at': status == 'pending' ? null : DateTime.now().toIso8601String(),
      }, where: 'venue_id = ?', whereArgs: [int.parse(id)]);
      debugPrint('[VenueRepository] Set venue id=$id status=$status, rows=$changed');
      return changed;
    } catch (error, stack) {
      debugPrint('[VenueRepository] updateVenueStatus($id) failed: $error\n$stack');
      rethrow;
    }
  }

  Future<List<String>> getVenueImagePaths(String venueId) async {
    try {
      final db = await _databaseHelper.database;
      final rows = await db.query('venue_images', columns: ['image_url'],
        where: 'venue_id = ?', whereArgs: [int.parse(venueId)],
        orderBy: 'is_primary DESC, sort_order ASC, image_id ASC');
      return rows.map((row) => row['image_url']! as String).toList(growable: false);
    } catch (error, stack) {
      debugPrint('[VenueRepository] getVenueImagePaths($venueId) failed: $error\n$stack');
      rethrow;
    }
  }

  Future<void> saveVenueImagePaths(String venueId, List<String> paths) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) => _replaceImages(txn, int.parse(venueId), paths));
      debugPrint('[VenueRepository] Saved ${paths.length} image paths for venue=$venueId');
    } catch (error, stack) {
      debugPrint('[VenueRepository] saveVenueImagePaths($venueId) failed: $error\n$stack');
      rethrow;
    }
  }

  Future<void> _replaceImages(DatabaseExecutor db, int venueId, List<String> paths) async {
    // Remove old primary first so the partial unique index remains satisfied.
    await db.delete('venue_images', where: 'venue_id = ?', whereArgs: [venueId]);
    for (var index = 0; index < paths.length; index++) {
      final imagePath = paths[index].trim();
      if (imagePath.isEmpty) continue;
      await db.insert('venue_images', {
        'venue_id': venueId, 'image_url': imagePath,
        'is_primary': index == 0 ? 1 : 0, 'sort_order': index,
      });
    }
  }

  Map<String, Object?> _venueValues(Venue venue, {String? description,
    String? openTime, String? closeTime}) => {
    'owner_id': int.parse(venue.ownerId),
    'sport_type_id': venue.sportTypeId ?? _sportId(venue.sportType),
    'name': venue.name, 'address': venue.address, 'district': venue.district,
    'city': venue.city, 'description': description,
    'price_per_hour': venue.pricePerHour,
    ...(openTime == null ? const {} : {'open_time': openTime}),
    ...(closeTime == null ? const {} : {'close_time': closeTime}),
    'status': venue.status,
  };

  int _sportId(String name) {
    const ids = {'Bóng đá': 1, 'Bóng đá mini': 1, 'Cầu lông': 2,
      'Tennis': 3, 'Bóng rổ': 4, 'Pickleball': 5};
    final id = ids[name];
    if (id == null) throw ArgumentError('Unknown sport type "$name"; set sportTypeId.');
    return id;
  }

  Venue _fromRow(Map<String, Object?> row) {
    final packed = row['image_paths'] as String?;
    final imageUrls = packed == null || packed.isEmpty
        ? <String>[] : packed.split(String.fromCharCode(31));
    return Venue(
      id: '${row['venue_id']}', ownerId: '${row['owner_id']}',
      sportTypeId: row['sport_type_id'] as int?,
      sportType: row['sport_name'] as String,
      name: row['name'] as String, address: row['address'] as String,
      district: row['district'] as String?, city: row['city'] as String?,
      pricePerHour: (row['price_per_hour'] as num).toDouble(),
      imageUrls: imageUrls, latitude: 0, longitude: 0,
      status: row['status'] as String,
    );
  }
}
