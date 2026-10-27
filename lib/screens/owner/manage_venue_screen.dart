import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../screens/owner/venue_bookings_screen.dart';
import '../../screens/owner/venue_update_screen.dart';
import '../../data/mock_store.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';

/// Hiển thị ảnh sân từ asset, URL hoặc file chọn từ máy.
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
  String _selectedFilter = 'all'; // 'all', 'approved', 'pending'

  @override
  Widget build(BuildContext context) {
    final allOwnVenues = MockStore.venues
        .where((v) => v.ownerId == MockStore.currentUser?.id)
        .toList();

    final totalVenues = allOwnVenues.length;
    final pendingVenues = allOwnVenues
        .where((v) => v.status == 'pending')
        .length;

    // Tính số lịch hôm nay
    final today = DateTime.now();
    final todayBookingsCount = MockStore.bookings.where((b) {
      if (!allOwnVenues.any((v) => v.id == b.venueId)) return false;
      return b.date.year == today.year &&
          b.date.month == today.month &&
          b.date.day == today.day;
    }).length;

    final filteredVenues = allOwnVenues.where((venue) {
      if (_selectedFilter == 'approved') return venue.status == 'approved';
      if (_selectedFilter == 'pending') return venue.status == 'pending';
      return true;
    }).toList();

    const primaryGreen = Color(0xFF0F8B5F);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Quản lý sân và lịch đặt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              MockStore.logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            AppRoutes.uploadVenue,
          );

          if (!mounted) return;

          if (result == true) {
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'Đăng ký sân',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thống kê 3 ô trên cùng
          Row(
            children: [
              Expanded(child: _buildStatCard('$totalVenues', 'Sân')),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard('$todayBookingsCount', 'Lịch hôm nay'),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('$pendingVenues', 'Chờ duyệt')),
            ],
          ),
          const SizedBox(height: 16),
          // Các chip lọc trạng thái
          Row(
            children: [
              _buildFilterChip('Tất cả', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Đã duyệt', 'approved'),
              const SizedBox(width: 8),
              _buildFilterChip('Chờ duyệt', 'pending'),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredVenues.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('Bạn chưa có sân nào được đăng ký.')),
            )
          else
            ...filteredVenues.map((venue) => _buildVenueCard(context, venue)),
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
    const primaryGreen = Color(0xFF0F8B5F);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryGreen,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade800,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryGreen : Colors.grey.shade300,
        ),
      ),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  Widget _buildVenueCard(BuildContext context, Venue venue) {
    final isApproved = venue.status == 'approved';
    const primaryGreen = Color(0xFF0F8B5F);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phần ảnh sân, huy hiệu trạng thái và số ảnh
          Builder(
            builder: (context) {
              final images = MockStore.imageUrlsOf(venue.id);
              return SizedBox(
                height: 130,
                width: double.infinity,
                child: Stack(
                  children: [
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
                    // Huy hiệu trạng thái (giữ nguyên code cũ)
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
                              ? primaryGreen
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                // Các nút chức năng
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        // Điều hướng sang màn hình Cập nhật thông tin sân riêng
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  VenueUpdateScreen(venue: venue),
                            ),
                          );
                          if (result == true) {
                            setState(() {});
                          }
                        },
                        child: const Text('Cập nhật'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        // Điều hướng sang màn hình Quản lý lịch đặt riêng
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  VenueBookingsScreen(venueId: venue.id),
                            ),
                          );
                        },
                        child: const Text('Lịch đặt'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.manageService,
                          arguments: venue.id,
                        ),
                        child: const Text('Dịch vụ'),
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

  String _statusLabel(String status) {
    return {
          'pending': 'Chờ duyệt',
          'approved': 'Đã duyệt',
          'rejected': 'Từ chối',
        }[status] ??
        status;
  }
}
