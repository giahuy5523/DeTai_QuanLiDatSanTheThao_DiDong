/// Model Sân thể thao - tương ứng bảng Venues trong ERD.
/// status: "pending" (chờ duyệt) | "approved" (đã duyệt) | "rejected" (từ chối)
class Venue {
  final String id;
  final String ownerId;
  final int? sportTypeId; // Khóa ngoại sport_type_id trong ERD
  final String sportType; // Tên hiển thị loại thể thao
  final String name;
  final String address;
  final String? district; // Quận/Huyện trong ERD
  final String? city;     // Thành phố trong ERD
  final double pricePerHour;
  final List<String> imageUrls;
  final double latitude;
  final double longitude;
  final String status;
  final double rating;

  Venue({
    required this.id,
    required this.ownerId,
    this.sportTypeId,
    required this.sportType,
    required this.name,
    required this.address,
    this.district,
    this.city,
    required this.pricePerHour,
    required this.imageUrls,
    required this.latitude,
    required this.longitude,
    this.status = 'pending',
    this.rating = 0.0,
  });

  /// Dữ liệu mẫu (mock data)
  static List<Venue> mockList() {
    return [
      Venue(
        id: 'v1',
        ownerId: 'owner1',
        sportTypeId: 1,
        sportType: 'Bóng đá',
        name: 'Sân bóng đá Thành Công',
        address: '12 Lý Thường Kiệt, Tân Bình, TP.HCM',
        district: 'Tân Bình',
        city: 'TP.HCM',
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
        sportTypeId: 2,
        sportType: 'Cầu lông',
        name: 'Sân cầu lông Phú Nhuận',
        address: '45 Phan Xích Long, Phú Nhuận, TP.HCM',
        district: 'Phú Nhuận',
        city: 'TP.HCM',
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
        sportTypeId: 3,
        sportType: 'Tennis',
        name: 'Sân tennis Quận 7',
        address: '88 Nguyễn Thị Thập, Quận 7, TP.HCM',
        district: 'Quận 7',
        city: 'TP.HCM',
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