/// Model Đặt sân - tương ứng bảng Bookings trong ERD.
/// status: "pending" | "confirmed" | "cancelled" | "completed"
/// paymentStatus: "unpaid" | "paid" | "refunded"
///
/// Sân, ngày và giờ đặt được suy ra qua slotId -> TimeSlots.
/// Dịch vụ khách chọn kèm nằm ở bảng BookingServices (booking_id, service_id...).
class Booking {
  final String bookingId; // booking_id (PK)
  final String userId; // user_id (FK -> Users)
  final String slotId; // slot_id (FK -> TimeSlots)
  final String? promoId; // promo_id (FK -> Promotions, có thể trống)
  final double originalAmount; // original_amount (tiền sân)
  final double serviceAmount; // service_amount (tổng tiền dịch vụ)
  final double discountAmount; // discount_amount
  final double totalAmount; // total_amount
  final String status;
  final String paymentStatus; // payment_status
  final String? note;
  final String? cancelReason; // cancel_reason
  final DateTime createdAt; // created_at
  final DateTime? cancelledAt; // cancelled_at

  Booking({
    required this.bookingId,
    required this.userId,
    required this.slotId,
    this.promoId,
    required this.originalAmount,
    this.serviceAmount = 0,
    this.discountAmount = 0,
    required this.totalAmount,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
    this.note,
    this.cancelReason,
    required this.createdAt,
    this.cancelledAt,
  });
}
