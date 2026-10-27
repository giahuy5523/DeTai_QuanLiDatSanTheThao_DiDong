import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/venue_image.dart';
import '../../data/mock_store.dart';
import '../../models/user.dart';
import '../../models/venue.dart';
import 'admin_drawer.dart';

/// Carousel ảnh sân: vuốt ngang để xem, góc trên phải hiện "1 / 3 ảnh".
class _VenueImageCarousel extends StatefulWidget {
  const _VenueImageCarousel({
    super.key,
    required this.images,
    required this.height,
    required this.errorPlaceholder,
  });

  final List<String> images;
  final double height;
  final Widget errorPlaceholder;

  @override
  State<_VenueImageCarousel> createState() => _VenueImageCarouselState();
}

class _VenueImageCarouselState extends State<_VenueImageCarousel> {
  final PageController _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (context, index) => VenueImage(
              source: widget.images[index],
              placeholder: widget.errorPlaceholder,
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_current + 1} / $total ảnh',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ApproveVenueScreen extends StatefulWidget {
  const ApproveVenueScreen({super.key});

  @override
  State<ApproveVenueScreen> createState() => _ApproveVenueScreenState();
}

class _ApproveVenueScreenState extends State<ApproveVenueScreen> {
  static const double _imageHeight = 190;

  List<Venue> get _pending =>
      MockStore.venues.where((venue) => venue.status == 'pending').toList();

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    const primaryGreen = Color(0xFF0F8B5F);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Duyệt sân mới',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [if (Navigator.canPop(context)) const BackButton()],
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      drawer: AdminDrawer(
        selectedIndex: 1,
        pendingVenueCount: MockStore.venues
            .where((v) => v.status == 'pending')
            .length,
      ),
      body: pending.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: pending.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) return _buildSummaryHeader(pending.length);
                return _buildVenueCard(pending[index - 1]);
              },
            ),
    );
  }

  // Hiển thị số lượng sân và trạng thái không có sân
  Widget _buildSummaryHeader(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count sân đang chờ duyệt',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Kiểm tra thông tin trước khi phê duyệt',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                size: 52,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Đã duyệt xong!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Không còn sân chờ duyệt.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // Card từng sân
  Widget _buildVenueCard(Venue venue) {
    final owner = MockStore.users.cast<AppUser?>().firstWhere(
      (user) => user?.id == venue.ownerId,
      orElse: () => null,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(venue),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow('${venue.address}, ${venue.district}, ${venue.city}'),
                if (owner != null) ...[
                  const SizedBox(height: 16),
                  _buildOwnerSection(owner),
                ],
                const SizedBox(height: 16),
                _buildActions(venue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(Venue venue) {
    return Stack(
      children: [
        _buildVenueImage(venue),
        // Lớp gradient để chữ/badge nổi bật trên ảnh
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _badge(
            label: 'Chờ duyệt',
            background: Color(0xFFF59E0B),
            foreground: Colors.black,
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: _badge(
            label: venue.sportType,
            background: Colors.white,
            foreground: AppTheme.primaryDark,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: _badge(
            label: '${_formatPrice(venue.pricePerHour)} đ/giờ',
            background: AppTheme.primary,
            foreground: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _badge({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildOwnerSection(AppUser owner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ảnh đại diện mặc định của người dùng
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryLight,
                child: Icon(Icons.person, size: 24, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chủ sân',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      owner.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(owner.phone),
          const SizedBox(height: 8),
          _infoRow(owner.email),
        ],
      ),
    );
  }

  Widget _buildActions(Venue venue) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _confirmReject(venue),
            child: const Text('Từ chối'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _updateStatus(venue, 'approved'),
            child: const Text('Duyệt'),
          ),
        ),
      ],
    );
  }

  // Ảnh sân
  Widget _buildVenueImage(Venue venue) {
    final images = MockStore.imageUrlsOf(venue.id);
    if (images.isEmpty) {
      return _imagePlaceholder();
    }

    return _VenueImageCarousel(
      key: ValueKey('carousel_${venue.id}'),
      images: images,
      height: _imageHeight,
      errorPlaceholder: _imagePlaceholder(),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: _imageHeight,
      width: double.infinity,
      color: AppTheme.primaryLight,
    );
  }

  // Thông tin sân
  Widget _infoRow(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.35,
        color: AppTheme.textPrimary,
      ),
    );
  }

  String _formatPrice(num value) {
    final digits = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }

  // Nút từ chối
  Future<void> _confirmReject(Venue venue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Từ chối sân?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('Bạn có chắc muốn từ chối sân "${venue.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Từ chối',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) _updateStatus(venue, 'rejected');
  }

  void _updateStatus(Venue venue, String status) {
    final index = MockStore.venues.indexWhere((item) => item.id == venue.id);

    if (index < 0) return;

    MockStore.venues[index] = venue.copyWith(status: status);

    setState(() {});

    final approved = status == 'approved';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: approved ? AppTheme.success : AppTheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                approved ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  approved
                      ? 'Đã duyệt sân "${venue.name}".'
                      : 'Đã từ chối sân "${venue.name}".',
                ),
              ),
            ],
          ),
        ),
      );
  }
}
