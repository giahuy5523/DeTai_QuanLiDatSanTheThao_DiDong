import 'package:flutter/material.dart';

import '../../data/mock_store.dart';
import '../../data/booking_repository.dart' as data_repo;
import '../../data/venue_repository.dart';
import '../../models/service.dart';
import '../../models/booking.dart';
import '../../models/promotion.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../widgets/venue_image.dart';

/// Màn hình đặt sân - phong cách Nhom1_DatSanTheThao.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _date = DateTime.now();
  String? _startTime;
  String? _endTime;

  final Map<String, int> _selectedServices = {}; // serviceId -> quantity
  final _promoController = TextEditingController();

  String? _promoMessage;
  double _discount = 0;
  String? _appliedPromoCode;

  List<Booking> _bookedBookings = [];
  bool _isLoadingAvailability = true;
  bool _availabilityLoadFailed = false;
  String? _availabilityKey;
  int _availabilityRequestId = 0;

  String? _catalogVenueId;
  List<int> _hours = const [6, 22];
  List<VenueService> _services = const [];
  List<String> _images = const [];
  List<Promotion> _promotions = const [];

  String _availabilityKeyFor(Venue venue) {
    return '${venue.id}_${_date.year}-${_date.month}-${_date.day}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    final venue = args is Venue
        ? args
        : (MockStore.venues.isNotEmpty
              ? MockStore.venues.first
              : Venue.mockList().first);

    if (_catalogVenueId != venue.id) {
      _catalogVenueId = venue.id;
      _loadCatalog(venue.id);
    }

    final nextKey = _availabilityKeyFor(venue);
    if (_availabilityKey != nextKey) {
      _availabilityKey = nextKey;
      _isLoadingAvailability = true;
      _availabilityLoadFailed = false;
      _loadBookedBookings(venue);
    }
  }

  Future<void> _loadCatalog(String venueId) async {
    final hours = await VenueRepository.loadHoursFor(venueId);
    final services = await VenueRepository.loadServicesFor(venueId);
    final images = await VenueRepository.loadImageUrlsFor(venueId);
    final promotions = await data_repo.BookingRepository.loadActivePromotions();
    if (!mounted || _catalogVenueId != venueId) return;
    setState(() {
      _hours = hours;
      _services = services;
      _images = images;
      _promotions = promotions;
    });
  }

  Future<void> _loadBookedBookings(Venue venue) async {
    final requestId = ++_availabilityRequestId;

    try {
      final bookings = await data_repo.BookingRepository.getBookingsForVenue(
        venue.id,
      );

      if (!mounted || requestId != _availabilityRequestId) return;

      setState(() {
        _bookedBookings = bookings
            .where(
              (booking) =>
                  booking.status != 'cancelled' &&
                  booking.date.year == _date.year &&
                  booking.date.month == _date.month &&
                  booking.date.day == _date.day,
            )
            .toList();
        _isLoadingAvailability = false;
        _availabilityLoadFailed = false;
      });
    } catch (_) {
      if (!mounted || requestId != _availabilityRequestId) return;

      setState(() {
        _bookedBookings = [];
        _isLoadingAvailability = false;
        _availabilityLoadFailed = true;
      });
    }
  }

  bool _hasBookedOverlap(String startTime, String endTime) {
    final start = _timeToMinutes(startTime);
    final end = _timeToMinutes(endTime);

    return _bookedBookings.any((booking) {
      final bookedStart = _timeToMinutes(booking.startTime);
      final bookedEnd = _timeToMinutes(booking.endTime);
      return start < bookedEnd && end > bookedStart;
    });
  }

  List<String> _timesFor(Venue venue, {bool includeClosing = false}) {
    final hours = _hours;
    final openingHour = hours[0];
    final closingHour = hours[1];

    var lastHour = closingHour;

    // Giờ bắt đầu không được là giờ đóng cửa.
    if (!includeClosing) {
      lastHour = closingHour - 1;
    }

    var times = [
      for (var hour = openingHour; hour <= lastHour; hour++)
        '${hour.toString().padLeft(2, '0')}:00',
    ];

    // Nếu chọn hôm nay thì không hiển thị các giờ bắt đầu đã trôi qua.
    if (!includeClosing && _sameDate(_date, DateTime.now())) {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      times = times.where((time) {
        return _timeToMinutes(time) > currentMinutes;
      }).toList();
    }

    return times;
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  double get _durationHours {
    if (_startTime == null || _endTime == null) return 0;

    final start = _timeToMinutes(_startTime!);
    final end = _timeToMinutes(_endTime!);
    return (end - start) / 60;
  }

  Future<bool> _isTimeRangeAvailable(
    Venue venue,
    String startTime,
    String endTime,
  ) {
    return data_repo.BookingRepository.isRangeAvailable(
      venueId: venue.id,
      date: _date,
      startTime: startTime,
      endTime: endTime,
    );
  }

  Future<void> _selectStartTime(Venue venue, String time) async {
    final nextHour = _timeToMinutes(time) ~/ 60 + 1;
    final endTime = '${nextHour.toString().padLeft(2, '0')}:00';
    final available = await _isTimeRangeAvailable(venue, time, endTime);

    if (!mounted) return;
    if (!available) {
      _showMessage('Khung giờ $time đã được đặt.');
      return;
    }

    setState(() {
      _startTime = time;
      _endTime = null;
    });
  }

  Future<void> _selectEndTime(Venue venue, String time) async {
    if (_startTime == null) {
      _showMessage('Vui lòng chọn giờ bắt đầu trước.');
      return;
    }

    if (_timeToMinutes(time) <= _timeToMinutes(_startTime!)) {
      _showMessage('Giờ kết thúc phải sau giờ bắt đầu.');
      return;
    }

    final available = await _isTimeRangeAvailable(venue, _startTime!, time);
    if (!mounted) return;
    if (!available) {
      _showMessage('Khoảng thời gian bạn chọn có khung giờ đã được đặt.');
      return;
    }

    setState(() => _endTime = time);
  }

  Future<void> _continueToConfirmation({
    required BuildContext context,
    required Venue venue,
    required double serviceTotal,
    required double courtTotal,
    required double subtotal,
    required double discountAmount,
    required double total,
  }) async {
    if (_startTime == null || _endTime == null) return;

    final available = await _isTimeRangeAvailable(
      venue,
      _startTime!,
      _endTime!,
    );
    if (!context.mounted) return;
    if (!available) {
      setState(() => _endTime = null);
      _showMessage('Khung giờ vừa chọn không còn khả dụng. Vui lòng chọn lại.');
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.bookingConfirmation,
      arguments: {
        'venue': venue,
        'date': _date,
        'startTime': _startTime,
        'endTime': _endTime,
        'serviceIds': _selectedServices.keys.toList(),
        'serviceQuantities': Map<String, int>.from(_selectedServices),
        'courtPrice': courtTotal,
        'serviceTotal': serviceTotal,
        'discount': _discount,
        'discountAmount': discountAmount,
        'subtotal': subtotal,
        'total': total,
        'promoCode': _appliedPromoCode,
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _pickDate(BuildContext context) async {
    final args = ModalRoute.of(context)?.settings.arguments;
    final venue = args is Venue
        ? args
        : (MockStore.venues.isNotEmpty
              ? MockStore.venues.first
              : Venue.mockList().first);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      initialDate: _date.isBefore(today) ? today : _date,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _startTime = null;
      _endTime = null;
      _bookedBookings = [];
      _isLoadingAvailability = true;
      _availabilityLoadFailed = false;
      _availabilityKey = _availabilityKeyFor(venue);
    });

    _loadBookedBookings(venue);
  }

  void _applyPromo() {
    final code = _promoController.text.trim().toUpperCase();

    setState(() {
      _discount = 0;
      _appliedPromoCode = null;
      _promoMessage = null;
    });

    if (code.isEmpty) {
      setState(() {
        _promoMessage = 'Vui lòng nhập mã khuyến mãi.';
      });
      return;
    }

    Promotion? promo;
    for (final item in _promotions) {
      if (item.code == code && item.isValidAt(DateTime.now())) {
        promo = item;
        break;
      }
    }

    setState(() {
      if (promo == null) {
        _discount = 0;
        _appliedPromoCode = null;
        _promoMessage = 'Mã không hợp lệ hoặc đã hết hạn.';
      } else {
        _discount = promo.discountPercent;
        _appliedPromoCode = code;
        _promoMessage =
            'Đã áp dụng giảm ${promo.discountPercent.toStringAsFixed(0)}%.';
      }
    });
  }

  String _formatDateDisplay(DateTime date) {
    final now = DateTime.now();
    final isToday = _sameDate(date, now);

    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];

    final dayLabel = isToday ? 'Hôm nay' : weekdays[date.weekday - 1];

    return '$dayLabel, '
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  IconData _getSportIcon(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'bóng đá':
        return Icons.sports_soccer_rounded;
      case 'cầu lông':
        return Icons.sports_tennis_rounded;
      case 'tennis':
        return Icons.sports_tennis_outlined;
      case 'bóng rổ':
        return Icons.sports_basketball_rounded;
      case 'bóng chuyền':
        return Icons.sports_volleyball_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    final Venue venue = args is Venue
        ? args
        : (MockStore.venues.isNotEmpty
              ? MockStore.venues.first
              : Venue.mockList().first);

    final services = _services;

    final serviceTotal = services.fold<double>(0, (sum, service) {
      final qty = _selectedServices[service.id] ?? 0;
      return sum + (service.price * qty);
    });

    final courtTotal = venue.pricePerHour * _durationHours;
    final subtotal = courtTotal + serviceTotal;
    final discountAmount = subtotal * _discount / 100;
    final total = subtotal - discountAmount;

    final canContinue =
        venue.status == 'approved' &&
        _startTime != null &&
        _endTime != null &&
        _durationHours > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Đặt sân')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildVenueInfoCard(venue),
          const SizedBox(height: 16),
          _buildSectionHeader(Icons.calendar_today_rounded, 'Ngày đặt sân'),
          const SizedBox(height: 8),
          _buildDateSelectionCard(context),
          const SizedBox(height: 16),
          _buildSectionHeader(Icons.access_time_rounded, 'Khung giờ đặt'),
          const SizedBox(height: 8),
          _buildTimeSlotsCard(venue),
          const SizedBox(height: 16),
          _buildSectionHeader(
            Icons.room_service_outlined,
            'Dịch vụ kèm theo (tùy chọn)',
          ),
          const SizedBox(height: 8),
          _buildServicesCard(services),
          const SizedBox(height: 16),
          _buildSectionHeader(Icons.local_offer_outlined, 'Mã khuyến mãi'),
          const SizedBox(height: 8),
          _buildPromoCodeCard(),
          const SizedBox(height: 16),
          _buildPriceSummaryCard(
            venue,
            serviceTotal,
            courtTotal,
            subtotal,
            discountAmount,
            total,
          ),
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: _buildStickyBottomCTA(
        context,
        venue,
        serviceTotal,
        courtTotal,
        subtotal,
        discountAmount,
        total,
        canContinue,
      ),
    );
  }

  Widget _buildVenuePhoto(Venue venue, {double height = 140}) {
    final images = _images;
    if (images.isEmpty) {
      return _missingImageNotice('Chưa có ảnh cho sân ${venue.name}.');
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: VenueImage(
          source: images.first,
          placeholder: _missingImageNotice(
            'Ảnh sân ${venue.name} không tải được. Kiểm tra đường dẫn ảnh.',
          ),
        ),
      ),
    );
  }

  Widget _missingImageNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _buildVenueInfoCard(Venue venue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVenuePhoto(venue, height: 150),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getSportIcon(venue.sportType),
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              venue.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppTheme.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    venue.sportType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${venue.pricePerHour.toStringAsFixed(0)} đ',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const TextSpan(
                        text: ' / giờ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectionCard(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _pickDate(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateDisplay(_date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Nhấn để chọn ngày khác',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.calendar_month_outlined,
                color: AppTheme.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlotsCard(Venue venue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingAvailability)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Đang tải lịch đặt sân...',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              )
            else if (_availabilityLoadFailed)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Không tải được lịch đặt sân. Vui lòng thử tải lại màn hình.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            const Text(
              'Bước 1: Chọn giờ bắt đầu',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timesFor(venue).map((time) {
                final isSelected = _startTime == time;
                final endMinutes = _timeToMinutes(time) + 60;
                final endTime =
                    '${(endMinutes ~/ 60).toString().padLeft(2, '0')}:'
                    '${(endMinutes % 60).toString().padLeft(2, '0')}';
                final isBooked =
                    _isLoadingAvailability ||
                    _availabilityLoadFailed ||
                    _hasBookedOverlap(time, endTime);

                return _buildTimeChip(
                  key: ValueKey('start_$time'),
                  label: time,
                  selected: isSelected,
                  disabled: isBooked,
                  onTap: () => _selectStartTime(venue, time),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bước 2: Chọn giờ kết thúc',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (_startTime == null)
              const Text(
                'Chọn giờ bắt đầu trước.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timesFor(venue, includeClosing: true)
                    .where(
                      (time) =>
                          _timeToMinutes(time) > _timeToMinutes(_startTime!),
                    )
                    .map((time) {
                      final isSelected = _endTime == time;
                      final isUnavailable =
                          _isLoadingAvailability ||
                          _availabilityLoadFailed ||
                          _hasBookedOverlap(_startTime!, time);

                      return _buildTimeChip(
                        key: ValueKey('end_$time'),
                        label: time,
                        selected: isSelected,
                        disabled: isUnavailable,
                        onTap: () => _selectEndTime(venue, time),
                      );
                    })
                    .toList(),
              ),
            if (_startTime != null && _endTime != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đã chọn: $_startTime - $_endTime '
                        '(${_durationHours.toStringAsFixed(0)} giờ)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Khung giờ đã đặt sẽ không thể lựa chọn.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip({
    required Key key,
    required String label,
    required bool selected,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: disabled
              ? AppTheme.background
              : selected
              ? AppTheme.primary
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled
                ? AppTheme.border
                : selected
                ? AppTheme.primary
                : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              disabled
                  ? Icons.block_rounded
                  : selected
                  ? Icons.check_circle_rounded
                  : Icons.access_time_rounded,
              size: 14,
              color: disabled
                  ? AppTheme.textSecondary
                  : selected
                  ? Colors.white
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
                color: disabled
                    ? AppTheme.textSecondary
                    : selected
                    ? Colors.white
                    : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceImage(String serviceName) {
    final normalized = serviceName.toLowerCase();
    final asset = normalized.contains('nước')
        ? 'assets/services/water.jpg'
        : normalized.contains('vợt')
        ? 'assets/services/racket.jpg'
        : normalized.contains('giày')
        ? 'assets/services/shoes.jpg'
        : null;
    if (asset == null) {
      return _missingServiceImage('Chưa có ảnh cho dịch vụ: $serviceName');
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        asset,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _missingServiceImage('Thiếu ảnh: $asset'),
      ),
    );
  }

  Widget _missingServiceImage(String message) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildServicesCard(List services) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: services.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Sân hiện chưa cung cấp dịch vụ phụ trợ.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              )
            : Column(
                children: services.map((service) {
                  final qty = _selectedServices[service.id] ?? 0;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: qty > 0
                          ? AppTheme.primaryLight.withValues(alpha: 0.35)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: qty > 0 ? AppTheme.primary : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _serviceImage(service.name),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: TextStyle(
                                  fontWeight: qty > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${service.price.toStringAsFixed(0)} đ / ${service.unit}',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: qty > 0
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              onPressed: qty > 0
                                  ? () => setState(() {
                                      if (qty == 1) {
                                        _selectedServices.remove(service.id);
                                      } else {
                                        _selectedServices[service.id] = qty - 1;
                                      }
                                    })
                                  : null,
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: AppTheme.primary,
                              onPressed: () => setState(() {
                                _selectedServices[service.id] = qty + 1;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildPromoCodeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    onChanged: (_) => setState(() {
                      _discount = 0;
                      _appliedPromoCode = null;
                      _promoMessage = null;
                    }),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Ví dụ: SAN10',
                      prefixIcon: Icon(
                        Icons.discount_outlined,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(90, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: _applyPromo,
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
            if (_promoMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      _discount > 0
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 16,
                      color: _discount > 0 ? AppTheme.primary : AppTheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _promoMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _discount > 0
                              ? AppTheme.primary
                              : AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSummaryCard(
    Venue venue,
    double serviceTotal,
    double courtTotal,
    double subtotal,
    double discountAmount,
    double total,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chi tiết thanh toán',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
            ),
            const Divider(height: 20, color: AppTheme.border),
            _summaryRow(
              'Tiền thuê sân (${_durationHours.toStringAsFixed(0)} giờ)',
              courtTotal,
            ),
            if (serviceTotal > 0) ...[
              const SizedBox(height: 8),
              _summaryRow('Dịch vụ phụ trợ', serviceTotal),
            ],
            if (_discount > 0) ...[
              const SizedBox(height: 8),
              _summaryRow(
                'Giảm giá (${_discount.toStringAsFixed(0)}%)',
                -discountAmount,
                valueColor: AppTheme.primary,
              ),
            ],
            const Divider(height: 22, color: AppTheme.border),
            _summaryRow(
              'Tổng cộng',
              total,
              bold: true,
              valueColor: AppTheme.primary,
              fontSize: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomCTA(
    BuildContext context,
    Venue venue,
    double serviceTotal,
    double courtTotal,
    double subtotal,
    double discountAmount,
    double total,
    bool canContinue,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng thanh toán',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${total.toStringAsFixed(0)} đ',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: ElevatedButton(
                onPressed: canContinue
                    ? () => _continueToConfirmation(
                        context: context,
                        venue: venue,
                        serviceTotal: serviceTotal,
                        courtTotal: courtTotal,
                        subtotal: subtotal,
                        discountAmount: discountAmount,
                        total: total,
                      )
                    : null,
                child: Text(
                  canContinue
                      ? 'Tiếp tục'
                      : venue.status != 'approved'
                      ? (venue.status == 'pending'
                            ? 'Sân đang chờ duyệt'
                            : 'Sân chưa thể đặt')
                      : _startTime == null
                      ? 'Chọn giờ bắt đầu'
                      : _endTime == null
                      ? 'Chọn giờ kết thúc'
                      : 'Khung giờ không khả dụng',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    double amount, {
    bool bold = false,
    Color? valueColor,
    double fontSize = 14,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: fontSize,
      color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
    );

    final valueStyle = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
      fontSize: fontSize,
      color: valueColor ?? AppTheme.textPrimary,
    );

    final formattedAmount = amount < 0
        ? '-${(-amount).toStringAsFixed(0)} đ'
        : '${amount.toStringAsFixed(0)} đ';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 12),
        Text(formattedAmount, style: valueStyle),
      ],
    );
  }
}
