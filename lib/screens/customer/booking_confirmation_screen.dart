import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';

/// Màn hình xác nhận thông tin đặt sân.
/// Luồng: Chọn sân -> Xác nhận thông tin -> Chọn phương thức thanh toán.
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  String _nextHour(String start) {
    final parts = start.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
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
      case 'pickleball':
        return Icons.sports_tennis_rounded;
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

    final venue = args['venue'] as Venue? ??
        (MockStore.venues.isNotEmpty
            ? MockStore.venues.first
            : Venue.mockList().first);

    final date = args['date'] as DateTime? ?? DateTime.now();
    final startTime =
        args['startTime'] as String? ?? args['time'] as String? ?? '08:00';
    final endTime =
        args['endTime'] as String? ?? _nextHour(startTime);

    final serviceIds = List<String>.from(
      args['serviceIds'] as List<dynamic>? ?? const [],
    );

    final courtPrice =
        (args['courtPrice'] as num?)?.toDouble() ?? venue.pricePerHour;
    final serviceTotal =
        (args['serviceTotal'] as num?)?.toDouble() ?? 0;
    final discount =
        (args['discount'] as num?)?.toDouble() ?? 0;
    final discountAmount =
        (args['discountAmount'] as num?)?.toDouble() ?? 0;
    final total = (args['total'] as num?)?.toDouble() ??
        (courtPrice + serviceTotal - discountAmount);
    final promoCode = args['promoCode'] as String?;

    final currentUser = MockStore.currentUser;
    final selectedServices = MockStore.servicesFor(venue.id)
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
          _buildHeaderBanner(),
          const SizedBox(height: 16),
          _buildCustomerCard(currentUser),
          const SizedBox(height: 16),
          _buildVenueCard(venue),
          const SizedBox(height: 16),
          _buildBookingDetailsCard(
            date: date,
            startTime: startTime,
            endTime: endTime,
            selectedServices: selectedServices,
            promoCode: promoCode,
            discount: discount,
          ),
          const SizedBox(height: 16),
          _buildPriceBreakdownCard(
            courtPrice: courtPrice,
            serviceTotal: serviceTotal,
            discount: discount,
            discountAmount: discountAmount,
            total: total,
          ),
          const SizedBox(height: 16),
          _buildImportantNotes(),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(
        context: context,
        venue: venue,
        date: date,
        startTime: startTime,
        endTime: endTime,
        serviceIds: serviceIds,
        courtPrice: courtPrice,
        serviceTotal: serviceTotal,
        discount: discount,
        discountAmount: discountAmount,
        total: total,
        promoCode: promoCode,
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
        ),
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
                  'Kiểm tra trước khi thanh toán',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Hãy kiểm tra sân, khung giờ, dịch vụ và tổng tiền trước khi tiếp tục.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(dynamic currentUser) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Thông tin người đặt',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: AppTheme.border),
            _buildDetailRow(
              icon: Icons.badge_outlined,
              label: 'Họ và tên',
              value: currentUser?.name ?? 'Khách hàng',
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.phone_outlined,
              label: 'Số điện thoại',
              value: currentUser?.phone ?? 'Chưa cập nhật',
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: currentUser?.email ?? 'Chưa cập nhật',
            ),
          ],
        ),
      ),
    );
  }

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
                Text(
                  'Thời gian & Dịch vụ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: AppTheme.border),
            _buildDetailRow(
              icon: Icons.event_note_outlined,
              label: 'Ngày đặt sân',
              value: dateStr,
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Khung giờ',
              value: '$startTime - $endTime',
            ),
            const SizedBox(height: 14),
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
                          children: selectedServices.map(
                            (s) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${s.name} • ${s.price.toStringAsFixed(0)} đ/${s.unit}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                        ),
                ),
              ],
            ),
            if (promoCode != null && promoCode.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Khuyến mãi',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
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
                      '$promoCode  •  -${discount.toStringAsFixed(0)}%',
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
            _buildCostRow('Tiền thuê sân', courtPrice),
            if (serviceTotal > 0) ...[
              const SizedBox(height: 8),
              _buildCostRow('Dịch vụ phụ trợ', serviceTotal),
            ],
            if (discountAmount > 0) ...[
              const SizedBox(height: 8),
              _buildCostRow(
                discount > 0
                    ? 'Giảm giá (${discount.toStringAsFixed(0)}%)'
                    : 'Giảm giá',
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

  Widget _buildImportantNotes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: AppTheme.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Lưu ý đặt sân',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildBullet('Khung giờ chỉ được giữ khi hệ thống tạo đơn đặt sân.'),
            _buildBullet('Nếu thanh toán thất bại, anh có thể thử lại hoặc chọn phương thức khác.'),
            _buildBullet('Vui lòng kiểm tra kỹ thông tin trước khi xác nhận.'),
          ],
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions({
    required BuildContext context,
    required Venue venue,
    required DateTime date,
    required String startTime,
    required String endTime,
    required List<String> serviceIds,
    required double courtPrice,
    required double serviceTotal,
    required double discount,
    required double discountAmount,
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
            Expanded(
              flex: 4,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment_rounded, size: 19),
                label: const Text('Chọn phương thức thanh toán'),
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
                    'courtPrice': courtPrice,
                    'serviceTotal': serviceTotal,
                    'discount': discount,
                    'discountAmount': discountAmount,
                    'total': total,
                    'promoCode': promoCode,
                  },
                ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCostRow(
    String label,
    double amount, {
    Color? valueColor,
  }) {
    final formatted = amount < 0
        ? '-${(-amount).toStringAsFixed(0)} đ'
        : '${amount.toStringAsFixed(0)} đ';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
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
