import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/promotion.dart';
import '../../utils/app_theme.dart';
import 'admin_drawer.dart';

/// Màn hình Quản lý Khuyến mãi dành cho Quản trị viên (Admin).
/// Hỗ trợ Xem danh sách, Thêm mới, Chỉnh sửa, Bật/Tắt trạng thái và Xóa mã khuyến mãi.
class ManagePromotionScreen extends StatefulWidget {
  const ManagePromotionScreen({super.key});

  @override
  State<ManagePromotionScreen> createState() => _ManagePromotionScreenState();
}

class _ManagePromotionScreenState extends State<ManagePromotionScreen> {
  // Mở BottomSheet thêm hoặc chỉnh sửa khuyến mãi
  Future<void> _openPromotionSheet({Promotion? promotion}) async {
    final isEditing = promotion != null;
    final codeController = TextEditingController(text: promotion?.code ?? '');
    final discountController = TextEditingController(
      text: promotion != null
          ? promotion.discountPercent.toStringAsFixed(0)
          : '',
    );
    DateTime selectedDate =
        promotion?.expiryDate ?? DateTime.now().add(const Duration(days: 30));
    bool isActive = promotion?.isActive ?? true;
    String? errorMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh gạt modal
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tiêu đề
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEditing
                                ? Icons.edit_note_rounded
                                : Icons.add_circle_outline_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? 'Chỉnh sửa mã khuyến mãi'
                                    : 'Thêm mã khuyến mãi mới',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEditing
                                    ? 'Cập nhật thông tin chiết khấu và hạn dùng'
                                    : 'Thiết lập mã giảm giá cho khách hàng',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppTheme.border),

