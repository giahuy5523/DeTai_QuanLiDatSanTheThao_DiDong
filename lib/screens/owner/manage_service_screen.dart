import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/service.dart';

class ManageServiceScreen extends StatefulWidget {
  const ManageServiceScreen({super.key});

  @override
  State<ManageServiceScreen> createState() => _ManageServiceScreenState();
}

class _ManageServiceScreenState extends State<ManageServiceScreen> {
  String get _venueId => ModalRoute.of(context)!.settings.arguments as String;

  List<VenueService> get _services => MockStore.servicesByVenue[_venueId] ?? [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý dịch vụ kèm theo')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _editService(), icon: const Icon(Icons.add), label: const Text('Thêm dịch vụ')),
      body: _services.isEmpty
          ? const Center(child: Text('Chưa có dịch vụ.'))
          : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _services.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (context, i) {
              final s = _services[i];
              return Card(child: ListTile(
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${s.price.toStringAsFixed(0)} đ / ${s.unit}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(onPressed: () => _editService(service: s), icon: const Icon(Icons.edit_outlined)),
                  IconButton(onPressed: () => _deleteService(s), icon: const Icon(Icons.delete_outline)),
                ]),
              ));
            }),
    );
  }

  Future<void> _editService({VenueService? service}) async {
    final nameController = TextEditingController(text: service?.name ?? '');
    final priceController = TextEditingController(text: service == null ? '' : service.price.toStringAsFixed(0));
    final unitController = TextEditingController(text: service?.unit ?? 'lần');
    final result = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(service == null ? 'Thêm dịch vụ' : 'Sửa dịch vụ'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên dịch vụ')),
        const SizedBox(height: 10),
        TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá')),
        const SizedBox(height: 10),
        TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Đơn vị')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu'))],
    ));
    if (result != true) return;
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim());
    if (name.isEmpty || price == null || price <= 0) return;
    setState(() {
      final list = MockStore.servicesByVenue[_venueId] ??= [];
      if (service == null) {
        list.add(VenueService(id: 's${DateTime.now().microsecondsSinceEpoch}', venueId: _venueId, name: name, price: price, unit: unitController.text.trim().isEmpty ? 'lần' : unitController.text.trim()));
      } else {
        final index = list.indexWhere((s) => s.id == service.id);
        if (index >= 0) list[index] = VenueService(id: service.id, venueId: _venueId, name: name, price: price, unit: unitController.text.trim().isEmpty ? 'lần' : unitController.text.trim());
      }
    });
  }

  void _deleteService(VenueService service) {
    setState(() => MockStore.servicesByVenue[_venueId]?.removeWhere((s) => s.id == service.id));
  }
}
