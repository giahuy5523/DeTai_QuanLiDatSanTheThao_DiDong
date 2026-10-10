/// Model Môn thể thao - tương ứng bảng SportTypes trong ERD.
/// Danh mục môn thể thao (bóng đá mini, cầu lông, tennis...).
class SportType {
  final int sportTypeId; // sport_type_id (PK)
  final String name; // name (UK)
  final String? description;
  final String? icon; // tên icon hoặc đường dẫn icon

  SportType({
    required this.sportTypeId,
    required this.name,
    this.description,
    this.icon,
  });

  /// Dữ liệu mẫu, khớp với sportTypeId trong Venue.mockList().
  static List<SportType> mockList() {
    return [
      SportType(sportTypeId: 1, name: 'Bóng đá', icon: 'sports_soccer'),
      SportType(sportTypeId: 2, name: 'Cầu lông', icon: 'sports_tennis'),
      SportType(sportTypeId: 3, name: 'Tennis', icon: 'sports_tennis'),
    ];
  }
}
