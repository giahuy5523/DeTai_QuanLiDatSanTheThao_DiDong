import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/service.dart';

class ManageServiceScreen extends StatefulWidget {
  final String venueId;

  const ManageServiceScreen({super.key, required this.venueId});

  @override
  State<ManageServiceScreen> createState() => _ManageServiceScreenState();
}

class _ManageServiceScreenState extends State<ManageServiceScreen> {
  List<VenueService> get _services =>
      MockStore.servicesByVenue[widget.venueId] ?? [];

  @override
  Widget build(BuildContext context) {
    final venue = MockStore.venueById(widget.venueId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          venue == null
              ? 'Quản lý dịch vụ kèm theo'
              : 'Dịch vụ - ${venue.name}',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editService(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm dịch vụ'),
      ),
      body: _services.isEmpty
          ? const Center(child: Text('Chưa có dịch vụ.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final service = _services[i];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.room_service_outlined),
                    ),
                    title: Text(
                      service.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${service.price.toStringAsFixed(0)} đ / ${service.unit}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sửa',
                          onPressed: () => _editService(service: service),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Xóa',
                          onPressed: () => _deleteService(service),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editService({VenueService? service}) async {
    final nameController = TextEditingController(text: service?.name ?? '');

    final priceController = TextEditingController(
      text: service == null ? '' : service.price.toStringAsFixed(0),
    );

    final unitController = TextEditingController(text: service?.unit ?? 'lần');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(service == null ? 'Thêm dịch vụ' : 'Sửa dịch vụ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên dịch vụ'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Giá',
                  suffixText: 'đ',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Đơn vị',
                  hintText: 'Ví dụ: lần, chai, giờ...',
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(service == null ? 'Thêm' : 'Lưu'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) return;

    final name = nameController.text.trim();
    final price = double.tryParse(
      priceController.text.trim().replaceAll(',', ''),
    );
    final unit = unitController.text.trim();

    if (name.isEmpty || price == null || !price.isFinite || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên và giá dịch vụ hợp lệ.'),
        ),
      );
      return;
    }

    setState(() {
      final list = MockStore.servicesByVenue[widget.venueId] ??= [];

      final normalizedUnit = unit.isEmpty ? 'lần' : unit;

      if (service == null) {
        list.add(
          VenueService(
            id: 's${DateTime.now().microsecondsSinceEpoch}',
            venueId: widget.venueId,
            name: name,
            price: price,
            unit: normalizedUnit,
          ),
        );
      } else {
        final index = list.indexWhere((item) => item.id == service.id);

        if (index >= 0) {
          list[index] = VenueService(
            id: service.id,
            venueId: widget.venueId,
            name: name,
            price: price,
            unit: normalizedUnit,
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          service == null ? 'Đã thêm dịch vụ.' : 'Đã cập nhật dịch vụ.',
        ),
      ),
    );
  }

  void _deleteService(VenueService service) {
    setState(() {
      MockStore.servicesByVenue[widget.venueId]?.removeWhere(
        (item) => item.id == service.id,
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã xóa "${service.name}".')));
  }
}
