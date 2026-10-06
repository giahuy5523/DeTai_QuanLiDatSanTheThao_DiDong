/// Model Dịch vụ kèm theo sân - tương ứng bảng Services trong ERD.
/// Ví dụ: cho thuê vợt, bán nước uống, thuê giày...
/// Mỗi Venue có thể có nhiều Service (1 Venue - N Service).
/// status: "active" | "inactive"
class VenueService {
  final String serviceId; // service_id (PK)
  final String venueId; // venue_id (FK -> Venues)
  final String name;
  final String? description;
  final String unit; // ví dụ: "lần", "chai", "giờ"
  final double price;
  final String status;

  VenueService({
    required this.serviceId,
    required this.venueId,
    required this.name,
    this.description,
    this.unit = 'lần',
    required this.price,
    this.status = 'active',
  });

  /// Dữ liệu mẫu (mock data) để code UI khi chưa nối dữ liệu thật.
  static List<VenueService> mockListFor(String venueId) {
    return [
      VenueService(
        serviceId: 's1',
        venueId: venueId,
        name: 'Nước suối',
        description: 'Chai 500ml',
        unit: 'chai',
        price: 10000,
      ),
      VenueService(
        serviceId: 's2',
        venueId: venueId,
        name: 'Thuê vợt cầu lông',
        unit: 'buổi',
        price: 20000,
      ),
      VenueService(
        serviceId: 's3',
        venueId: venueId,
        name: 'Thuê giày thể thao',
        unit: 'buổi',
        price: 15000,
      ),
    ];
  }
}
