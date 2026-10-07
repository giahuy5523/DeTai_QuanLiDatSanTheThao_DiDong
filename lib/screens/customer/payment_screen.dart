import 'dart:math';

import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/booking.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'momo';
  bool _agreed = false;
  bool _isProcessing = false;
  bool _showBankInfo = false;
  bool _simulateFailure = false;

  String _nextHour(String start) {
    final hour = int.tryParse(start.split(':').first) ?? 0;
    return '${(hour + 1).toString().padLeft(2, '0')}:00';
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(0)} đ';
  }

  String _dateText(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'momo':
        return 'Ví MoMo';
      case 'vnpay':
        return 'VNPay';
      case 'bank_transfer':
        return 'Chuyển khoản ngân hàng';
      default:
        return 'Tiền mặt tại sân';
    }
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'momo':
        return Icons.account_balance_wallet_rounded;
      case 'vnpay':
        return Icons.qr_code_2_rounded;
      case 'bank_transfer':
        return Icons.account_balance_rounded;
      default:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map<String, dynamic>
        ? rawArgs
        : <String, dynamic>{};

    final venue =
        args['venue'] as Venue? ??
        (MockStore.venues.isNotEmpty
            ? MockStore.venues.first
            : Venue.mockList().first);

    final date = args['date'] as DateTime? ?? DateTime.now();
    final startTime =
        args['startTime'] as String? ?? args['time'] as String? ?? '08:00';
    final endTime = args['endTime'] as String? ?? _nextHour(startTime);

    final serviceIds = List<String>.from(
      args['serviceIds'] as List<dynamic>? ?? const [],
    );

    final courtPrice =
        (args['courtPrice'] as num?)?.toDouble() ?? venue.pricePerHour;
    final serviceTotal = (args['serviceTotal'] as num?)?.toDouble() ?? 0;
    final discount = (args['discount'] as num?)?.toDouble() ?? 0;
    final discountAmount = (args['discountAmount'] as num?)?.toDouble() ?? 0;
    final total =
        (args['total'] as num?)?.toDouble() ??
        (courtPrice + serviceTotal - discountAmount);
    final promoCode = args['promoCode'] as String?;

    final services = MockStore.servicesFor(
      venue.id,
    ).where((s) => serviceIds.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Chọn phương thức thanh toán'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildBookingSummary(
            venue: venue,
            date: date,
            startTime: startTime,
            endTime: endTime,
            services: services,
            promoCode: promoCode,
            courtPrice: courtPrice,
            serviceTotal: serviceTotal,
            discount: discount,
            discountAmount: discountAmount,
            total: total,
          ),
          const SizedBox(height: 16),
          _buildPaymentMethods(),
          const SizedBox(height: 12),
          if (_method == 'bank_transfer') _buildBankTransferInfo(total),
          const SizedBox(height: 12),
          _buildPaymentNotice(),
          const SizedBox(height: 12),
          _buildAgreement(),
          const SizedBox(height: 12),
          _buildDemoOptions(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(total),
    );
  }

  Widget _buildBookingSummary({
    required Venue venue,
    required DateTime date,
    required String startTime,
    required String endTime,
    required List services,
    required String? promoCode,
    required double courtPrice,
    required double serviceTotal,
    required double discount,
    required double discountAmount,
    required double total,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Thông tin đơn đặt sân',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: AppTheme.border),
            _priceLine('Tiền thuê sân', courtPrice),
            if (serviceTotal > 0) _priceLine('Dịch vụ', serviceTotal),
            if (discountAmount > 0)
              _priceLine(
                discount > 0
                    ? 'Giảm giá (${discount.toStringAsFixed(0)}%)'
                    : 'Giảm giá',
                -discountAmount,
                positive: true,
              ),
            const SizedBox(height: 8),
            Text(
              venue.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            _summaryLine(
              Icons.calendar_today_outlined,
              'Ngày',
              _dateText(date),
            ),
            _summaryLine(
              Icons.access_time_rounded,
              'Khung giờ',
              '$startTime - $endTime',
            ),
            _summaryLine(Icons.location_on_outlined, 'Địa điểm', venue.address),
            if (services.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Dịch vụ kèm theo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...services.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${s.name} • ${_formatMoney(s.price)}/${s.unit}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (promoCode != null && promoCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 17,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mã khuyến mãi: $promoCode',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 22, color: AppTheme.border),
            _priceLine('Tiền thuê sân', courtPrice),
            if (serviceTotal > 0) _priceLine('Dịch vụ', serviceTotal),
            if (discountAmount > 0)
              _priceLine('Giảm giá', -discountAmount, positive: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng thanh toán',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  Text(
                    _formatMoney(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      color: AppTheme.primary,
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

  Widget _summaryLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppTheme.textSecondary),
          const SizedBox(width: 7),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceLine(String label, double amount, {bool positive = false}) {
    final isNegative = amount < 0;
    final text = isNegative
        ? '-${_formatMoney(-amount)}'
        : _formatMoney(amount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: positive ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      {
        'id': 'cash',
        'title': 'Tiền mặt',
        'subtitle': 'Thanh toán trực tiếp tại sân',
      },
      {
        'id': 'momo',
        'title': 'Ví MoMo',
        'subtitle': 'Thanh toán qua ví điện tử (mô phỏng)',
      },
      {
        'id': 'vnpay',
        'title': 'VNPay',
        'subtitle': 'Thanh toán qua cổng VNPay (mô phỏng)',
      },
      {
        'id': 'bank_transfer',
        'title': 'Chuyển khoản ngân hàng',
        'subtitle': 'Chuyển khoản theo thông tin của hệ thống',
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Phương thức thanh toán',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            const SizedBox(height: 8),
            ...methods.map(
              (method) => _buildMethodCard(
                id: method['id']!,
                title: method['title']!,
                subtitle: method['subtitle']!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required String id,
    required String title,
    required String subtitle,
  }) {
    final selected = _method == id;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isProcessing
          ? null
          : () {
              setState(() {
                _method = id;
                _showBankInfo = id == 'bank_transfer';
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? Colors.white : AppTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _paymentIcon(id),
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _method,
              onChanged: _isProcessing
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _method = value;
                        _showBankInfo = value == 'bank_transfer';
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankTransferInfo(double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_rounded,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thông tin chuyển khoản',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Ẩn/hiện',
                  onPressed: () {
                    setState(() => _showBankInfo = !_showBankInfo);
                  },
                  icon: Icon(
                    _showBankInfo
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ),
              ],
            ),
            if (_showBankInfo) ...[
              const Divider(height: 20),
              _bankRow('Ngân hàng', 'Vietcombank'),
              _bankRow('Số tài khoản', '0123 456 789'),
              _bankRow('Chủ tài khoản', 'ALOBO SPORT'),
              _bankRow('Số tiền', _formatMoney(total)),
              _bankRow('Nội dung', 'ALBO DAT SAN'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 17, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đây là dữ liệu mô phỏng cho đồ án, không thực hiện chuyển khoản thật.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentNotice() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 19,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _method == 'cash'
                    ? 'Đơn sẽ được ghi nhận với phương thức tiền mặt và thanh toán tại sân.'
                    : 'Thanh toán được mô phỏng. Hệ thống sẽ tạo Payment ở trạng thái pending trước khi xác nhận kết quả.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreement() {
    return Card(
      child: CheckboxListTile(
        value: _agreed,
        onChanged: _isProcessing
            ? null
            : (value) {
                setState(() => _agreed = value ?? false);
              },
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        title: const Text(
          'Tôi xác nhận thông tin đặt sân là chính xác',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Tôi đồng ý tiếp tục với phương thức thanh toán đã chọn.',
          style: TextStyle(fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildDemoOptions() {
    return Card(
      child: SwitchListTile(
        value: _simulateFailure,
        onChanged: _isProcessing
            ? null
            : (value) {
                setState(() => _simulateFailure = value);
              },
        title: const Text(
          'Mô phỏng thanh toán thất bại',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Dùng khi demo nhánh failed trong Sequence Diagram.',
          style: TextStyle(fontSize: 10),
        ),
        secondary: const Icon(Icons.science_outlined),
      ),
    );
  }

  Widget _buildBottomBar(double total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cần thanh toán',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  _formatMoney(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (!_agreed || _isProcessing) ? null : _handlePayment,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_rounded),
                label: Text(
                  _isProcessing
                      ? 'Đang xử lý thanh toán...'
                      : 'Xác nhận thanh toán',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    if (!_agreed || _isProcessing) return;

    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map<String, dynamic>
        ? rawArgs
        : <String, dynamic>{};

    final venue =
        args['venue'] as Venue? ??
        (MockStore.venues.isNotEmpty
            ? MockStore.venues.first
            : Venue.mockList().first);

    final date = args['date'] as DateTime? ?? DateTime.now();
    final startTime =
        args['startTime'] as String? ?? args['time'] as String? ?? '08:00';
    final endTime = args['endTime'] as String? ?? _nextHour(startTime);

    final serviceIds = List<String>.from(
      args['serviceIds'] as List<dynamic>? ?? const [],
    );
    final courtPrice =
        (args['courtPrice'] as num?)?.toDouble() ?? venue.pricePerHour;
    final serviceTotal = (args['serviceTotal'] as num?)?.toDouble() ?? 0;
    final discountAmount = (args['discountAmount'] as num?)?.toDouble() ?? 0;
    final total =
        (args['total'] as num?)?.toDouble() ??
        (courtPrice + serviceTotal - discountAmount);
    final promoCode = args['promoCode'] as String?;
    final userId = MockStore.currentUser?.id ?? 'customer1';

    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // 1. Kiểm tra tính khả dụng của khoảng thời gian (Khớp bước 27-30 Sequence)
    final isAvailable = MockStore.isRangeAvailable(
      venue.id,
      date,
      startTime,
      endTime,
    );

    if (!isAvailable) {
      setState(() => _isProcessing = false);
      await _showSlotUnavailable();
      return;
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final bookingId = 'b$timestamp';
    final paymentId = 'pay$timestamp';

    // 2. Tạo Booking ở trạng thái pending (Khớp bước 32 Sequence & ERD)
    // Đã bỏ thuộc tính paymentId theo đúng sơ đồ chuẩn hóa ERD
    final pendingBooking = Booking(
      id: bookingId,
      venueId: venue.id,
      userId: userId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      originalAmount: courtPrice,
      serviceAmount: serviceTotal,
      discountAmount: discountAmount,
      totalPrice: total,
      status: 'pending',
      paymentStatus: 'unpaid',
      promotionCode: promoCode,
      selectedServiceIds: serviceIds,
    );

    MockStore.addBooking(pendingBooking);

    // 3. Tạo Payments ở trạng thái pending (Khớp bước 41 Sequence & Bảng Payments trong ERD)
    final payment = <String, dynamic>{
      'id': paymentId,
      'bookingId': bookingId, // Khóa ngoại FK trỏ tới Bookings
      'method': _method,
      'amount': total,
      'status': 'pending',
      'transactionCode': null,
      'createdAt': DateTime.now(),
    };
    MockStore.payments.add(payment);

    final paymentSuccess = !_simulateFailure;

    if (!paymentSuccess) {
      // Thanh toán thất bại (Khớp bước 46 Sequence)
      payment['status'] = 'failed';
      payment['transactionCode'] = 'TXN-FAILED-$timestamp';

      // Cập nhật booking trạng thái cancelled/failed thay vì xóa cứng
      MockStore.bookings.removeWhere((b) => b.id == bookingId);

      setState(() => _isProcessing = false);
      await _showPaymentFailed(bookingId: bookingId, paymentId: paymentId);
      return;
    }

    // 4. Thanh toán thành công (Khớp bước 42-43 Sequence)
    final transactionCode = _method == 'cash'
        ? null
        : 'TXN${Random().nextInt(900000) + 100000}';

    payment['status'] = 'success';
    payment['transactionCode'] = transactionCode;
    payment['paidAt'] = DateTime.now();

    MockStore.bookings.removeWhere((b) => b.id == bookingId);

    // Cập nhật trạng thái Booking sang confirmed & paid (hoặc unpaid nếu thanh toán tiền mặt)
    final confirmedBooking = Booking(
      id: bookingId,
      venueId: venue.id,
      userId: userId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      originalAmount: courtPrice,
      serviceAmount: serviceTotal,
      discountAmount: discountAmount,
      totalPrice: total,
      status: 'confirmed',
      paymentStatus: _method == 'cash' ? 'unpaid' : 'paid',
      promotionCode: promoCode,
      selectedServiceIds: serviceIds,
    );

    MockStore.addBooking(confirmedBooking);

    // 5. Tăng lượt sử dụng mã giảm giá (Cập nhật sau khi thanh toán thành công)
    if (promoCode != null && promoCode.isNotEmpty) {
      try {
        final dynamic promo = MockStore.promotions.firstWhere(
          (p) => p.code.toLowerCase() == promoCode.toLowerCase(),
        );
        promo.usedCount = (promo.usedCount ?? 0) + 1;
      } catch (_) {}
    }

    setState(() => _isProcessing = false);

    await _showPaymentSuccess(
      venue: venue,
      date: date,
      startTime: startTime,
      endTime: endTime,
      total: total,
      bookingId: bookingId,
      paymentId: paymentId,
      transactionCode: transactionCode,
    );
  }

  Future<void> _showSlotUnavailable() {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.event_busy_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Khung giờ không còn trống')),
          ],
        ),
        content: const Text(
          'Khung giờ này vừa được người khác đặt. '
          'Booking chưa được tạo và bạn có thể quay lại chọn giờ khác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Chọn giờ khác'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentFailed({
    required String bookingId,
    required String paymentId,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Thanh toán thất bại')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment đã được ghi nhận với trạng thái failed. '
              'Bạn có thể thử lại với phương thức khác.',
            ),
            const SizedBox(height: 14),
            _resultRow('Mã đặt sân', bookingId),
            _resultRow('Mã thanh toán', paymentId),
            _resultRow('Phương thức', _paymentMethodLabel(_method)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đổi phương thức'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _simulateFailure = false);
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentSuccess({
    required Venue venue,
    required DateTime date,
    required String startTime,
    required String endTime,
    required double total,
    required String bookingId,
    required String paymentId,
    required String? transactionCode,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
            SizedBox(height: 8),
            Text('Thanh toán thành công', textAlign: TextAlign.center),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Đặt sân đã được xác nhận.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              _resultRow('Mã đặt sân', bookingId),
              _resultRow('Mã thanh toán', paymentId),
              if (transactionCode != null)
                _resultRow('Mã giao dịch', transactionCode),
              _resultRow('Sân', venue.name),
              _resultRow('Ngày', _dateText(date)),
              _resultRow('Thời gian', '$startTime - $endTime'),
              _resultRow('Thanh toán', _paymentMethodLabel(_method)),
              _resultRow('Trạng thái', 'success / confirmed'),
              const Divider(height: 22),
              _resultRow('Tổng tiền', _formatMoney(total), bold: true),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.popUntil(
              context,
              (route) =>
                  route.settings.name == AppRoutes.customerShell ||
                  route.settings.name == AppRoutes.home ||
                  route.isFirst,
            ),
            child: const Text('Về trang chủ'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}