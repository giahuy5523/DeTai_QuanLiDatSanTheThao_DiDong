/// Model Dịch vụ đi kèm trong đơn đặt sân - tương ứng bảng BookingServices trong ERD.
class BookingServiceItem {
  final String serviceId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  BookingServiceItem({
    required this.serviceId,
    required this.quantity,
    required this.unitPrice,
  }) : subtotal = unitPrice * quantity;
}

/// Model Đặt sân - tương ứng bảng Bookings trong ERD.
/// status: "pending" | "confirmed" | "cancelled" | "completed"
/// paymentStatus: "unpaid" | "paid" | "refunded"
class Booking {
  final String id;
  final String venueId;
  final String userId;
  final DateTime date;
  final String startTime;
  final String endTime;

  // Giữ totalPrice để tương thích với các screen cũ, đồng thời hỗ trợ các khoản chi tiết
  final double totalPrice;
  final double originalAmount;
  final double serviceAmount;
  final double discountAmount;

  String status;
  String paymentStatus;
  String? paymentId;
  final String? promoId;
  final String? promotionCode;
  final String? note;
  String? cancelReason;
  DateTime? cancelledAt;
  final DateTime createdAt;

  final List<BookingServiceItem> serviceItems;
  final List<String> selectedServiceIds;

  Booking({
    required this.id,
    required this.venueId,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required double totalPrice,
    double? originalAmount,
    double? serviceAmount,
    double? discountAmount,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
    this.paymentId,
    this.promoId,
    this.promotionCode,
    this.note,
    this.cancelReason,
    this.cancelledAt,
    DateTime? createdAt,
    List<BookingServiceItem>? serviceItems,
    List<String>? selectedServiceIds,
  })  : totalPrice = totalPrice,
        originalAmount = originalAmount ?? totalPrice,
        serviceAmount = serviceAmount ?? 0.0,
        discountAmount = discountAmount ?? 0.0,
        createdAt = createdAt ?? DateTime.now(),
        serviceItems = serviceItems ?? const [],
        selectedServiceIds = selectedServiceIds ??
            (serviceItems != null ? serviceItems.map((e) => e.serviceId).toList() : const []);

  double get totalAmount => totalPrice;
}