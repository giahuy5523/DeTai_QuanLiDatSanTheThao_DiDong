import 'package:sqflite/sqflite.dart';

import '../models/promotion.dart';
import '../utils/database_helper.dart';
import 'mock_store.dart';

/// SQLite access for promotion codes (bảng `promotions`).
///
/// Sau mỗi thao tác ghi, [refreshCache] cập nhật `MockStore.promotions` để các
/// màn hình khác còn đọc từ cache (ví dụ màn đặt sân của khách) thấy dữ liệu mới.
class PromotionRepository {
  PromotionRepository._();

  static Future<Database> get _db => DatabaseHelper().database;

  static Promotion _fromRow(Map<String, Object?> row) => Promotion(
    id: row['id'] as String,
    code: row['code'] as String,
    discountPercent: (row['discountPercent'] as num).toDouble(),
    expiryDate: DateTime.parse(row['expiryDate'] as String),
    isActive: row['isActive'] == 1,
    usedCount: (row['usedCount'] as num).toInt(),
  );

  /// Tất cả mã khuyến mãi, theo thứ tự được tạo.
  static Future<List<Promotion>> loadAll() async {
    final rows = await (await _db).query('promotions', orderBy: 'rowid');
    return rows.map(_fromRow).toList();
  }

  /// Mã đã tồn tại chưa (không phân biệt hoa thường).
  /// [excludeId] dùng khi sửa, để bỏ qua chính mã đang sửa.
  static Future<bool> codeExists(String code, {String? excludeId}) async {
    final rows = await (await _db).query(
      'promotions',
      columns: ['id'],
      where: excludeId == null
          ? 'UPPER(code) = ?'
          : 'UPPER(code) = ? AND id != ?',
      whereArgs: [code.trim().toUpperCase(), ?excludeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Thêm mới hoặc cập nhật. Khi cập nhật không ghi đè `usedCount`, vì số lượt
  /// dùng do luồng đặt sân tăng lên và có thể đã thay đổi sau khi màn hình tải.
  static Future<void> save(Promotion promotion) async {
    final db = await _db;
    final values = <String, Object?>{
      'code': promotion.code,
      'discountPercent': promotion.discountPercent,
      'expiryDate': promotion.expiryDate.toIso8601String(),
      'isActive': promotion.isActive ? 1 : 0,
    };
    final count = await db.update(
      'promotions',
      values,
      where: 'id = ?',
      whereArgs: [promotion.id],
    );
    if (count == 0) {
      await db.insert('promotions', {
        'id': promotion.id,
        ...values,
        'usedCount': promotion.usedCount,
      });
    }
    await refreshCache();
  }

  static Future<void> setActive(String id, bool isActive) async {
    final count = await (await _db).update(
      'promotions',
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) throw StateError('Không tìm thấy mã khuyến mãi.');
    await refreshCache();
  }

  /// Xóa mã. Các lịch đặt đã dùng mã vẫn giữ `promotionCode`, còn `promoId`
  /// tự về NULL nhờ `ON DELETE SET NULL` trong schema.
  static Future<void> delete(String id) async {
    await (await _db).delete('promotions', where: 'id = ?', whereArgs: [id]);
    await refreshCache();
  }

  /// Đồng bộ `MockStore.promotions` với dữ liệu trong SQLite.
  static Future<void> refreshCache() async {
    final promotions = await loadAll();
    MockStore.promotions
      ..clear()
      ..addAll(promotions);
  }
}
