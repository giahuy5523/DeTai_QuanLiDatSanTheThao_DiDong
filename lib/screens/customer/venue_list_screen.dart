import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../utils/app_routes.dart';
import '../../widgets/venue_card.dart';

class VenueListScreen extends StatefulWidget {
  const VenueListScreen({super.key});

  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> {
  String _sport = 'Tất cả';

  @override
  Widget build(BuildContext context) {
    final approved =
        MockStore.venues.where((venue) => venue.status == 'approved').toList();
    final sports = [
      'Tất cả',
      ...approved.map((venue) => venue.sportType).toSet()
    ];
    final venues = approved
        .where((venue) => _sport == 'Tất cả' || venue.sportType == _sport)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách sân')),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
              children: sports
                  .map((sport) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(sport),
                            selected: _sport == sport,
                            onSelected: (_) => setState(() => _sport = sport)),
                      ))
                  .toList()),
        ),
        Expanded(
            child: venues.isEmpty
                ? const Center(child: Text('Chưa có sân phù hợp.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: venues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => VenueCard(
                        venue: venues[index],
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.venueDetail,
                            arguments: venues[index])),
                  )),
      ]),
    );
  }
}
