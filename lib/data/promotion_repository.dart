import 'package:sqflite/sqflite.dart';

import '../models/promotion.dart';
import '../utils/database_helper.dart';
import 'mock_store.dart';

/// SQLite repository for admin promotion management: create, update, enable/
/// disable and delete. Cache (MockStore) writes run only after commit.
class PromotionRepository {
  PromotionRepository._();

  static Database? _database;
  /// Chỉ dùng trong test (widget test không có SQLite driver). Production
  /// luôn đi qua SQLite: nếu database không mở được, lỗi được ném ra,
  /// không chuyển sang MockStore.
  static bool _useMockStoreForTesting = false;

  static void setDatabaseForTesting(Database? db) => _database = db;

  static void setUseMockStoreForTesting(bool enabled) {
    _useMockStoreForTesting = enabled;
  }

  static Future<Database?> get _db async {
    if (_useMockStoreForTesting) return null;
    if (_database != null) return _database;
    _database = await DatabaseHelper().database;
    return _database;
  }

  /// Chạy một transaction SQLite; thao tác cache được xếp hàng và chỉ chạy
  /// sau khi commit thành công.
  static Future<T> _txn<T>(
    Database db,
    Future<T> Function(Transaction txn, List<void Function()> afterCommit)
    action,
  ) async {
    final afterCommit = <void Function()>[];
    final result = await db.transaction<T>((txn) => action(txn, afterCommit));
    for (final op in afterCommit) {
      op();
    }
    return result;
  }

