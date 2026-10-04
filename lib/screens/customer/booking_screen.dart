import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/promotion.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _date = DateTime.now();
  String? _time;
  final Set<String> _selectedServices = {};
  final _promoController = TextEditingController();
  String? _promoMessage;
  double _discount = 0;

  final _times = const ['08:00', '09:00', '10:00', '14:00', '15:00', '16:00', '18:00', '19:00', '20:00', '21:00'];

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _applyPromo() {
    final code = _promoController.text.trim().toUpperCase();
    Promotion? promo;
    for (final item in MockStore.promotions) {
      if (item.code == code && item.isActive && item.expiryDate.isAfter(DateTime.now())) {
        promo = item;
        break;
      }
    }
    setState(() {
      if (promo == null) {
        _discount = 0;
        _promoMessage = 'Mã không hợp lệ hoặc đã hết hạn.';
      } else {
        _discount = promo.discountPercent;
        _promoMessage = 'Đã áp dụng giảm ${promo.discountPercent.toStringAsFixed(0)}%.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final venue = ModalRoute.of(context)!.settings.arguments as Venue;
    final services = MockStore.servicesFor(venue.id);
    final serviceTotal = services.where((s) => _selectedServices.contains(s.id)).fold<double>(0, (sum, s) => sum + s.price);
    final subtotal = venue.pricePerHour + serviceTotal;
    final total = subtotal * (1 - _discount / 100);

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt sân')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(venue.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Card(child: ListTile(leading: const Icon(Icons.event), title: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'), subtitle: const Text('Chọn ngày đặt sân'), trailing: const Icon(Icons.chevron_right), onTap: () async {
            final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)), initialDate: _date);
            if (picked != null) setState(() => _date = picked);
          })),
          const SizedBox(height: 16),
          Text('Chọn khung giờ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _times.map((time) => ChoiceChip(label: Text(time), selected: _time == time, onSelected: (_) => setState(() => _time = time))).toList()),
          const SizedBox(height: 20),
          Text('Dịch vụ kèm theo (không bắt buộc)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ...services.map((service) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(service.name),
                subtitle: Text('${service.price.toStringAsFixed(0)} đ/${service.unit}'),
                value: _selectedServices.contains(service.id),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selectedServices.add(service.id);
                  } else {
                    _selectedServices.remove(service.id);
                  }
                }),
              )),
          const SizedBox(height: 12),
          Text('Khuyến mãi (không bắt buộc)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _promoController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Ví dụ: SAN10'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _applyPromo, child: const Text('Áp dụng')),
          ]),
          if (_promoMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_promoMessage!, style: TextStyle(color: _discount > 0 ? Colors.green : Colors.red))),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            _summaryRow('Tiền sân', venue.pricePerHour),
            _summaryRow('Dịch vụ', serviceTotal),
            if (_discount > 0) _summaryRow('Giảm giá', -subtotal * _discount / 100),
            const Divider(),
            _summaryRow('Tổng thanh toán', total, bold: true),
          ]))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _time == null ? null : () => Navigator.pushNamed(context, AppRoutes.payment, arguments: {
              'venue': venue,
              'date': _date,
              'time': _time,
              'serviceIds': _selectedServices.toList(),
              'total': total,
              'promoCode': _promoController.text.trim().toUpperCase().isEmpty ? null : _promoController.text.trim().toUpperCase(),
            }),
            child: const Text('Tiếp tục đến thanh toán'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: style), Text('${amount.toStringAsFixed(0)} đ', style: style)]));
  }
}
