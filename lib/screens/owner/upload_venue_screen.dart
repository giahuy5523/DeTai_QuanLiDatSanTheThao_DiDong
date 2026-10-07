import 'package:flutter/material.dart';

class UploadVenueScreen extends StatefulWidget {
  const UploadVenueScreen({super.key});

  @override
  State<UploadVenueScreen> createState() => _UploadVenueScreenState();
}

class _UploadVenueScreenState extends State<UploadVenueScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _price = TextEditingController();
  String _sportType = 'Bóng đá';
  int _imageCount = 0;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _address.text.trim().isEmpty || _price.text.trim().isEmpty || _imageCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ thông tin và chọn tối thiểu 3 ảnh.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sân đã được gửi chờ quản trị viên duyệt.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký sân mới')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên sân')),
        const SizedBox(height: 12),
        TextField(controller: _address, decoration: const InputDecoration(labelText: 'Địa chỉ')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: _sportType, decoration: const InputDecoration(labelText: 'Loại sân'), items: const [
          DropdownMenuItem(value: 'Bóng đá', child: Text('Bóng đá')),
          DropdownMenuItem(value: 'Cầu lông', child: Text('Cầu lông')),
          DropdownMenuItem(value: 'Tennis', child: Text('Tennis')),
        ], onChanged: (v) => setState(() => _sportType = v ?? 'Bóng đá')),
        const SizedBox(height: 12),
        TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá / giờ')),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ảnh sân: $_imageCount / tối thiểu 3', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: List.generate(_imageCount, (i) => Container(width: 72, height: 72, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.image_outlined)))),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => setState(() => _imageCount = (_imageCount + 1).clamp(0, 9).toInt()), icon: const Icon(Icons.add_a_photo), label: const Text('Thêm ảnh (mô phỏng)')),
        ]))),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _submit, child: const Text('Gửi duyệt')),
      ]),
    );
  }
}
