import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../data/booking_repository.dart' as data_repo;
import '../../utils/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../widgets/venue_image.dart';

// ============================================================================
// Compatibility facade for legacy MockStore-based tests.
// The actual screen continues to use the SQLite repository asynchronously.
// ============================================================================

class BookingRepository {
  static Map<String, dynamic>? cancelBooking(String bookingId) {
    final bookingIndex = MockStore.bookings.indexWhere(
      (booking) => booking.id == bookingId,
    );

    if (bookingIndex == -1) return null;

    final booking = MockStore.bookings[bookingIndex];
    final oldStatus = booking.status;
    final promoId = booking.promoId;
    final shouldRefund = booking.paymentStatus == 'paid';

    if (!MockStore.cancelBooking(
      bookingId,
      cancelReason: 'Khách hàng chủ động hủy',
    )) {
      return null;
    }

    return {
      'oldStatus': oldStatus,
      'promoId': promoId,
      'shouldRefund': shouldRefund,
    };
  }
}

class BookingController {
  /// API đồng bộ giữ tương thích với các test MockStore hiện có.
  static bool cancelBooking(String bookingId) {
    return BookingRepository.cancelBooking(bookingId) != null;
  }

  /// Luồng thực tế của màn hình: hủy đơn qua SQLite Repository.
  static Future<bool> cancelBookingAsync(String bookingId) {
    return data_repo.BookingRepository.cancelBooking(
      bookingId,
      cancelReason: 'Khách hàng chủ động hủy',
    );
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
  late Future _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    final userId = MockStore.currentUser?.id ?? '';
    _bookingsFuture = data_repo.BookingRepository.getBookingsForUser(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử đặt sân')),
      body: FutureBuilder(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Không thể tải lịch sử đặt sân. Vui lòng thử lại.'),
            );
          }
          final bookings = snapshot.data ?? const [];
          if (bookings.isEmpty) {
            return const Center(child: Text('Chưa có đơn đặt sân.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final venue = MockStore.venueById(booking.venueId);
              final canCancel =
                  booking.status == 'pending' || booking.status == 'confirmed';

              return Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.bookingDetail,
                    arguments: booking.id,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVenuePhoto(
                          booking.venueId,
                          venue?.name ?? 'Sân thể thao',
                        ),
                        const SizedBox(height: 10),
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVenuePhoto(String venueId, String venueName) {
    final images = MockStore.imageUrlsOf(venueId);
    if (images.isEmpty) {
      return _missingVenueImage('Chưa có ảnh cho sân $venueName.');
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: double.infinity,
        height: 130,
        child: VenueImage(
          source: images.first,
          placeholder: _missingVenueImage(
            'Ảnh sân $venueName không tải được. Kiểm tra đường dẫn ảnh.',
          ),
        ),
      ),
    );
  }

  Widget _missingVenueImage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _statusChip(String status) {
    final label =
        {
          'pending': 'Chờ xác nhận',
          'confirmed': 'Đã xác nhận',
          'cancelled': 'Đã hủy',
          'completed': 'Hoàn tất',
        }[status] ??
        status;

    return Chip(label: Text(label));
  }

  Future<void> _onCancelPressed(String bookingId) async {
    final success = await BookingController.cancelBookingAsync(bookingId);

    if (!mounted) return;

    if (success) {
      setState(() {
        _loadBookings();
      });
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Đã hủy đơn đặt sân thành công.'
                : MockStore.lastCancellationError ??
                      'Không thể hủy đơn này. Vui lòng kiểm tra trạng thái đơn.',
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
