import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/user.dart';
import '../../utils/auth_validation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String _role = 'customer';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim().toLowerCase();
    MockStore.addUser(
      AppUser(
        id: 'user${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        email: email,
        phone: _phone.text.trim(),
        password: _password.text,
        role: _role,
      ),
    );
    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Họ tên'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  AuthValidation.email(v) ??
                  (MockStore.emailExists(v!) ? 'Email đã được sử dụng' : null),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              validator: AuthValidation.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              validator: AuthValidation.password,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu'),
              validator: (v) =>
                  v == _password.text ? null : 'Mật khẩu xác nhận không khớp',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Loại tài khoản'),
              items: const [
                DropdownMenuItem(value: 'customer', child: Text('Khách hàng')),
                DropdownMenuItem(value: 'owner', child: Text('Chủ sân')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'customer'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Không được để trống' : null;
}
