import 'package:flutter/material.dart';
import 'package:sportfield_booking/screens/admin/admin_shell_layout.dart';
import '../../data/mock_store.dart';
import '../../models/venue.dart';

class ApproveVenueScreen extends StatefulWidget {
  const ApproveVenueScreen({super.key});

  @override
  State<ApproveVenueScreen> createState() => _ApproveVenueScreenState();
}

class _ApproveVenueScreenState extends State<ApproveVenueScreen> {
  List<Venue> get _pending =>
      MockStore.venues.where((v) => v.status == 'pending').toList();

  @override
  Widget build(BuildContext context) {
    final pending = _pending;

    return AdminShellLayout(
      title: 'Duyệt sân mới',
      body: pending.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: pending.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                if (i == 0) return _SummaryHeader(count: pending.length);
                final venue = pending[i - 1];
                return _VenueCard(
                  venue: venue,
                  onReject: () => _confirmAndUpdate(venue, 'rejected'),
                  onApprove: () => _confirmAndUpdate(venue, 'approved'),
                );
              },
            ),
    );
  }

  Future<void> _confirmAndUpdate(Venue venue, String status) async {
    final approved = status == 'approved';
    final scheme = Theme.of(context).colorScheme;
    final color = approved ? scheme.primary : scheme.error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            approved ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: color,
            size: 32,
          ),
        ),
        title: Text(
          approved ? 'Duyệt sân này?' : 'Từ chối sân này?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          approved
              ? ' "${venue.name}" sẽ được hiển thị cho người dùng đặt sân.'
              : ' "${venue.name}" sẽ bị từ chối và không được hiển thị.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(approved ? 'Duyệt' : 'Từ chối'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _updateStatus(venue, status);
    }
  }

  void _updateStatus(Venue venue, String status) {
    final index = MockStore.venues.indexWhere((v) => v.id == venue.id);
    if (index < 0) return;
    MockStore.venues[index] = Venue(
      id: venue.id,
      ownerId: venue.ownerId,
      name: venue.name,
      address: venue.address,
      sportType: venue.sportType,
      pricePerHour: venue.pricePerHour,
      imageUrls: venue.imageUrls,
      latitude: venue.latitude,
      longitude: venue.longitude,
      status: status,
      rating: venue.rating,
    );
    setState(() {});

    final approved = status == 'approved';
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: approved ? scheme.primary : scheme.error,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(
                approved ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(approved ? 'Đã duyệt sân.' : 'Đã từ chối sân.'),
              ),
            ],
          ),
        ),
      );
  }
}

// Số lượng sân chờ phê duyệt
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.pending_actions, color: Colors.white),
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
                    fontSize: 16,
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
}

// Card cho từng sân
class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.onReject,
    required this.onApprove,
  });

  final Venue venue;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoverImage(venue: venue),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        venue.address,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.sports_soccer,
                      label: venue.sportType,
                      background: scheme.primaryContainer,
                      foreground: scheme.onPrimaryContainer,
                    ),
                    _InfoChip(
                      icon: Icons.payments_outlined,
                      label: '${_formatPrice(venue.pricePerHour)} đ/giờ',
                      background: const Color(0xFFEFF6F1),
                      foreground: scheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Từ chối'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: scheme.error,
                          side: BorderSide(
                              color: scheme.error.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Duyệt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                        ),
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

  static String _formatPrice(num value) {
    final s = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

// Ảnh bìa kèm trạng thái và huy hiệu đánh giá
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = venue.imageUrls.isNotEmpty;

    final placeholder = Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.stadium_outlined,
        size: 48,
        color: scheme.primary.withValues(alpha: 0.6),
      ),
    );

    return AspectRatio(
      aspectRatio: 16 / 8,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            Image.network(
              venue.imageUrls.first,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
            )
          else
            placeholder,
          Positioned(
            top: 10,
            left: 10,
            child: _Badge(
              icon: Icons.hourglass_top,
              label: 'Chờ duyệt',
              background: const Color(0xFFFEF3C7),
              foreground: const Color(0xFF92400E),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _Badge(
              icon: Icons.star_rounded,
              label: venue.rating.toStringAsFixed(1),
              background: Colors.white,
              foreground: const Color(0xFF111827),
              iconColor: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor ?? foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// Trạng thái không có sân
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.task_alt, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'Không còn sân chờ duyệt.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Các sân mới sẽ xuất hiện ở đây khi chủ sân gửi yêu cầu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
