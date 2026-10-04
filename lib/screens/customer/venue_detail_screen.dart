import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';

class VenueDetailScreen extends StatelessWidget {
  const VenueDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final venue = ModalRoute.of(context)!.settings.arguments as Venue;
    final services = MockStore.servicesFor(venue.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết sân')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(Icons.sports, size: 72, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(venue.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.location_on_outlined, size: 18), const SizedBox(width: 4), Expanded(child: Text(venue.address))]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.sports, size: 18), const SizedBox(width: 4), Text(venue.sportType), const SizedBox(width: 16), const Icon(Icons.star, size: 18, color: Colors.amber), const SizedBox(width: 4), Text(venue.rating.toStringAsFixed(1))]),
          const SizedBox(height: 14),
          Text('${venue.pricePerHour.toStringAsFixed(0)} đ / giờ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 20),
          Text('Lịch trống hôm nay', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: const [
            Chip(label: Text('08:00 - 09:00')),
            Chip(label: Text('09:00 - 10:00')),
            Chip(label: Text('18:00 - 19:00')),
            Chip(label: Text('20:00 - 21:00')),
          ]),
          if (services.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Dịch vụ kèm theo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ...services.map((s) => ListTile(contentPadding: EdgeInsets.zero, title: Text(s.name), trailing: Text('${s.price.toStringAsFixed(0)} đ/${s.unit}'))),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.booking, arguments: venue),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Đặt sân ngay'),
          ),
        ],
      ),
    );
  }
}
