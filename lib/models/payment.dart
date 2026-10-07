/// Model Thanh toán - tương ứng bảng Payments trong ERD.
/// method: "cash" | "momo" | "vnpay" | "bank_transfer"
/// status: "pending" | "success" | "failed" | "refunded"
class Payment {
  final String id;
  final String bookingId;
  final double amount;
  final String method;
  String status;
  final String? transactionCode;
  DateTime? paidAt;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.method,
    this.status = 'unpaid',
    this.transactionCode,
    this.paidAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}