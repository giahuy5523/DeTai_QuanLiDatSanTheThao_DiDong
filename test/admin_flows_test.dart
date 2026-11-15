import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/data/venue_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/models/promotion.dart';
import 'package:sportfield_booking/models/venue.dart';
import 'package:sportfield_booking/screens/admin/approve_venue_screen.dart';
import 'package:sportfield_booking/screens/admin/manage_promotion_screen.dart';
import 'package:sportfield_booking/screens/admin/manage_refund_screen.dart';
import 'package:sportfield_booking/utils/app_theme.dart';

void main() {
  _approveVenueTests();
  _managePromotionTests();
  _manageRefundTests();
}

// ---------------------------------------------------------------------------
// Admin: duyệt sân
// ---------------------------------------------------------------------------
void _approveVenueTests() {
  group('Admin approve venue', () {
    const pendingVenueId = 'admin-approval-pending';
    const approvedVenueId = 'admin-approval-approved';
    final originalVenues = List<Venue>.of(MockStore.venues);

    setUp(() {
      VenueRepository.setUseMockStoreForTesting(true);
      MockStore.venues
        ..clear()
        // Chỉ nạp 2 sân test, không nạp originalVenues: dữ liệu mock gốc có thể
        // chứa sân "pending" khác nên màn hình sẽ không bao giờ trống.
        ..addAll([
          Venue(
            id: pendingVenueId,
            ownerId: 'owner1',
            sportType: 'Football',
            name: 'Pending Test Court',
            address: '1 Test Street',
            pricePerHour: 120000,
            imageUrls: const [],
            latitude: 10,
            longitude: 106,
            status: 'pending',
          ),
          Venue(
            id: approvedVenueId,
            ownerId: 'owner2',
            sportType: 'Tennis',
            name: 'Already Approved Court',
            address: '2 Test Street',
            pricePerHour: 150000,
            imageUrls: const [],
            latitude: 10,
            longitude: 106,
            status: 'approved',
          ),
        ]);
    });

    tearDown(() {
      VenueRepository.setUseMockStoreForTesting(false);
      MockStore.venues
        ..clear()
        ..addAll(originalVenues);
    });

    testWidgets('Admin approves a pending venue', (tester) async {
      _useTallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ApproveVenueScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Test Court'), findsOneWidget);
      expect(find.text('Already Approved Court'), findsNothing);

      final approveButton = find.descendant(
        of: find.byKey(const ValueKey(pendingVenueId)),
        matching: find.text('Duyệt'),
      );
      expect(approveButton, findsOneWidget);
      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      expect(
        MockStore.venues
            .singleWhere((venue) => venue.id == pendingVenueId)
            .status,
        'approved',
      );
      expect(find.text('Pending Test Court'), findsNothing);
      expect(find.text('Đã duyệt xong!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Admin: quản lý khuyến mãi
// ---------------------------------------------------------------------------
void _managePromotionTests() {
  group('Admin manage promotion', () {
    const addedCode = 'ADMINFLOW25';
    final originalPromotions = List<Promotion>.of(MockStore.promotions);

    setUp(() {
      BookingRepository.setUseMockStoreForTesting(true);
      VenueRepository.setUseMockStoreForTesting(true);
      MockStore.promotions
        ..clear()
        ..addAll(originalPromotions);
    });

    tearDown(() {
      BookingRepository.setUseMockStoreForTesting(false);
      VenueRepository.setUseMockStoreForTesting(false);
      MockStore.promotions
        ..clear()
        ..addAll(originalPromotions);
    });

    testWidgets('Admin creates, edits, and deletes a promotion', (
      tester,
    ) async {
      _useTallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ManagePromotionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm mã'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'adminflow25');
      await tester.enterText(fields.at(1), '25');
      await tester.tap(find.text('Tạo khuyến mãi'));
      await tester.pumpAndSettle();

      final added = MockStore.promotions.singleWhere(
        (promotion) => promotion.code == addedCode,
      );
      expect(added.discountPercent, 25);

      final card = find.byKey(ValueKey('promo-${added.id}'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: card, matching: find.text('Chỉnh sửa')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '30');
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(
        MockStore.promotions
            .singleWhere((promotion) => promotion.id == added.id)
            .discountPercent,
        30,
      );

      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: card, matching: find.text('Xóa')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận xóa'));
      await tester.pumpAndSettle();

      expect(
        MockStore.promotions.any((promotion) => promotion.id == added.id),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Admin: quản lý hoàn tiền
// ---------------------------------------------------------------------------
void _manageRefundTests() {
  group('Admin manage refund', () {
    const successBookingId = 'admin-refund-success';
    const failedBookingId = 'admin-refund-failed';
    final originalBookings = List<Booking>.of(MockStore.bookings);
    final originalPayments = List<Map<String, dynamic>>.of(MockStore.payments);

    setUp(() {
      BookingRepository.setUseMockStoreForTesting(true);
      MockStore.bookings
        ..clear()
        ..addAll(originalBookings)
        ..addAll([_booking(successBookingId), _booking(failedBookingId)]);
      MockStore.payments
        ..clear()
        ..addAll(originalPayments)
        ..addAll([_payment(successBookingId), _payment(failedBookingId)]);
    });

    tearDown(() {
      BookingRepository.setUseMockStoreForTesting(false);
      MockStore.bookings
        ..clear()
        ..addAll(originalBookings);
      MockStore.payments
        ..clear()
        ..addAll(originalPayments);
    });

    testWidgets('Admin records successful and failed refund outcomes', (
      tester,
    ) async {
      _useTallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ManageRefundScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đơn $successBookingId'), findsOneWidget);
      expect(find.text('Đơn $failedBookingId'), findsOneWidget);

      final successCard = find.ancestor(
        of: find.text('Đơn $successBookingId'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: successCard, matching: find.text('Hoàn tất')),
      );
      await tester.pumpAndSettle();

      expect(
        MockStore.paymentOfBooking(successBookingId)?['refundStatus'],
        'succeeded',
      );
      expect(
        MockStore.paymentOfBooking(successBookingId)?['status'],
        'refunded',
      );
      expect(
        MockStore.bookings
            .singleWhere((b) => b.id == successBookingId)
            .paymentStatus,
        'refunded',
      );
      expect(find.text('Đơn $successBookingId'), findsNothing);

      final failedCard = find.ancestor(
        of: find.text('Đơn $failedBookingId'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: failedCard, matching: find.text('Thất bại')),
      );
      await tester.pumpAndSettle();

      expect(
        MockStore.paymentOfBooking(failedBookingId)?['refundStatus'],
        'failed',
      );
      expect(
        MockStore.bookings
            .singleWhere((b) => b.id == failedBookingId)
            .paymentStatus,
        'paid',
      );
      expect(find.text('Đơn $failedBookingId'), findsNothing);
      expect(find.text('Không có khoản nào đang chờ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Màn hình test mặc định chỉ 800x600 nên nút nằm dưới màn hình sẽ không tap
/// được. Dùng màn hình cao hơn để mọi nút đều nằm trong vùng hiển thị.
void _useTallScreen(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 2000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Booking _booking(String id) => Booking(
  id: id,
  venueId: 'refund-test-venue',
  userId: 'refund-test-customer',
  date: DateTime(2026, 12, 1),
  startTime: '18:00',
  endTime: '19:00',
  totalPrice: 150000,
  status: 'cancelled',
  paymentStatus: 'paid',
  cancelledAt: DateTime(2026, 11, 12, 10),
);

Map<String, dynamic> _payment(String bookingId) => {
  'id': 'payment-$bookingId',
  'bookingId': bookingId,
  'method': 'momo',
  'amount': 150000,
  'status': 'success',
  'transactionCode': 'TXN-$bookingId',
  'refundAmount': 150000,
  'refundStatus': 'processing',
};
