import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/user.dart';
import '../../utils/auth_validation.dart';
import 'auth_layout.dart';

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
  Widget build(BuildContext context) => AuthLayout(
    register: true,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: 'Số điện thoại',
            hint: '+84   Nhập số điện thoại',
            controller: _phone,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: AuthValidation.phone,
          ),
          const SizedBox(height: 7),
          AuthField(
            label: 'Email',
            hint: 'Nhập email của bạn',
            controller: _email,
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                AuthValidation.email(v) ??
                (MockStore.emailExists(v!) ? 'Email đã được sử dụng' : null),
          ),
          const SizedBox(height: 7),
          const Text(
            'Loại tài khoản',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _roleButton('customer', 'Khách hàng'),
              const SizedBox(width: 5),
              _roleButton('owner', 'Chủ sân'),
            ],
          ),
          const SizedBox(height: 18),
          AuthField(
            label: 'Họ và tên',
            hint: 'Nhập họ và tên',
            controller: _name,
            icon: Icons.person_outline,
            validator: _required,
          ),
          const SizedBox(height: 14),
          AuthField(
            label: 'Mật khẩu (*)',
            hint: 'Nhập mật khẩu',
            controller: _password,
            icon: Icons.lock_outline,
            obscure: true,
            validator: AuthValidation.password,
          ),
          const SizedBox(height: 14),
          AuthField(
            label: 'Xác nhận mật khẩu (*)',
            hint: 'Nhập lại mật khẩu',
            controller: _confirmation,
            icon: Icons.lock_outline,
            obscure: true,
            onSubmitted: _submit,
            validator: (v) =>
                v == _password.text ? null : 'Mật khẩu xác nhận không khớp',
          ),
          const SizedBox(height: 26),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('TẠO TÀI KHOẢN'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Đã có tài khoản? Đăng nhập',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _roleButton(String role, String label) {
    final selected = _role == role;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          onPressed: () => setState(() => _role = role),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            backgroundColor: selected ? authGreen : Colors.white,
            foregroundColor: selected ? Colors.white : authInk,
            side: BorderSide(color: selected ? authGreen : authBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Không được để trống' : null;
}
