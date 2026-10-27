import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/mock_store.dart';
import '../../models/promotion.dart';
import '../../utils/app_theme.dart';
import 'admin_drawer.dart';

/// Màn hình Quản lý Khuyến mãi dành cho Quản trị viên (Admin).
/// Hỗ trợ Xem danh sách, Lọc, Thêm mới, Chỉnh sửa, Bật/Tắt nhanh,
/// Sao chép mã và Xóa mã khuyến mãi.
class ManagePromotionScreen extends StatefulWidget {
  const ManagePromotionScreen({super.key});

  @override
  State<ManagePromotionScreen> createState() => _ManagePromotionScreenState();
}

class _ManagePromotionScreenState extends State<ManagePromotionScreen> {
  // Màu bổ sung theo thiết kế mới
  static const Color _mint = Color(0xFFA7F3D0);
  static const Color _mintText = Color(0xFF065F46);
  static const Color _fieldTint = Color(0xFFF0F7F4);
  static const Color _cardBg = Colors.white;
  static const Color _pageBg = Color(0xFFF5F7FA);
  static const Color _danger = Color(0xFFEF4444);

  // ───────────────────────── Helpers ─────────────────────────

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  int _daysLeft(DateTime expiry) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(expiry.year, expiry.month, expiry.day);
    return end.difference(today).inDays;
  }

  InputDecoration _fieldDecoration({required String hint, String? suffix}) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      suffixText: suffix,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(_mint, 1.2),
      enabledBorder: border(_mint, 1.2),
      focusedBorder: border(AppTheme.primary, 1.8),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: AppTheme.textPrimary,
      ),
    ),
  );

  Widget _quickChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: _mint,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppTheme.primary : _mint),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? _mintText : AppTheme.textSecondary,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showSnack(String message, {Color? color}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color ?? AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ───────────────────────── Thêm / Sửa ─────────────────────────

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
            void clearError() {
              if (errorMessage != null) {
                setModalState(() => errorMessage = null);
              }
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh gạt modal
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _mint,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Tiêu đề
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _fieldTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.add_rounded,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                              const SizedBox(height: 3),
                              Text(
                                isEditing
                                    ? 'Cập nhật thông tin chiết khấu và hạn dùng'
                                    : 'Thiết lập mã giảm giá cho khách hàng',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Thông báo lỗi nếu có
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: _danger,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: _danger,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Mã khuyến mãi
                    _fieldLabel('Mã khuyến mãi'),
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9_-]'),
                        ),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      onChanged: (_) => clearError(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      decoration: _fieldDecoration(
                        hint: 'Ví dụ: HELLO2026, SAN20',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mức giảm giá
                    _fieldLabel('Mức giảm giá (%)'),
                    TextField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        clearError();
                        setModalState(() {});
                      },
                      decoration: _fieldDecoration(
                        hint: 'Nhập số phần trăm (1 - 100)',
                        suffix: '%',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [5, 10, 15, 20, 30, 50].map((v) {
                        final current = double.tryParse(
                          discountController.text.trim(),
                        );
                        return _quickChip(
                          label: '$v%',
                          selected: current == v.toDouble(),
                          onTap: () {
                            discountController.text = '$v';
                            clearError();
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Hạn sử dụng
                    _fieldLabel('Hạn sử dụng'),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
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
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _mint, width: 1.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(selectedDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Text(
                              'Đổi ngày',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          [
                            {'label': '+7 ngày', 'days': 7},
                            {'label': '+30 ngày', 'days': 30},
                            {'label': '+90 ngày', 'days': 90},
                            {'label': '+180 ngày', 'days': 180},
                          ].map((item) {
                            final days = item['days'] as int;
                            final now = DateTime.now();
                            final target = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            ).add(Duration(days: days));
                            final isSame =
                                target.year == selectedDate.year &&
                                target.month == selectedDate.month &&
                                target.day == selectedDate.day;
                            return _quickChip(
                              label: item['label'] as String,
                              selected: isSame,
                              onTap: () =>
                                  setModalState(() => selectedDate = target),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Switch: Trạng thái kích hoạt
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _fieldTint,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _mint, width: 1.2),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppTheme.primary,
                          title: const Text(
                            'Kích hoạt mã',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            isActive
                                ? 'Khách hàng có thể sử dụng mã này'
                                : 'Tạm ẩn mã, khách hàng không thể dùng',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          value: isActive,
                          onChanged: (val) =>
                              setModalState(() => isActive = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Nút Hủy và Lưu
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: ElevatedButton(
                            style: _filledButtonStyle(_danger),
                            onPressed: () => Navigator.pop(modalContext),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: ElevatedButton(
                            style: _filledButtonStyle(AppTheme.primary),
                            onPressed: () {
                              final normalizedCode = codeController.text
                                  .trim()
                                  .toUpperCase();
                              final discountVal = double.tryParse(
                                discountController.text.trim(),
                              );

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
                                      usedCount: promotion.usedCount,
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
                              _showSnack(
                                isEditing
                                    ? 'Đã cập nhật mã "$normalizedCode"'
                                    : 'Đã tạo mới mã "$normalizedCode"',
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

    codeController.dispose();
    discountController.dispose();
  }

  ButtonStyle _filledButtonStyle(Color color, {double height = 52}) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    );
  }

  // ───────────────────────── Xóa / Bật tắt ─────────────────────────

  Future<void> _confirmDelete(Promotion promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: _danger,
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
                  color: _danger,
                ),
              ),
              const TextSpan(
                text:
                    ' khỏi hệ thống? Khách hàng sẽ không thể sử dụng mã này nữa.',
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          ElevatedButton(
            style: _filledButtonStyle(Colors.grey.shade500, height: 42),
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: _filledButtonStyle(_danger, height: 42),
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
      _showSnack(
        'Đã xóa thành công mã "${promotion.code}"',
        color: AppTheme.error,
      );
    }
  }

  void _toggleActive(Promotion p, bool value) {
    final idx = MockStore.promotions.indexWhere((e) => e.id == p.id);
    if (idx < 0) return;
    setState(() {
      MockStore.promotions[idx] = Promotion(
        id: p.id,
        code: p.code,
        discountPercent: p.discountPercent,
        expiryDate: p.expiryDate,
        isActive: value,
        usedCount: p.usedCount,
      );
    });
    _showSnack(
      value ? 'Đã kích hoạt mã "${p.code}"' : 'Đã tạm dừng mã "${p.code}"',
    );
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final all = MockStore.promotions;
    final now = DateTime.now();
    final activeCount = all.where((p) => p.isValidAt(now)).length;

    return Scaffold(
      drawer: AdminDrawer(
        selectedIndex: 2,
        pendingVenueCount: MockStore.venues
            .where((v) => v.status == 'pending')
            .length,
      ),
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Quản lý khuyến mãi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [if (Navigator.canPop(context)) const BackButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPromotionSheet(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm mã',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: all.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _buildOverviewHeader(total: all.length, active: activeCount),
                const SizedBox(height: 20),

                // Tiêu đề danh sách
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
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
                        '${all.length} mã',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                ...all.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildAdminPromoCard(p),
                  ),
                ),
              ],
            ),
    );
  }

  // Thẻ tổng quan (nền xanh, chữ trắng)
  Widget _buildOverviewHeader({required int total, required int active}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            Color.alphaBlend(
              Colors.black.withValues(alpha: 0.12),
              AppTheme.primary,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bảng điều khiển khuyến mãi',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quản lý và thiết lập mã ưu đãi khách hàng',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStatItem(label: 'Tổng mã', value: '$total'),
              ),
              Expanded(
                child: _buildStatItem(label: 'Đang mở', value: '$active'),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Tạm ẩn /\nhết hạn',
                  value: '${total - active}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.25,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Thẻ mã khuyến mãi
  Widget _buildAdminPromoCard(Promotion p) {
    final isExpired = p.isExpiredAt(DateTime.now());
    final isEffective = p.isActive && !isExpired;
    final daysLeft = _daysLeft(p.expiryDate);

    String remainText;
    if (isExpired) {
      remainText = 'Đã hết hạn';
    } else if (daysLeft == 0) {
      remainText = 'Hết hạn hôm nay';
    } else {
      remainText = 'Còn $daysLeft ngày';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEffective ? const Color(0xFFE8ECF2) : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ô tỷ lệ giảm
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isEffective ? _mint : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${p.discountPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isEffective ? _mintText : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Thông tin + nút
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            p.code,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: isEffective
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          _buildStatusBadge(
                            isActive: p.isActive,
                            isExpired: isExpired,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Chiết khấu: ${p.discountPercent.toStringAsFixed(0)}% tổng hóa đơn',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Hết hạn: ${_formatDate(p.expiryDate)}  •  $remainText',
                  style: TextStyle(
                    fontSize: 13,
                    color: isExpired ? _danger : AppTheme.textSecondary,
                    fontWeight: isExpired ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      size: 15,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Đã dùng: ${p.usedCount} lượt',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Bật / tắt nhanh
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.isActive ? 'Đang bật' : 'Đang tắt',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: p.isActive,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppTheme.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) => _toggleActive(p, v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Nút Chỉnh sửa / Xóa
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: _filledButtonStyle(AppTheme.primary, height: 44),
                        onPressed: () => _openPromotionSheet(promotion: p),
                        child: const Text('Chỉnh sửa'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: _filledButtonStyle(_danger, height: 44),
                        onPressed: () => _confirmDelete(p),
                        child: const Text('Xóa'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Huy hiệu trạng thái (dạng viên thuốc)
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
      textColor = _danger;
    } else {
      text = 'Đang kích hoạt';
      bgColor = _mint;
      textColor = _mintText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
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
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: _mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 54,
                color: _mintText,
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
              style: _filledButtonStyle(AppTheme.primary, height: 48),
            ),
          ],
        ),
      ),
    );
  }
}
