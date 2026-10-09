import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/mock_store.dart';
import '../../models/promotion.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';

/// Màn hình danh sách ưu đãi / mã khuyến mãi dành cho Khách hàng.
/// Phong cách Nhom1_DatSanTheThao với thẻ voucher bo góc, sao chép mã và nút dùng ngay.
class CustomerPromotionScreen extends StatelessWidget {
  const CustomerPromotionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Tải dữ liệu từ MockStore
    final promotions = MockStore.promotions;
    final now = DateTime.now();
    final activeCount = promotions.where((p) => p.isValidAt(now)).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Ưu đãi'),
        automaticallyImplyLeading: false,
      ),
      body: promotions.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // ─── Header Banner Nhom1_DatSanTheThao ─────────────────────────────
                _buildHeaderBanner(),
                const SizedBox(height: 20),

                // ─── Tiêu đề danh sách ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Mã khuyến mãi khả dụng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '$activeCount mã đang mở',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Danh sách thẻ khuyến mãi ────────────────────────
                ...promotions.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PromotionVoucherCard(promotion: p),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Nhom1_DatSanTheThao',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kho ưu đãi thể thao',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sao chép mã giảm giá và áp dụng khi đặt sân để nhận ngay mức giá tốt nhất.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 54,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có mã ưu đãi nào',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Các voucher giảm giá hấp dẫn sẽ được cập nhật sớm. Hãy quay lại sau nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionVoucherCard extends StatelessWidget {
  const _PromotionVoucherCard({required this.promotion});

  final Promotion promotion;

  bool get _isExpired => promotion.isExpiredAt(DateTime.now());
  bool get _isUsable => promotion.isValidAt(DateTime.now());

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: promotion.code));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Đã sao chép mã "${promotion.code}" vào bộ nhớ tạm'),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _useCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: promotion.code));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã sao chép mã "${promotion.code}". Chọn sân ngay để đặt chỗ!',
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
    // Điều hướng về Tab Trang chủ (index 0) trong CustomerShell
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.customerShell,
      (route) => false,
      arguments: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiryFormatted =
        '${promotion.expiryDate.day.toString().padLeft(2, '0')}/${promotion.expiryDate.month.toString().padLeft(2, '0')}/${promotion.expiryDate.year}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isUsable ? AppTheme.border : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Khối tỷ lệ giảm giá bên trái
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _isUsable
                        ? AppTheme.primaryLight
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isUsable
                          ? AppTheme.primary.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${promotion.discountPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _isUsable
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        'GIẢM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _isUsable
                              ? AppTheme.primaryDark
                              : AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Nội dung voucher
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _isUsable
                                  ? AppTheme.primaryLight
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              promotion.code,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: _isUsable
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          _buildStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Giảm ${promotion.discountPercent.toStringAsFixed(0)}% chi phí thuê sân cho mọi khung giờ',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: _isExpired
                                ? AppTheme.error
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'HSD: $expiryFormatted',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _isExpired
                                    ? AppTheme.error
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Hàng nút hành động: Sao chép mã & Dùng ngay
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                // Nút "Sao chép mã"
                TextButton.icon(
                  onPressed: () => _copyCode(context),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Sao chép mã'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_isUsable) ...[
                  // Nút "Dùng ngay"
                  ElevatedButton(
                    onPressed: () => _useCode(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(96, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Dùng ngay'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    String label;
    Color bgColor;
    Color textColor;

    if (!promotion.isActive) {
      label = 'Tạm dừng';
      bgColor = Colors.grey.shade200;
      textColor = AppTheme.textSecondary;
    } else if (_isExpired) {
      label = 'Hết hạn';
      bgColor = const Color(0xFFFEE2E2);
      textColor = AppTheme.error;
    } else {
      label = 'Đang áp dụng';
      bgColor = AppTheme.primaryLight;
      textColor = AppTheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
