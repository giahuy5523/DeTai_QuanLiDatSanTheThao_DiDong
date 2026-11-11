import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/mock_store.dart';
import '../../data/booking_repository.dart';
import '../../data/promotion_repository.dart';
import '../../data/venue_repository.dart';
import '../../models/promotion.dart';
import '../../utils/app_theme.dart';
import 'admin_drawer.dart';

// Màn hình Quản lý Khuyến mãi dành cho Quản trị viên (Admin).
// Hỗ trợ Xem danh sách, Lọc, Thêm mới, Chỉnh sửa, Bật/Tắt nhanh,
// Sao chép mã và Xóa mã khuyến mãi. Dữ liệu lưu trong SQLite.
class ManagePromotionScreen extends StatefulWidget {
  const ManagePromotionScreen({super.key});

  @override
  State<ManagePromotionScreen> createState() => _ManagePromotionScreenState();
}

class _ManagePromotionScreenState extends State<ManagePromotionScreen> {
  // Dữ liệu đọc từ SQLite.
  List<Promotion> _promotions = const [];
  int _pendingVenueCount = 0;
  bool _isLoading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final promotions = await PromotionRepository.loadAll();
      // Số sân chờ duyệt chỉ để hiển thị trên drawer: lỗi ở đây không chặn màn.
      var pending = _pendingVenueCount;
      try {
        final venues = await VenueRepository.loadVenues();
        pending = venues.where((v) => v.status == 'pending').length;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _promotions = promotions;
        _pendingVenueCount = pending;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Không thể tải danh sách khuyến mãi. Vui lòng thử lại.';
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _load();
  }

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
    // Viền, màu nền, padding lấy từ AppTheme.lightTheme.inputDecorationTheme.
    return InputDecoration(hintText: hint, suffixText: suffix, isDense: true);
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
      selectedColor: AppTheme.primaryLight,
      backgroundColor: AppTheme.cardColor,
      side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? AppTheme.primaryDark : AppTheme.textSecondary,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showSnack(
    String message, {
    Color? color,
    IconData icon = Icons.check_circle_outline,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
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

  void _showError(String message) =>
      _showSnack(message, color: AppTheme.error, icon: Icons.cancel_outlined);

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
    ModalRoute<void>? sheetRoute;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        sheetRoute = ModalRoute.of<void>(ctx);
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            void clearError() {
              if (errorMessage != null) {
                setModalState(() => errorMessage = null);
              }
            }

            return Container(
              // Giới hạn chiều cao: nội dung dài hơn thì cuộn bên trong,
              // không kéo sheet phủ kín màn hình.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.9,
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.cardColor,
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
                          color: AppTheme.primaryLight,
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
                            color: AppTheme.primaryLight,
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
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
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
                          border: Border.all(
                            color: AppTheme.border,
                            width: 1.2,
                          ),
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
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border, width: 1.2),
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
                            style: _filledButtonStyle(AppTheme.error),
                            onPressed: () => Navigator.pop(modalContext),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: ElevatedButton(
                            style: _filledButtonStyle(AppTheme.primary),
                            onPressed: () async {
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

                              bool success = false;
                              if (isEditing) {
                                final updatedPromo = Promotion(
                                  id: promotion.id,
                                  code: normalizedCode,
                                  discountPercent: discountVal,
                                  expiryDate: selectedDate,
                                  isActive: isActive,
                                  usedCount: promotion.usedCount,
                                  usageHistory: promotion.usageHistory,
                                );
                                success =
                                    await BookingRepository.updatePromotion(
                                      updatedPromo,
                                    );
                              } else {
                                final newPromo = Promotion(
                                  id: 'p${DateTime.now().millisecondsSinceEpoch}',
                                  code: normalizedCode,
                                  discountPercent: discountVal,
                                  expiryDate: selectedDate,
                                  isActive: isActive,
                                );
                                success =
                                    await BookingRepository.createPromotion(
                                      newPromo,
                                    );
                              }

                              if (!success) {
                                setModalState(() {
                                  errorMessage =
                                      'Không thể lưu mã khuyến mãi. Vui lòng kiểm tra lại.';
                                });
                                return;
                              }

                              if (!mounted || !modalContext.mounted) return;
                              Navigator.pop(modalContext);
                              await _load();
                              if (!mounted) return;
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

    await sheetRoute?.completed;
    codeController.dispose();
    discountController.dispose();
  }

  ButtonStyle _filledButtonStyle(Color color, {double height = 52}) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: color.withValues(alpha: 0.4),
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
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          ElevatedButton(
            style: _filledButtonStyle(AppTheme.textSecondary, height: 42),
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: _filledButtonStyle(AppTheme.error, height: 42),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    final success = await BookingRepository.deletePromotion(promotion.id);
    if (!mounted) return;

    if (!success) {
      setState(() => _busy = false);
      _showError('Không thể xóa mã "${promotion.code}". Vui lòng thử lại.');
      return;
    }

    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    _showSnack(
      'Đã xóa thành công mã "${promotion.code}"',
      color: AppTheme.error,
    );
  }

  Future<void> _toggleActive(Promotion p, bool value) async {
    setState(() => _busy = true);
    final success = await BookingRepository.togglePromotionActive(p.id, value);
    if (!mounted) return;

    if (!success) {
      setState(() => _busy = false);
      _showError('Không thể cập nhật trạng thái mã "${p.code}"');
      return;
    }

    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    _showSnack(
      value ? 'Đã kích hoạt mã "${p.code}"' : 'Đã tạm dừng mã "${p.code}"',
    );
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final all = _promotions;
    final now = DateTime.now();
    final activeCount = all.where((p) => p.isValidAt(now)).length;

    return Scaffold(
      drawer: AdminDrawer(
        selectedIndex: 2,
        pendingVenueCount: _pendingVenueCount,
      ),
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Quản lý khuyến mãi',
          style: TextStyle(color: Colors.white),
        ),
        actions: [if (Navigator.canPop(context)) const BackButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading || _error != null
            ? null
            : () => _openPromotionSheet(),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(_error!)
          : all.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
            ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
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
      key: ValueKey('promo-${p.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEffective ? AppTheme.border : AppTheme.border,
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
              color: isEffective ? AppTheme.primaryLight : AppTheme.border,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${p.discountPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isEffective
                      ? AppTheme.primaryDark
                      : AppTheme.textSecondary,
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
                    color: isExpired ? AppTheme.error : AppTheme.textSecondary,
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
                        onChanged: _busy ? null : (v) => _toggleActive(p, v),
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
                        onPressed: _busy
                            ? null
                            : () => _openPromotionSheet(promotion: p),
                        child: const Text('Chỉnh sửa'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: _filledButtonStyle(AppTheme.error, height: 44),
                        onPressed: _busy ? null : () => _confirmDelete(p),
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
      bgColor = AppTheme.border;
      textColor = AppTheme.textSecondary;
    } else if (isExpired) {
      text = 'Đã hết hạn';
      bgColor = AppTheme.error.withValues(alpha: 0.12);
      textColor = AppTheme.error;
    } else {
      text = 'Đang kích hoạt';
      bgColor = AppTheme.primaryLight;
      textColor = AppTheme.primaryDark;
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
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 54,
                color: AppTheme.primaryDark,
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
