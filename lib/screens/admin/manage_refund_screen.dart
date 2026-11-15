import 'package:flutter/material.dart';

import '../../data/booking_repository.dart';
import '../../utils/app_theme.dart';
import '../../data/account_service.dart';
import '../../data/mock_store.dart';
import 'admin_drawer.dart';

/// Admin xác nhận kết quả hoàn tiền mô phỏng cho các đơn đã hủy.
class ManageRefundScreen extends StatefulWidget {
  const ManageRefundScreen({super.key});

  @override
  State<ManageRefundScreen> createState() => _ManageRefundScreenState();
}

class _ManageRefundScreenState extends State<ManageRefundScreen> {
  late Future<List<PendingRefund>> _future;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _future = BookingRepository.getPendingRefunds();
  }

  void _reload() {
    setState(() {
      _future = BookingRepository.getPendingRefunds();
    });
  }

  Future<void> _onRefresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _resolve(PendingRefund refund, {required bool success}) async {
    if (MockStore.currentUser?.role != 'admin' ||
        AccountService.expireSessionIfNeeded()) {
      return;
    }

    // Chặn bấm nhiều lần trên cùng một khoản hoàn tiền.
    if (_busy.contains(refund.bookingId)) return;
    setState(() => _busy.add(refund.bookingId));

    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = success
          ? await BookingRepository.completeRefund(refund.bookingId)
          : await BookingRepository.failRefund(refund.bookingId);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: !ok
              ? AppTheme.warning
              : success
              ? AppTheme.success
              : AppTheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  !ok
                      ? 'Khoản này đã được xử lý trước đó.'
                      : success
                      ? 'Đã xác nhận hoàn tiền thành công.'
                      : 'Đã đánh dấu hoàn tiền thất bại.',
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Text('Lỗi lưu dữ liệu. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(refund.bookingId));
      if (mounted) _reload();
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Không rõ';
    final d = time.day.toString().padLeft(2, '0');
    final m = time.month.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$d/$m/${time.year} $h:$min';
  }

  String _formatMoney(num value) {
    final s = value.round().toString();
    final grouped = s.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$grouped đ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Hoàn tiền chờ xác nhận',
          style: TextStyle(color: Colors.white),
        ),
      ),
      drawer: const AdminDrawer(selectedIndex: 3),
      body: FutureBuilder<List<PendingRefund>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline_rounded,
              iconColor: AppTheme.error,
              title: 'Không tải được danh sách hoàn tiền',
              subtitle: 'Vui lòng kiểm tra kết nối và thử lại.',
              action: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            );
          }

          final items = snapshot.data ?? const <PendingRefund>[];
          if (items.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _onRefresh,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: const _StateMessage(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppTheme.success,
                      title: 'Không có khoản nào đang chờ',
                      subtitle: 'Tất cả hoàn tiền đã được xử lý.',
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _onRefresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: items.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _buildSummary(items);
                return _buildRefundCard(items[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(List<PendingRefund> items) {
    final total = items.fold<double>(0, (sum, r) => sum + r.refundAmount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${items.length} khoản chờ xác nhận',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatMoney(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundCard(PendingRefund refund) {
    final busy = _busy.contains(refund.bookingId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: mã đơn + trạng thái
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đơn ${refund.bookingId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Chờ xác nhận',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Số tiền hoàn
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Số tiền hoàn',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _formatMoney(refund.refundAmount),
                    style: const TextStyle(
                      color: AppTheme.primaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Khách',
              value: refund.userId,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event_busy_outlined,
              label: 'Hủy lúc',
              value: _formatTime(refund.cancelledAt),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: AppTheme.border),
            ),

            // Hành động
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _resolve(refund, success: false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Thất bại'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(
                        color: busy
                            ? AppTheme.border
                            : AppTheme.error.withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                      minimumSize: const Size(0, 46),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _resolve(refund, success: true),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.textSecondary,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Hoàn tất'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
