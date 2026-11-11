// Thông tin liên hệ của chủ sân, dùng cho màn Admin duyệt sân.
class VenueOwnerInfo {
  const VenueOwnerInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
}
