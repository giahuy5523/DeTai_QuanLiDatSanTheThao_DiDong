import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../utils/app_routes.dart';
import '../../widgets/venue_image.dart';

class VenueListScreen extends StatefulWidget {
  const VenueListScreen({super.key});

  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> {
  String _sport = 'Tất cả';

  @override
  Widget build(BuildContext context) {
    final approved = MockStore.venues
        .where((venue) => venue.status == 'approved')
        .toList();
    final sports = [
      'Tất cả',
      ...approved.map((venue) => venue.sportType).toSet(),
    ];
    final venues = approved
        .where((venue) => _sport == 'Tất cả' || venue.sportType == _sport)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách sân')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: sports
                  .map(
                    (sport) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(sport),
                        selected: _sport == sport,
                        onSelected: (_) => setState(() => _sport = sport),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: venues.isEmpty
                ? const Center(child: Text('Chưa có sân phù hợp.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: venues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final venue = venues[index];
                      final images = MockStore.imageUrlsOf(venue.id);

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 2,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.venueDetail,
                            arguments: venue,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 170,
                                width: double.infinity,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (images.isNotEmpty)
                                      VenueImage(
                                        source: images.first,
                                        placeholder: _buildVenuePlaceholder(),
                                      )
                                    else
                                      _buildVenuePlaceholder(),
                                    Positioned(
                                      left: 12,
                                      top: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.95,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          venue.sportType,
                                          style: const TextStyle(
                                            color: Color(0xFF087451),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      venue.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 17,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            venue.address,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.payments_outlined,
                                          size: 18,
                                          color: Color(0xFF087451),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${_formatPrice(venue.pricePerHour)}đ/giờ',
                                            style: const TextStyle(
                                              color: Color(0xFF087451),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 15,
                                          color: Color(0xFF087451),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Chi tiết',
                                          style: TextStyle(
                                            color: Color(0xFF087451),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenuePlaceholder() {
    return Container(
      color: const Color(0xFF087451),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Colors.white70,
        size: 38,
      ),
    );
  }

  String _formatPrice(num value) {
    final s = value.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
