import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
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
  // ---- Màu sắc ----
  static const _primaryGreen = Color(0xFF0F8B5F);
  static const _darkGreen = Color(0xFF065F46);
  static const _background = Color(0xFFF5F7FA);
  static const _blue = Color(0xFF3B82F6);
  static const _orange = Color(0xFFFFB13B);
  static const _red = Color(0xFFEF4444);
  static const _textDark = Color(0xFF111827);
  static const _textGrey = Color(0xFF6B7280);
  static const _avatarBg = Color(0xFFB7F0D8);

  static const _stripDays = 14;

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
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
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
              style: const TextStyle(color: _textGrey),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
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
      color: _background,
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
                color: selected ? _primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _primaryGreen.withValues(alpha: 0.3),
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
                      color: selected ? Colors.white : _textGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : _textDark,
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
                          ? (selected ? Colors.white : _primaryGreen)
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
                color: selected ? _primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f.value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _textGrey,
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
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ngày ${_selectedDate.day}/${_selectedDate.month} chưa có khách đặt sân.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textGrey),
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
      key: ValueKey(booking.id),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    color: _textDark,
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
                backgroundColor: _avatarBg,
                child: Icon(Icons.person, size: 28, color: _darkGreen),
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
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerPhone,
                      style: const TextStyle(color: _textGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tổng tiền
          Row(
            children: [
              const Expanded(
                child: Text('Tổng tiền', style: TextStyle(color: _textGrey)),
              ),
              Text(
                _formatMoney(booking.totalPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _darkGreen,
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
                color: const Color(0xFFE8F7F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 14,
                    color: _primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mã ${booking.promotionCode}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _darkGreen,
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

  Widget _buildStatusPill(String status) {
    late final String label;
    late final Color bg;
    late final Color fg;

    switch (status) {
      case 'pending':
        label = 'Chờ xác nhận';
        bg = _orange;
        fg = _textDark;
        break;
      case 'confirmed':
        label = 'Đã xác nhận';
        bg = _blue;
        fg = Colors.white;
        break;
      case 'completed':
        label = 'Đã hoàn thành';
        bg = _primaryGreen;
        fg = Colors.white;
        break;
      case 'cancelled':
        label = 'Đã hủy';
        bg = const Color(0xFFE5E7EB);
        fg = _textGrey;
        break;
      default:
        label = status;
        bg = const Color(0xFFE5E7EB);
        fg = _textGrey;
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
                color: _red,
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
                color: _primaryGreen,
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
                color: _red,
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
                color: _primaryGreen,
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
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _updating ? null : onPressed,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
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
            child: const Text('Đồng ý', style: TextStyle(color: _red)),
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
      updated = await VenueRepository.updateBookingStatus(
        bookingId: booking.id,
        ownerId: user.id,
        newStatus: newStatus,
        cancelReason: newStatus == 'cancelled' ? 'Chủ sân hủy lịch đặt' : null,
      );
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
