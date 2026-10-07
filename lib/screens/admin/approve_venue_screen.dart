import 'package:flutter/material.dart';
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
  List<Venue> get _pending =>
      MockStore.venues.where((venue) => venue.status == 'pending').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt sân mới'),
        actions: [if (Navigator.canPop(context)) const BackButton()],
      ),
      drawer: const AdminDrawer(selectedIndex: 1),
      body: _pending.isEmpty
          ? const Center(child: Text('Không còn sân chờ duyệt.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _pending.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final venue = _pending[index];
                return _buildVenueCard(venue);
              },
            ),
    );
  }

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
          _buildVenueImage(venue),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _infoRow(Icons.location_on_outlined, venue.address),
                const SizedBox(height: 7),
                _infoRow(Icons.sports_outlined, venue.sportType),
                const SizedBox(height: 7),
                _infoRow(
                  Icons.payments_outlined,
                  '${venue.pricePerHour.toStringAsFixed(0)} đ/giờ',
                ),
                if (owner != null) ...[
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Thông tin chủ sân',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  _infoRow(Icons.person_outline, owner.name),
                  const SizedBox(height: 7),
                  _infoRow(Icons.phone_outlined, owner.phone),
                  const SizedBox(height: 7),
                  _infoRow(Icons.email_outlined, owner.email),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateStatus(venue, 'rejected'),
                        icon: const Icon(Icons.close),
                        label: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(venue, 'approved'),
                        icon: const Icon(Icons.check),
                        label: const Text('Duyệt'),
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

  Widget _buildVenueImage(Venue venue) {
    final images = MockStore.imageUrlsOf(venue.id);
    if (images.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 56),
        ),
      );
    }

    return SizedBox(
      height: 180,
      width: double.infinity,
      child: VenueImage(
        source: images.first,
        placeholder: _imageErrorPlaceholder(),
      ),
    );
  }

  Widget _imageErrorPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.broken_image_outlined, size: 56)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  void _updateStatus(Venue venue, String status) {
    final index = MockStore.venues.indexWhere((item) => item.id == venue.id);

    if (index < 0) return;

    MockStore.venues[index] = venue.copyWith(status: status);

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'approved'
              ? 'Đã duyệt sân "${venue.name}".'
              : 'Đã từ chối sân "${venue.name}".',
        ),
      ),
    );
  }
}
