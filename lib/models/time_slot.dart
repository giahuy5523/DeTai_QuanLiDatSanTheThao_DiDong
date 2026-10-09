/// Model Khung giờ - tương ứng bảng TimeSlots trong ERD.
/// Khung giờ cụ thể của một sân trong một ngày.
/// status: "available" | "booked" | "blocked"
class TimeSlot {
  final String slotId; // slot_id (PK)
  final String venueId; // venue_id (FK -> Venues)
  final DateTime slotDate; // slot_date
  final String startTime; // start_time, định dạng "HH:mm"
  final String endTime; // end_time, định dạng "HH:mm"
  final double price;
  final String status;

  TimeSlot({
    required this.slotId,
    required this.venueId,
    required this.slotDate,
    required this.startTime,
    required this.endTime,
    required this.price,
    this.status = 'available',
  });

  /// Dữ liệu mẫu: các khung giờ 1 tiếng trong ngày hôm nay của một sân.
  static List<TimeSlot> mockListFor(String venueId, double pricePerHour) {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    return [
      TimeSlot(
        slotId: '${venueId}_1',
        venueId: venueId,
        slotDate: date,
        startTime: '17:00',
        endTime: '18:00',
        price: pricePerHour,
      ),
      TimeSlot(
        slotId: '${venueId}_2',
        venueId: venueId,
        slotDate: date,
        startTime: '18:00',
        endTime: '19:00',
        price: pricePerHour,
        status: 'booked',
      ),
      TimeSlot(
        slotId: '${venueId}_3',
        venueId: venueId,
        slotDate: date,
        startTime: '19:00',
        endTime: '20:00',
        price: pricePerHour,
      ),
    ];
  }
}
