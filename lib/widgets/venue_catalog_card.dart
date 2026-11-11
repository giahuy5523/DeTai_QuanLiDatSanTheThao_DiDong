import 'package:flutter/material.dart';

import '../models/venue.dart';
import '../utils/app_routes.dart';
import 'venue_image.dart';

/// Responsive list card shared by Home, Search and the complete venue list.
class VenueCatalogCard extends StatelessWidget {
  const VenueCatalogCard({super.key, required this.venue});
  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final image = venue.imageUrls.isEmpty ? null : venue.imageUrls.first;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.venueDetail, arguments: venue),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 156,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              if (image != null)
                VenueImage(source: image, placeholder: _placeholder())
              else
                _placeholder(),
              Positioned(
                left: 10, top: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(venue.sportType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              Positioned(
                right: 10, top: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0xFFE7F6EE), borderRadius: BorderRadius.circular(20)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    child: Text('Đã duyệt', style: TextStyle(color: Color(0xFF087451), fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(venue.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.place_outlined, size: 17, color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(child: Text(venue.address, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54))),
              ]),
              const SizedBox(height: 10),
              Text('${_price(venue.pricePerHour)} đ/giờ', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF087451), fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFE6F1EC),
    alignment: Alignment.center,
    child: const Icon(Icons.stadium_outlined, size: 42, color: Color(0xFF087451)),
  );

  static String _price(num value) {
    final digits = value.round().toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
      out.write(digits[i]);
    }
    return out.toString();
  }
}
