/// Model Dịch vụ trong đơn đặt - tương ứng bảng BookingServices trong ERD.
/// Dịch vụ khách chọn kèm trong một đơn đặt sân.
/// unitPrice là giá tại thời điểm đặt (không đổi khi dịch vụ đổi giá sau này).
class BookingService {
  final String bookingServiceId; // booking_service_id (PK)
  final String bookingId; // booking_id (FK -> Bookings)
  final String serviceId; // service_id (FK -> Services)
  final int quantity;
  final double unitPrice; // unit_price
  final double subtotal; // subtotal = quantity * unitPrice

  BookingService({
    required this.bookingServiceId,
    required this.bookingId,
    required this.serviceId,
    this.quantity = 1,
    required this.unitPrice,
    required this.subtotal,
  });
}
