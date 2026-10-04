/// Model Thanh toán - tương ứng bảng Payments trong ERD.
/// method: "cash" | "momo" | "vnpay" (mô phỏng, chưa tích hợp cổng thanh toán thật)
/// status: "unpaid" | "paid" | "failed"
class Payment {
  final String id;
  final String bookingId;
  final double amount;
  final String method;
  final String status;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.method,
    this.status = 'unpaid',
    required this.createdAt,
  });
}
