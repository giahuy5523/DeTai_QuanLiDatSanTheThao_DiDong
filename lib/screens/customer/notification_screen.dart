import 'package:flutter/material.dart';

import '../../data/mock_store.dart';
import '../../data/booking_repository.dart' as data_repo;
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

  Future<List<AppNotification>> _loadNotifications() {
    if (_userId.isEmpty) return Future.value(const <AppNotification>[]);
    return data_repo.BookingRepository.getNotificationsForUser(_userId);
  }

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
  }

  Future<void> _refresh() async {
    final future = _loadNotifications();
    setState(() => _notificationsFuture = future);
    await future;
  }

  Future<void> _markAllAsRead() async {
    if (_userId.isEmpty) return;
    await data_repo.BookingRepository.markAllNotificationsAsRead(_userId);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: MockStore.notificationRevision,
            builder: (context, _, _) {
              final unread = MockStore.unreadNotificationCount(_userId);
              return IconButton(
                tooltip: 'Đánh dấu tất cả đã đọc',
                onPressed: unread == 0 ? null : _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded),
              );
            },
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
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 150),
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Center(child: Text('Bạn chưa có thông báo nào.')),
                ],
              ),
            );
          }

          final groups = _groupByDate(items);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  for (final notification in entry.value) ...[
                    _notificationCard(notification),
                    const SizedBox(height: 9),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, List<AppNotification>> _groupByDate(
    List<AppNotification> notifications,
  ) {
    final groups = <String, List<AppNotification>>{};
    for (final notification in notifications) {
      final label = _dateGroupLabel(notification.createdAt);
      (groups[label] ??= <AppNotification>[]).add(notification);
    }
    return groups;
  }

  String _dateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = today.difference(target).inDays;
    if (difference == 0) return 'Hôm nay';
    if (difference == 1) return 'Hôm qua';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _notificationCard(AppNotification notification) {
    final unread = !notification.isRead;
    return Card(
      margin: EdgeInsets.zero,
      elevation: unread ? 1.5 : 0,
      color: unread ? AppTheme.primaryLight : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: unread ? AppTheme.primary.withValues(alpha: 0.28) : AppTheme.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openNotification(notification),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(notification.type), color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _time(notification.createdAt),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 5),
                  child: Icon(Icons.circle, size: 9, color: AppTheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(AppNotification notification) async {
    final userId = MockStore.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    // Validate the related booking before marking the notification as read.
    // Missing bookings and bookings owned by another user must stay unread.
    final booking = await data_repo.BookingRepository.getBookingById(
      notification.bookingId,
    );
    if (!mounted ||
        MockStore.currentUser?.id != userId ||
        booking == null ||
        booking.userId != userId) {
      return;
    }

    await data_repo.BookingRepository.markNotificationAsRead(notification.id);
    if (!mounted || MockStore.currentUser?.id != userId) return;
    _reload();

    await Navigator.pushNamed<void>(
      context,
      AppRoutes.bookingDetail,
      arguments: notification.bookingId,
    );
  }

  IconData _iconFor(AppNotificationType type) => switch (type) {
    AppNotificationType.bookingCancelled => Icons.event_busy_outlined,
    AppNotificationType.refundProcessing => Icons.hourglass_top_rounded,
    AppNotificationType.refundSucceeded => Icons.check_circle_outline_rounded,
    AppNotificationType.refundFailed => Icons.error_outline_rounded,
    AppNotificationType.paymentFailed => Icons.payment_rounded,
  };

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
