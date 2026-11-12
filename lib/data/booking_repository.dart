import 'dart:math';
import 'package:sqflite/sqflite.dart';

import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/payment.dart';
import '../models/promotion.dart';
import '../utils/database_helper.dart';
import 'mock_store.dart';

/// SQLite Repository managing persistence and transactions for Booking,
/// Payment, PromotionUsage, and AppNotification.
class BookingRepository {
  BookingRepository._();

  static Database? _database;
  static bool _useMockStoreForTesting = false;
  static bool get isInitialized => _database != null;

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

  /// Chạy một transaction SQLite. Các thao tác ghi vào cache MockStore được
  /// xếp vào `afterCommit` và chỉ chạy SAU khi transaction commit thành công,
  /// nên rollback không làm MockStore đi trước database.
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
  // 1. KIỂM TRA KHUNG GIỜ KHẢ DỤNG
  // --------------------------------------------------------------------------
  static Future<bool> isRangeAvailable({
    required String venueId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? excludeBookingId,
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? await _db;
    if (client == null) {
      // Fallback về MockStore nếu SQLite chưa mở (e.g. trong widget test không có SQLite driver)
      return MockStore.isRangeAvailable(venueId, date, startTime, endTime);
    }
    final from = _toMinutes(startTime.trim());
    final to = _toMinutes(endTime.trim());
    if (from < 0 || to <= from) return false;

    final dateStr = _formatDateOnly(date);
    final conditions = <String>[
      'venueId = ?',
      "status != 'cancelled'",
      'substr(date, 1, 10) = ?',
    ];
    final args = <Object?>[venueId, dateStr];

    if (excludeBookingId != null && excludeBookingId.isNotEmpty) {
      conditions.add('id != ?');
      args.add(excludeBookingId);
    }

    final rows = await client.query(
      'bookings',
      columns: ['startTime', 'endTime'],
      where: conditions.join(' AND '),
      whereArgs: args,
    );

    for (final row in rows) {
      final existingStart = _toMinutes((row['startTime'] as String).trim());
      final existingEnd = _toMinutes((row['endTime'] as String).trim());
      if (from < existingEnd && to > existingStart) {
        return false;
      }
    }
    return true;
  }

  // --------------------------------------------------------------------------
  // 2. TRANSACTION ĐẶT SÂN VÀ THANH TOÁN (Trọn gói)
  // --------------------------------------------------------------------------
  static Future<BookingPaymentResult> processBookingPayment({
    required Booking booking,
    required String method,
    bool simulateFailure = false,
    String? transactionCode,
  }) async {
    final db = await _db;
    if (db == null) {
      // Fallback về MockStore nếu SQLite chưa mở (e.g. trong widget test không có SQLite driver)
      return MockStore.processBookingPayment(
        booking: booking,
        method: method,
        simulateFailure: simulateFailure,
        transactionCode: transactionCode,
      );
    }

    // 1. Kiểm tra tính hợp lệ cơ bản
    if (!booking.totalPrice.isFinite ||
        booking.totalPrice < 0 ||
        !['cash', 'momo', 'vnpay', 'bank_transfer'].contains(method)) {
      return const BookingPaymentResult(
        isSuccess: false,
        isSlotAvailable: false,
        failureReason: 'Thông tin đơn đặt sân hoặc phương thức không hợp lệ.',
      );
    }

    return _txn<BookingPaymentResult>(db, (txn, afterCommit) async {
      // 1.1 Kiểm tra trùng booking id
      final existingBooking = await txn.query(
        'bookings',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [booking.id],
        limit: 1,
      );
      if (existingBooking.isNotEmpty) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: false,
          failureReason: 'Mã đặt sân đã tồn tại.',
        );
      }

      // 1.2 Kiểm tra venue tồn tại và giá
      final venueRows = await txn.query(
        'venues',
        columns: ['id', 'status', 'pricePerHour'],
        where: 'id = ?',
        whereArgs: [booking.venueId],
        limit: 1,
      );
      if (venueRows.isEmpty || venueRows.single['status'] != 'approved') {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: false,
          failureReason: 'Thông tin sân không hợp lệ hoặc chưa được duyệt.',
        );
      }
      final pricePerHour = (venueRows.single['pricePerHour'] as num).toDouble();
      final from = _toMinutes(booking.startTime.trim());
      final to = _toMinutes(booking.endTime.trim());
      if (from < 0 || to <= from) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: false,
          failureReason: 'Khung giờ đặt sân không hợp lệ.',
        );
      }
      final expectedOriginal = pricePerHour * ((to - from) / 60);
      if ((booking.originalAmount - expectedOriginal).abs() > 0.01) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: false,
          failureReason: 'Tiền thuê sân không khớp với bảng giá.',
        );
      }

      // 1.3 Kiểm tra user
      final userRows = await txn.query(
        'Users',
        columns: ['user_id', 'role'],
        where: 'user_id = ? AND role = ? AND is_active = 1',
        whereArgs: [booking.userId, 'customer'],
        limit: 1,
      );
      if (userRows.isEmpty) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: false,
          failureReason: 'Khách hàng không tồn tại hoặc không hợp lệ.',
        );
      }

      // 1.4 Kiểm tra dịch vụ đi kèm
      final availableServiceRows = await txn.query(
        'venue_services',
        where: 'venueId = ?',
        whereArgs: [booking.venueId],
      );
      final availableServices = {
        for (final r in availableServiceRows)
          r['id'] as String: (r['price'] as num).toDouble(),
      };
      double calculatedServiceAmount = 0.0;
      for (final item in booking.serviceItems) {
        final expectedPrice = availableServices[item.serviceId];
        if (expectedPrice == null ||
            item.quantity <= 0 ||
            (item.unitPrice - expectedPrice).abs() > 0.01) {
          return const BookingPaymentResult(
            isSuccess: false,
            isSlotAvailable: true,
            failureReason: 'Thông tin dịch vụ đi kèm không hợp lệ.',
          );
        }
        calculatedServiceAmount += item.subtotal;
      }
      if ((booking.serviceAmount - calculatedServiceAmount).abs() > 0.01) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: true,
          failureReason: 'Tổng tiền dịch vụ không khớp.',
        );
      }

      // 1.5 Kiểm tra khuyến mãi
      final normalizedPromoCode = booking.promotionCode?.trim().toUpperCase();
      final hasPromoCode =
          normalizedPromoCode != null && normalizedPromoCode.isNotEmpty;
      final subtotal = booking.originalAmount + booking.serviceAmount;

      if (hasPromoCode) {
        final promoRows = await txn.query(
          'promotions',
          where: 'UPPER(code) = ? AND isActive = 1',
          whereArgs: [normalizedPromoCode],
          limit: 1,
        );
        if (promoRows.isEmpty) {
          return const BookingPaymentResult(
            isSuccess: false,
            isSlotAvailable: true,
            failureReason: 'Mã khuyến mãi không hợp lệ.',
          );
        }
        final promoRow = promoRows.single;
        final expiry = DateTime.parse(promoRow['expiryDate'] as String);
        final now = DateTime.now();
        if (now.isAfter(
          DateTime(
            expiry.year,
            expiry.month,
            expiry.day,
          ).add(const Duration(days: 1)),
        )) {
          return const BookingPaymentResult(
            isSuccess: false,
            isSlotAvailable: true,
            failureReason: 'Mã khuyến mãi đã hết hạn.',
          );
        }
        final discountPercent = (promoRow['discountPercent'] as num).toDouble();
        final expectedDiscount = subtotal * discountPercent / 100;
        final expectedTotal = subtotal - expectedDiscount;
        if ((booking.discountAmount - expectedDiscount).abs() > 0.01 ||
            (booking.totalPrice - expectedTotal).abs() > 0.01 ||
            booking.promoId != promoRow['id']) {
          return const BookingPaymentResult(
            isSuccess: false,
            isSlotAvailable: true,
            failureReason: 'Thông tin giảm giá không khớp với mã khuyến mãi.',
          );
        }
      } else {
        if (booking.promoId != null ||
            booking.discountAmount > 0.01 ||
            (booking.totalPrice - subtotal).abs() > 0.01) {
          return const BookingPaymentResult(
            isSuccess: false,
            isSlotAvailable: true,
            failureReason: 'Số tiền đặt sân không hợp lệ.',
          );
        }
      }

      // 2. Kiểm tra khung giờ trùng lặp (Ngay trong transaction)
      final available = await isRangeAvailable(
        venueId: booking.venueId,
        date: booking.date,
        startTime: booking.startTime,
        endTime: booking.endTime,
        executor: txn,
      );
      if (!available) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: false,
          failureReason: 'Khung giờ không còn trống.',
        );
      }

      final resolvedPaymentId =
          booking.paymentId ?? 'pay_${DateTime.now().microsecondsSinceEpoch}';
      final isOnlinePayment = method != 'cash';

      // 3. Phân nhánh: Mô phỏng thanh toán trực tuyến thất bại
      if (isOnlinePayment && simulateFailure) {
        final failedTxn =
            transactionCode ??
            'TXN-FAILED-${DateTime.now().microsecondsSinceEpoch}';
        const failCancelReason = 'Thanh toán trực tuyến thất bại';
        final failCancelledAt = DateTime.now();

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
          'status': 'cancelled',
          'paymentStatus': 'unpaid',
          'paymentId': resolvedPaymentId,
          'promoId': booking.promoId,
          'promotionCode': booking.promotionCode,
          'note': booking.note,
          'cancelReason': failCancelReason,
          'cancelledAt': failCancelledAt.toIso8601String(),
          'createdAt': booking.createdAt.toIso8601String(),
        });

        final paymentRecord = <String, dynamic>{
          'id': resolvedPaymentId,
          'bookingId': booking.id,
          'method': method,
          'amount': booking.totalPrice,
          'status': 'failed',
          'transactionCode': failedTxn,
          'createdAt': DateTime.now().toIso8601String(),
        };
        await txn.insert('payments', paymentRecord);

        final notifId = 'notif_${DateTime.now().microsecondsSinceEpoch}';
        await txn.insert('app_notifications', {
          'id': notifId,
          'userId': booking.userId,
          'bookingId': booking.id,
          'title': 'Thanh toán thất bại',
          'content':
              'Thanh toán trực tuyến cho booking ${booking.id} không thành công. Booking đã được đóng.',
          'createdAt': DateTime.now().toIso8601String(),
          'type': AppNotificationType.paymentFailed.name,
          'isRead': 0,
        });

        afterCommit.add(() {
          booking.status = 'cancelled';
          booking.paymentStatus = 'unpaid';
          booking.paymentId = resolvedPaymentId;
          booking.cancelReason = failCancelReason;
          booking.cancelledAt = failCancelledAt;
          MockStore.bookings.add(booking);
          MockStore.payments.add({
            ...paymentRecord,
            'createdAt': DateTime.parse(paymentRecord['createdAt'] as String),
          });
        });

        return BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: true,
          failureReason: 'Giao dịch thanh toán trực tuyến không thành công.',
          booking: booking,
          payment: paymentRecord,
          transactionCode: failedTxn,
        );
      }

      // 4. Phân nhánh: Thành công
      const bookingStatus = 'confirmed';
      final bool isCash = method == 'cash';
      final String paymentStatusValue = isCash ? 'unpaid' : 'paid';
      final String? successTxn;
      final Map<String, dynamic> paymentRecord;

      if (method == 'cash') {
        successTxn = null;
        paymentRecord = <String, dynamic>{
          'id': resolvedPaymentId,
          'bookingId': booking.id,
          'method': method,
          'amount': booking.totalPrice,
          'status': 'pending',
          'transactionCode': null,
          'createdAt': DateTime.now().toIso8601String(),
        };
      } else {
        successTxn =
            transactionCode ?? 'TXN${Random().nextInt(900000) + 100000}';
        paymentRecord = <String, dynamic>{
          'id': resolvedPaymentId,
          'bookingId': booking.id,
          'method': method,
          'amount': booking.totalPrice,
          'status': 'success',
          'transactionCode': successTxn,
          'paidAt': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        };
      }

      // 4.1 Insert bookings
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
        'status': bookingStatus,
        'paymentStatus': paymentStatusValue,
        'paymentId': resolvedPaymentId,
        'promoId': booking.promoId,
        'promotionCode': booking.promotionCode,
        'note': booking.note,
        'cancelReason': null,
        'cancelledAt': null,
        'createdAt': booking.createdAt.toIso8601String(),
      });

      // 4.2 Insert booking_services
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
        });
      }

      // 4.3 Insert payments
      await txn.insert('payments', paymentRecord);

      // 4.4 Promotion Usage (nếu có)
      if (booking.promoId != null && booking.promoId!.isNotEmpty) {
        final usageId = 'pu_${DateTime.now().microsecondsSinceEpoch}';
        await txn.insert('promotion_usages', {
          'id': usageId,
          'promotionId': booking.promoId,
          'userId': booking.userId,
          'bookingId': booking.id,
          'isReversed': 0,
          'createdAt': DateTime.now().toIso8601String(),
        });
        await txn.rawUpdate(
          'UPDATE promotions SET usedCount = usedCount + 1 WHERE id = ?',
          [booking.promoId],
        );
      }

      // 5. Cập nhật Cache MockStore: chỉ chạy sau khi commit
      afterCommit.add(() {
        booking.status = bookingStatus;
        booking.paymentStatus = paymentStatusValue;
        booking.paymentId = resolvedPaymentId;
        MockStore.bookings.add(booking);
        MockStore.payments.add({
          ...paymentRecord,
          'createdAt': DateTime.parse(paymentRecord['createdAt'] as String),
          if (paymentRecord['paidAt'] != null)
            'paidAt': DateTime.parse(paymentRecord['paidAt'] as String),
        });
        if (booking.promoId != null) {
          final pIndex = MockStore.promotions.indexWhere(
            (p) => p.id == booking.promoId,
          );
          if (pIndex != -1) {
            final p = MockStore.promotions[pIndex];
            if (!p.usageHistory.any((u) => u.bookingId == booking.id)) {
              p.usageHistory.add(
                PromotionUsage(
                  promotionId: booking.promoId!,
                  userId: booking.userId,
                  bookingId: booking.id,
                ),
              );
              p.usedCount++;
            }
          }
        }
      });

      return BookingPaymentResult(
        isSuccess: true,
        isSlotAvailable: true,
        booking: booking,
        payment: paymentRecord,
        transactionCode: successTxn,
      );
    });
  }

  // --------------------------------------------------------------------------
  // 3. TRANSACTION HỦY ĐẶT SÂN VÀ HOÀN TIỀN
  // --------------------------------------------------------------------------
  static Future<bool> cancelBooking(
    String bookingId, {
    String cancelReason = 'Khách hàng chủ động hủy',
  }) async {
    final db = await _db;
    if (db == null) {
      return MockStore.cancelBooking(bookingId, cancelReason: cancelReason);
    }

    return _txn<bool>(db, (txn, afterCommit) async {
      final bookingRows = await txn.query(
        'bookings',
        where: 'id = ?',
        whereArgs: [bookingId],
        limit: 1,
      );
      if (bookingRows.isEmpty) return false;

      final bookingMap = bookingRows.single;
      final currentStatus = bookingMap['status'] as String;
      if (currentStatus != 'pending' && currentStatus != 'confirmed') {
        return false;
      }

      final isMarkedPaid = bookingMap['paymentStatus'] == 'paid';
      final paymentRows = await txn.query(
        'payments',
        where: 'bookingId = ?',
        whereArgs: [bookingId],
      );

      final successfulPayments = paymentRows
          .where((p) => p['status'] == 'success')
          .toList();

      if (!isMarkedPaid && successfulPayments.isNotEmpty) {
        return false;
      }

      Map<String, Object?>? targetPayment;
      if (isMarkedPaid) {
        final paymentId = bookingMap['paymentId'] as String?;
        if (paymentId != null) {
          final linked = paymentRows
              .where((p) => p['id'] == paymentId)
              .toList();
          if (linked.length != 1 ||
              linked.single['status'] != 'success' ||
              linked.single['refundStatus'] != null) {
            return false;
          }
          targetPayment = linked.single;
        } else {
          final valid = paymentRows
              .where(
                (p) => p['status'] == 'success' && p['refundStatus'] == null,
              )
              .toList();
          if (valid.length != 1) return false;
          targetPayment = valid.single;
        }
      }

      final shouldRefund = isMarkedPaid && targetPayment != null;
      final cancelledAt = DateTime.now();

      // Cập nhật booking
      await txn.update(
        'bookings',
        {
          'status': 'cancelled',
          'cancelReason': cancelReason,
          'cancelledAt': cancelledAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [bookingId],
      );

      // Cập nhật payment nếu có hoàn tiền
      double? refundAmount;
      if (shouldRefund) {
        refundAmount = (targetPayment['amount'] as num).toDouble();
        await txn.update(
          'payments',
          {
            'refundAmount': refundAmount,
            'refundStatus': 'processing',
            'refundMethod': null,
            'refundExpectedAt': null,
          },
          where: 'id = ?',
          whereArgs: [targetPayment['id']],
        );
      }

      // Tạo thông báo hủy booking
      final userId = bookingMap['userId'] as String;
      final notifCancelId =
          'notif_cancel_${DateTime.now().microsecondsSinceEpoch}';
      await txn.insert('app_notifications', {
        'id': notifCancelId,
        'userId': userId,
        'bookingId': bookingId,
        'title': 'Booking đã bị hủy',
        'content': 'Booking $bookingId đã được hủy.',
        'createdAt': cancelledAt.toIso8601String(),
        'type': AppNotificationType.bookingCancelled.name,
        'isRead': 0,
      });

      // Tạo thông báo hoàn tiền (nếu có)
      if (shouldRefund && refundAmount != null) {
        final notifRefundId =
            'notif_refund_${DateTime.now().microsecondsSinceEpoch}';
        await txn.insert('app_notifications', {
          'id': notifRefundId,
          'userId': userId,
          'bookingId': bookingId,
          'title': 'Yêu cầu hoàn tiền đang xử lý',
          'content':
              'Booking $bookingId: yêu cầu hoàn ${refundAmount.toStringAsFixed(0)} đ đang được xử lý.',
          'createdAt': cancelledAt.toIso8601String(),
          'type': AppNotificationType.refundProcessing.name,
          'refundAmount': refundAmount,
          'refundStatus': 'processing',
          'isRead': 0,
        });
      }

      // Rollback promotion usage nếu có
      final promoId = bookingMap['promoId'] as String?;
      if (promoId != null && promoId.isNotEmpty) {
        final usageRows = await txn.query(
          'promotion_usages',
          where:
              'promotionId = ? AND userId = ? AND bookingId = ? AND isReversed = 0',
          whereArgs: [promoId, userId, bookingId],
        );
        if (usageRows.isNotEmpty) {
          await txn.update(
            'promotion_usages',
            {'isReversed': 1},
            where: 'id = ?',
            whereArgs: [usageRows.first['id']],
          );
          await txn.rawUpdate(
            'UPDATE promotions SET usedCount = MAX(0, usedCount - 1) WHERE id = ?',
            [promoId],
          );
        }
      }

      afterCommit.add(() {
        MockStore.cancelBooking(bookingId, cancelReason: cancelReason);
      });
      return true;
    });
  }

  static Future<bool> completeRefund(String bookingId) async {
    final db = await _db;
    if (db == null) {
      return MockStore.completeRefund(bookingId);
    }
    return _txn<bool>(db, (txn, afterCommit) async {
      final bookingRows = await txn.query(
        'bookings',
        where: 'id = ?',
        whereArgs: [bookingId],
        limit: 1,
      );
      if (bookingRows.isEmpty) return false;
      final booking = bookingRows.single;
      if (booking['status'] != 'cancelled' ||
          booking['paymentStatus'] != 'paid') {
        return false;
      }

      final paymentRows = await txn.query(
        'payments',
        where: "bookingId = ? AND refundStatus = 'processing'",
        whereArgs: [bookingId],
      );
      if (paymentRows.length != 1) return false;
      final payment = paymentRows.single;

      final refundAmount = (payment['refundAmount'] as num).toDouble();
      if (refundAmount < 0) return false;

      await txn.update(
        'payments',
        {'status': 'refunded', 'refundStatus': 'succeeded'},
        where: 'id = ?',
        whereArgs: [payment['id']],
      );

      await txn.update(
        'bookings',
        {'paymentStatus': 'refunded'},
        where: 'id = ?',
        whereArgs: [bookingId],
      );

      final notifId = 'notif_ref_succ_${DateTime.now().microsecondsSinceEpoch}';
      await txn.insert('app_notifications', {
        'id': notifId,
        'userId': booking['userId'],
        'bookingId': bookingId,
        'title': 'Hoàn tiền thành công',
        'content':
            'Booking $bookingId: hoàn ${refundAmount.toStringAsFixed(0)} đ đã hoàn tất.',
        'createdAt': DateTime.now().toIso8601String(),
        'type': AppNotificationType.refundSucceeded.name,
        'refundAmount': refundAmount,
        'refundStatus': 'succeeded',
        'isRead': 0,
      });

      afterCommit.add(() => MockStore.completeRefund(bookingId));
      return true;
    });
  }

  static Future<bool> failRefund(String bookingId) async {
    final db = await _db;
    if (db == null) {
      return MockStore.failRefund(bookingId);
    }
    return _txn<bool>(db, (txn, afterCommit) async {
      final bookingRows = await txn.query(
        'bookings',
        where: 'id = ?',
        whereArgs: [bookingId],
        limit: 1,
      );
      if (bookingRows.isEmpty) return false;
      final booking = bookingRows.single;
      if (booking['status'] != 'cancelled' ||
          booking['paymentStatus'] != 'paid') {
        return false;
      }

      final paymentRows = await txn.query(
        'payments',
        where: "bookingId = ? AND refundStatus = 'processing'",
        whereArgs: [bookingId],
      );
      if (paymentRows.length != 1) return false;
      final payment = paymentRows.single;

      final refundAmount = (payment['refundAmount'] as num).toDouble();

      await txn.update(
        'payments',
        {'refundStatus': 'failed'},
        where: 'id = ?',
        whereArgs: [payment['id']],
      );

      final notifId = 'notif_ref_fail_${DateTime.now().microsecondsSinceEpoch}';
      await txn.insert('app_notifications', {
        'id': notifId,
        'userId': booking['userId'],
        'bookingId': bookingId,
        'title': 'Hoàn tiền thất bại',
        'content':
            'Booking $bookingId: hoàn ${refundAmount.toStringAsFixed(0)} đ không thành công.',
        'createdAt': DateTime.now().toIso8601String(),
        'type': AppNotificationType.refundFailed.name,
        'refundAmount': refundAmount,
        'refundStatus': 'failed',
        'isRead': 0,
      });

      afterCommit.add(() => MockStore.failRefund(bookingId));
      return true;
    });
  }

  // --------------------------------------------------------------------------
  // 3.1 CẬP NHẬT TRẠNG THÁI BOOKING DÀNH CHO OWNER (Xác nhận / Hoàn thành)
  // --------------------------------------------------------------------------
  static Future<bool> updateBookingStatusByOwner({
    required String bookingId,
    required String newStatus,
    required String ownerId,
  }) async {
    if (newStatus != 'confirmed' && newStatus != 'completed') {
      return false;
    }

    final db = await _db;
    if (db == null) {
      // Fallback về MockStore nếu SQLite chưa mở
      final idx = MockStore.bookings.indexWhere((b) => b.id == bookingId);
      if (idx == -1) return false;
      final current = MockStore.bookings[idx];
      final ownsVenue = MockStore.venues.any(
        (v) => v.id == current.venueId && v.ownerId == ownerId,
      );
      if (!ownsVenue) return false;
      if ((current.status == 'pending' && newStatus == 'confirmed') ||
          (current.status == 'confirmed' && newStatus == 'completed')) {
        current.status = newStatus;
        return true;
      }
      return false;
    }

    return _txn<bool>(db, (txn, afterCommit) async {
      final rows = await txn.rawQuery(
        'SELECT b.id, b.status, b.venueId, v.ownerId FROM bookings b JOIN venues v ON v.id = b.venueId WHERE b.id = ? LIMIT 1',
        [bookingId],
      );

      if (rows.isEmpty) return false;
      final bookingRow = rows.single;
      if (bookingRow['ownerId'] != ownerId) return false;

      final currentStatus = bookingRow['status'] as String;
      final isValidTransition =
          (currentStatus == 'pending' && newStatus == 'confirmed') ||
          (currentStatus == 'confirmed' && newStatus == 'completed');
      if (!isValidTransition) return false;

      await txn.update(
        'bookings',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [bookingId],
      );

      afterCommit.add(() {
        final mockIdx = MockStore.bookings.indexWhere((b) => b.id == bookingId);
        if (mockIdx != -1) {
          MockStore.bookings[mockIdx].status = newStatus;
        }
      });
      return true;
    });
  }

  // --------------------------------------------------------------------------
  // 3.2 QUẢN LÝ KHUYẾN MÃI DÀNH CHO ADMIN (Tạo, Sửa, Xóa/Vô hiệu hóa, Bật/Tắt)
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

  // --------------------------------------------------------------------------
  // 4. TRUY VẤN DỮ LIỆU
  // --------------------------------------------------------------------------
  static Future<List<Booking>> getBookingsForUser(String userId) async {
    final db = await _db;
    if (db == null) {
      return MockStore.customerBookings(userId);
    }
    final rows = await db.query(
      'bookings',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    if (rows.isEmpty) return const [];
    return _inflateBookings(db, rows);
  }

  static Future<Booking?> getBookingById(String bookingId) async {
    final db = await _db;
    if (db == null) {
      return MockStore.bookings.where((b) => b.id == bookingId).firstOrNull;
    }
    final rows = await db.query(
      'bookings',
      where: 'id = ?',
      whereArgs: [bookingId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final bookings = await _inflateBookings(db, rows);
    return bookings.firstOrNull;
  }

  static Future<List<Booking>> getBookingsForVenue(String venueId) async {
    final db = await _db;
    if (db == null) {
      return MockStore.bookings.where((b) => b.venueId == venueId).toList();
    }
    final rows = await db.query(
      'bookings',
      where: 'venueId = ?',
      whereArgs: [venueId],
      orderBy: 'date DESC, startTime ASC',
    );
    if (rows.isEmpty) return const [];
    return _inflateBookings(db, rows);
  }

  static Future<List<Booking>> getBookingsForOwner(String ownerId) async {
    final db = await _db;
    if (db == null) {
      final venues = MockStore.venues
          .where((v) => v.ownerId == ownerId)
          .map((v) => v.id)
          .toSet();
      return MockStore.bookings
          .where((b) => venues.contains(b.venueId))
          .toList();
    }
    final rows = await db.rawQuery(
      '''
      SELECT b.* FROM bookings b
      JOIN venues v ON v.id = b.venueId
      WHERE v.ownerId = ?
      ORDER BY b.date DESC, b.startTime ASC
    ''',
      [ownerId],
    );
    if (rows.isEmpty) return const [];
    return _inflateBookings(db, rows);
  }

  static Future<Payment?> getPaymentForBooking(String bookingId) async {
    final db = await _db;
    if (db == null) {
      final p = MockStore.paymentRecordForBooking(bookingId);
      return p != null ? Payment.fromMap(p) : null;
    }
    final rows = await db.query(
      'payments',
      where: 'bookingId = ?',
      whereArgs: [bookingId],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Payment.fromMap(rows.single);
  }

  // --------------------------------------------------------------------------
  // 5. THÔNG BÁO (APP NOTIFICATIONS)
  // --------------------------------------------------------------------------
  static Future<List<AppNotification>> getNotificationsForUser(
    String userId,
  ) async {
    final db = await _db;
    if (db == null) {
      return MockStore.notificationsFor(userId);
    }
    final rows = await db.query(
      'app_notifications',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return rows
        .map(
          (r) => AppNotification(
            id: r['id'] as String,
            userId: r['userId'] as String,
            bookingId: r['bookingId'] as String,
            title: r['title'] as String,
            content: r['content'] as String,
            createdAt: DateTime.parse(r['createdAt'] as String),
            type: AppNotificationType.values.byName(r['type'] as String),
            refundAmount: (r['refundAmount'] as num?)?.toDouble(),
            refundMethod: r['refundMethod'] as String?,
            refundExpectedAt: r['refundExpectedAt'] != null
                ? DateTime.parse(r['refundExpectedAt'] as String)
                : null,
            refundStatus: r['refundStatus'] as String?,
            isRead: (r['isRead'] as int? ?? 0) == 1,
          ),
        )
        .toList();
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    final db = await _db;
    if (db == null) {
      MockStore.markNotificationRead(notificationId);
      return;
    }
    final updated = await db.update(
      'app_notifications',
      {'isRead': 1},
      where: 'id = ? AND isRead = 0',
      whereArgs: [notificationId],
    );
    if (updated > 0) {
      // Đồng bộ trạng thái đã đọc và badge trong MockStore.
      MockStore.markNotificationRead(notificationId);
    }
  }

  static Future<void> markAllNotificationsAsRead(String userId) async {
    final db = await _db;
    if (db == null) {
      MockStore.markAllNotificationsRead(userId);
      return;
    }
    final updated = await db.update(
      'app_notifications',
      {'isRead': 1},
      where: 'userId = ? AND isRead = 0',
      whereArgs: [userId],
    );
    if (updated > 0) {
      // Đồng bộ danh sách trong cache và notificationRevision.
      MockStore.markAllNotificationsRead(userId);
    }
  }

  // --------------------------------------------------------------------------
  // 6. ĐỒNG BỘ CACHE VỀ MOCKSTORE (COMPATIBILITY LAYER)
  // --------------------------------------------------------------------------
  /// Đọc dữ liệu từ SQLite vào biến tạm trước; chỉ ghi vào MockStore khi thành công hoàn toàn.
  static Future<void> refreshCache() async {
    if (_useMockStoreForTesting) return;

    final db = await _db;
    if (db == null) {
      throw StateError(
        'SQLite chưa được khởi tạo, không thể khôi phục dữ liệu booking.',
      );
    }

    // 1. Đọc và mapping bookings kèm serviceItems
    final bookingRows = await db.query('bookings', orderBy: 'createdAt ASC');
    final inflatedBookings = await _inflateBookings(db, bookingRows);

    // 2. Đọc payments
    final paymentRows = await db.query('payments', orderBy: 'createdAt ASC');
    final mappedPayments = <Map<String, dynamic>>[];
    for (final row in paymentRows) {
      final createdAt = row['createdAt'] as String?;
      final paidAt = row['paidAt'] as String?;
      final refundExpectedAt = row['refundExpectedAt'] as String?;
      mappedPayments.add({
        'id': row['id'],
        'bookingId': row['bookingId'],
        'method': row['method'],
        'amount': (row['amount'] as num).toDouble(),
        'status': row['status'],
        'transactionCode': row['transactionCode'],
        'paidAt': paidAt != null ? DateTime.parse(paidAt) : null,
        'createdAt': createdAt != null
            ? DateTime.parse(createdAt)
            : DateTime.now(),
        'refundAmount': (row['refundAmount'] as num?)?.toDouble(),
        'refundMethod': row['refundMethod'],
        'refundStatus': row['refundStatus'],
        'refundExpectedAt': refundExpectedAt != null
            ? DateTime.parse(refundExpectedAt)
            : null,
      });
    }

    // 3. Đọc promotions kèm promotion_usages
    final promoRows = await db.query('promotions', orderBy: 'id ASC');
    final usageRows = await db.query(
      'promotion_usages',
      orderBy: 'createdAt ASC',
    );
    final usagesByPromo = <String, List<PromotionUsage>>{};
    for (final u in usageRows) {
      final pId = u['promotionId'] as String;
      (usagesByPromo[pId] ??= []).add(
        PromotionUsage(
          promotionId: pId,
          userId: u['userId'] as String,
          bookingId: u['bookingId'] as String,
          isReversed: (u['isReversed'] as int? ?? 0) == 1,
        ),
      );
    }
    final mappedPromotions = promoRows
        .map(
          (r) => Promotion(
            id: r['id'] as String,
            code: r['code'] as String,
            discountPercent: (r['discountPercent'] as num).toDouble(),
            expiryDate: DateTime.parse(r['expiryDate'] as String),
            isActive: (r['isActive'] as int? ?? 1) == 1,
            usedCount: r['usedCount'] as int? ?? 0,
            usageHistory: usagesByPromo[r['id']] ?? [],
          ),
        )
        .toList();

    // 4. Đọc app_notifications
    final notifRows = await db.query(
      'app_notifications',
      orderBy: 'createdAt DESC',
    );
    final mappedNotifs = notifRows
        .map(
          (r) => AppNotification(
            id: r['id'] as String,
            userId: r['userId'] as String,
            bookingId: r['bookingId'] as String,
            title: r['title'] as String,
            content: r['content'] as String,
            createdAt: DateTime.parse(r['createdAt'] as String),
            type: AppNotificationType.values.byName(r['type'] as String),
            refundAmount: (r['refundAmount'] as num?)?.toDouble(),
            refundMethod: r['refundMethod'] as String?,
            refundExpectedAt: r['refundExpectedAt'] != null
                ? DateTime.parse(r['refundExpectedAt'] as String)
                : null,
            refundStatus: r['refundStatus'] as String?,
            isRead: (r['isRead'] as int? ?? 0) == 1,
          ),
        )
        .toList();

    // 5. Cập nhật vào MockStore sau khi toàn bộ quá trình đọc & parse thành công
    MockStore.bookings
      ..clear()
      ..addAll(inflatedBookings);

    MockStore.payments
      ..clear()
      ..addAll(mappedPayments);

    MockStore.promotions
      ..clear()
      ..addAll(mappedPromotions);

    MockStore.notifications
      ..clear()
      ..addAll(mappedNotifs);
    MockStore.notificationRevision.value++;
  }

  // --------------------------------------------------------------------------
  // 7. HELPER HỖ TRỢ
  // --------------------------------------------------------------------------
  static Future<List<Booking>> _inflateBookings(
    DatabaseExecutor db,
    List<Map<String, Object?>> bookingRows,
  ) async {
    if (bookingRows.isEmpty) return const [];
    final bookingIds = bookingRows.map((r) => r['id'] as String).toList();
    final serviceRows = await db.query(
      'booking_services',
      where: 'bookingId IN (${List.filled(bookingIds.length, '?').join(',')})',
      whereArgs: bookingIds,
    );

    final servicesByBooking = <String, List<BookingServiceItem>>{};
    for (final row in serviceRows) {
      final bId = row['bookingId'] as String;
      (servicesByBooking[bId] ??= []).add(
        BookingServiceItem(
          serviceId: row['serviceId'] as String,
          serviceName: row['serviceName'] as String?,
          quantity: row['quantity'] as int,
          unitPrice: (row['unitPrice'] as num).toDouble(),
        ),
      );
    }

    return bookingRows.map((row) {
      final id = row['id'] as String;
      final cancelledAtStr = row['cancelledAt'] as String?;
      return Booking(
        id: id,
        venueId: row['venueId'] as String,
        userId: row['userId'] as String,
        date: DateTime.parse(row['date'] as String),
        startTime: row['startTime'] as String,
        endTime: row['endTime'] as String,
        totalPrice: (row['totalPrice'] as num).toDouble(),
        originalAmount: (row['originalAmount'] as num).toDouble(),
        serviceAmount: (row['serviceAmount'] as num).toDouble(),
        discountAmount: (row['discountAmount'] as num).toDouble(),
        status: row['status'] as String,
        paymentStatus: row['paymentStatus'] as String,
        paymentId: row['paymentId'] as String?,
        promoId: row['promoId'] as String?,
        promotionCode: row['promotionCode'] as String?,
        note: row['note'] as String?,
        cancelReason: row['cancelReason'] as String?,
        cancelledAt: cancelledAtStr != null
            ? DateTime.parse(cancelledAtStr)
            : null,
        createdAt: DateTime.parse(row['createdAt'] as String),
        serviceItems: servicesByBooking[id] ?? const [],
      );
    }).toList();
  }

  static int _toMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return -1;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return -1;
    return hour * 60 + minute;
  }

  static String _formatDateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
