import 'package:flutter/material.dart';
import '../../utils/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController(text: 'Nguyễn Văn Khách');
  final _email = TextEditingController(text: 'customer@gmail.com');
  final _phone = TextEditingController(text: '0901234567');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thông tin cá nhân (mô phỏng).')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const CircleAvatar(radius: 38, child: Icon(Icons.person, size: 40)),
        const SizedBox(height: 18),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Họ tên')),
        const SizedBox(height: 12),
        TextField(controller: _email, enabled: false, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _save, child: const Text('Lưu thay đổi')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false), icon: const Icon(Icons.logout), label: const Text('Đăng xuất')),
      ]),
    );
  }
}
