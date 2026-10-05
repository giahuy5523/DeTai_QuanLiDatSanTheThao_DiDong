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
  List<Venue> get _pending => MockStore.venues.where((v) => v.status == 'pending').toList();

  @override
  Widget build(BuildContext context) {
    return AdminShellLayout(
      title: 'Duyệt sân mới',
      body: _pending.isEmpty ? const Center(child: Text('Không còn sân chờ duyệt.')) : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final venue = _pending[i];
          return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(venue.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(venue.address),
            const SizedBox(height: 6),
            Text('${venue.sportType} • ${venue.pricePerHour.toStringAsFixed(0)} đ/giờ'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _updateStatus(venue, 'rejected'), icon: const Icon(Icons.close), label: const Text('Từ chối'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(onPressed: () => _updateStatus(venue, 'approved'), icon: const Icon(Icons.check), label: const Text('Duyệt'))),
            ]),
          ])));
        },
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'approved' ? 'Đã duyệt sân.' : 'Đã từ chối sân.')));
  }
}
