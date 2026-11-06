/// Model Người dùng - tương ứng bảng Users trong ERD.
/// role: "customer" | "owner" | "admin"
class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String password;
  final String role;

  /// Application-owned local image; AccountRepository persists this path.
  final String? avatarPath;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    this.role = 'customer',
    this.avatarPath,
  });
}
