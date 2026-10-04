import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../utils/app_routes.dart';
import '../../widgets/venue_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final venues = MockStore.venues.where((v) => v.status == 'approved').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.bookingHistory), icon: const Icon(Icons.receipt_long)),
          IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.profile), icon: const Icon(Icons.person_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tìm sân phù hợp với bạn', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Chọn môn thể thao, khu vực và khung giờ yêu thích.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
                icon: const Icon(Icons.search),
                label: const Text('Tìm kiếm sân'),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          Text('Sân nổi bật', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...venues.map((venue) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VenueCard(
                  venue: venue,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.venueDetail, arguments: venue),
                ),
              )),
        ],
      ),
    );
  }
}
