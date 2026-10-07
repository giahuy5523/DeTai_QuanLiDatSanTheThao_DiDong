import 'package:flutter/material.dart';

import '../screens/admin/approve_venue_screen.dart';
import '../screens/admin/manage_promotion_screen.dart';
import '../screens/admin/statistics_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/customer/booking_confirmation_screen.dart';
import '../screens/customer/booking_history_screen.dart';
import '../screens/customer/booking_screen.dart';
import '../screens/customer/customer_promotion_screen.dart';
import '../screens/customer/customer_shell.dart';
import '../screens/customer/home_screen.dart';
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
  static const customerShell = '/customer';
  static const home = '/home';
  static const search = '/search';
  static const venueDetail = '/venue-detail';
  static const booking = '/booking';
  static const bookingConfirmation = '/booking-confirmation';
  static const payment = '/payment';
  static const bookingHistory = '/booking-history';
  static const profile = '/profile';
  static const customerPromotion = '/promotions';
  static const uploadVenue = '/upload-venue';
  static const manageVenue = '/manage-venue';
  static const manageService = '/manage-service';
  static const approveVenue = '/approve-venue';
  static const managePromotion = '/manage-promotion';
  static const statistics = '/statistics';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        customerShell: (ctx) {
          final tabIndex = ModalRoute.of(ctx)?.settings.arguments as int? ?? 0;
          return CustomerShell(initialIndex: tabIndex);
        },
        home: (_) => const HomeScreen(),
        search: (_) => const SearchScreen(),
        venueDetail: (_) => const VenueDetailScreen(),
        booking: (_) => const BookingScreen(),
        bookingConfirmation: (_) => const BookingConfirmationScreen(),
        payment: (_) => const PaymentScreen(),
        bookingHistory: (_) => const BookingHistoryScreen(),
        profile: (_) => const ProfileScreen(),
        customerPromotion: (_) => const CustomerPromotionScreen(),
        uploadVenue: (_) => const UploadVenueScreen(),
        manageVenue: (_) => const ManageVenueScreen(),
        manageService: (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          final venueId = args is String ? args : '';

          return ManageServiceScreen(venueId: venueId);
        },
        approveVenue: (_) => const ApproveVenueScreen(),
        managePromotion: (_) => const ManagePromotionScreen(),
        statistics: (_) => const StatisticsScreen(),
      };
}
