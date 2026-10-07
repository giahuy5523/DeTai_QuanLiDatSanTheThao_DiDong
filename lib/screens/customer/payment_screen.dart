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
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map<String, dynamic>
        ? rawArgs
        : <String, dynamic>{};
    final venue =
        args['venue'] as Venue? ??
        (MockStore.venues.isNotEmpty
            ? MockStore.venues.first
            : Venue.mockList().first);
    final date = args['date'] as DateTime? ?? DateTime.now();
    final startTime =
        args['startTime'] as String? ?? args['time'] as String? ?? '08:00';
    final endTime = args['endTime'] as String? ?? _nextHour(startTime);
    final serviceIds = List<String>.from(
      args['serviceIds'] as List<dynamic>? ?? const [],
    );
    final total = (args['total'] as num?)?.toDouble() ?? venue.pricePerHour;
    final promoCode = args['promoCode'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(venue.name),
                  subtitle: Text(
                    '${date.day}/${date.month}/${date.year} • $startTime - $endTime',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.room_service_outlined),
                  title: Text('${serviceIds.length} dịch vụ kèm theo'),
                  subtitle: promoCode == null
                      ? const Text('Không dùng mã khuyến mãi')
                      : Text('Mã: $promoCode'),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng tiền',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${total.toStringAsFixed(0)} đ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Phương thức thanh toán',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          RadioGroup<String>(
            groupValue: _method,
            onChanged: (value) {
              if (value != null) setState(() => _method = value);
            },
            child: const Column(
              children: [
                RadioListTile<String>(value: 'cash', title: Text('Tiền mặt')),
                RadioListTile<String>(
                  value: 'momo',
                  title: Text('Ví MoMo (mô phỏng)'),
                ),
                RadioListTile<String>(
                  value: 'vnpay',
                  title: Text('VNPay (mô phỏng)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _done
                ? null
                : () {
                    final timestamp = DateTime.now().microsecondsSinceEpoch;
                    final bookingId = 'b$timestamp';
                    final paymentId = 'pay$timestamp';

                    final booking = Booking(
                      id: bookingId,
                      venueId: venue.id,
                      userId: MockStore.currentUser!.id,
                      date: date,
                      startTime: startTime,
                      endTime: endTime,
                      totalPrice: total,
                      status: 'confirmed',
                      paymentId: paymentId,
                      promotionCode: promoCode,
                      selectedServiceIds: serviceIds,
                    );

                    if (!MockStore.confirmBooking(booking, _method)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Khung giờ không còn khả dụng. Vui lòng chọn lại.',
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() => _done = true);

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(child: Text('Đặt sân thành công')),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Thanh toán đã được xác nhận.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 16),
                              _buildConfirmationRow('Mã đặt sân', bookingId),
                              _buildConfirmationRow('Mã thanh toán', paymentId),
                              _buildConfirmationRow('Sân', venue.name),
                              _buildConfirmationRow(
                                'Ngày',
                                '${date.day}/${date.month}/${date.year}',
                              ),
                              _buildConfirmationRow(
                                'Thời gian',
                                '$startTime - $endTime',
                              ),
                              _buildConfirmationRow(
                                'Thanh toán',
                                _paymentMethodLabel(_method),
                              ),
                              _buildConfirmationRow(
                                'Tổng tiền',
                                '${total.toStringAsFixed(0)} đ',
                              ),
                              if (promoCode != null && promoCode.isNotEmpty)
                                _buildConfirmationRow('Khuyến mãi', promoCode),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.popUntil(
                              context,
                              (route) =>
                                  route.settings.name ==
                                      AppRoutes.customerShell ||
                                  route.settings.name == AppRoutes.home ||
                                  route.isFirst,
                            ),
                            child: const Text('Về trang chủ'),
                          ),
                        ],
                      ),
                    );
                  },
            child: const Text('Xác nhận thanh toán'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'momo':
        return 'Ví MoMo (mô phỏng)';
      case 'vnpay':
        return 'VNPay (mô phỏng)';
      default:
        return 'Tiền mặt';
    }
  }

  String _nextHour(String start) {
    final hour = int.tryParse(start.split(':').first) ?? 0;
    return '${(hour + 1).toString().padLeft(2, '0')}:00';
  }
}
