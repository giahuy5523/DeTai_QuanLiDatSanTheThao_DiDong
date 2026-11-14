// Số liệu tổng hợp toàn hệ thống cho màn thống kê của Admin.
class SystemStatistics {
  const SystemStatistics({
    required this.bookingsByStatus,
    required this.venuesByStatus,
    required this.revenue,
  });

  final Map<String, int> bookingsByStatus;
  final Map<String, int> venuesByStatus;

  /// Tổng tiền đã thanh toán của các lịch đặt đã xác nhận hoặc hoàn thành.
  final double revenue;

  int get totalBookings =>
      bookingsByStatus.values.fold<int>(0, (sum, count) => sum + count);

  int bookings(String status) => bookingsByStatus[status] ?? 0;
  int venues(String status) => venuesByStatus[status] ?? 0;
}