  // --------------------------------------------------------------------------
  static Future<bool> createPromotion(Promotion promotion) async {
    final normalizedCode = promotion.code.trim().toUpperCase();
    if (normalizedCode.isEmpty ||
        !promotion.discountPercent.isFinite ||
        promotion.discountPercent <= 0 ||
        promotion.discountPercent > 100) {
      return false;
    }

    final db = await _db;
    if (db == null) {
      final exists = MockStore.promotions.any(
        (p) => p.code.trim().toUpperCase() == normalizedCode,
      );
      if (exists) return false;
      MockStore.promotions.add(promotion);
      return true;
    }

    return _txn<bool>(db, (txn, afterCommit) async {
      final existing = await txn.query(
        'promotions',
        columns: ['id'],
        where: 'UPPER(code) = ?',
        whereArgs: [normalizedCode],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;

      await txn.insert('promotions', {
        'id': promotion.id,
        'code': normalizedCode,
        'discountPercent': promotion.discountPercent,
        'expiryDate': promotion.expiryDate.toIso8601String(),
        'isActive': promotion.isActive ? 1 : 0,
        'usedCount': promotion.usedCount,
      });

      afterCommit.add(() => MockStore.promotions.add(promotion));
      return true;
    });
  }

  static Future<bool> updatePromotion(Promotion promotion) async {
    final normalizedCode = promotion.code.trim().toUpperCase();
    if (normalizedCode.isEmpty ||
        !promotion.discountPercent.isFinite ||
        promotion.discountPercent <= 0 ||
        promotion.discountPercent > 100) {
      return false;
    }

    final db = await _db;
    if (db == null) {
      final idx = MockStore.promotions.indexWhere((p) => p.id == promotion.id);
      if (idx == -1) return false;
      final duplicate = MockStore.promotions.any(
        (p) =>
            p.code.trim().toUpperCase() == normalizedCode &&
            p.id != promotion.id,
      );
      if (duplicate) return false;
      MockStore.promotions[idx] = promotion;
      return true;
    }

    return _txn<bool>(db, (txn, afterCommit) async {
      final duplicate = await txn.query(
        'promotions',
        columns: ['id'],
        where: 'UPPER(code) = ? AND id != ?',
        whereArgs: [normalizedCode, promotion.id],
        limit: 1,
      );
      if (duplicate.isNotEmpty) return false;

      final updated = await txn.update(
        'promotions',
        {
          'code': normalizedCode,
          'discountPercent': promotion.discountPercent,
          'expiryDate': promotion.expiryDate.toIso8601String(),
          'isActive': promotion.isActive ? 1 : 0,
          'usedCount': promotion.usedCount,
        },
        where: 'id = ?',
        whereArgs: [promotion.id],
      );
      if (updated == 0) return false;

      afterCommit.add(() {
        final idx = MockStore.promotions.indexWhere((p) => p.id == promotion.id);
        if (idx != -1) {
          MockStore.promotions[idx] = promotion;
        }
      });
      return true;
    });
  }

  static Future<bool> togglePromotionActive(
    String promoId,
    bool isActive,
  ) async {
    final db = await _db;
    if (db == null) {
      final idx = MockStore.promotions.indexWhere((p) => p.id == promoId);
      if (idx == -1) return false;
      final p = MockStore.promotions[idx];
      MockStore.promotions[idx] = Promotion(
        id: p.id,
        code: p.code,
        discountPercent: p.discountPercent,
        expiryDate: p.expiryDate,
        isActive: isActive,
        usedCount: p.usedCount,
        usageHistory: p.usageHistory,
      );
      return true;
    }

    return _txn<bool>(db, (txn, afterCommit) async {
      final count = await txn.update(
        'promotions',
        {'isActive': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [promoId],
      );
      if (count == 0) return false;

      afterCommit.add(() {
        final idx = MockStore.promotions.indexWhere((p) => p.id == promoId);
        if (idx != -1) {
          final p = MockStore.promotions[idx];
          MockStore.promotions[idx] = Promotion(
            id: p.id,
            code: p.code,
            discountPercent: p.discountPercent,
            expiryDate: p.expiryDate,
            isActive: isActive,
            usedCount: p.usedCount,
            usageHistory: p.usageHistory,
          );
        }
      });
      return true;
    });
  }

  static Future<bool> deletePromotion(String promoId) async {
    final db = await _db;
    if (db == null) {
      final idx = MockStore.promotions.indexWhere((p) => p.id == promoId);
      if (idx == -1) return false;
      final p = MockStore.promotions[idx];
      // Kiểm tra nếu đã được dùng thì không xóa cứng để tránh mất lịch sử mà vô hiệu hóa
      if (p.usedCount > 0 || p.usageHistory.isNotEmpty) {
        MockStore.promotions[idx] = Promotion(
          id: p.id,
          code: p.code,
          discountPercent: p.discountPercent,
          expiryDate: p.expiryDate,
          isActive: false,
          usedCount: p.usedCount,
          usageHistory: p.usageHistory,
        );
        return true;
      }
      MockStore.promotions.removeAt(idx);
      return true;
    }

    return _txn<bool>(db, (txn, afterCommit) async {
      final promoRows = await txn.query(
        'promotions',
        columns: ['id', 'usedCount'],
        where: 'id = ?',
        whereArgs: [promoId],
        limit: 1,
      );
      if (promoRows.isEmpty) return false;

      final usedCount = promoRows.single['usedCount'] as int? ?? 0;
      final usages = await txn.query(
        'promotion_usages',
        columns: ['id'],
        where: 'promotionId = ?',
        whereArgs: [promoId],
        limit: 1,
      );

      // Nếu đã từng có lịch sử sử dụng hoặc usedCount > 0: bảo toàn lịch sử bằng cách vô hiệu hóa
      if (usedCount > 0 || usages.isNotEmpty) {
        await txn.update(
          'promotions',
          {'isActive': 0},
          where: 'id = ?',
          whereArgs: [promoId],
        );
        afterCommit.add(() {
          final idx = MockStore.promotions.indexWhere((p) => p.id == promoId);
          if (idx != -1) {
            final p = MockStore.promotions[idx];
            MockStore.promotions[idx] = Promotion(
              id: p.id,
              code: p.code,
              discountPercent: p.discountPercent,
              expiryDate: p.expiryDate,
              isActive: false,
              usedCount: p.usedCount,
              usageHistory: p.usageHistory,
            );
          }
        });
        return true;
      }

      await txn.delete('promotions', where: 'id = ?', whereArgs: [promoId]);

      afterCommit.add(
        () => MockStore.promotions.removeWhere((p) => p.id == promoId),
      );
      return true;
    });
  }
}
