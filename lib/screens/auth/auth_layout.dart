import 'auth_banner.dart';
import 'package:flutter/material.dart';

const authGreen = Color(0xFF0F8B5F);
const authInk = Color(0xFF172B3A);
const authMuted = Color(0xFF778799);
const authBorder = Color(0xFFDFE6EB);

void showBackendNotice(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Chức năng sẽ được tích hợp trong giai đoạn backend'),
      ),
    );
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.register, required this.child});
  final bool register;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(primary: authGreen),
        textTheme: theme.textTheme.apply(
          bodyColor: authInk,
          displayColor: authInk,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: authGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(50),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: authGreen,
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    AuthBanner(register: register),
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 15),
                      padding: EdgeInsets.fromLTRB(
                        13,
                        register ? 24 : 27,
                        13,
                        8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.onSubmitted,
  });
  final String label, hint;
  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 4),
      TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscure,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: !obscure,
        textInputAction: onSubmitted == null
            ? TextInputAction.next
            : TextInputAction.done,
        onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: authMuted, fontSize: 13),
          prefixIcon: ExcludeSemantics(
            child: Center(
              widthFactor: 1,
              child: Text(
                icon == Icons.phone_outlined
                    ? '☎'
                    : icon == Icons.mail_outline
                    ? '✉'
                    : '♙',
                style: const TextStyle(fontSize: 18, color: authMuted),
              ),
            ),
          ),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 17,
          ),
          isDense: true,
          errorMaxLines: 3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: authBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: authGreen, width: 1.5),
          ),
        ),
      ),
    ],
  );
}
