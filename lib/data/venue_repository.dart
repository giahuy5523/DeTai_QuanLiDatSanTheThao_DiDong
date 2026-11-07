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

  /// Tên sân theo id, null nếu không tìm thấy.
  static Future<String?> venueNameFor(String venueId) async {
    final rows = await (await _db).query(
      'venues',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [venueId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['name'] as String;
  }

  /// Thêm mới hoặc cập nhật một dịch vụ của sân, rồi làm mới cache.
  static Future<void> saveService(VenueService service) async {
    final db = await _db;
    final values = <String, Object?>{
      'venueId': service.venueId,
      'name': service.name,
      'price': service.price,
      'unit': service.unit,
    };
    final count = await db.update(
      'venue_services',
      values,
      where: 'id = ?',
      whereArgs: [service.id],
    );
    if (count == 0) {
      await db.insert('venue_services', {'id': service.id, ...values});
    }
    await refreshCache();
  }

  /// Xóa dịch vụ. Trả về false (và không xóa) nếu dịch vụ đã được dùng trong
  /// một lịch đặt, vì booking_services tham chiếu venue_services(id).
  static Future<bool> deleteService(String serviceId) async {
    final db = await _db;
    final used =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM booking_services WHERE serviceId = ?',
            [serviceId],
          ),
        ) ??
        0;
    if (used > 0) return false;
    await db.delete('venue_services', where: 'id = ?', whereArgs: [serviceId]);
    await refreshCache();
    return true;
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

  /// Tất cả lịch đặt của một sân, kèm thông tin khách, sắp theo ngày và giờ.
  static Future<List<VenueBookingEntry>> loadBookingsForVenue(
    String venueId,
  ) async {
    final rows = await (await _db).rawQuery(
      '''
      SELECT b.id, b.date, b.startTime, b.endTime, b.totalPrice, b.status,
             b.promotionCode,
             u.full_name AS customerName, u.phone AS customerPhone
      FROM bookings b
      LEFT JOIN Users u ON u.user_id = b.userId
      WHERE b.venueId = ?
      ORDER BY b.date, b.startTime
    ''',
      [venueId],
    );
    return rows
        .map(
          (row) => VenueBookingEntry(
            id: row['id'] as String,
            date: DateTime.parse(row['date'] as String),
            startTime: row['startTime'] as String,
            endTime: row['endTime'] as String,
            totalPrice: (row['totalPrice'] as num).toDouble(),
            status: row['status'] as String,
            promotionCode: row['promotionCode'] as String?,
            customerName: row['customerName'] as String?,
            customerPhone: row['customerPhone'] as String?,
          ),
        )
        .toList();
  }

  // Chủ sân đổi trạng thái lịch đặt. Chỉ cho phép khi sân thuộc về [ownerId]
  // và trạng thái hiện tại hợp lệ:
  //   pending -> confirmed | cancelled
  //   confirmed -> completed | cancelled
  // Trả về false nếu không có dòng nào được cập nhật.
  static Future<bool> updateBookingStatus({
    required String bookingId,
    required String ownerId,
    required String newStatus,
    String? cancelReason,
  }) async {
    const allowedFrom = <String, List<String>>{
      'confirmed': ['pending'],
      'completed': ['confirmed'],
      'cancelled': ['pending', 'confirmed'],
    };
    final from = allowedFrom[newStatus];
    if (from == null) return false;

    final db = await _db;
    final values = <String, Object?>{'status': newStatus};
    if (newStatus == 'cancelled') {
      values['cancelReason'] = cancelReason ?? 'Chủ sân hủy lịch đặt';
      values['cancelledAt'] = DateTime.now().toIso8601String();
    }
    final count = await db.update(
      'bookings',
      values,
      where:
          'id = ? '
          'AND status IN (${List.filled(from.length, '?').join(',')}) '
          'AND venueId IN (SELECT id FROM venues WHERE ownerId = ?)',
      whereArgs: [bookingId, ...from, ownerId],
    );
    if (count == 0) return false;

    // Đồng bộ bản sao trong bộ nhớ cho các màn hình khác còn đọc MockStore.
    final index = MockStore.bookings.indexWhere((b) => b.id == bookingId);
    if (index >= 0) {
      final cached = MockStore.bookings[index];
      cached.status = newStatus;
      if (newStatus == 'cancelled') {
        cached.cancelReason = values['cancelReason'] as String?;
      }
    }
    return true;
  }

  // Tên, số điện thoại và email của các chủ sân, theo id người dùng.
  // Id không tồn tại trong bảng Users sẽ không có trong kết quả.
  static Future<Map<String, VenueOwnerInfo>> loadOwnerContacts(
    Iterable<String> ownerIds,
  ) async {
    final ids = ownerIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await (await _db).query(
      'Users',
      columns: ['user_id', 'full_name', 'phone', 'email'],
      where: 'user_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    return {
      for (final row in rows)
        row['user_id'] as String: VenueOwnerInfo(
          id: row['user_id'] as String,
          name: row['full_name'] as String,
          phone: row['phone'] as String,
          email: row['email'] as String,
        ),
    };
  }

  // Tính số liệu thống kê bằng SQL (COUNT / SUM), không tải toàn bộ bản ghi.
  static Future<SystemStatistics> loadSystemStatistics() async {
    final db = await _db;

    final bookingRows = await db.rawQuery('''
      SELECT status,
             COUNT(*) AS total,
             COALESCE(SUM(totalPrice), 0) AS amount
      FROM bookings
      GROUP BY status
    ''');
    final venueRows = await db.rawQuery('''
      SELECT status, COUNT(*) AS total
      FROM venues
      GROUP BY status
    ''');

    final bookingsByStatus = <String, int>{};
    var revenue = 0.0;
    for (final row in bookingRows) {
      final status = row['status'] as String;
      bookingsByStatus[status] = (row['total'] as num).toInt();
      if (status == 'confirmed' || status == 'completed') {
        revenue += (row['amount'] as num).toDouble();
      }
    }

    final venuesByStatus = <String, int>{
      for (final row in venueRows)
        row['status'] as String: (row['total'] as num).toInt(),
    };

    return SystemStatistics(
      bookingsByStatus: bookingsByStatus,
      venuesByStatus: venuesByStatus,
      revenue: revenue,
    );
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

// Nó là dữ liệu gọn cho màn "Lịch đặt sân" của chủ sân,
// đã gộp sẵn tên và số điện thoại khách.
class VenueBookingEntry {
  const VenueBookingEntry({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.status,
    this.promotionCode,
    this.customerName,
    this.customerPhone,
  });

  final String id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final double totalPrice;
  final String status;
  final String? promotionCode;
  final String? customerName;
  final String? customerPhone;
}

// Thông tin liên hệ của chủ sân, dùng cho màn Admin duyệt sân.
class VenueOwnerInfo {
  const VenueOwnerInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
}

// Số liệu tổng hợp toàn hệ thống cho màn thống kê của Admin.
class SystemStatistics {
  const SystemStatistics({
    required this.bookingsByStatus,
    required this.venuesByStatus,
    required this.revenue,
  });

  final Map<String, int> bookingsByStatus;
  final Map<String, int> venuesByStatus;

  /// Tổng tiền các lịch đặt đã xác nhận hoặc hoàn thành.
  final double revenue;

  int get totalBookings =>
      bookingsByStatus.values.fold<int>(0, (sum, count) => sum + count);

  int bookings(String status) => bookingsByStatus[status] ?? 0;
  int venues(String status) => venuesByStatus[status] ?? 0;
}
