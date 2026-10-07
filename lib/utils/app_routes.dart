import 'package:flutter/material.dart';
import '../data/mock_store.dart';
import '../models/venue.dart';

import '../screens/admin/approve_venue_screen.dart';
import '../screens/admin/manage_promotion_screen.dart';
import '../screens/admin/statistics_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/customer/booking_history_screen.dart';
import '../screens/customer/booking_screen.dart';
import '../screens/customer/home_screen.dart';
import '../screens/customer/venue_list_screen.dart';
import '../screens/customer/payment_screen.dart';
import '../screens/customer/profile_screen.dart';
import '../screens/customer/search_screen.dart';
import '../screens/customer/venue_detail_screen.dart';
import '../screens/owner/manage_service_screen.dart';
import '../screens/owner/manage_venue_screen.dart';
import '../screens/owner/upload_venue_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const venueList = '/venues';
  static const search = '/search';
  static const venueDetail = '/venue-detail';
  static const booking = '/booking';
  static const payment = '/payment';
  static const bookingHistory = '/booking-history';
  static const profile = '/profile';
  static const uploadVenue = '/upload-venue';
  static const manageVenue = '/manage-venue';
  static const manageService = '/manage-service';
  static const approveVenue = '/approve-venue';
  static const managePromotion = '/manage-promotion';
  static const statistics = '/statistics';

  static Map<String, WidgetBuilder> get routes {
    final builders = <String, WidgetBuilder>{
      login: (_) => const LoginScreen(),
      register: (_) => const RegisterScreen(),
      home: (_) => const HomeScreen(),
      venueList: (_) => const VenueListScreen(),
      search: (_) => const SearchScreen(),
      venueDetail: (_) => const VenueDetailScreen(),
      booking: (_) => const BookingScreen(),
      payment: (_) => const PaymentScreen(),
      bookingHistory: (_) => const BookingHistoryScreen(),
      profile: (_) => const ProfileScreen(),
      uploadVenue: (_) => const UploadVenueScreen(),
      manageVenue: (_) => const ManageVenueScreen(),
      manageService: (_) => const ManageServiceScreen(),
      approveVenue: (_) => const ApproveVenueScreen(),
      managePromotion: (_) => const ManagePromotionScreen(),
      statistics: (_) => const StatisticsScreen(),
    };
    return builders.map(
      (name, builder) => MapEntry(name, (context) {
        if (name == login || name == register) return builder(context);
        final role = MockStore.currentUser?.role;
        final ownerRoutes = {uploadVenue, manageVenue, manageService};
        final adminRoutes = {approveVenue, managePromotion, statistics};
        final requiredRole = ownerRoutes.contains(name)
            ? 'owner'
            : adminRoutes.contains(name)
            ? 'admin'
            : 'customer';
        if (role != requiredRole) {
          return const _RouteError('Bạn không có quyền truy cập màn hình này.');
        }
        final args = ModalRoute.of(context)?.settings.arguments;
        if ((name == venueDetail || name == booking) &&
            (args is! Venue || args.status != 'approved')) {
          return const _RouteError('Thông tin sân không hợp lệ.');
        }
        if (name == manageService &&
            (args is! String ||
                MockStore.venueById(args)?.ownerId !=
                    MockStore.currentUser?.id)) {
          return const _RouteError('Thông tin sân không hợp lệ.');
        }
        if (name == payment &&
            (args is! Map<String, dynamic> ||
                args['venue'] is! Venue ||
                args['date'] is! DateTime ||
                args['time'] is! String ||
                args['total'] is! num)) {
          return const _RouteError('Thông tin thanh toán không hợp lệ.');
        }
        return builder(context);
      }),
    );
  }
}

class _RouteError extends StatelessWidget {
  const _RouteError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Không thể mở màn hình')),
    body: Center(child: Text(message)),
  );
}
