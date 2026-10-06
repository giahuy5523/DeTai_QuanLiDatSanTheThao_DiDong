import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/booking.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'cash';
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final venue = args['venue'] as Venue;
    final date = args['date'] as DateTime;
    final time = args['time'] as String;
    final serviceIds = List<String>.from(args['serviceIds'] as List<dynamic>? ?? const []);
    final total = (args['total'] as num).toDouble();
    final promoCode = args['promoCode'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Column(children: [
            ListTile(title: Text(venue.name), subtitle: Text('${date.day}/${date.month}/${date.year} • $time - ${_nextHour(time)}')),
            ListTile(leading: const Icon(Icons.room_service_outlined), title: Text('${serviceIds.length} dịch vụ kèm theo'), subtitle: promoCode == null ? const Text('Không dùng mã khuyến mãi') : Text('Mã: $promoCode')),
            Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tổng tiền', style: TextStyle(fontWeight: FontWeight.w800)), Text('${total.toStringAsFixed(0)} đ', style: const TextStyle(fontWeight: FontWeight.w800))])),
          ])),
          const SizedBox(height: 16),
          Text('Phương thức thanh toán', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          RadioGroup<String>(
            groupValue: _method,
            onChanged: (value) {
              if (value != null) setState(() => _method = value);
            },
            child: const Column(children: [
              RadioListTile<String>(value: 'cash', title: Text('Tiền mặt')),
              RadioListTile<String>(value: 'momo', title: Text('Ví MoMo (mô phỏng)')),
              RadioListTile<String>(value: 'vnpay', title: Text('VNPay (mô phỏng)')),
            ]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _done ? null : () {
            final booking = Booking(
              id: 'b${DateTime.now().millisecondsSinceEpoch}',
              venueId: venue.id,
              userId: MockStore.currentUser!.id,
              date: date,
              startTime: time,
              endTime: _nextHour(time),
              totalPrice: total,
              status: 'confirmed',
              paymentId: 'pay${DateTime.now().millisecondsSinceEpoch}',
              promotionCode: promoCode,
              selectedServiceIds: serviceIds,
            );
            MockStore.addBooking(booking);
            setState(() => _done = true);
            showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
              title: const Text('Đặt sân thành công'),
              content: const Text('Thanh toán đã được mô phỏng và trạng thái đơn chuyển sang Đã xác nhận.'),
              actions: [TextButton(onPressed: () => Navigator.popUntil(context, (route) => route.settings.name == AppRoutes.home), child: const Text('Về trang chủ'))],
            ));
          }, child: const Text('Xác nhận thanh toán')),
        ],
      ),
    );
  }

  String _nextHour(String start) {
    final hour = int.tryParse(start.split(':').first) ?? 0;
    return '${(hour + 1).toString().padLeft(2, '0')}:00';
  }
}
