/// Model Sân thể thao - tương ứng bảng Venues trong ERD.
/// status: "pending" (chờ duyệt) | "approved" (đã duyệt) | "rejected" (từ chối)
class Venue {
  final String venueId; // venue_id (PK)
  final String ownerId; // owner_id (FK -> Users)
  final String sportTypeId; // sport_type_id (FK -> SportTypes)
  final String name;
  final String address;
  final String district;
  final String city;
  final String? description;
  final double pricePerHour; // price_per_hour
  final String openTime; // open_time, định dạng "HH:mm"
  final String closeTime; // close_time, định dạng "HH:mm"
  final String status;
  final String? rejectReason; // reject_reason
  final String? reviewedBy; // reviewed_by (FK -> Users, admin)
  final DateTime? reviewedAt; // reviewed_at
  final DateTime createdAt; // created_at

  Venue({
    required this.venueId,
    required this.ownerId,
    required this.sportTypeId,
    required this.name,
    required this.address,
    required this.district,
    required this.city,
    this.description,
    required this.pricePerHour,
    required this.openTime,
    required this.closeTime,
    this.status = 'pending',
    this.rejectReason,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  /// Dữ liệu mẫu (mock data) dùng cho giao diện khi chưa nối Firebase/SQLite thật.
  static List<Venue> mockList() {
    return [
      Venue(
        venueId: 'v1',
        ownerId: 'owner1',
        sportTypeId: 'st1',
        name: 'Sân bóng đá Thành Công',
        address: '12 Lý Thường Kiệt',
        district: 'Tân Bình',
        city: 'TP.HCM',
        description: 'Sân cỏ nhân tạo mini, có đèn chiếu sáng buổi tối.',
        pricePerHour: 300000,
        openTime: '06:00',
        closeTime: '22:00',
        status: 'approved',
        reviewedBy: 'admin1',
        reviewedAt: DateTime.now().subtract(const Duration(days: 10)),
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
      Venue(
        venueId: 'v2',
        ownerId: 'owner2',
        sportTypeId: 'st2',
        name: 'Sân cầu lông Phú Nhuận',
        address: '45 Phan Xích Long',
        district: 'Phú Nhuận',
        city: 'TP.HCM',
        description: 'Sân trong nhà, mặt thảm tiêu chuẩn thi đấu.',
        pricePerHour: 120000,
        openTime: '05:30',
        closeTime: '23:00',
        status: 'approved',
        reviewedBy: 'admin1',
        reviewedAt: DateTime.now().subtract(const Duration(days: 8)),
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
      ),
      Venue(
        venueId: 'v3',
        ownerId: 'owner1',
        sportTypeId: 'st3',
        name: 'Sân tennis Quận 7',
        address: '88 Nguyễn Thị Thập',
        district: 'Quận 7',
        city: 'TP.HCM',
        pricePerHour: 250000,
        openTime: '06:00',
        closeTime: '21:00',
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}
