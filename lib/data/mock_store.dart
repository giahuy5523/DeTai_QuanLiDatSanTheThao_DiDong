import '../models/booking.dart';
import '../models/promotion.dart';
import '../models/service.dart';
import '../models/user.dart';
import '../models/venue.dart';

class MockStore {
  MockStore._();
  static AppUser? currentUser;

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
        'imageUrl': 'https://picsum.photos/seed/venue$i-1/800/500',
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

  static Map<String, dynamic>? paymentOfBooking(String bookingId) {
    for (final p in payments) {
      if (p['bookingId'] == bookingId) return p;
    }
    return null;
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

  static bool confirmBooking(Booking booking, String method) {
    if (!booking.totalPrice.isFinite ||
        booking.totalPrice < 0 ||
        !['cash', 'momo', 'vnpay', 'bank_transfer'].contains(method) ||
        bookings.any((item) => item.id == booking.id)) {
      return false;
    }
    if (!isRangeAvailable(
      booking.venueId,
      booking.date,
      booking.startTime,
      booking.endTime,
    )) {
      return false;
    }
    booking.status = 'confirmed';
    booking.paymentStatus = 'paid';
    bookings.add(booking);
    payments.add({
      'id': booking.paymentId ?? 'pay_${DateTime.now().millisecondsSinceEpoch}',
      'bookingId': booking.id,
      'method': method,
      'amount': booking.totalPrice,
      'status': 'success',
      'transactionCode': null,
    });
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

  static void addUser(AppUser user) {
    if (emailExists(user.email)) throw ArgumentError('Email đã được sử dụng');
    users.add(user);
  }
}
