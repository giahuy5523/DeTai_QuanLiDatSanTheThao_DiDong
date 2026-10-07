import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/promotion.dart';

class ManagePromotionScreen extends StatefulWidget {
  const ManagePromotionScreen({super.key});

  @override
  State<ManagePromotionScreen> createState() => _ManagePromotionScreenState();
}

class _ManagePromotionScreenState extends State<ManagePromotionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý khuyến mãi')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _editPromotion(), icon: const Icon(Icons.add), label: const Text('Thêm mã')),
      body: ListView.separated(padding: const EdgeInsets.all(16), itemCount: MockStore.promotions.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (context, i) {
        final p = MockStore.promotions[i];
        return Card(child: ListTile(
          title: Text(p.code, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('Giảm ${p.discountPercent.toStringAsFixed(0)}% • HSD ${p.expiryDate.day}/${p.expiryDate.month}/${p.expiryDate.year}'),
          trailing: Wrap(children: [IconButton(onPressed: () => _editPromotion(promotion: p), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: () => setState(() => MockStore.promotions.removeWhere((x) => x.id == p.id)), icon: const Icon(Icons.delete_outline))]),
        ));
      }),
    );
  }

  Future<void> _editPromotion({Promotion? promotion}) async {
    final code = TextEditingController(text: promotion?.code ?? '');
    final discount = TextEditingController(text: promotion == null ? '' : promotion.discountPercent.toStringAsFixed(0));
    final result = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(promotion == null ? 'Thêm khuyến mãi' : 'Sửa khuyến mãi'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Mã')), const SizedBox(height: 10), TextField(controller: discount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giảm (%)'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu'))],
    ));
    if (result != true) return;
    final value = double.tryParse(discount.text.trim());
    final normalizedCode = code.text.trim().toUpperCase();
    if (normalizedCode.isEmpty || value == null || value <= 0 || value > 100) return;
    setState(() {
      if (promotion == null) {
        MockStore.promotions.add(Promotion(id: 'p${DateTime.now().microsecondsSinceEpoch}', code: normalizedCode, discountPercent: value, expiryDate: DateTime.now().add(const Duration(days: 30))));
      } else {
        final i = MockStore.promotions.indexWhere((p) => p.id == promotion.id);
        if (i >= 0) MockStore.promotions[i] = Promotion(id: promotion.id, code: normalizedCode, discountPercent: value, expiryDate: promotion.expiryDate, isActive: promotion.isActive);
      }
    });
  }
}
