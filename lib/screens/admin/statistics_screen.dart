import 'package:flutter/material.dart';
import '../../data/venue_repository.dart';
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

  // Số liệu tổng hợp từ SQLite.
  SystemStatistics? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await VenueRepository.loadSystemStatistics();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Không thể tải số liệu thống kê. Vui lòng thử lại.';
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _loadStats();
  }

  // Định dạng tiền: 120000 -> "120.000 đ"
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
    final stats = _stats;

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
        pendingVenueCount: stats?.venues('pending') ?? 0,
        // Quay lại từ màn khác (vd. duyệt sân) thì tính lại số liệu.
        onReturn: _loadStats,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || stats == null
          ? _buildError(_error ?? 'Không có dữ liệu thống kê.')
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: _buildContent(stats),
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
              style: const TextStyle(color: _muted),
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

  Widget _buildContent(SystemStatistics stats) {
    final totalBookings = stats.totalBookings;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
        _revenueCard('Doanh thu mô phỏng', _formatVnd(stats.revenue)),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _metric('Lượt đặt sân', '$totalBookings')),
              const SizedBox(width: 8),
              Expanded(
                child: _metric('Sân đã duyệt', '${stats.venues('approved')}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric('Sân chờ duyệt', '${stats.venues('pending')}'),
              ),
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
                (status) =>
                    _statusBar(status, stats.bookings(status), totalBookings),
              ),
            ],
          ),
        ),
      ],
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
      key: ValueKey('metric-$title'),
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
