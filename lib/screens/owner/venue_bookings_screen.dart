import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../data/booking_repository.dart';
import '../../data/venue_repository.dart';
import '../../models/venue_booking_entry.dart';
import '../../utils/app_theme.dart';

class VenueBookingsScreen extends StatefulWidget {
  final String venueId;

  const VenueBookingsScreen({super.key, required this.venueId});

  @override
  State<VenueBookingsScreen> createState() => _VenueBookingsScreenState();
}

class _VenueBookingsScreenState extends State<VenueBookingsScreen> {
  // Màu "đã xác nhận"
  static const _confirmedBlue = Color(0xFF3B82F6);

  static const _stripDays = 62;

  // Dữ liệu lịch đặt đọc từ SQLite.
  List<VenueBookingEntry> _bookings = const [];
  bool _isLoading = true;
  bool _updating = false;
  bool _initialDatePicked = false;
  String? _error;

  late DateTime _selectedDate;
  late DateTime _stripStart;
  String? _statusFilter; // null = tất cả

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _selectedDate = today;
    _stripStart = DateTime(today.year, today.month, today.day - 1);
    _loadBookings();
  }

  // Dữ liệu
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _loadBookings() async {
    try {
      final bookings = await VenueRepository.loadBookingsForVenue(
        widget.venueId,
      );
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _isLoading = false;
        _error = null;
        // Lần tải đầu: chọn ngày gần nhất (từ hôm nay trở đi) có lịch đặt.
        if (!_initialDatePicked) {
          _initialDatePicked = true;
          final today = _dateOnly(DateTime.now());
          final upcoming =
              bookings
                  .map((b) => _dateOnly(b.date))
                  .where((d) => !d.isBefore(today))
                  .toList()
                ..sort();
          if (upcoming.isNotEmpty) {
            _selectedDate = upcoming.first;
            _stripStart = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day - 1,
            );
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Không thể tải lịch đặt. Vui lòng thử lại.';
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _loadBookings();
  }

  List<VenueBookingEntry> get _dayBookings =>
      _bookings.where((b) => _sameDay(b.date, _selectedDate)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  String _weekdayLabel(DateTime d) =>
      d.weekday == DateTime.sunday ? 'CN' : 'T${d.weekday + 1}';

  String _formatMoney(num value) {
    final s = value.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '$buf đ';
  }

  // Build
  @override
  Widget build(BuildContext context) {
    final dayBookings = _dayBookings;
    final filtered = _statusFilter == null
        ? dayBookings
        : dayBookings.where((b) => b.status == _statusFilter).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Lịch đặt sân',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(_error!)
          : Column(
              children: [
                _buildDateStrip(),
                _buildFilterChips(dayBookings),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) =>
                              _buildBookingCard(context, filtered[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  // Dải chọn ngày
  Widget _buildDateStrip() {
    final itemWidth = (MediaQuery.of(context).size.width - 32 - 4 * 8) / 5;

    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stripDays,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = DateTime(
            _stripStart.year,
            _stripStart.month,
            _stripStart.day + i,
          );
          final selected = _sameDay(day, _selectedDate);
          final hasBooking = _bookings.any((b) => _sameDay(b.date, day));

          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = day;
              _statusFilter = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: itemWidth,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayLabel(day),
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Chấm báo ngày có lịch đặt
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasBooking
                          ? (selected ? Colors.white : AppTheme.primary)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Bộ lọc trạng thái
  Widget _buildFilterChips(List<VenueBookingEntry> dayBookings) {
    int count(String status) =>
        dayBookings.where((b) => b.status == status).length;

    final filters = <MapEntry<String?, String>>[
      MapEntry(null, 'Tất cả ${dayBookings.length}'),
      MapEntry('pending', 'Chờ ${count('pending')}'),
      MapEntry('confirmed', 'Đã xác nhận ${count('confirmed')}'),
      MapEntry('completed', 'Hoàn thành ${count('completed')}'),
      MapEntry('cancelled', 'Đã hủy ${count('cancelled')}'),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final selected = _statusFilter == f.key;
          return GestureDetector(
            onTap: () => setState(() => _statusFilter = f.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: selected ? null : Border.all(color: AppTheme.border),
              ),
              child: Text(
                f.value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Trạng thái rỗng
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Chưa có lịch đặt',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ngày ${_selectedDate.day}/${_selectedDate.month} chưa có khách đặt sân.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // Thẻ lịch đặt
  Widget _buildBookingCard(BuildContext context, VenueBookingEntry booking) {
    final customerName = booking.customerName ?? 'Khách không xác định';
    final customerPhone = booking.customerPhone ?? 'Không có số điện thoại';

    return Container(
      key: ValueKey('owner-booking-${booking.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Giờ + trạng thái
          Row(
            children: [
              Expanded(
                child: Text(
                  '${booking.startTime} - ${booking.endTime}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _buildStatusPill(booking.status),
            ],
          ),
          const SizedBox(height: 14),

          // Khách hàng
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryLight,
                child: Icon(
                  Icons.person,
                  size: 28,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerPhone,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dịch vụ khách đã chọn (nếu có)
          if (booking.services.isNotEmpty) ...[
            _buildServicesSection(booking.services),
            const SizedBox(height: 14),
          ],

          // Tổng tiền
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tổng tiền',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              Text(
                _formatMoney(booking.totalPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),

          // Mã khuyến mãi (nếu có)
          if (booking.promotionCode != null &&
              booking.promotionCode!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mã ${booking.promotionCode}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Nút thao tác
          ..._buildActions(booking),
        ],
      ),
    );
  }

  Widget _buildServicesSection(List<VenueBookingServiceItem> services) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dịch vụ đã chọn',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final service in services)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${service.name} × ${service.quantity}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _formatMoney(service.subtotal),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    late final String label;
    late final Color bg;
    late final Color fg;

    switch (status) {
      case 'pending':
        label = 'Chờ xác nhận';
        bg = AppTheme.accent;
        fg = AppTheme.textPrimary;
        break;
      case 'confirmed':
        label = 'Đã xác nhận';
        bg = _confirmedBlue;
        fg = Colors.white;
        break;
      case 'completed':
        label = 'Đã hoàn thành';
        bg = AppTheme.primary;
        fg = Colors.white;
        break;
      case 'cancelled':
        label = 'Đã hủy';
        bg = AppTheme.border;
        fg = AppTheme.textSecondary;
        break;
      default:
        label = status;
        bg = AppTheme.border;
        fg = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  List<Widget> _buildActions(VenueBookingEntry booking) {
    if (booking.status == 'pending') {
      return [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                label: 'Từ chối',
                color: AppTheme.error,
                onPressed: () => _confirmAndUpdate(
                  booking,
                  'cancelled',
                  title: 'Từ chối lịch đặt?',
                  message: 'Khách sẽ nhận được thông báo lịch đặt bị từ chối.',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                label: 'Xác nhận',
                color: AppTheme.primary,
                onPressed: () => _updateBookingStatus(booking, 'confirmed'),
              ),
            ),
          ],
        ),
      ];
    }

    if (booking.status == 'confirmed') {
      return [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                label: 'Hủy đặt',
                color: AppTheme.error,
                onPressed: () => _confirmAndUpdate(
                  booking,
                  'cancelled',
                  title: 'Hủy lịch đặt?',
                  message: 'Bạn có chắc muốn hủy lịch đặt sân này không?',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                label: 'Hoàn thành',
                color: AppTheme.primary,
                onPressed: () => _updateBookingStatus(booking, 'completed'),
              ),
            ),
          ],
        ),
      ];
    }

    return const [];
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
        ),
        onPressed: _updating ? null : onPressed,
        child: Text(label),
      ),
    );
  }

  // Cập nhật trạng thái
  Future<void> _confirmAndUpdate(
    VenueBookingEntry booking,
    String newStatus, {
    required String title,
    required String message,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Đồng ý',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );

    if (mounted && ok == true) await _updateBookingStatus(booking, newStatus);
  }

  Future<void> _updateBookingStatus(
    VenueBookingEntry booking,
    String newStatus,
  ) async {
    if (_updating) return;
    final user = MockStore.currentUser;
    if (user == null || user.role != 'owner') {
      _showSnack('Chỉ chủ sân được cập nhật lịch đặt.', success: false);
      return;
    }

    setState(() => _updating = true);
    var updated = false;
    try {
      // Kiểm tra quyền sở hữu sân và trạng thái hợp lệ được làm ngay trong SQL.
      final ownsVenue = (await VenueRepository.loadVenues(
        ownerId: user.id,
      )).any((venue) => venue.id == widget.venueId);
      updated =
          ownsVenue &&
          (newStatus == 'cancelled'
              ? await BookingRepository.cancelBooking(
                  booking.id,
                  cancelReason: 'Chủ sân hủy lịch đặt',
                )
              : await BookingRepository.updateBookingStatusByOwner(
                  bookingId: booking.id,
                  ownerId: user.id,
                  newStatus: newStatus,
                ));
    } catch (_) {
      if (mounted) {
        _showSnack(
          'Không thể cập nhật lịch đặt. Vui lòng thử lại.',
          success: false,
        );
      }
    }

    if (!mounted) return;
    setState(() => _updating = false);
    if (!updated) {
      // Có thể trạng thái đã đổi ở nơi khác: tải lại để hiển thị đúng.
      await _loadBookings();
      if (mounted) {
        _showSnack(
          'Không thể cập nhật lịch đặt này. Vui lòng kiểm tra lại.',
          success: false,
        );
      }
      return;
    }

    await _loadBookings();
    if (!mounted) return;

    const messages = {
      'cancelled': 'Đã hủy lịch đặt sân.',
      'confirmed': 'Đã xác nhận lịch đặt sân.',
      'completed': 'Đã đánh dấu lịch đặt là hoàn thành.',
    };
    _showSnack(
      messages[newStatus] ?? 'Đã cập nhật.',
      success: newStatus != 'cancelled',
    );
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppTheme.success : AppTheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
