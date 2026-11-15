/// Model Thanh toán - tương ứng bảng Payments trong ERD.
/// method: "cash" | "momo" | "vnpay" | "bank_transfer"
/// status: "pending" | "success" | "failed" | "refunded"
/// refundStatus: "processing" | "succeeded" | "failed"
class Payment {
  final String? paymentId; // payment_id (PK)
  final String? bookingId; // booking_id (FK -> Bookings)
  final String? method;
  final double? amount;
  String status;
  final String? transactionCode;
  DateTime? paidAt;
  final DateTime? createdAt;
  final double? refundAmount;
  final String? refundMethod;
  final String? refundStatus;
  final DateTime? refundExpectedAt;

  Payment({
    required this.paymentId,
    required this.bookingId,
    required this.method,
    required this.amount,
    this.status = 'pending',
    this.transactionCode,
    this.paidAt,
    this.createdAt,
    this.refundAmount,
    this.refundMethod,
    this.refundStatus,
    this.refundExpectedAt,
  });

  factory Payment.fromMap(Map<String, dynamic> data) {
    DateTime? dateValue(Object? value) => value is DateTime ? value : null;
    double? finiteAmount(Object? value) {
      if (value is! num) return null;
      final amount = value.toDouble();
      return amount.isFinite && amount >= 0 ? amount : null;
    }

    const knownStatuses = {'pending', 'success', 'failed', 'refunded'};
    final rawStatus = data['status'];
    return Payment(
      paymentId: data['id'] is String ? data['id'] as String : null,
      bookingId: data['bookingId'] is String
          ? data['bookingId'] as String
          : null,
      method: data['method'] is String ? data['method'] as String : null,
      amount: finiteAmount(data['amount']),
      status: rawStatus is String && knownStatuses.contains(rawStatus)
          ? rawStatus
          : 'unknown',
      transactionCode: data['transactionCode'] is String
          ? data['transactionCode'] as String
          : null,
      paidAt: dateValue(data['paidAt']),
      createdAt: dateValue(data['createdAt']),
      refundAmount: finiteAmount(data['refundAmount']),
      refundMethod: data['refundMethod'] is String
          ? data['refundMethod'] as String
          : null,
      refundStatus: data['refundStatus'] is String
          ? data['refundStatus'] as String
          : null,
      refundExpectedAt: dateValue(data['refundExpectedAt']),
    );
  }
}
