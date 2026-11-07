import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../screens/owner/venue_bookings_screen.dart';
import '../../screens/owner/venue_update_screen.dart';
import '../../data/mock_store.dart';
import '../../data/account_service.dart';
import '../../data/venue_repository.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';

// Hiển thị ảnh sân từ asset, URL hoặc file chọn từ máy.
class VenueImageView extends StatelessWidget {
  const VenueImageView(
    this.source, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        kIsWeb ||
        source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('blob:');
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    }
    if (isNetwork) {
      return Image.network(
        source,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    }
    return Image.file(
      File(source),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
}

class ManageVenueScreen extends StatefulWidget {
  const ManageVenueScreen({super.key});

  @override
  State<ManageVenueScreen> createState() => _ManageVenueScreenState();
}

class _ManageVenueScreenState extends State<ManageVenueScreen> {
  static const _primaryGreen = Color(0xFF0F8B5F);

  String _selectedFilter = 'all'; // 'all', 'approved', 'pending'

  // Toàn bộ dữ liệu hiển thị đều đến từ SQLite.
  List<Venue> _venues = const [];
  int _todayBookingsCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reloadFromDatabase();
  }

  /// Đọc danh sách sân của chủ sân và số lịch đặt hôm nay từ SQLite.
  Future<void> _reloadFromDatabase() async {
    // Phiên đăng nhập do AccountService khôi phục từ bảng Session.
    final ownerId = MockStore.currentUser?.id;
    if (ownerId == null) {
      if (!mounted) return;
      setState(() {
        _venues = const [];
        _todayBookingsCount = 0;
        _isLoading = false;
        _error = 'Chưa đăng nhập. Vui lòng đăng nhập lại.';
      });
      return;
    }

    try {
      final results = await Future.wait([
        VenueRepository.loadVenues(ownerId: ownerId),
        VenueRepository.todayBookingCountForOwner(ownerId),
      ]);
      if (!mounted) return;
      setState(() {
        _venues = results[0] as List<Venue>;
        _todayBookingsCount = results[1] as int;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Không thể tải dữ liệu sân. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _logout() async {
    try {
      await AccountService.logout();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể đăng xuất. Vui lòng thử lại.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _openUploadVenue() async {
    final result = await Navigator.pushNamed(context, AppRoutes.uploadVenue);
    if (!mounted) return;
    if (result == true) await _reloadFromDatabase();
  }

  Future<void> _openUpdateVenue(Venue venue) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VenueUpdateScreen(venue: venue)),
    );
    if (!mounted) return;
    if (result == true) await _reloadFromDatabase();
  }

  Future<void> _openBookings(Venue venue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VenueBookingsScreen(venueId: venue.id)),
    );
    if (!mounted) return;
    // Chủ sân có thể đã hủy/xác nhận lịch nên số lịch hôm nay có thể đổi.
    await _reloadFromDatabase();
  }

  Future<void> _openServices(Venue venue) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.manageService,
      arguments: venue.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalVenues = _venues.length;
    final pendingVenues = _venues.where((v) => v.status == 'pending').length;

    final filteredVenues = _venues.where((venue) {
      if (_selectedFilter == 'approved') return venue.status == 'approved';
      if (_selectedFilter == 'pending') return venue.status == 'pending';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Quản lý sân và lịch đặt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        onPressed: _openUploadVenue,
        icon: const Icon(Icons.add),
        label: const Text(
          'Đăng ký sân',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(totalVenues, pendingVenues, filteredVenues),
    );
  }

  Widget _buildBody(
    int totalVenues,
    int pendingVenues,
    List<Venue> filteredVenues,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _reloadFromDatabase,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Thống kê 3 ô trên cùng
          Row(
            children: [
              Expanded(child: _buildStatCard('$totalVenues', 'Sân')),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard('$_todayBookingsCount', 'Lịch hôm nay'),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('$pendingVenues', 'Chờ duyệt')),
            ],
          ),
          const SizedBox(height: 16),
          // Các chip lọc trạng thái
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('Tất cả', 'all'),
              _buildFilterChip('Đã duyệt', 'approved'),
              _buildFilterChip('Chờ duyệt', 'pending'),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            _buildErrorState(_error!)
          else if (filteredVenues.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('Bạn chưa có sân nào được đăng ký.')),
            )
          else
            ...filteredVenues.map(_buildVenueCard),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _reloadFromDatabase();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006B3E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: _primaryGreen,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade800,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? _primaryGreen : Colors.grey.shade300,
        ),
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, softWrap: false),
        ),
      ),
    );
  }

  Widget _buildVenueCard(Venue venue) {
    final isApproved = venue.status == 'approved';
    final images = venue.imageUrls;

    return Card(
      key: ValueKey(venue.id),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phần ảnh sân, huy hiệu trạng thái và số ảnh
          SizedBox(
            height: 130,
            width: double.infinity,
            child: Stack(
              children: [
                if (images.isEmpty)
                  Container(
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                    ),
                  )
                else
                  PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (_, i) => VenueImageView(
                      images[i],
                      width: double.infinity,
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.blue.shade500,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Huy hiệu trạng thái
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? _primaryGreen
                          : const Color(0xFFFFB547),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(venue.status),
                      style: TextStyle(
                        color: isApproved ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                // Số ảnh
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${images.length} ảnh',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  venue.address,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '${venue.sportType} • ${venue.pricePerHour.toStringAsFixed(0)} đ/giờ',
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                // Các nút chức năng
                Row(
                  children: [
                    _buildActionButton(
                      'Cập nhật',
                      () => _openUpdateVenue(venue),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton('Lịch đặt', () => _openBookings(venue)),
                    const SizedBox(width: 8),
                    _buildActionButton('Dịch vụ', () => _openServices(venue)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    return {
          'pending': 'Chờ duyệt',
          'approved': 'Đã duyệt',
          'rejected': 'Từ chối',
        }[status] ??
        status;
  }
}
