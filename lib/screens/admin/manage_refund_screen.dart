import 'package:flutter/material.dart';

import '../../data/booking_repository.dart';
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

  Future<void> _resolve(PendingRefund refund, {required bool success}) async {
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
          content: Text(
            !ok
                ? 'Khoản này đã được xử lý trước đó.'
                : success
                ? 'Đã xác nhận hoàn tiền thành công.'
                : 'Đã đánh dấu hoàn tiền thất bại.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Lỗi lưu dữ liệu. Vui lòng thử lại.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hoàn tiền chờ xác nhận')),
      drawer: const AdminDrawer(selectedIndex: 3),
      body: FutureBuilder<List<PendingRefund>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Không tải được danh sách hoàn tiền.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = snapshot.data ?? const <PendingRefund>[];
          if (items.isEmpty) {
            return const Center(
              child: Text('Không có khoản hoàn tiền nào đang chờ.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final refund = items[index];
              final busy = _busy.contains(refund.bookingId);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đơn ${refund.bookingId}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Khách: ${refund.userId}'),
                      Text('Hoàn: ${refund.refundAmount.toStringAsFixed(0)} đ'),
                      Text('Hủy lúc: ${_formatTime(refund.cancelledAt)}'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _resolve(refund, success: false),
                            child: const Text('Thất bại'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: busy
                                ? null
                                : () => _resolve(refund, success: true),
                            child: const Text('Hoàn tất'),
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
      ),
    );
  }
}
