import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../utils/app_routes.dart';

class ManageVenueScreen extends StatelessWidget {
  const ManageVenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ownVenues = MockStore.venues.where((v) => v.ownerId == 'owner1').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý sân & lịch đặt')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.pushNamed(context, AppRoutes.uploadVenue), icon: const Icon(Icons.add), label: const Text('Đăng ký sân')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ...ownVenues.map((venue) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(venue.name, style: const TextStyle(fontWeight: FontWeight.w800))), Chip(label: Text(_statusLabel(venue.status)))]),
          Text(venue.address, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _showVenueInfo(context, venue.name), icon: const Icon(Icons.edit), label: const Text('Thông tin'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _showBookings(context, venue.id), icon: const Icon(Icons.calendar_month), label: const Text('Lịch đặt'))),
          ],),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.manageService), icon: const Icon(Icons.room_service_outlined), label: const Text('Quản lý dịch vụ kèm theo'))),
        ])))),
      ]),
    );
  }

  String _statusLabel(String status) => {'pending': 'Chờ duyệt', 'approved': 'Đã duyệt', 'rejected': 'Từ chối'}[status] ?? status;

  void _showVenueInfo(BuildContext context, String name) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Quản lý thông tin sân'), content: Text('Chỉnh sửa thông tin cho "$name" (mô phỏng).'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))]));
  }

  void _showBookings(BuildContext context, String venueId) {
    final bookings = MockStore.bookings.where((b) => b.venueId == venueId).toList();
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Lịch đặt sân', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      if (bookings.isEmpty) const Text('Chưa có lịch đặt.'),
      ...bookings.map((b) => ListTile(leading: const Icon(Icons.event_available), title: Text('${b.date.day}/${b.date.month}/${b.date.year} • ${b.startTime}-${b.endTime}'), subtitle: Text('Trạng thái: ${b.status}'))),
    ])));
  }
}
