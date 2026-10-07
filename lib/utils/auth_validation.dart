class AuthValidation {
  static String? email(String? value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
        ? null
        : 'Nhập email hợp lệ';
  }

  static String? password(String? value) =>
      value == null || value.trim().length < 6
      ? 'Mật khẩu tối thiểu 6 ký tự'
      : null;

  static String? phone(String? value) =>
      RegExp(r'^0[0-9]{9}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Số điện thoại gồm 10 chữ số, bắt đầu bằng 0';
}
