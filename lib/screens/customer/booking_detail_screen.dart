import 'package:flutter/material.dart';
import '../../data/booking_repository.dart' as data_repo;
import '../../data/mock_store.dart';
import '../../models/booking.dart';
import '../../models/payment.dart';
import '../../models/venue.dart';
import '../../utils/app_theme.dart';
import '../../widgets/venue_image.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  Future<_BookingDetailData?> _load() async {
    final booking = await data_repo.BookingRepository.getBookingById(bookingId);
    if (booking == null) return null;
    final payment = await data_repo.BookingRepository.getPaymentForBooking(
      booking.id,
    );
    return _BookingDetailData(
      booking: booking,
      venue: MockStore.venueById(booking.venueId),
      payment: payment,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BookingDetailData?>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _messageScaffold('Không thể tải chi tiết booking này.');
        }
        final data = snapshot.data;
        if (data == null) {
          return _messageScaffold('Không tìm thấy booking trong lịch sử.');
        }
        return _BookingDetailView(
          booking: data.booking,
          venue: data.venue,
          payment: data.payment,
        );
      },
    );
  }
}

class _BookingDetailData {
  const _BookingDetailData({
    required this.booking,
    required this.venue,
    required this.payment,
  });

  final Booking booking;
  final Venue? venue;
  final Payment? payment;
}

Scaffold _messageScaffold(String message) => Scaffold(
  appBar: AppBar(title: const Text('Chi tiết booking')),
  body: Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  ),
);

class _BookingDetailView extends StatelessWidget {
  const _BookingDetailView({
    required this.booking,
    required this.venue,
    required this.payment,
  });

  final Booking booking;
  final Venue? venue;
  final Payment? payment;

