import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import 'account_repository.dart';
import 'booking_repository.dart';
import 'mock_store.dart';
import 'venue_repository.dart';
import '../utils/database_helper.dart';

/// Keeps existing screens compatible while account storage uses SQLite.
class AccountService {
  AccountService._();
  static AccountRepository? repository;

  static Future<void> initialize() async {
    final appDatabase = await DatabaseHelper().database;
    repository = await AccountRepository.open(
      seed: List.of(MockStore.users),
      database: appDatabase,
    );
    await AccountRepository.importLegacyAccountDatabase(appDatabase);
    await _seedBusinessData(appDatabase);
    await VenueRepository.initialize(appDatabase);
    await BookingRepository.refreshCache();
    await _refresh();
    MockStore.currentUser = await repository!.restoreSession();
  }

  static Future<void> _seedBusinessData(Database database) async {
    await database.transaction((txn) async {
      for (final row in MockStore.sportTypes) {
        await txn.insert('sport_types', {
          'sportTypeId': row['id'],
          'name': row['name'],
          'description': row['description'],
          'icon': row['icon'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final venue in MockStore.venues) {
        await txn.insert('venues', {
          'id': venue.id,
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
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        final hours = MockStore.hoursOf(venue.id);
        await txn.insert('venue_hours', {
          'venueId': venue.id,
          'openHour': hours[0],
          'closeHour': hours[1],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final image in MockStore.venueImages) {
        await txn.insert('venue_images', {
          'id': image['id'],
          'venueId': image['venueId'],
          'imageUrl': image['imageUrl'],
          'isPrimary': image['isPrimary'] == true ? 1 : 0,
          'sortOrder': image['sortOrder'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final services in MockStore.servicesByVenue.values) {
        for (final service in services) {
          await txn.insert('venue_services', {
            'id': service.id,
            'venueId': service.venueId,
            'name': service.name,
            'price': service.price,
            'unit': service.unit,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      for (final promotion in MockStore.promotions) {
        await txn.insert('promotions', {
          'id': promotion.id,
          'code': promotion.code,
          'discountPercent': promotion.discountPercent,
          'expiryDate': promotion.expiryDate.toIso8601String(),
          'isActive': promotion.isActive ? 1 : 0,
          'usedCount': promotion.usedCount,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final booking in MockStore.bookings) {
        await txn.insert('bookings', {
          'id': booking.id,
          'venueId': booking.venueId,
          'userId': booking.userId,
          'date': booking.date.toIso8601String(),
          'startTime': booking.startTime,
          'endTime': booking.endTime,
          'totalPrice': booking.totalPrice,
          'originalAmount': booking.originalAmount,
          'serviceAmount': booking.serviceAmount,
          'discountAmount': booking.discountAmount,
          'status': booking.status,
          'paymentStatus': booking.paymentStatus,
          'paymentId': booking.paymentId,
          'promoId': booking.promoId,
          'promotionCode': booking.promotionCode,
          'note': booking.note,
          'cancelReason': booking.cancelReason,
          'cancelledAt': booking.cancelledAt?.toIso8601String(),
          'createdAt': booking.createdAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        for (var i = 0; i < booking.serviceItems.length; i++) {
          final item = booking.serviceItems[i];
          await txn.insert('booking_services', {
            'id': '${booking.id}_${item.serviceId}_$i',
            'bookingId': booking.id,
            'serviceId': item.serviceId,
            'serviceName': item.serviceName,
            'quantity': item.quantity,
            'unitPrice': item.unitPrice,
            'subtotal': item.subtotal,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      for (final payment in MockStore.payments) {
        final createdAt = payment['createdAt'];
        final paidAt = payment['paidAt'];
        await txn.insert('payments', {
          'id': payment['id'],
          'bookingId': payment['bookingId'],
          'method': payment['method'],
          'amount': payment['amount'],
          'status': payment['status'],
          'transactionCode': payment['transactionCode'],
          'paidAt': paidAt is DateTime ? paidAt.toIso8601String() : paidAt,
          'createdAt': createdAt is DateTime
              ? createdAt.toIso8601String()
              : (createdAt?.toString() ?? DateTime.now().toIso8601String()),
          'refundAmount': payment['refundAmount'],
          'refundMethod': payment['refundMethod'],
          'refundStatus': payment['refundStatus'],
          'refundExpectedAt': payment['refundExpectedAt'] is DateTime
              ? (payment['refundExpectedAt'] as DateTime).toIso8601String()
              : payment['refundExpectedAt'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  static Future<void> _refresh() async {
    final users = await repository!.allUsers();
    MockStore.users
      ..clear()
      ..addAll(users);
  }

  static Future<AppUser?> login(String email, String password) async {
    final db = repository;
    if (db == null) return MockStore.login(email, password);
    final user = await db.login(email, password);
    if (user != null) MockStore.currentUser = user;
    return user;
  }

  static Future<void> register(AppUser user) async {
    final db = repository;
    if (db == null) {
      MockStore.addUser(user);
      return;
    }
    await db.register(user);
    await _refresh();
  }

  static Future<void> logout() async {
    await repository?.logout();
    MockStore.logout();
  }

  static Future<AppUser?> updateProfile({
    required String userId,
    required String name,
    required String phone,
    required String? avatarPath,
  }) async {
    if (MockStore.currentUser?.id != userId) return null;
    final db = repository;
    if (db == null) {
      return MockStore.updateCurrentProfile(
        userId: userId,
        name: name,
        phone: phone,
        avatarPath: avatarPath,
      );
    }
    final updated = await db.updateProfile(
      userId: userId,
      name: name,
      phone: phone,
      avatarPath: avatarPath,
    );
    if (updated != null) {
      final index = MockStore.users.indexWhere((u) => u.id == userId);
      if (index >= 0) MockStore.users[index] = updated;
      if (MockStore.currentUser?.id == userId) MockStore.currentUser = updated;
    }
    return updated;
  }
}
