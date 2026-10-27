import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import 'admin_drawer.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const Color _green = Color(0xFF118C5F);
  static const Color _mint = Color(0xFFA7F3D0);
  static const Color _background = Color(0xFFF5F7FA);
  static const Color _ink = Color(0xFF12261F);
  static const Color _muted = Color(0xFF64748B);
  static const Color _red = Color(0xFFEF4444);
  static const Color _amber = Color(0xFFF59E0B);

  /// Định dạng tiền kiểu Việt Nam: 120000 -> "120.000 đ"
  String _formatVnd(double value) {
    final digits = value.toStringAsFixed(0);
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$formatted đ';
  }

  @override
  Widget build(BuildContext context) {
    final bookings = MockStore.bookings;
    final approvedVenues = MockStore.venues
        .where((v) => v.status == 'approved')
        .length;
    final pendingVenues = MockStore.venues
        .where((v) => v.status == 'pending')
        .length;
    final totalRevenue = bookings
        .where((b) => b.status == 'confirmed' || b.status == 'completed')
        .fold<double>(0, (sum, b) => sum + b.totalPrice);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Thống kê toàn hệ thống',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      drawer: AdminDrawer(
        selectedIndex: 0,
        pendingVenueCount: MockStore.venues.where((v) => v.status == 'pending').length,
        onReturn: () {
          if (mounted) setState(() {});
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Tổng quan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _revenueCard('Doanh thu mô phỏng', _formatVnd(totalRevenue)),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _metric('Lượt đặt sân', '${bookings.length}')),
                const SizedBox(width: 8),
                Expanded(child: _metric('Sân đã duyệt', '$approvedVenues')),
                const SizedBox(width: 8),
                Expanded(child: _metric('Sân chờ duyệt', '$pendingVenues')),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trạng thái đặt sân',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 14),
                ...['pending', 'confirmed', 'completed', 'cancelled'].map(
                  (status) => _statusBar(
                    status,
                    bookings.where((b) => b.status == status).length,
                    bookings.length,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueCard(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFFB7F0D8), fontSize: 13),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: _green,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.25),
          ),
        ],
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
    final colors = <String, Color>{
      'pending': _amber,
      'confirmed': _green,
      'completed': _green,
      'cancelled': _red,
    };
    final progress = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  labels[status] ?? status,
                  style: const TextStyle(color: _ink, fontSize: 14),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: _mint,
              valueColor: AlwaysStoppedAnimation<Color>(
                colors[status] ?? _green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
