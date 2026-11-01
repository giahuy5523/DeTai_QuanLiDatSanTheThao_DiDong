import 'package:flutter/material.dart';
import '../../utils/app_routes.dart';
import '../../data/mock_store.dart';
import '../../utils/auth_validation.dart';
import 'auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _phoneMode = false;
  final _phone = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (_phoneMode) {
      showBackendNotice(context);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = MockStore.login(_email.text, _password.text);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email hoặc mật khẩu không đúng.')),
      );
      return;
    }
    switch (user.role) {
      case 'owner':
        Navigator.pushReplacementNamed(context, AppRoutes.manageVenue);
        break;
      case 'admin':
        Navigator.pushReplacementNamed(context, AppRoutes.statistics);
        break;
      default:
        Navigator.pushReplacementNamed(context, AppRoutes.customerShell);
    }
  }

  Future<void> _register() async {
    final email = await Navigator.pushNamed(context, AppRoutes.register);
    if (!mounted || email is! String) return;
    setState(() => _phoneMode = false);
    _email.text = email;
    _password.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tạo tài khoản thành công. Vui lòng đăng nhập.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    register: false,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F6),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                _tab('Số điện thoại', true),
                const SizedBox(width: 2),
                _tab('Email', false),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AuthField(
            key: ValueKey(_phoneMode),
            label: _phoneMode ? 'Số điện thoại của bạn?' : 'Email của bạn?',
            hint: _phoneMode
                ? '+84   Nhập số điện thoại'
                : 'Nhập email của bạn',
            controller: _phoneMode ? _phone : _email,
            icon: _phoneMode ? Icons.phone_outlined : Icons.mail_outline,
            keyboardType: _phoneMode
                ? TextInputType.phone
                : TextInputType.emailAddress,
            validator: _phoneMode ? AuthValidation.phone : AuthValidation.email,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Mật khẩu (*)',
            hint: 'Nhập mật khẩu (*)',
            controller: _password,
            icon: Icons.lock_outline,
            obscure: _obscure,
            validator: AuthValidation.password,
            onSubmitted: _login,
            suffix: IconButton(
              tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility : Icons.visibility_off,
                size: 18,
                color: authMuted,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showBackendNotice(context),
              child: const Text(
                'Quên mật khẩu?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 2),
          ElevatedButton(onPressed: _login, child: const Text('ĐĂNG NHẬP')),
          const SizedBox(height: 12),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE7F5EF),
              minimumSize: const Size.fromHeight(46),
              padding: const EdgeInsets.symmetric(horizontal: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => showBackendNotice(context),
            child: const Row(
              children: [
                Icon(Icons.fingerprint, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Đăng nhập với sinh trắc học',
                    style: TextStyle(color: authInk, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'HOẶC ĐĂNG NHẬP BẰNG',
            textAlign: TextAlign.center,
            style: TextStyle(color: authMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          _social('G', 'Đăng nhập với Google'),
          const SizedBox(height: 10),
          _social('●', 'Đăng nhập với Apple'),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _register,
            child: const Text('Chưa có tài khoản? Đăng ký'),
          ),
        ],
      ),
    ),
  );

  Widget _tab(String label, bool phone) {
    final selected = _phoneMode == phone;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          onPressed: () {
            setState(() => _phoneMode = phone);
          },
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 42),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _social(String symbol, String label) => OutlinedButton(
    onPressed: () => showBackendNotice(context),
    style: OutlinedButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: authInk,
      minimumSize: const Size.fromHeight(41),
      side: const BorderSide(color: authBorder),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    child: Row(
      children: [
        Text(
          symbol,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