  @override
  Widget build(BuildContext context) {
    final selectedBooking = booking;
    final selectedVenue = venue;
    final selectedPayment = payment;
    final hasServiceSnapshot = selectedBooking.hasServiceSnapshot;
    final hasPriceBreakdown = selectedBooking.hasPriceBreakdown;
    final preDiscountTotal = hasPriceBreakdown
        ? selectedBooking.originalAmount + selectedBooking.serviceAmount
        : null;
    final breakdownIsValid =
        hasPriceBreakdown &&
        _isValidAmount(selectedBooking.originalAmount) &&
        _isValidAmount(selectedBooking.serviceAmount) &&
        _isValidAmount(selectedBooking.discountAmount) &&
        _isValidAmount(selectedBooking.totalPrice) &&
        selectedBooking.discountAmount <= preDiscountTotal! &&
        (preDiscountTotal -
                    selectedBooking.discountAmount -
                    selectedBooking.totalPrice)
                .abs() <=
            0.01;
    final serviceSnapshotIsValid =
        selectedBooking.hasServiceSnapshot &&
        selectedBooking.serviceItems.every(
          (item) =>
              item.quantity > 0 &&
              _isValidAmount(item.unitPrice) &&
              _isValidAmount(item.subtotal) &&
              (item.unitPrice * item.quantity - item.subtotal).abs() <= 0.01,
        ) &&
        (!hasPriceBreakdown ||
            (selectedBooking.serviceItems.fold<double>(
                          0,
                          (sum, item) => sum + item.subtotal,
                        ) -
                        selectedBooking.serviceAmount)
                    .abs() <=
                0.01);

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết booking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            'Sân thể thao',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _venuePhoto(selectedVenue),
                const SizedBox(height: 12),
                _row('Tên sân', selectedVenue?.name ?? 'Không có dữ liệu sân'),
                _row('Địa chỉ', selectedVenue?.address ?? 'Không có dữ liệu'),
                _row(
                  'Loại thể thao',
                  selectedVenue?.sportType ?? 'Không có dữ liệu',
                ),
              ],
            ),
          ),
          _section(
            'Thông tin đặt sân',
            Column(
              children: [
                _row('Mã booking', selectedBooking.id),
                _row(
                  'Ngày',
                  '${selectedBooking.date.day}/${selectedBooking.date.month}/${selectedBooking.date.year}',
                ),
                _row(
                  'Giờ',
                  '${selectedBooking.startTime} – ${selectedBooking.endTime}',
                ),
                _row('Trạng thái', _bookingStatus(selectedBooking.status)),
                if (selectedBooking.cancelReason != null)
                  _row('Lý do hủy', selectedBooking.cancelReason!),
              ],
            ),
          ),
          _section(
            'Dịch vụ',
            !hasServiceSnapshot
                ? const Text('Không có dữ liệu dịch vụ tại thời điểm đặt.')
                : !serviceSnapshotIsValid
                ? const Text(
                    'Dữ liệu dịch vụ đã lưu không hợp lệ hoặc không khớp hóa đơn.',
                  )
                : selectedBooking.serviceItems.isEmpty
                ? const Text('Không sử dụng dịch vụ kèm theo.')
                : Column(
                    children: selectedBooking.serviceItems.asMap().entries.map((
                      entry,
                    ) {
                      final item = entry.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry.key > 0) const Divider(height: 24),
                          Text(
                            item.serviceName ?? 'Tên dịch vụ chưa được lưu',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _serviceMetric('Số lượng', '${item.quantity}'),
                              _serviceMetric('Đơn giá', _money(item.unitPrice)),
                              _serviceMetric(
                                'Thành tiền',
                                _money(item.subtotal),
                              ),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          _section(
            'Hóa đơn',
            Column(
              children: [
                if (hasPriceBreakdown && !breakdownIsValid)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Cảnh báo: các thành phần hóa đơn không khớp tổng tiền hoặc chứa dữ liệu không hợp lệ.',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  ),
                _amountRow(
                  'Tiền thuê sân',
                  hasPriceBreakdown ? selectedBooking.originalAmount : null,
                ),
                _amountRow(
                  'Tiền dịch vụ',
                  hasPriceBreakdown ? selectedBooking.serviceAmount : null,
                ),
                _amountRow('Tổng trước giảm', preDiscountTotal),
                _amountRow(
                  'Giảm giá',
                  hasPriceBreakdown ? selectedBooking.discountAmount : null,
                ),
                const Divider(),
                _amountRow(
                  'Tổng thanh toán',
                  selectedBooking.totalPrice,
                  bold: true,
                ),
              ],
            ),
          ),
          _section(
            'Thanh toán',
            selectedPayment == null
                ? const Text('Không có bản ghi thanh toán.')
                : Column(
                    children: [
                      _row(
                        'Phương thức',
                        selectedPayment.method ?? 'Không có dữ liệu',
                      ),
                      _row(
                        'Trạng thái',
                        _paymentStatus(selectedPayment.status),
                      ),
                      _row(
                        'Mã giao dịch',
                        selectedPayment.transactionCode ?? 'Không có dữ liệu',
                      ),
                      if (selectedPayment.createdAt != null)
                        _row(
                          'Thời điểm tạo',
                          _dateTime(selectedPayment.createdAt!),
                        ),
                      if (selectedPayment.paidAt != null)
                        _row(
                          'Thời điểm thanh toán',
                          _dateTime(selectedPayment.paidAt!),
                        ),
                    ],
                  ),
          ),
          if (selectedBooking.status == 'cancelled')
            _section(
              'Hoàn tiền',
              selectedPayment?.refundStatus == null
                  ? const Text('Không có dữ liệu hoàn tiền.')
                  : Column(
                      children: [
                        _amountRow(
                          'Số tiền yêu cầu hoàn',
                          selectedPayment!.refundAmount,
                        ),
                        _row(
                          'Trạng thái hoàn',
                          _refundStatus(selectedPayment.refundStatus!),
                        ),
                        _row(
                          'Phương thức nhận tiền',
                          selectedPayment.refundMethod ?? 'Chưa được xác định',
                        ),
                        _row(
                          'Thời gian dự kiến',
                          selectedPayment.refundExpectedAt == null
                              ? 'Chưa được xác định'
                              : _dateTime(selectedPayment.refundExpectedAt!),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }


  Widget _venuePhoto(Venue? venue) {
    if (venue == null) return _photoPlaceholder('Không có dữ liệu sân.');
    final images = MockStore.imageUrlsOf(venue.id);
    final source = images.isNotEmpty
        ? images.first
        : venue.imageUrls.firstOrNull;
    if (source == null || source.isEmpty) {
      return _photoPlaceholder('Sân chưa có ảnh.');
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: VenueImage(
          source: source,
          placeholder: _photoPlaceholder('Không thể tải ảnh sân.'),
        ),
      ),
    );
  }

  Widget _photoPlaceholder(String message) => Container(
    height: 100,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
  );

  Widget _section(String title, Widget content) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
        ),
      ],
    ),
  );

  Widget _serviceMetric(String label, String value) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _amountRow(String label, double? amount, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              amount == null ? 'Không có dữ liệu' : _money(amount),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  bool _isValidAmount(double value) => value.isFinite && value >= 0;

  String _money(double value) => _isValidAmount(value)
      ? '${value.toStringAsFixed(0)} đ'
      : 'Dữ liệu không hợp lệ';

  String _bookingStatus(String value) => switch (value) {
    'pending' => 'Chờ xác nhận',
    'confirmed' => 'Đã xác nhận',
    'cancelled' => 'Đã hủy',
    'completed' => 'Hoàn tất',
    _ => value,
  };

  String _paymentStatus(String value) => switch (value) {
    'unknown' => 'Không xác định',
    'pending' => 'Đang chờ thanh toán',
    'success' => 'Đã thanh toán',
    'failed' => 'Thanh toán thất bại',
    'refunded' => 'Đã hoàn tiền',
    _ => value,
  };

  String _refundStatus(String value) => switch (value) {
    'processing' => 'Đang xử lý',
    'succeeded' => 'Thành công',
    'failed' => 'Thất bại',
    _ => value,
  };

  String _dateTime(DateTime value) =>
      '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
