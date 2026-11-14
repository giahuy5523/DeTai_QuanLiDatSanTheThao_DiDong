import 'package:sportfield_booking/data/venue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/models/promotion.dart';
import 'package:sportfield_booking/screens/owner/venue_bookings_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() {
    BookingRepository.setUseMockStoreForTesting(true);
    VenueRepository.setUseMockStoreForTesting(true);
  });

  tearDownAll(() {
    BookingRepository.setUseMockStoreForTesting(false);
    VenueRepository.setUseMockStoreForTesting(false);
  });
  for (final action in ['Xác nhận', 'Hoàn thành', 'Hủy đặt']) {
    testWidgets(
      'Owner $action preserves booking details and payment consistency',
      (tester) async {
        final savedBookings = List.of(MockStore.bookings);
        final savedPayments = List.of(MockStore.payments);
        final promo = MockStore.promotions.firstWhere((p) => p.code == 'SAN10');
        final savedUsage = promo.usedCount;
        final savedUsageHistory = promo.usageHistory
            .map(
              (usage) => PromotionUsage(
                promotionId: usage.promotionId,
                userId: usage.userId,
                bookingId: usage.bookingId,
                isReversed: usage.isReversed,
              ),
            )
            .toList();
        addTearDown(() {
          MockStore.bookings
            ..clear()
            ..addAll(savedBookings);
          MockStore.payments
            ..clear()
            ..addAll(savedPayments);
          promo.usedCount = savedUsage;
          promo.usageHistory
            ..clear()
            ..addAll(savedUsageHistory);
          MockStore.logout();
        });
        MockStore.bookings.clear();
        MockStore.payments.clear();
        final booking = Booking(
          id: 'owner-regression',
          venueId: 'v1',
          userId: 'customer1',
          date: DateTime.now().add(const Duration(days: 2)),
          startTime: '18:00',
          endTime: '19:00',
          totalPrice: 297000,
          originalAmount: 300000,
          serviceAmount: 30000,
          discountAmount: 33000,
          promoId: promo.id,
          promotionCode: promo.code,
          note: 'Giữ ghi chú',
          serviceItems: [
            BookingServiceItem(serviceId: 's1', quantity: 1, unitPrice: 30000),
          ],
        );
        expect(MockStore.confirmBooking(booking, 'momo'), isTrue);
        final payment = MockStore.paymentOfBooking(booking.id)!;
        if (action == 'Xác nhận') booking.status = 'pending';
        MockStore.login('owner@gmail.com', '123456');
        await tester.pumpWidget(
          MaterialApp(home: const VenueBookingsScreen(venueId: 'v1')),
        );
        await tester.pumpAndSettle();
        await press(tester, action);
        if (action == 'Hủy đặt') {
          await tapVisible(tester, find.text('Đồng ý'));
          expect(booking.status, 'cancelled');
          expect(booking.paymentStatus, 'paid');
          expect(payment['status'], 'success');
          expect(payment['refundStatus'], 'processing');
          expect(promo.usedCount, savedUsage);
          expect(MockStore.completeRefund(booking.id), isTrue);
          expect(booking.paymentStatus, 'refunded');
          expect(payment['status'], 'refunded');
          expect(MockStore.cancelBooking(booking.id), isFalse);
          expect(promo.usedCount, savedUsage);
        } else {
          expect(
            booking.status,
            action == 'Xác nhận' ? 'confirmed' : 'completed',
          );
          expect(booking.paymentStatus, 'paid');
          expect(payment['status'], 'success');
        }
        expect(MockStore.bookings.single, same(booking));
        expect(booking.originalAmount, 300000);
        expect(booking.serviceAmount, 30000);
        expect(booking.discountAmount, 33000);
        expect(booking.promoId, promo.id);
        expect(booking.serviceItems.single.serviceId, 's1');
        expect(booking.note, 'Giữ ghi chú');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
