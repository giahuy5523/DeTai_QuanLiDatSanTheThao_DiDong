import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/app_notification.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late Future<List<AppNotification>> _notificationsFuture;

  String get _userId => MockStore.currentUser?.id ?? '';

  Future<List<AppNotification>> _loadNotifications() async =>
      MockStore.notificationsFor(_userId);

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  void _reload() {
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: () {
              MockStore.markAllNotificationsRead(_userId);
              _reload();
            },
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error),
                  const SizedBox(height: 8),
                  const Text('Không thể tải thông báo.'),
                  TextButton(onPressed: _reload, child: const Text('Thử lại')),
                ],
              ),
            );
          }
          final items = snapshot.data ?? const <AppNotification>[];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 48,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(height: 12),
                    Text('Bạn chưa có thông báo nào.'),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _notificationCard(items[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _notificationCard(AppNotification notification) => Card(
    color: notification.isRead ? Colors.white : AppTheme.primaryLight,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openNotification(notification),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconFor(notification.type), color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(notification.content),
                  if (notification.refundAmount != null) ...[
                    const SizedBox(height: 6),
                    Text('Mã booking: ${notification.bookingId}'),
                    Text(
                      'Số tiền yêu cầu hoàn: ${notification.refundAmount!.toStringAsFixed(0)} đ',
                    ),
                    Text(
                      'Phương thức nhận tiền: ${notification.refundMethod ?? 'Chưa xác định'}',
                    ),
                    Text(
                      'Thời gian dự kiến: ${_dateTime(notification.refundExpectedAt)}',
                    ),
                    Text(
                      'Trạng thái hoàn: ${_refundStatus(notification.refundStatus)}',
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _dateTime(notification.createdAt),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 5),
                child: Icon(Icons.circle, size: 9, color: AppTheme.primary),
              ),
          ],
        ),
      ),
    ),
  );

  void _openNotification(AppNotification notification) {
    final userId = MockStore.currentUser?.id;
    final canOpen = userId != null &&
        MockStore.bookings.any(
          (booking) =>
              booking.id == notification.bookingId && booking.userId == userId,
        );
    if (!canOpen) return;
    try {
      Navigator.pushNamed<void>(
        context,
        AppRoutes.bookingDetail,
        arguments: notification.bookingId,
      );
    } catch (_) {
      return;
    }
    MockStore.markNotificationRead(notification.id);
    _reload();
  }

  IconData _iconFor(AppNotificationType type) => switch (type) {
    AppNotificationType.bookingCancelled => Icons.event_busy_outlined,
    AppNotificationType.refundProcessing => Icons.hourglass_top_rounded,
    AppNotificationType.refundSucceeded => Icons.check_circle_outline_rounded,
    AppNotificationType.refundFailed => Icons.error_outline_rounded,
    AppNotificationType.paymentFailed => Icons.payment_rounded,
  };

  String _dateTime(DateTime? value) => value == null
      ? 'Chưa xác định'
      : '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _refundStatus(String? value) => switch (value) {
    'processing' => 'Đang xử lý',
    'succeeded' => 'Thành công',
    'failed' => 'Thất bại',
    _ => 'Chưa xác định',
  };
}
