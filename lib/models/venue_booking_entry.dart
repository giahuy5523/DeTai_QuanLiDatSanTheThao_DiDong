// Nó là dữ liệu gọn cho màn "Lịch đặt sân" của chủ sân,
// đã gộp sẵn tên và số điện thoại khách.
class VenueBookingEntry {
  const VenueBookingEntry({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.status,
    this.promotionCode,
    this.customerName,
    this.customerPhone,
  });

  final String id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final double totalPrice;
  final String status;
  final String? promotionCode;
  final String? customerName;
  final String? customerPhone;
}
