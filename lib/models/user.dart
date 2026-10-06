/// Model Người dùng - tương ứng bảng Users trong ERD.
/// role: "customer" | "owner" | "admin"
class AppUser {
  final String userId; // user_id (PK)
  final String fullName; // full_name
  final String email; // email (UK)
  final String phone; // phone (UK)
  final String role; // role
  final String? avatarUrl; // avatar_url
  final bool isActive; // is_active
  final DateTime createdAt; // created_at

  // Lưu ý: password_hash không đưa vào model phía client.

  AppUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.role = 'customer',
    this.avatarUrl,
    this.isActive = true,
    required this.createdAt,
  });
}
