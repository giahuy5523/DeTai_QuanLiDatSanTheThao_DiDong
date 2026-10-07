/// Model Sân thể thao - tương ứng bảng Venues trong ERD.
/// status: "pending" (chờ duyệt) | "approved" (đã duyệt) | "rejected" (từ chối)
class Venue {
  final String id;
  final String ownerId;
  final String name;
  final String address;
  final String sportType;
  final double pricePerHour;
  final List<String> imageUrls;
  final double latitude;
  final double longitude;
  final String status;
  final double rating;

  Venue({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.sportType,
    required this.pricePerHour,
    required this.imageUrls,
    required this.latitude,
    required this.longitude,
    this.status = 'pending',
    this.rating = 0.0,
  });
  Venue copyWith({
    String? name,
    String? address,
    String? sportType,
    double? pricePerHour,
    List<String>? imageUrls,
    double? latitude,
    double? longitude,
    String? status,
    double? rating,
  }) {
    return Venue(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      sportType: sportType ?? this.sportType,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      imageUrls: imageUrls ?? this.imageUrls,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      rating: rating ?? this.rating,
    );
  }

  /// Dữ liệu mẫu (mock data) dùng cho giao diện khi chưa nối Firebase/SQLite thật.
  static List<Venue> mockList() {
    return [
      Venue(
        id: 'v1',
        ownerId: 'owner1',
        name: 'Sân bóng đá Thành Công',
        address: '12 Lý Thường Kiệt, Tân Bình, TP.HCM',
        sportType: 'Bóng đá',
        pricePerHour: 300000,
        imageUrls: const [],
        latitude: 10.7975,
        longitude: 106.6520,
        status: 'approved',
        rating: 4.5,
      ),
      Venue(
        id: 'v2',
        ownerId: 'owner2',
        name: 'Sân cầu lông Phú Nhuận',
        address: '45 Phan Xích Long, Phú Nhuận, TP.HCM',
        sportType: 'Cầu lông',
        pricePerHour: 120000,
        imageUrls: const [],
        latitude: 10.7990,
        longitude: 106.6800,
        status: 'approved',
        rating: 4.2,
      ),
      Venue(
        id: 'v3',
        ownerId: 'owner1',
        name: 'Sân tennis Quận 7',
        address: '88 Nguyễn Thị Thập, Quận 7, TP.HCM',
        sportType: 'Tennis',
        pricePerHour: 250000,
        imageUrls: const [],
        latitude: 10.7320,
        longitude: 106.7210,
        status: 'pending',
        rating: 0.0,
      ),
    ];
  }
}
