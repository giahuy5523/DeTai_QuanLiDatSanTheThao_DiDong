/// Model Thanh toán - tương ứng bảng Payments trong ERD.
/// method: "cash" | "momo" | "vnpay" | "bank_transfer"
///   (mô phỏng, chưa tích hợp cổng thanh toán thật)
/// status: "pending" | "success" | "failed" | "refunded"
class Payment {
  final String paymentId; // payment_id (PK)
  final String bookingId; // booking_id (FK -> Bookings)
  final String method;
  final double amount;
  final String status;
  final String? transactionCode; // transaction_code (UK)
  final DateTime? paidAt; // paid_at (null khi chưa thanh toán thành công)
  final DateTime createdAt; // created_at

  Payment({
    required this.paymentId,
    required this.bookingId,
    required this.method,
    required this.amount,
    this.status = 'pending',
    this.transactionCode,
    this.paidAt,
    required this.createdAt,
  });
}