                    // Thông báo lỗi nếu có
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppTheme.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Trường nhập: Mã khuyến mãi
                    const Text(
                      'Mã khuyến mãi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Ví dụ: HELLO2026, SAN20',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Trường nhập: Tỷ lệ giảm giá (%)
                    const Text(
                      'Mức giảm giá (%)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Nhập số phần trăm (1 - 100)',
                        prefixIcon: Icon(Icons.percent_rounded, size: 20),
                        suffixText: '%',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Trường chọn: Ngày hết hạn
                    const Text(
                      'Hạn sử dụng',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final normalizedSelectedDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                        );
                        final lastDate = today.add(const Duration(days: 730));

                        final picked = await showDatePicker(
                          context: modalContext,
                          initialDate: normalizedSelectedDate.isAfter(lastDate)
                              ? lastDate
                              : normalizedSelectedDate,
                          firstDate: normalizedSelectedDate.isBefore(today)
                              ? normalizedSelectedDate
                              : today,
                          lastDate: lastDate,
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Đổi ngày',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Switch: Trạng thái kích hoạt
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppTheme.primary,
                          title: const Text(
                            'Kích hoạt mã',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            isActive
                                ? 'Khách hàng có thể sử dụng mã này'
                                : 'Tạm ẩn mã, khách hàng không thể dùng',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          value: isActive,
                          onChanged: (val) =>
                              setModalState(() => isActive = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nút Hủy và Lưu
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(modalContext),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: ElevatedButton(
                            onPressed: () {
                              final normalizedCode = codeController.text
                                  .trim()
                                  .toUpperCase();
                              final discountVal = double.tryParse(
                                discountController.text.trim(),
                              );

                              // Kiểm tra hợp lệ dữ liệu
                              if (normalizedCode.isEmpty) {
                                setModalState(() {
                                  errorMessage = 'Vui lòng nhập mã khuyến mãi.';
                                });
                                return;
                              }

                              if (discountVal == null ||
                                  !discountVal.isFinite ||
                                  discountVal <= 0 ||
                                  discountVal > 100) {
                                setModalState(() {
                                  errorMessage =
                                      'Mức giảm giá phải nằm trong khoảng từ 1% đến 100%.';
                                });
                                return;
                              }

                              // Kiểm tra trùng mã
                              final isDuplicate = MockStore.promotions.any(
                                (p) =>
                                    p.code.toUpperCase() == normalizedCode &&
                                    (!isEditing || p.id != promotion.id),
                              );
                              if (isDuplicate) {
                                setModalState(() {
                                  errorMessage =
                                      'Mã "$normalizedCode" đã tồn tại trong hệ thống.';
                                });
                                return;
                              }

                              // Cập nhật MockStore.promotions
                              setState(() {
                                if (isEditing) {
                                  final idx = MockStore.promotions.indexWhere(
                                    (p) => p.id == promotion.id,
                                  );
                                  if (idx >= 0) {
                                    MockStore.promotions[idx] = Promotion(
                                      id: promotion.id,
                                      code: normalizedCode,
                                      discountPercent: discountVal,
                                      expiryDate: selectedDate,
                                      isActive: isActive,
                                    );
                                  }
                                } else {
                                  MockStore.promotions.add(
                                    Promotion(
                                      id: 'p${DateTime.now().millisecondsSinceEpoch}',
                                      code: normalizedCode,
                                      discountPercent: discountVal,
                                      expiryDate: selectedDate,
                                      isActive: isActive,
                                    ),
                                  );
                                }
                              });

                              Navigator.pop(modalContext);

                              ScaffoldMessenger.of(
                                context,
                              ).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Đã cập nhật mã "$normalizedCode"'
                                        : 'Đã tạo mới mã "$normalizedCode"',
                                  ),
                                  backgroundColor: AppTheme.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              isEditing ? 'Lưu thay đổi' : 'Tạo khuyến mãi',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Xác nhận xóa khuyến mãi
  Future<void> _confirmDelete(Promotion promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Xóa khuyến mãi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Bạn có chắc chắn muốn xóa mã ưu đãi '),
              TextSpan(
                text: '"${promotion.code}"',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.error,
                ),
              ),
              const TextSpan(
                text:
                    ' khỏi hệ thống? Khách hàng sẽ không thể sử dụng mã này nữa.',
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        MockStore.promotions.removeWhere((p) => p.id == promotion.id);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa thành công mã "${promotion.code}"'),
          backgroundColor: AppTheme.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final promotions = MockStore.promotions;
    final now = DateTime.now();
    final activeCount = promotions.where((p) => p.isValidAt(now)).length;

    return Scaffold(
      drawer: const AdminDrawer(selectedIndex: 2),
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Quản lý khuyến mãi'),
        actions: [if (Navigator.canPop(context)) const BackButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPromotionSheet(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm mã',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: promotions.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
              children: [
                // ─── Header tổng quan Nhom1_DatSanTheThao ──────────────────────────
                _buildOverviewHeader(
                  total: promotions.length,
                  active: activeCount,
                ),
                const SizedBox(height: 18),

                // ─── Tiêu đề danh sách ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Danh sách mã giảm giá',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${promotions.length} mã',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Danh sách thẻ khuyến mãi ────────────────────────
                ...promotions.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildAdminPromoCard(p),
                  ),
                ),
              ],
            ),
    );
  }

  // Thẻ tổng quan
  Widget _buildOverviewHeader({required int total, required int active}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảng điều khiển khuyến mãi',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Quản lý và thiết lập mã ưu đãi khách hàng',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _openPromotionSheet(),
                icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
                tooltip: 'Thêm khuyến mãi mới',
              ),
            ],
          ),
          const Divider(height: 22, color: AppTheme.border),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Tổng mã',
                  value: '$total',
                  icon: Icons.confirmation_number_outlined,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.border),
              Expanded(
                child: _buildStatItem(
                  label: 'Đang mở',
                  value: '$active',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.primary,
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.border),
              Expanded(
                child: _buildStatItem(
                  label: 'Tạm ẩn/Hết hạn',
                  value: '${total - active}',
                  icon: Icons.pause_circle_outline_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Thẻ hiển thị mã khuyến mãi trong danh sách Admin
  Widget _buildAdminPromoCard(Promotion p) {
    final isExpired = p.isExpiredAt(DateTime.now());
    final isEffective = p.isActive && !isExpired;
    final expiryFormatted =
        '${p.expiryDate.day.toString().padLeft(2, '0')}/${p.expiryDate.month.toString().padLeft(2, '0')}/${p.expiryDate.year}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEffective ? AppTheme.border : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon tỷ lệ giảm
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isEffective
                        ? AppTheme.primaryLight
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEffective
                          ? AppTheme.primary.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${p.discountPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isEffective
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Thông tin mã
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            p.code,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isEffective
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          _buildStatusBadge(
                            isActive: p.isActive,
                            isExpired: isExpired,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chiết khấu: ${p.discountPercent.toStringAsFixed(0)}% tổng hóa đơn',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: isExpired
                                ? AppTheme.error
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Hết hạn: $expiryFormatted',
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpired
                                    ? AppTheme.error
                                    : AppTheme.textSecondary,
                                fontWeight: isExpired
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
            const Divider(height: 20, color: AppTheme.border),

            // Nút thao tác: Sửa và Xóa
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Nút chỉnh sửa
                OutlinedButton.icon(
                  onPressed: () => _openPromotionSheet(promotion: p),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Chỉnh sửa'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(80, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: AppTheme.primary, width: 1),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Nút xóa
                IconButton(
                  onPressed: () => _confirmDelete(p),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppTheme.error,
                  tooltip: 'Xóa mã',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Huy hiệu trạng thái
  Widget _buildStatusBadge({required bool isActive, required bool isExpired}) {
    String text;
    Color bgColor;
    Color textColor;

    if (!isActive) {
      text = 'Tạm dừng';
      bgColor = Colors.grey.shade200;
      textColor = AppTheme.textSecondary;
    } else if (isExpired) {
      text = 'Đã hết hạn';
      bgColor = const Color(0xFFFEE2E2);
      textColor = AppTheme.error;
    } else {
      text = 'Đang kích hoạt';
      bgColor = AppTheme.primaryLight;
      textColor = AppTheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // Giao diện khi danh sách trống
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
              'Chưa có mã khuyến mãi nào',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hệ thống hiện chưa có mã giảm giá. Hãy tạo mã khuyến mãi đầu tiên cho khách hàng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openPromotionSheet(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm khuyến mãi ngay'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 46)),
            ),
          ],
        ),
      ),
    );
  }
}
