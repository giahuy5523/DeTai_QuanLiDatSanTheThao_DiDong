import 'package:flutter/material.dart';
import '../../data/mock_store.dart';

// ============================================================================
// Repository: xử lý hủy đơn và giải phóng khung giờ trong MockStore.
// Lưu ý: đây là mô phỏng nghiệp vụ, chưa phải transaction SQLite thật.
// ============================================================================

class BookingRepository {
  static Map<String, dynamic>? cancelBooking(String bookingId) {
    final bookingIndex =
        MockStore.bookings.indexWhere((booking) => booking.id == bookingId);

    if (bookingIndex == -1) return null;

    final booking = MockStore.bookings[bookingIndex];

    // Chỉ cho phép hủy đơn đang chờ xác nhận hoặc đã xác nhận.
    if (booking.status != 'pending' && booking.status != 'confirmed') {
      return null;
    }

    final oldStatus = booking.status;
    final promoId = booking.promoId;
    final payment = MockStore.paymentOfBooking(bookingId);

    // Chỉ hoàn tiền khi cả Booking và Payment đều ghi nhận đã thanh toán.
    final shouldRefund = booking.paymentStatus == 'paid' &&
        payment != null &&
        payment['status'] == 'success';

    // Cập nhật đơn đặt sân.
    booking.status = 'cancelled';
    booking.cancelReason = 'Khách hàng chủ động hủy';
    booking.cancelledAt = DateTime.now();

    if (shouldRefund) {
      booking.paymentStatus = 'refunded';
    }

    // MockStore.timeSlotsFor() tự bỏ qua booking có status == 'cancelled',
    // vì vậy khung giờ sẽ không còn bị đơn này chiếm giữ.

    return {
      'oldStatus': oldStatus,
      'promoId': promoId,
      'shouldRefund': shouldRefund,
    };
  }
}

// ============================================================================
// PromotionService: hoàn lại lượt sử dụng mã khuyến mãi trong MockStore.
// ============================================================================

class PromotionService {
  static bool cancelPromoUse(String promoId) {
    final promoIndex =
        MockStore.promotions.indexWhere((promotion) => promotion.id == promoId);

    if (promoIndex == -1) return false;

    final promotion = MockStore.promotions[promoIndex];

    // Không để số lượt sử dụng giảm xuống số âm.
    if (promotion.usedCount <= 0) return false;

    promotion.usedCount--;
    return true;
  }
}

// ============================================================================
// PaymentService: cập nhật trạng thái bản ghi thanh toán sau khi đủ điều kiện.
// Đây chỉ là mô phỏng, không thực hiện hoàn tiền thật qua cổng thanh toán.
// ============================================================================

class PaymentService {
  static bool processRefund(String bookingId) {
    final payment = MockStore.paymentOfBooking(bookingId);

    if (payment == null || payment['status'] != 'success') {
      return false;
    }

    payment['status'] = 'refunded';
    return true;
  }
}

// ============================================================================
// Controller: điều phối các bước theo Sequence.
// ============================================================================

class BookingController {
  static bool cancelBooking(String bookingId) {
    final result = BookingRepository.cancelBooking(bookingId);
    if (result == null) return false;

    final promoId = result['promoId'] as String?;
    final shouldRefund = result['shouldRefund'] as bool;

    // opt: đơn có sử dụng mã khuyến mãi.
    if (promoId != null && promoId.isNotEmpty) {
      PromotionService.cancelPromoUse(promoId);
    }

    // opt: đơn đã thanh toán thành công.
    if (shouldRefund) {
      final refunded = PaymentService.processRefund(bookingId);

      // Nếu không cập nhật được Payment, khôi phục trạng thái paymentStatus
      // để tránh Booking báo đã hoàn tiền trong khi Payment chưa được cập nhật.
      if (!refunded) {
        final bookingIndex =
            MockStore.bookings.indexWhere((booking) => booking.id == bookingId);
        if (bookingIndex != -1) {
          MockStore.bookings[bookingIndex].paymentStatus = 'paid';
        }
      }
    }

    return true;
  }
}

// ============================================================================
// UI: BookingHistoryScreen
// ============================================================================

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final bookings =
        MockStore.customerBookings(MockStore.currentUser?.id ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử đặt sân')),
      body: bookings.isEmpty
          ? const Center(child: Text('Chưa có đơn đặt sân.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final venue = MockStore.venueById(booking.venueId);
                final canCancel = booking.status == 'pending' ||
                    booking.status == 'confirmed';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue?.name ?? 'Sân thể thao',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${booking.date.day}/${booking.date.month}/${booking.date.year} • '
                          '${booking.startTime} - ${booking.endTime}',
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${booking.totalPrice.toStringAsFixed(0)} đ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _statusChip(booking.status),
                          ],
                        ),
                        if (canCancel) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              key: ValueKey('cancel_${booking.id}'),
                              onPressed: () => _onCancelPressed(booking.id),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Hủy đặt sân'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _statusChip(String status) {
    final label = {
          'pending': 'Chờ xác nhận',
          'confirmed': 'Đã xác nhận',
          'cancelled': 'Đã hủy',
          'completed': 'Hoàn tất',
        }[status] ??
        status;

    return Chip(label: Text(label));
  }

  void _onCancelPressed(String bookingId) {
    final success = BookingController.cancelBooking(bookingId);

    if (!mounted) return;

    if (success) {
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Đã hủy đơn đặt sân thành công.')),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Không thể hủy đơn này. Vui lòng kiểm tra trạng thái đơn.'),
          ),
        );
    }
  }
}
