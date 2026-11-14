import 'package:flutter/material.dart';
import '../../utils/app_routes.dart';
import '../../data/account_service.dart';
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
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      final user = await AccountService.login(_email.text, _password.text);
      if (!mounted) return;
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đăng nhập. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    final email = await Navigator.pushNamed(context, AppRoutes.register);
    if (!mounted || email is! String) return;
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
          AuthField(
            label: 'Email',
            hint: 'Nhập email của bạn',
            controller: _email,
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: AuthValidation.email,
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
          const SizedBox(height: 2),
          ElevatedButton(
            onPressed: _busy ? null : _login,
            child: Text(_busy ? 'ĐANG ĐĂNG NHẬP…' : 'ĐĂNG NHẬP'),
          ),
          TextButton(
            onPressed: _busy ? null : _register,
            child: const Text('Chưa có tài khoản? Đăng ký'),
          ),
        ],
      ),
    ),
  );
}
