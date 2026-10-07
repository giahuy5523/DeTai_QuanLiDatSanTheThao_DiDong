/// Model Dịch vụ kèm theo sân - ví dụ: cho thuê vợt, bán nước uống, thuê giày...
/// Mỗi Venue có thể có nhiều Service (1 Venue - N Service).
class VenueService {
  final String id;
  final String venueId;
  final String name;
  final double price;
  final String unit; // ví dụ: "lần", "chai", "giờ"

  VenueService({
    required this.id,
    required this.venueId,
    required this.name,
    required this.price,
    this.unit = 'lần',
  });

  /// Dữ liệu mẫu (mock data) để code UI khi chưa nối dữ liệu thật.
  static List<VenueService> mockListFor(String venueId) {
    return [
      VenueService(
        id: 's1',
        venueId: venueId,
        name: 'Nước suối',
        price: 10000,
        unit: 'chai',
      ),
      VenueService(
        id: 's2',
        venueId: venueId,
        name: 'Thuê vợt cầu lông',
        price: 20000,
        unit: 'buổi',
      ),
      VenueService(
        id: 's3',
        venueId: venueId,
        name: 'Thuê giày thể thao',
        price: 15000,
        unit: 'buổi',
      ),
    ];
  }
}
