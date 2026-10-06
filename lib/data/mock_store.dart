import '../models/booking.dart';
import '../models/promotion.dart';
import '../models/service.dart';
import '../models/venue.dart';
import '../models/user.dart';

/// Kho dữ liệu tạm thời dùng cho giai đoạn giao diện/mô phỏng.
/// Sau này có thể thay lớp này bằng Firebase/SQLite mà không phải đổi toàn bộ UI.
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
      id: 'owner1',
      name: 'Chủ sân demo',
      email: 'owner@gmail.com',
      phone: '0900000002',
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
  static final List<Venue> venues = Venue.mockList();
  static final List<Promotion> promotions = Promotion.mockList();

  static final Map<String, List<VenueService>> servicesByVenue = {
    for (final venue in venues) venue.id: VenueService.mockListFor(venue.id),
  };

  static final List<Booking> bookings = [
    Booking(
      id: 'b1',
      venueId: 'v1',
      userId: 'customer1',
      date: DateTime.now().add(const Duration(days: 1)),
      startTime: '18:00',
      endTime: '19:00',
      totalPrice: 310000,
      status: 'confirmed',
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
      paymentId: 'pay2',
    ),
  ];

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

  static AppUser? findUserByEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();

    for (final user in users) {
      if (user.email.toLowerCase() == normalizedEmail) {
        return user;
      }
    }

    return null;
  }

  static bool emailExists(String email) {
    return findUserByEmail(email) != null;
  }

  static void addUser(AppUser user) {
    if (emailExists(user.email)) {
      throw ArgumentError('Email đã được sử dụng');
    }
    users.add(user);
  }
}
