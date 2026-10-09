/// Model Ảnh sân - tương ứng bảng VenueImages trong ERD.
/// Mỗi sân có tối thiểu 3 ảnh (ràng buộc kiểm tra ở tầng nghiệp vụ).
class VenueImage {
  final String imageId; // image_id (PK)
  final String venueId; // venue_id (FK -> Venues)
  final String imageUrl; // image_url
  final bool isPrimary; // is_primary (ảnh đại diện)
  final int sortOrder; // sort_order
  final DateTime createdAt; // created_at

  VenueImage({
    required this.imageId,
    required this.venueId,
    required this.imageUrl,
    this.isPrimary = false,
    this.sortOrder = 0,
    required this.createdAt,
  });
}
