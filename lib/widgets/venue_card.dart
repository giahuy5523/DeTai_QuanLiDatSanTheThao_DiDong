import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../utils/app_theme.dart';

/// Thẻ hiển thị thông tin sân thể thao theo phong cách Nhom1_DatSanTheThao.
class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  IconData _iconFor(String sportType) {
    switch (sportType) {
      case 'Bóng đá':
        return Icons.sports_soccer;
      case 'Bóng rổ':
        return Icons.sports_basketball;
      case 'Tennis':
      case 'Cầu lông':
        return Icons.sports_tennis;
      case 'Bóng chuyền':
        return Icons.sports_volleyball;
      default:
        return Icons.sports;
    }
  }

  Color _colorFor(String sportType) {
    switch (sportType) {
      case 'Bóng đá':
        return const Color(0xFF16A34A);
      case 'Bóng rổ':
        return const Color(0xFFEA580C);
      case 'Tennis':
        return const Color(0xFF0EA5E9);
      case 'Cầu lông':
        return const Color(0xFF7C3AED);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sportColor = _colorFor(venue.sportType);
    final sportBg = sportColor.withValues(alpha: 0.1);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Thumbnail ────────────────────────────────────
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: sportBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconFor(venue.sportType),
                  size: 40,
                  color: sportColor,
                ),
              ),
              const SizedBox(width: 14),

              // ─── Info ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sport type badge + status
                    Row(
                      children: [
                        _SportBadge(label: venue.sportType, color: sportColor),
                        const Spacer(),
                        if (venue.status == 'approved') _OpenBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Name
                    Text(
                      venue.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Address
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            venue.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Rating + Price row
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          venue.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_formatPrice(venue.pricePerHour)} đ/giờ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppTheme.primary,
                              ),
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
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }
}

class _SportBadge extends StatelessWidget {
  const _SportBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Còn sân',
        style: TextStyle(
          color: AppTheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
