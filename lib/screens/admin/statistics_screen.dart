import 'package:flutter/material.dart';
import 'package:sportfield_booking/screens/admin/admin_shell_layout.dart';
import '../../data/mock_store.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookings = MockStore.bookings;
    final approvedVenues = MockStore.venues.where((v) => v.status == 'approved').length;
    final pendingVenues = MockStore.venues.where((v) => v.status == 'pending').length;
    final totalRevenue = bookings
        .where((b) => b.status == 'confirmed' || b.status == 'completed')
        .fold<double>(0, (sum, b) => sum + b.totalAmount);

    return AdminShellLayout(
      title: 'Thống kê toàn hệ thống',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tổng quan',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _metric(
                context,
                'Lượt đặt sân',
                '${bookings.length}',
                Icons.calendar_month,
              ),
              _metric(
                context,
                'Sân đã duyệt',
                '$approvedVenues',
                Icons.sports,
              ),
              _metric(
                context,
                'Sân chờ duyệt',
                '$pendingVenues',
                Icons.pending_actions,
              ),
              _metric(
                context,
                'Doanh thu mô phỏng',
                '${totalRevenue.toStringAsFixed(0)} đ',
                Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trạng thái đặt sân',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    'pending',
                    'confirmed',
                    'completed',
                    'cancelled',
                  ].map(
                    (status) => _statusBar(
                      status,
                      bookings.where((b) => b.status == status).length,
                      bookings.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(title, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(String status, int count, int total) {
    final labels = <String, String>{
      'pending': 'Chờ xác nhận',
      'confirmed': 'Đã xác nhận',
      'completed': 'Hoàn tất',
      'cancelled': 'Đã hủy',
    };
    final progress = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(labels[status] ?? status)),
              Text('$count'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }
}
