import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/promotion.dart';
import '../models/service.dart';
import '../models/user.dart';
import '../models/venue.dart';

/// Kết quả xử lý thanh toán và tạo đơn đặt sân.
/// Điểm tích hợp để sau này chuyển đổi sang SQLite Repository transaction.
class BookingPaymentResult {
  final bool isSuccess;
  final bool isSlotAvailable;
  final String? failureReason;
  final Booking? booking;
  final Map<String, dynamic>? payment;
  final String? transactionCode;

  const BookingPaymentResult({
    required this.isSuccess,
    required this.isSlotAvailable,
    this.failureReason,
    this.booking,
    this.payment,
    this.transactionCode,
  });
}

class MockStore {
  MockStore._();
  static AppUser? currentUser;
  static String? lastCancellationError;
  static final List<AppNotification> notifications = [];
  static final ValueNotifier<int> notificationRevision = ValueNotifier(0);
  static int _notificationSequence = 0;

  static List<AppNotification> notificationsFor(String userId) =>
      notifications.where((item) => item.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static int unreadNotificationCount(String userId) => notifications
      .where((item) => item.userId == userId && !item.isRead)
      .length;

  static bool markNotificationRead(String notificationId) {
    final notification = notifications
        .where((item) => item.id == notificationId)
        .firstOrNull;
    if (notification == null || notification.isRead) return false;
    notification.isRead = true;
    notificationRevision.value++;
    return true;
  }

  static void markAllNotificationsRead(String userId) {
    var changed = false;
    for (final notification in notifications) {
      if (notification.userId == userId && !notification.isRead) {
        notification.isRead = true;
        changed = true;
      }
    }
    if (changed) notificationRevision.value++;
  }

  static void _addNotification({
    required String userId,
    required String bookingId,
    required String title,
    required String content,
    required AppNotificationType type,
    double? refundAmount,
    String? refundMethod,
    DateTime? refundExpectedAt,
    String? refundStatus,
  }) {
    notifications.add(
      AppNotification(
        id: 'ntf_${DateTime.now().microsecondsSinceEpoch}_${_notificationSequence++}',
        userId: userId,
        bookingId: bookingId,
        title: title,
        content: content,
        createdAt: DateTime.now(),
        type: type,
        refundAmount: refundAmount,
        refundMethod: refundMethod,
        refundExpectedAt: refundExpectedAt,
        refundStatus: refundStatus,
      ),
    );
    notificationRevision.value++;
  }

  static AppUser? login(String email, String password) {
    final user = findUserByEmail(email);
    if (user == null || user.password != password) return null;
    currentUser = user;
    return user;
  }

  static void logout() => currentUser = null;

  // 1. Users
  static final List<AppUser> users = [
    AppUser(
      id: 'customer1',
      name: 'Nguyễn Văn Khách',
      email: 'customer@gmail.com',
      phone: '0900000001',
      password: '123456',
      role: 'customer',
    ),
    AppUser(
      id: 'customer2',
      name: 'Lê Thị Thu',
      email: 'thu.le@gmail.com',
      phone: '0900000004',
      password: '123456',
      role: 'customer',
    ),
    AppUser(
      id: 'owner1',
      name: 'Chủ sân demo 1',
      email: 'owner@gmail.com',
      phone: '0900000002',
      password: '123456',
      role: 'owner',
    ),
    AppUser(
      id: 'owner2',
      name: 'Chủ sân demo 2',
      email: 'owner2@gmail.com',
      phone: '0900000005',
      password: '123456',
      role: 'owner',
    ),
    AppUser(
      id: 'admin1',
      name: 'Quản trị viên',
      email: 'admin@gmail.com',
      phone: '0900000003',
      password: '123456',
      role: 'admin',
    ),
  ];

  // 2. SportTypes
  static final List<Map<String, dynamic>> sportTypes = [
    {'id': 1, 'name': 'Bóng đá', 'description': 'Sân cỏ nhân tạo 5-7 người'},
    {'id': 2, 'name': 'Cầu lông', 'description': 'Sân cầu lông trong nhà'},
    {'id': 3, 'name': 'Tennis', 'description': 'Sân tennis ngoài trời'},
    {'id': 4, 'name': 'Bóng rổ', 'description': 'Sân bóng rổ'},
    {'id': 5, 'name': 'Pickleball', 'description': 'Sân pickleball'},
  ];

  // Dùng cùng mã môn thể thao kiểu int như Venue và bộ lọc tìm kiếm.
  static int? sportTypeIdFor(String name) {
    for (final sport in sportTypes) {
      if (sport['name'] == name) return sport['id'] as int;
    }
    return null;
  }

  // 3. Venues
  static final List<Venue> venues = [
    Venue(
      id: 'v1',
      ownerId: 'owner1',
      sportTypeId: 1,
      sportType: 'Bóng đá',
      name: 'Sân bóng đá Thành Công',
      address: '12 Lý Thường Kiệt, Phường 14',
      district: 'Tân Bình',
      city: 'TP.HCM',
      pricePerHour: 300000,
      imageUrls: const [],
      latitude: 10.7975,
      longitude: 106.6520,
      status: 'approved',
      rating: 4.8,
    ),
    Venue(
      id: 'v2',
      ownerId: 'owner2',
      sportTypeId: 2,
      sportType: 'Cầu lông',
      name: 'Sân cầu lông Phú Nhuận',
      address: '45 Phan Xích Long, Phường 2',
      district: 'Phú Nhuận',
      city: 'TP.HCM',
      pricePerHour: 120000,
      imageUrls: const [],
      latitude: 10.7990,
      longitude: 106.6800,
      status: 'approved',
      rating: 4.5,
    ),
    Venue(
      id: 'v3',
      ownerId: 'owner1',
      sportTypeId: 3,
      sportType: 'Tennis',
      name: 'Sân tennis Nguyễn Thị Thập',
      address: '88 Nguyễn Thị Thập, Tân Hưng',
      district: 'Quận 7',
      city: 'TP.HCM',
      pricePerHour: 250000,
      imageUrls: const [],
      latitude: 10.7320,
      longitude: 106.7210,
      status: 'approved',
      rating: 4.2,
    ),
    Venue(
      id: 'v4',
      ownerId: 'owner2',
      sportTypeId: 1,
      sportType: 'Bóng đá',
      name: 'Sân bóng đá Thảo Điền',
      address: '12 Quốc Hương, Thảo Điền',
      district: 'Quận 2',
      city: 'TP.HCM',
      pricePerHour: 450000,
      imageUrls: const [],
      latitude: 10.8050,
      longitude: 106.7320,
      status: 'approved',
      rating: 4.9,
    ),
    Venue(
      id: 'v5',
      ownerId: 'owner1',
      sportTypeId: 4,
      sportType: 'Bóng rổ',
      name: 'Clb Bóng rổ Phan Đình Phùng',
      address: '8 Võ Văn Tần, Phường 6',
      district: 'Quận 3',
      city: 'TP.HCM',
      pricePerHour: 200000,
      imageUrls: const [],
      latitude: 10.7780,
      longitude: 106.6900,
      status: 'approved',
      rating: 4.3,
    ),
    Venue(
      id: 'v6',
      ownerId: 'owner2',
      sportTypeId: 5,
      sportType: 'Pickleball',
      name: 'Pickleball Club Bình Thạnh',
      address: '207 Đinh Bộ Lĩnh, Phường 26',
      district: 'Bình Thạnh',
      city: 'TP.HCM',
      pricePerHour: 180000,
      imageUrls: const [],
      latitude: 10.8080,
      longitude: 106.7110,
      status: 'approved',
      rating: 4.7,
    ),
    Venue(
      id: 'v7',
      ownerId: 'owner1',
      sportTypeId: 2,
      sportType: 'Cầu lông',
      name: 'Sân cầu lông Viettel',
      address: '158 Hoàng Hoa Thám, Phường 12',
      district: 'Tân Bình',
      city: 'TP.HCM',
      pricePerHour: 110000,
      imageUrls: const [],
      latitude: 10.8010,
      longitude: 106.6480,
      status: 'approved',
      rating: 4.0,
    ),
    Venue(
      id: 'v8',
      ownerId: 'owner2',
      sportTypeId: 1,
      sportType: 'Bóng đá',
      name: 'Sân bóng đá Chảo Lửa',
      address: '30 Phan Thúc Duyện, Phường 4',
      district: 'Tân Bình',
      city: 'TP.HCM',
      pricePerHour: 350000,
      imageUrls: const [],
      latitude: 10.8000,
      longitude: 106.6580,
      status: 'pending',
      rating: 0.0,
    ),
  ];

  static List<Venue> get approvedVenues =>
      venues.where((v) => v.status == 'approved').toList();

  static List<String> get districts {
    final set = <String>{};
    for (final v in approvedVenues) {
      final district = v.district;
      if (district != null && district.isNotEmpty) {
        set.add(district);
      }
    }
    return set.toList()..sort();
  }

  // VenueImages
  static final List<Map<String, dynamic>> venueImages = [
    for (var i = 1; i <= 8; i++) ...[
      {
        'id': 'img${i}a',
        'venueId': 'v$i',
        'imageUrl': [
          'assets/sports_dataset/football/football_001.jpg',
          'assets/sports_dataset/badminton/badminton_001.jpg',
          'assets/sports_dataset/tennis/tennis_001.jpg',
          'assets/sports_dataset/football/football_002.jpg',
          'assets/sports_dataset/basketball/basketball_001.jpg',
          'assets/sports_dataset/pickleball/pickleball_001.jpg',
          'assets/sports_dataset/badminton/badminton_002.jpg',
          'assets/sports_dataset/football/football_003.jpg',
        ][i - 1],
        'isPrimary': true,
        'sortOrder': 1,
      },
    ],
  ];

  static List<String> imageUrlsOf(String venueId) {
    final rows = venueImages.where((e) => e['venueId'] == venueId).toList()
      ..sort(
        (a, b) => (a['sortOrder'] as int).compareTo(b['sortOrder'] as int),
      );
    return rows.map((e) => e['imageUrl'] as String).toList();
  }

  static void setVenueImages(String venueId, List<String> urls) {
  venueImages.removeWhere((e) => e['venueId'] == venueId);
  for (var i = 0; i < urls.length; i++) {
    venueImages.add({
      'id': 'img_${venueId}_$i',
      'venueId': venueId,
      'imageUrl': urls[i],
      'isPrimary': i == 0,
      'sortOrder': i + 1,
      });
    }
  }

  static const Map<String, List<int>> openHours = {
    'v1': [6, 22],
    'v2': [6, 22],
    'v3': [6, 21],
    'v4': [6, 22],
    'v5': [7, 21],
    'v6': [6, 22],
    'v7': [6, 22],
    'v8': [6, 22],
  };

  static List<int> hoursOf(String venueId) =>
      openHours[venueId] ?? const [6, 22];

  static final List<Promotion> promotions = Promotion.mockList();

  static final Map<String, List<VenueService>> servicesByVenue = {
    'v1': [
      VenueService(
        id: 's1',
        venueId: 'v1',
        name: 'Thuê áo bib (bộ 10 cái)',
        price: 30000,
        unit: 'bộ',
      ),
      VenueService(
        id: 's2',
        venueId: 'v1',
        name: 'Nước suối chai 500ml',
        price: 10000,
        unit: 'chai',
      ),
    ],
    'v2': [
      VenueService(
        id: 's4',
        venueId: 'v2',
        name: 'Thuê vợt cầu lông',
        price: 30000,
        unit: 'cây/giờ',
      ),
    ],
  };

  // 6. Bookings
  static final List<Booking> bookings = [
    Booking(
      id: 'b1',
      venueId: 'v1',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 1)),
      startTime: '18:00',
      endTime: '19:00',
      totalPrice: 330000,
      status: 'confirmed',
      paymentStatus: 'paid',
      paymentId: 'pay1',
      selectedServiceIds: const ['s1'],
    ),
    Booking(
      id: 'b2',
      venueId: 'v2',
      userId: 'customer1',
      date: DateTime.now().subtract(const Duration(days: 3)),
      startTime: '08:00',
      endTime: '09:00',
      totalPrice: 120000,
      status: 'completed',
      paymentStatus: 'paid',
      paymentId: 'pay2',
    ),
  ];

  // 7. Payments
  static final List<Map<String, dynamic>> payments = [
    {
      'id': 'pay1',
      'bookingId': 'b1',
      'method': 'momo',
      'amount': 330000,
      'status': 'success',
      'transactionCode': 'TXN1001',
    },
    {
      'id': 'pay2',
      'bookingId': 'b2',
      'method': 'cash',
      'amount': 120000,
      'status': 'success',
      'transactionCode': null,
    },
  ];

  // Giữ lịch sử các lần thanh toán trong MockStore.
  static List<Map<String, dynamic>> paymentsOfBooking(String bookingId) =>
      payments.where((payment) => payment['bookingId'] == bookingId).toList();

  // Ưu tiên lần thanh toán thành công gần nhất cho luồng hủy/hoàn tiền.
  // Booking.paymentId là tham chiếu tùy chọn đến giao dịch hiện tại.
  static Map<String, dynamic>? paymentOfBooking(String bookingId) {
    final matches = paymentsOfBooking(bookingId);
    if (matches.isEmpty) return null;
    for (final payment in matches.reversed) {
      if (payment['status'] == 'success' || payment['status'] == 'refunded') {
        return payment;
      }
    }
    return matches.last;
  }

  static Map<String, dynamic>? paymentRecordForBooking(String bookingId) {
    final booking = bookings.where((item) => item.id == bookingId).firstOrNull;
    if (booking == null) return null;
    if (booking.paymentId != null) {
      final linked = payments
          .where(
            (payment) =>
                payment['id'] == booking.paymentId &&
                payment['bookingId'] == bookingId,
          )
          .firstOrNull;
      return linked;
    }
    return paymentOfBooking(bookingId);
  }

  static List<Map<String, dynamic>> timeSlotsFor(
    String venueId,
    DateTime date,
  ) {
    final venue = venueById(venueId);
    if (venue == null) return const [];
    final hours = hoursOf(venueId);
    final now = DateTime.now();
    final isToday = _sameDay(date, now);
    final nowMinutes = now.hour * 60 + now.minute;
    final dayBookings = bookings
        .where(
          (b) =>
              b.venueId == venueId &&
              b.status != 'cancelled' &&
              _sameDay(b.date, date),
        )
        .toList();

    final slots = <Map<String, dynamic>>[];
    for (var h = hours[0]; h < hours[1]; h++) {
      final from = h * 60;
      final to = from + 60;
      final booked = dayBookings.any(
        (b) => _toMinutes(b.startTime) < to && _toMinutes(b.endTime) > from,
      );
      final past = isToday && from <= nowMinutes;
      slots.add({
        'venueId': venueId,
        'date': date,
        'startTime': hourLabel(h),
        'endTime': hourLabel(h + 1),
        'price': venue.pricePerHour,
        'status': booked ? 'booked' : (past ? 'blocked' : 'available'),
      });
    }
    return slots;
  }

  static String hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static int _toMinutes(String hhmm) {
    final parts = hhmm.trim().split(':');
    if (parts.length != 2) return -1;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return -1;
    }

    return hour * 60 + minute;
  }

  static Venue? venueById(String id) {
    for (final venue in venues) {
      if (venue.id == id) return venue;
    }
    return null;
  }

  static List<VenueService> servicesFor(String venueId) {
    return List<VenueService>.from(servicesByVenue[venueId] ?? const []);
  }

  static List<Booking> customerBookings(String userId) {
    return bookings.where((b) => b.userId == userId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static void addBooking(Booking booking) {
    bookings.add(booking);
  }

  static bool updateVenue(Venue venue) {
    final index = venues.indexWhere((item) => item.id == venue.id);
    if (index < 0) return false;
    venues[index] = venue;
    return true;
  }

  static void addVenue(Venue venue) {
    venues.add(venue);
    servicesByVenue[venue.id] = [];
  }

  static bool isRangeAvailable(
    String venueId,
    DateTime date,
    String start,
    String end,
  ) {
    final venue = venueById(venueId);
    if (venue == null || venue.status != 'approved') return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(date.year, date.month, date.day);

    if (bookingDay.isBefore(today)) {
      return false;
    }

    final from = _toMinutes(start.trim());
    final to = _toMinutes(end.trim());
    final hours = hoursOf(venueId);
    if (from < 0 || to < 0) {
      return false;
    }

    // Kiểm tra nằm trong khung giờ mở cửa của sân
    if (to <= from || from < hours[0] * 60 || to > hours[1] * 60) {
      return false;
    }

    // Nếu chọn hôm nay thì giờ bắt đầu không được trong quá khứ
    if (_sameDay(date, now)) {
      final nowMinutes = now.hour * 60 + now.minute;
      if (from <= nowMinutes) {
        return false;
      }
    }

    // Kiểm tra trùng lịch với các booking đã confirmed hoặc pending
    return !bookings.any(
      (booking) =>
          booking.venueId == venueId &&
          booking.status != 'cancelled' &&
          _sameDay(booking.date, date) &&
          from < _toMinutes(booking.endTime.trim()) &&
          to > _toMinutes(booking.startTime.trim()),
    );
  }

  /// Xử lý tạo booking và payment thống nhất theo đúng quy ước nghiệp vụ.
  /// Điểm tích hợp tập trung để sau này thay bằng SQLite Repository transaction.
  static BookingPaymentResult processBookingPayment({
    required Booking booking,
    required String method,
    bool simulateFailure = false,
    String? transactionCode,
  }) {
    // 1. Kiểm tra tính hợp lệ cơ bản của đơn và phương thức
    if (!booking.totalPrice.isFinite ||
        booking.totalPrice < 0 ||
        !['cash', 'momo', 'vnpay', 'bank_transfer'].contains(method) ||
        bookings.any((item) => item.id == booking.id)) {
      return const BookingPaymentResult(
        isSuccess: false,
        isSlotAvailable: false,
        failureReason: 'Thông tin đơn đặt sân hoặc phương thức không hợp lệ.',
      );
    }

    final venue = venueById(booking.venueId);
    final from = _toMinutes(booking.startTime.trim());
    final to = _toMinutes(booking.endTime.trim());
    final paymentId = booking.paymentId;
    if (venue == null ||
        venue.status != 'approved' ||
        !venue.pricePerHour.isFinite ||
        venue.pricePerHour < 0 ||
        !users.any(
          (user) => user.id == booking.userId && user.role == 'customer',
        ) ||
        from < 0 ||
        to <= from ||
        (booking.originalAmount - venue.pricePerHour * ((to - from) / 60))
                .abs() >
            0.01 ||
        (paymentId != null &&
            payments.any((payment) => payment['id'] == paymentId))) {
      return const BookingPaymentResult(
        isSuccess: false,
        isSlotAvailable: false,
        failureReason:
            'Thông tin sân, khung giờ hoặc mã thanh toán không hợp lệ.',
      );
    }

    // 2. Kiểm tra mã khuyến mãi trước khi ghi nhận booking/payment.
    final normalizedPromoCode = booking.promotionCode?.trim().toUpperCase();
    final hasPromoCode =
        normalizedPromoCode != null && normalizedPromoCode.isNotEmpty;
    final hasPromoId = booking.promoId != null && booking.promoId!.isNotEmpty;

    final amountsAreValid =
        booking.originalAmount.isFinite &&
        booking.originalAmount >= 0 &&
        booking.serviceAmount.isFinite &&
        booking.serviceAmount >= 0 &&
        booking.discountAmount.isFinite &&
        booking.discountAmount >= 0 &&
        booking.totalPrice.isFinite &&
        booking.totalPrice >= 0;

    final subtotal = booking.originalAmount + booking.serviceAmount;

    if (!amountsAreValid || !subtotal.isFinite) {
      return const BookingPaymentResult(
        isSuccess: false,
        isSlotAvailable: true,
        failureReason: 'Số tiền đặt sân không hợp lệ.',
      );
    }

    final selectedServiceIds = booking.selectedServiceIds;
    final availableServices = servicesFor(booking.venueId);
    final serviceItems = booking.serviceItems;
    final itemIds = serviceItems.map((item) => item.serviceId).toList();
    final calculatedServiceAmount = serviceItems.fold<double>(0, (sum, item) {
      final service = availableServices
          .where((candidate) => candidate.id == item.serviceId)
          .firstOrNull;
      if (service == null ||
          item.quantity <= 0 ||
          !item.unitPrice.isFinite ||
          item.unitPrice < 0 ||
          (item.unitPrice - service.price).abs() > 0.01 ||
          !item.subtotal.isFinite) {
        return double.nan;
      }
      return sum + item.subtotal;
    });
    if (selectedServiceIds.toSet().length != selectedServiceIds.length ||
        itemIds.toSet().length != itemIds.length ||
        selectedServiceIds.toSet().difference(itemIds.toSet()).isNotEmpty ||
        itemIds.toSet().difference(selectedServiceIds.toSet()).isNotEmpty ||
        !calculatedServiceAmount.isFinite ||
        (booking.serviceAmount - calculatedServiceAmount).abs() > 0.01) {
      return const BookingPaymentResult(
        isSuccess: false,
        isSlotAvailable: true,
        failureReason: 'Thông tin dịch vụ hoặc số tiền dịch vụ không hợp lệ.',
      );
    }

    if (hasPromoCode) {
      final promotion = promotions
          .where((p) => p.code.trim().toUpperCase() == normalizedPromoCode)
          .firstOrNull;

      if (promotion == null || !promotion.isValidAt(DateTime.now())) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: true,
          failureReason: 'Mã khuyến mãi không hợp lệ hoặc đã hết hạn.',
        );
      }

      final expectedDiscount = subtotal * promotion.discountPercent / 100;
      final expectedTotal = subtotal - expectedDiscount;

      if (!expectedDiscount.isFinite ||
          !expectedTotal.isFinite ||
          expectedDiscount < 0 ||
          expectedTotal < 0 ||
          booking.promoId != promotion.id ||
          (booking.discountAmount - expectedDiscount).abs() > 0.01 ||
          (booking.totalPrice - expectedTotal).abs() > 0.01) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: true,
          failureReason: 'Thông tin giảm giá không khớp với mã khuyến mãi.',
        );
      }

      final activeUses = promotion.usageHistory.where(
        (usage) => !usage.isReversed,
      );
      if (promotion.usedCount >= promotion.usageLimit ||
          activeUses.where((usage) => usage.userId == booking.userId).length >=
              promotion.perUserLimit ||
          promotion.usageHistory.any(
            (usage) => usage.bookingId == booking.id,
          )) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: true,
          failureReason: 'Mã khuyến mãi đã hết lượt sử dụng.',
        );
      }
    } else {
      if (hasPromoId ||
          booking.discountAmount > 0.01 ||
          (booking.totalPrice - subtotal).abs() > 0.01) {
        return const BookingPaymentResult(
          isSuccess: false,
          isSlotAvailable: true,
          failureReason: 'Thông tin đơn đặt sân hoặc khuyến mãi không hợp lệ.',
        );
      }
    }
    // 3. Kiểm tra lại tính khả dụng của khung giờ ngay trước khi ghi nhận
    if (!isRangeAvailable(
      booking.venueId,
      booking.date,
      booking.startTime,
      booking.endTime,
    )) {
      return const BookingPaymentResult(
        isSuccess: false,
        isSlotAvailable: false,
        failureReason: 'Khung giờ không còn trống.',
      );
    }

    final resolvedPaymentId =
        paymentId ?? 'pay_${DateTime.now().microsecondsSinceEpoch}';
    booking.paymentId = resolvedPaymentId;

    final isOnlinePayment = method != 'cash';

    // 3. Phân nhánh: Mô phỏng thanh toán trực tuyến thất bại
    if (isOnlinePayment && simulateFailure) {
      final failedTxn =
          transactionCode ??
          'TXN-FAILED-${DateTime.now().microsecondsSinceEpoch}';
      booking.status = 'cancelled';
      booking.paymentStatus = 'unpaid';
      booking.cancelReason = 'Thanh toán trực tuyến thất bại';
      booking.cancelledAt = DateTime.now();

      final paymentRecord = <String, dynamic>{
        'id': resolvedPaymentId,
        'bookingId': booking.id,
        'method': method,
        'amount': booking.totalPrice,
        'status': 'failed',
        'transactionCode': failedTxn,
        'createdAt': DateTime.now(),
      };

      bookings.add(booking);
      payments.add(paymentRecord);
      _addNotification(
        userId: booking.userId,
        bookingId: booking.id,
        title: 'Thanh toán thất bại',
        content:
            'Thanh toán trực tuyến cho booking ${booking.id} không thành công. Booking đã được đóng.',
        type: AppNotificationType.paymentFailed,
      );

      return BookingPaymentResult(
        isSuccess: false,
        isSlotAvailable: true,
        failureReason: 'Giao dịch thanh toán trực tuyến không thành công.',
        booking: booking,
        payment: paymentRecord,
        transactionCode: failedTxn,
      );
    }

    // 4. Phân nhánh: Thanh toán thành công (Tiền mặt hoặc Trực tuyến)
    booking.status = 'confirmed';
    final String? successTxn;
    final Map<String, dynamic> paymentRecord;

    if (method == 'cash') {
      // Tiền mặt tại sân: booking confirmed, paymentStatus unpaid, payment pending
      successTxn = null;
      booking.paymentStatus = 'unpaid';
      paymentRecord = <String, dynamic>{
        'id': resolvedPaymentId,
        'bookingId': booking.id,
        'method': method,
        'amount': booking.totalPrice,
        'status': 'pending',
        'transactionCode': null,
        'createdAt': DateTime.now(),
      };
    } else {
      // Trực tuyến thành công: booking confirmed, paymentStatus paid, payment success
      successTxn = transactionCode ?? 'TXN${Random().nextInt(900000) + 100000}';
      booking.paymentStatus = 'paid';
      paymentRecord = <String, dynamic>{
        'id': resolvedPaymentId,
        'bookingId': booking.id,
        'method': method,
        'amount': booking.totalPrice,
        'status': 'success',
        'transactionCode': successTxn,
        'paidAt': DateTime.now(),
        'createdAt': DateTime.now(),
      };
    }

    bookings.add(booking);
    payments.add(paymentRecord);

    // 5. Ghi nhận lượt promotion một lần duy nhất sau booking/payment thành công.
    final promoId = booking.promoId;
    if (promoId != null && promoId.isNotEmpty) {
      final promoIndex = promotions.indexWhere((p) => p.id == promoId);
      if (promoIndex != -1) {
        final promotion = promotions[promoIndex];
        if (!promotion.usageHistory.any(
          (usage) => usage.bookingId == booking.id,
        )) {
          promotion.usageHistory.add(
            PromotionUsage(
              promotionId: promoId,
              userId: booking.userId,
              bookingId: booking.id,
            ),
          );
          promotion.usedCount++;
        }
      }
    }

    return BookingPaymentResult(
      isSuccess: true,
      isSlotAvailable: true,
      booking: booking,
      payment: paymentRecord,
      transactionCode: successTxn,
    );
  }

  /// Wrapper tương thích ngược cho confirmBooking
  static bool confirmBooking(
    Booking booking,
    String method, {
    bool simulateFailure = false,
    String? transactionCode,
  }) {
    final result = processBookingPayment(
      booking: booking,
      method: method,
      simulateFailure: simulateFailure,
      transactionCode: transactionCode,
    );
    return result.isSuccess;
  }

  /// Hủy đơn đặt sân và hoàn tiền mô phỏng tập trung tại MockStore.
  /// Điểm tích hợp để sau này chuyển đổi sang SQLite Repository transaction.
  static bool cancelBooking(
    String bookingId, {
    String cancelReason = 'Khách hàng chủ động hủy',
  }) {
    lastCancellationError = null;
    final bookingIndex = bookings.indexWhere((b) => b.id == bookingId);
    if (bookingIndex == -1) return false;

    final booking = bookings[bookingIndex];
    if (booking.status != 'pending' && booking.status != 'confirmed') {
      return false;
    }

    final bookingPayments = paymentsOfBooking(bookingId);
    final successfulPayments = bookingPayments
        .where((payment) => payment['status'] == 'success')
        .toList();
    final isMarkedPaid = booking.paymentStatus == 'paid';

    // Reject inconsistent data before changing any booking/payment/promo state.
    if (!isMarkedPaid && successfulPayments.isNotEmpty) {
      lastCancellationError = 'Dữ liệu thanh toán không nhất quán.';
      return false;
    }

    Map<String, dynamic>? payment;
    if (isMarkedPaid) {
      if (booking.paymentId != null) {
        final linkedPayments = bookingPayments
            .where((item) => item['id'] == booking.paymentId)
            .toList();
        if (linkedPayments.length != 1 ||
            !_isValidSuccessfulPayment(booking, linkedPayments.single) ||
            linkedPayments.single['refundStatus'] != null) {
          lastCancellationError =
              'Payment được liên kết không hợp lệ cho booking.';
          return false;
        }
        payment = linkedPayments.single;
      } else {
        final validPayments = bookingPayments
            .where(
              (item) =>
                  _isValidSuccessfulPayment(booking, item) &&
                  item['refundStatus'] == null,
            )
            .toList();
        if (validPayments.isEmpty) {
          lastCancellationError =
              'Không tìm thấy payment thành công hợp lệ cho booking.';
          return false;
        }
        if (validPayments.length > 1) {
          lastCancellationError =
              'Có nhiều payment thành công hợp lệ cho booking.';
          return false;
        }
        payment = validPayments.single;
      }
    } else if (successfulPayments.isNotEmpty) {
      lastCancellationError = 'Dữ liệu thanh toán không nhất quán.';
      return false;
    } else if (booking.paymentId != null) {
      payment = bookingPayments
          .where((item) => item['id'] == booking.paymentId)
          .firstOrNull;
    }

    final shouldRefund = isMarkedPaid;

    if (shouldRefund) {
      final refundAmount = (payment!['amount'] as num).toDouble();
      payment['refundAmount'] = refundAmount;
      payment['refundStatus'] = 'processing';
      payment['refundMethod'] = null;
      payment['refundExpectedAt'] = null;
    }

    booking.status = 'cancelled';
    booking.cancelReason = cancelReason;
    booking.cancelledAt = DateTime.now();

    _addNotification(
      userId: booking.userId,
      bookingId: booking.id,
      title: 'Booking đã bị hủy',
      content: 'Booking ${booking.id} đã được hủy.',
      type: AppNotificationType.bookingCancelled,
    );
    if (shouldRefund) {
      final refundAmount = (payment!['refundAmount'] as num).toDouble();
      _addNotification(
        userId: booking.userId,
        bookingId: booking.id,
        title: 'Yêu cầu hoàn tiền đang xử lý',
        content:
            'Booking ${booking.id}: yêu cầu hoàn ${refundAmount.toStringAsFixed(0)} đ đang được xử lý. Phương thức nhận tiền và thời gian dự kiến chưa được xác định.',
        type: AppNotificationType.refundProcessing,
        refundAmount: refundAmount,
        refundMethod: null,
        refundExpectedAt: null,
        refundStatus: 'processing',
      );
    }

    // Hoàn đúng usage record đã ghi nhận; giữ lịch sử và đánh dấu đã hoàn.
    final promoId = booking.promoId;
    if (promoId != null && promoId.isNotEmpty) {
      final promoIndex = promotions.indexWhere((p) => p.id == promoId);
      if (promoIndex != -1) {
        final promotion = promotions[promoIndex];
        final usage = promotion.usageHistory
            .where(
              (item) =>
                  item.promotionId == promoId &&
                  item.userId == booking.userId &&
                  item.bookingId == booking.id &&
                  !item.isReversed,
            )
            .firstOrNull;
        if (usage != null) {
          usage.isReversed = true;
          if (promotion.usedCount > 0) promotion.usedCount--;
        }
      }
    }

    return true;
  }

  static bool completeRefund(String bookingId) =>
      _resolveRefund(bookingId, succeeded: true);

  static bool failRefund(String bookingId) =>
      _resolveRefund(bookingId, succeeded: false);

  static bool _isValidSuccessfulPayment(
    Booking booking,
    Map<String, dynamic> payment,
  ) {
    final paymentId = payment['id'];
    final amount = payment['amount'];
    return paymentId is String &&
        paymentId.isNotEmpty &&
        payment['bookingId'] == booking.id &&
        payment['status'] == 'success' &&
        amount is num &&
        amount.toDouble().isFinite &&
        amount.toDouble() >= 0 &&
        amount.toDouble() == booking.totalPrice;
  }

  static bool _resolveRefund(String bookingId, {required bool succeeded}) {
    final booking = bookings.where((item) => item.id == bookingId).firstOrNull;
    if (booking == null ||
        booking.status != 'cancelled' ||
        booking.paymentStatus != 'paid') {
      return false;
    }

    final refundCandidates = payments
        .where(
          (item) =>
              item['bookingId'] == bookingId &&
              item['refundStatus'] == 'processing' &&
              (booking.paymentId == null || item['id'] == booking.paymentId),
        )
        .toList();
    if (refundCandidates.length != 1) {
      lastCancellationError = booking.paymentId == null
          ? 'Không xác định được duy nhất payment đang hoàn cho booking.'
          : 'Không tìm thấy duy nhất payment được liên kết đang hoàn.';
      return false;
    }

    final payment = refundCandidates.single;
    if (!_isValidSuccessfulPayment(booking, payment) ||
        payment['status'] != 'success' ||
        payment['refundStatus'] != 'processing' ||
        payment['refundAmount'] is! num ||
        !(payment['refundAmount'] as num).toDouble().isFinite ||
        (payment['refundAmount'] as num).toDouble() !=
            (payment['amount'] as num).toDouble()) {
      lastCancellationError = 'Payment đang hoàn không hợp lệ cho booking.';
      return false;
    }

    final refundAmount = (payment['refundAmount'] as num).toDouble();
    if (refundAmount < 0) return false;

    if (succeeded) {
      payment['status'] = 'refunded';
      payment['refundStatus'] = 'succeeded';
      booking.paymentStatus = 'refunded';
    } else {
      payment['refundStatus'] = 'failed';
    }

    final status = succeeded ? 'succeeded' : 'failed';
    _addNotification(
      userId: booking.userId,
      bookingId: booking.id,
      title: succeeded ? 'Hoàn tiền thành công' : 'Hoàn tiền thất bại',
      content:
          'Booking ${booking.id}: hoàn ${refundAmount.toStringAsFixed(0)} đ ${succeeded ? 'đã hoàn tất' : 'không thành công'}.',
      type: succeeded
          ? AppNotificationType.refundSucceeded
          : AppNotificationType.refundFailed,
      refundAmount: refundAmount,
      refundStatus: status,
    );
    return true;
  }

  static AppUser? findUserByEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    for (final user in users) {
      if (user.email.toLowerCase() == normalizedEmail) return user;
    }
    return null;
  }

  static bool emailExists(String email) => findUserByEmail(email) != null;

  /// In-memory adapter for isolated widget tests; runtime uses AccountService.
  static AppUser? updateCurrentProfile({
    required String userId,
    required String name,
    required String phone,
    required String? avatarPath,
  }) {
    final user = currentUser;
    if (user == null || user.id != userId) return null;
    final index = users.indexWhere((entry) => entry.id == userId);
    if (index < 0) return null;
    final updated = AppUser(
      id: user.id,
      name: name.trim(),
      email: user.email,
      phone: phone.trim(),
      password: user.password,
      role: user.role,
      avatarPath: avatarPath,
    );
    users[index] = updated;
    currentUser = updated;
    return updated;
  }

  static void addUser(AppUser user) {
    if (emailExists(user.email)) throw ArgumentError('Email đã được sử dụng');
    users.add(user);
  }
}
