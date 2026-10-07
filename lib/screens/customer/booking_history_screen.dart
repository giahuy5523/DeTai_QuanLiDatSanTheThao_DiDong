import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/booking.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final bookings = MockStore.customerBookings(MockStore.currentUser?.id ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử đặt sân')),
      body: bookings.isEmpty
          ? const Center(child: Text('Chưa có đơn đặt sân.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final b = bookings[index];
                final venue = MockStore.venueById(b.venueId);
                final canCancel = b.status == 'pending' || b.status == 'confirmed';
                return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(venue?.name ?? 'Sân thể thao', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${b.date.day}/${b.date.month}/${b.date.year} • ${b.startTime} - ${b.endTime}'),
                  const SizedBox(height: 6),
                  Row(children: [Expanded(child: Text('${b.totalPrice.toStringAsFixed(0)} đ', style: const TextStyle(fontWeight: FontWeight.w700))), _statusChip(b.status)]),
                  if (canCancel) ...[
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(key: ValueKey('cancel_${b.id}'), onPressed: () => _cancel(b.id), icon: const Icon(Icons.cancel_outlined), label: const Text('Hủy đặt sân'))),
                  ],
                ])));
              },
            ),
    );
  }

  Widget _statusChip(String status) {
    final label = {'pending': 'Chờ xác nhận', 'confirmed': 'Đã xác nhận', 'cancelled': 'Đã hủy', 'completed': 'Hoàn tất'}[status] ?? status;
    return Chip(label: Text(label));
  }

  void _cancel(String bookingId) {
    final booking = MockStore.bookings.where((b) => b.id == bookingId).first;
    final index = MockStore.bookings.indexOf(booking);
    MockStore.bookings[index] = Booking(
      id: booking.id,
      venueId: booking.venueId,
      userId: booking.userId,
      date: booking.date,
      startTime: booking.startTime,
      endTime: booking.endTime,
      totalPrice: booking.totalPrice,
      status: 'cancelled',
      paymentId: booking.paymentId,
      promotionCode: booking.promotionCode,
      selectedServiceIds: booking.selectedServiceIds,
    );
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy đơn đặt sân.')));
  }
}
