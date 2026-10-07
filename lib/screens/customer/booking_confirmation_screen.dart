import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';

/// Màn hình Xác nhận thông tin đặt sân (Booking Confirmation) - phong cách ALOBO.
/// Nằm giữa bước Chọn sân (BookingScreen) và Thanh toán (PaymentScreen).
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  String _nextHour(String start) {
    final hour = int.tryParse(start.split(':').first) ?? 0;
    return '${(hour + 1).toString().padLeft(2, '0')}:00';
  }

  IconData _getSportIcon(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'bóng đá':
        return Icons.sports_soccer_rounded;
      case 'cầu lông':
        return Icons.sports_tennis_rounded;
      case 'tennis':
        return Icons.sports_tennis_outlined;
      case 'bóng rổ':
        return Icons.sports_basketball_rounded;
      case 'bóng chuyền':
        return Icons.sports_volleyball_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map<String, dynamic>
        ? rawArgs
        : <String, dynamic>{};

    // Trích xuất an toàn dữ liệu kèm fallback tránh màn hình trắng nếu thiếu args
    final Venue venue =
        args['venue'] as Venue? ??
        (MockStore.venues.isNotEmpty
            ? MockStore.venues.first
            : Venue.mockList().first);
    final DateTime date = args['date'] as DateTime? ?? DateTime.now();
    final String startTime =
        args['startTime'] as String? ?? args['time'] as String? ?? '08:00';
    final String endTime = args['endTime'] as String? ?? _nextHour(startTime);
    final List<String> serviceIds = List<String>.from(
      args['serviceIds'] as List<dynamic>? ?? const [],
    );
    final double courtPrice =
        (args['courtPrice'] as num?)?.toDouble() ?? venue.pricePerHour;
    final double serviceTotal =
        (args['serviceTotal'] as num?)?.toDouble() ?? 0.0;
    final double discount = (args['discount'] as num?)?.toDouble() ?? 0.0;
    final double discountAmount =
        (args['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final double total =
        (args['total'] as num?)?.toDouble() ??
        (courtPrice + serviceTotal - discountAmount);
    final String? promoCode = args['promoCode'] as String?;

    // Lấy thông tin các dịch vụ được chọn từ MockStore
    final allServices = MockStore.servicesFor(venue.id);
    final selectedServices = allServices
        .where((s) => serviceIds.contains(s.id))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Xác nhận đặt sân'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ─── Header: "Xác nhận thông tin đặt sân" ──────────────────
          _buildHeaderBanner(),
          const SizedBox(height: 16),

          // ─── Card 1: Thông tin sân & Địa điểm ─────────────────────
          _buildVenueCard(venue),
          const SizedBox(height: 16),

          // ─── Card 2: Thời gian & Dịch vụ ──────────────────────────
          _buildBookingDetailsCard(
            date: date,
            startTime: startTime,
            endTime: endTime,
            selectedServices: selectedServices,
            promoCode: promoCode,
            discount: discount,
          ),
          const SizedBox(height: 16),

          // ─── Card 3: Chi tiết chi phí & Tổng cộng ──────────────────
          _buildPriceBreakdownCard(
            courtPrice: courtPrice,
            serviceTotal: serviceTotal,
            discount: discount,
            discountAmount: discountAmount,
            total: total,
          ),
          const SizedBox(height: 16),
        ],
      ),

      // ─── Thanh tác vụ kép cố định: "Quay lại" & "Xác nhận & thanh toán" ──
      bottomNavigationBar: _buildBottomActions(
        context: context,
        venue: venue,
        date: date,
        startTime: startTime,
        endTime: endTime,
        serviceIds: serviceIds,
        total: total,
        promoCode: promoCode,
      ),
    );
  }

  // Header thông báo
  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_turned_in_rounded,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xác nhận thông tin đặt sân',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Vui lòng kiểm tra lại thông tin trước khi thanh toán.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card thông tin sân
  Widget _buildVenueCard(Venue venue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getSportIcon(venue.sportType),
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thông tin sân thể thao',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    venue.sportType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: AppTheme.border),
            Text(
              venue.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    venue.address,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Card chi tiết thời gian & dịch vụ
  Widget _buildBookingDetailsCard({
    required DateTime date,
    required String startTime,
    required String endTime,
    required List selectedServices,
    required String? promoCode,
    required double discount,
  }) {
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeStr = "$startTime - $endTime";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thời gian & Dịch vụ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: AppTheme.border),

            // Ngày đặt
            _buildDetailRow(
              icon: Icons.event_note_outlined,
              label: 'Ngày đặt sân',
              value: dateStr,
            ),
            const SizedBox(height: 10),

            // Khung giờ
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Khung giờ',
              value: timeStr,
            ),
            const SizedBox(height: 12),

            // Dịch vụ kèm theo
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.room_service_outlined,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 90,
                  child: Text(
                    'Dịch vụ',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: selectedServices.isEmpty
                      ? const Text(
                          'Không có dịch vụ thêm',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: selectedServices
                              .map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${s.name} (${s.price.toStringAsFixed(0)} đ/${s.unit})',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),

            if (promoCode != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Mã ưu đãi',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '$promoCode (-${discount.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Card chi tiết thanh toán
  Widget _buildPriceBreakdownCard({
    required double courtPrice,
    required double serviceTotal,
    required double discount,
    required double discountAmount,
    required double total,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: AppTheme.primary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Chi tiết thanh toán',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: AppTheme.border),
            _buildCostRow('Tiền thuê sân (1h)', courtPrice),
            if (serviceTotal > 0) ...[
              const SizedBox(height: 8),
              _buildCostRow('Dịch vụ phụ trợ', serviceTotal),
            ],
            if (discount > 0) ...[
              const SizedBox(height: 8),
              _buildCostRow(
                'Giảm giá (${discount.toStringAsFixed(0)}%)',
                -discountAmount,
                valueColor: AppTheme.primary,
              ),
            ],
            const Divider(height: 22, color: AppTheme.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng thanh toán',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(0)} đ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Thanh tác vụ cố định ở đáy: Quay lại & Xác nhận & thanh toán
  Widget _buildBottomActions({
    required BuildContext context,
    required Venue venue,
    required DateTime date,
    required String startTime,
    required String endTime,
    required List<String> serviceIds,
    required double total,
    required String? promoCode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Nút "Quay lại"
            Expanded(
              flex: 4,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại'),
              ),
            ),
            const SizedBox(width: 12),

            // Nút "Xác nhận & thanh toán" -> Điều hướng sang PaymentScreen
            Expanded(
              flex: 6,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.payment,
                  arguments: {
                    'venue': venue,
                    'date': date,
                    'startTime': startTime,
                    'endTime': endTime,
                    'time': startTime,
                    'serviceIds': serviceIds,
                    'total': total,
                    'promoCode': promoCode,
                  },
                ),
                child: const Text('Xác nhận & thanh toán'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCostRow(String label, double amount, {Color? valueColor}) {
    final formatted = amount < 0
        ? '-${(-amount).toStringAsFixed(0)} đ'
        : '${amount.toStringAsFixed(0)} đ';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        Text(
          formatted,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
