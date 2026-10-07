/// Model Đặt sân - tương ứng bảng Bookings trong ERD.
/// status: "pending" | "confirmed" | "cancelled" | "completed"
class Booking {
  final String id;
  final String venueId;
  final String userId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final double totalPrice;
  final String status;
  final String? paymentId;
  final String? promotionCode;
  final List<String>
  selectedServiceIds; // «extend»: dịch vụ kèm theo, không bắt buộc

  Booking({
    required this.id,
    required this.venueId,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    this.status = 'pending',
    this.paymentId,
    this.promotionCode,
    this.selectedServiceIds = const [],
  });
}
