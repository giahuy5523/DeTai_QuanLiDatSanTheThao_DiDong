enum AppNotificationType {
  bookingCancelled,
  refundProcessing,
  refundSucceeded,
  refundFailed,
  paymentFailed,
}

class AppNotification {
  final String id;
  final String userId;
  final String bookingId;
  final String title;
  final String content;
  final DateTime createdAt;
  final AppNotificationType type;
  final double? refundAmount;
  final String? refundMethod;
  final DateTime? refundExpectedAt;
  final String? refundStatus;
  bool isRead;

  AppNotification({
    required this.id,
    required this.userId,
    required this.bookingId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.type,
    this.refundAmount,
    this.refundMethod,
    this.refundExpectedAt,
    this.refundStatus,
    this.isRead = false,
  });
}
