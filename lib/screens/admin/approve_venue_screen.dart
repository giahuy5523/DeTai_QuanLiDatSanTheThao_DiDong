import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/venue_image.dart';
import '../../data/mock_store.dart';
import '../../models/user.dart';
import '../../models/venue.dart';
import 'admin_drawer.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt sân mới'),
        actions: [if (Navigator.canPop(context)) const BackButton()],
      ),
      drawer: const AdminDrawer(selectedIndex: 1),
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.pending_actions_outlined,
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
                _infoRow(
                  Icons.location_on_outlined,
                  '${venue.address}, ${venue.district}, ${venue.city}',
                ),
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
            icon: Icons.hourglass_top_rounded,
            label: 'Chờ duyệt',
            background: AppTheme.warning,
            foreground: Colors.white,
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: _badge(
            icon: Icons.sports_outlined,
            label: venue.sportType,
            background: Colors.white,
            foreground: AppTheme.primaryDark,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: _badge(
            icon: Icons.payments_outlined,
            label: '${_formatPrice(venue.pricePerHour)} đ/giờ',
            background: AppTheme.primary,
            foreground: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _badge({
    required IconData icon,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerSection(AppUser owner) {
    final initial = owner.name.trim().isEmpty
        ? '?'
        : owner.name.trim().characters.first.toUpperCase();

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
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
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
          _infoRow(Icons.phone_outlined, owner.phone),
          const SizedBox(height: 8),
          _infoRow(Icons.email_outlined, owner.email),
        ],
      ),
    );
  }

  Widget _buildActions(Venue venue) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error, width: 1.2),
            ),
            onPressed: () => _confirmReject(venue),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Từ chối'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateStatus(venue, 'approved'),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Duyệt'),
          ),
        ),
      ],
    );
  }

  // Ảnh sân
  Widget _buildVenueImage(Venue venue) {
    final images = MockStore.imageUrlsOf(venue.id);
    if (images.isEmpty) {
      return _imagePlaceholder(Icons.image_not_supported_outlined);
    }

    return SizedBox(
      height: _imageHeight,
      width: double.infinity,
      child: VenueImage(
        source: images.first,
        placeholder: _imagePlaceholder(Icons.broken_image_outlined),
      ),
    );
  }

  Widget _imagePlaceholder(IconData icon) {
    return Container(
      height: _imageHeight,
      width: double.infinity,
      color: AppTheme.primaryLight,
      child: Center(
        child: Icon(
          icon,
          size: 52,
          color: AppTheme.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  // Thông tin sân
  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
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