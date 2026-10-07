import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/booking.dart';
import '../../models/user.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';

class ManageVenueScreen extends StatefulWidget {
  const ManageVenueScreen({super.key});

  @override
  State<ManageVenueScreen> createState() => _ManageVenueScreenState();
}

class _ManageVenueScreenState extends State<ManageVenueScreen> {
  @override
  Widget build(BuildContext context) {
    final ownVenues = MockStore.venues
        .where((v) => v.ownerId == MockStore.currentUser?.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý sân & lịch đặt'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () {
              MockStore.logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            AppRoutes.uploadVenue,
          );

          if (!mounted) return;

          if (result == true) {
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Đăng ký sân'),
      ),
      body: ownVenues.isEmpty
          ? const Center(child: Text('Bạn chưa có sân nào được đăng ký.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...ownVenues.map(
                  (venue) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  venue.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              Chip(label: Text(_statusLabel(venue.status))),
                            ],
                          ),
                          Text(
                            venue.address,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${venue.sportType} • ${venue.pricePerHour.toStringAsFixed(0)} đ/giờ',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showEditVenue(context, venue),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Thông tin'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showBookings(context, venue.id),
                                  icon: const Icon(Icons.calendar_month),
                                  label: const Text('Lịch đặt'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.manageService,
                                arguments: venue.id,
                              ),
                              icon: const Icon(Icons.room_service_outlined),
                              label: const Text('Quản lý dịch vụ kèm theo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _statusLabel(String status) {
    return {
          'pending': 'Chờ duyệt',
          'approved': 'Đã duyệt',
          'rejected': 'Từ chối',
        }[status] ??
        status;
  }

  void _showEditVenue(BuildContext context, Venue venue) {
    final nameController = TextEditingController(text: venue.name);
    final addressController = TextEditingController(text: venue.address);
    final priceController = TextEditingController(
      text: venue.pricePerHour.toStringAsFixed(0),
    );

    String selectedSport = venue.sportType;

    final sports = [
      'Bóng đá',
      'Cầu lông',
      'Tennis',
      'Bóng rổ',
      'Bóng chuyền',
      'Khác',
    ];

    if (!sports.contains(selectedSport)) {
      sports.add(selectedSport);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Chỉnh sửa thông tin sân'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên sân',
                        prefixIcon: Icon(Icons.stadium_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSport,
                      decoration: const InputDecoration(
                        labelText: 'Loại thể thao',
                        prefixIcon: Icon(Icons.sports_soccer),
                      ),
                      items: sports
                          .map(
                            (sport) => DropdownMenuItem(
                              value: sport,
                              child: Text(sport),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedSport = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Giá thuê / giờ',
                        suffixText: 'đ',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final address = addressController.text.trim();
                    final price = double.tryParse(
                      priceController.text.trim().replaceAll(',', ''),
                    );

                    if (name.isEmpty ||
                        address.isEmpty ||
                        price == null ||
                        !price.isFinite ||
                        price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng nhập đầy đủ thông tin hợp lệ.',
                          ),
                        ),
                      );
                      return;
                    }

                    final updatedVenue = venue.copyWith(
                      name: name,
                      address: address,
                      sportType: selectedSport,
                      sportTypeId:
                          MockStore.sportTypes.firstWhere(
                                (sport) => sport['name'] == selectedSport,
                              )['id']
                              as int,
                      pricePerHour: price,
                    );

                    final success = MockStore.updateVenue(updatedVenue);

                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Không thể cập nhật thông tin sân.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);
                    setState(() {});

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã cập nhật thông tin sân.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBookings(BuildContext context, String venueId) {
    final bookings =
        MockStore.bookings.where((b) => b.venueId == venueId).toList()
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return a.startTime.compareTo(b.startTime);
          });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.8,
            child: bookings.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Chưa có lịch đặt.'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Lịch đặt sân',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...bookings.map(
                        (booking) => _buildBookingCard(sheetContext, booking),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBookingCard(BuildContext context, Booking booking) {
    AppUser? customer;

    for (final user in MockStore.users) {
      if (user.id == booking.userId) {
        customer = user;
        break;
      }
    }

    final customerName = customer?.name ?? 'Khách không xác định';
    final customerPhone = customer?.phone ?? 'Không có số điện thoại';

    final statusLabel =
        {
          'pending': 'Chờ xác nhận',
          'confirmed': 'Đã xác nhận',
          'cancelled': 'Đã hủy',
          'completed': 'Đã hoàn thành',
        }[booking.status] ??
        booking.status;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mã đặt: ${booking.id}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Divider(),
            _bookingInfoRow('Khách', customerName),
            _bookingInfoRow('Số điện thoại', customerPhone),
            _bookingInfoRow(
              'Ngày',
              '${booking.date.day}/${booking.date.month}/${booking.date.year}',
            ),
            _bookingInfoRow(
              'Thời gian',
              '${booking.startTime} - ${booking.endTime}',
            ),
            _bookingInfoRow(
              'Tổng tiền',
              '${booking.totalPrice.toStringAsFixed(0)} đ',
            ),
            _bookingInfoRow('Trạng thái', statusLabel),
            if (booking.promotionCode != null &&
                booking.promotionCode!.isNotEmpty)
              _bookingInfoRow('Khuyến mãi', booking.promotionCode!),
            if (booking.status == 'confirmed') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _updateBookingStatus(context, booking, 'cancelled');
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Hủy đặt'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _updateBookingStatus(context, booking, 'completed');
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Hoàn thành'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bookingInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _updateBookingStatus(
    BuildContext context,
    Booking booking,
    String newStatus,
  ) {
    final index = MockStore.bookings.indexWhere(
      (item) => item.id == booking.id,
    );

    if (index == -1) return;

    final updatedBooking = Booking(
      id: booking.id,
      venueId: booking.venueId,
      userId: booking.userId,
      date: booking.date,
      startTime: booking.startTime,
      endTime: booking.endTime,
      totalPrice: booking.totalPrice,
      status: newStatus,
      paymentId: booking.paymentId,
      promotionCode: booking.promotionCode,
      selectedServiceIds: booking.selectedServiceIds,
    );

    MockStore.bookings[index] = updatedBooking;

    Navigator.pop(context);

    setState(() {});

    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'cancelled'
              ? 'Đã hủy lịch đặt sân.'
              : 'Đã đánh dấu lịch đặt là hoàn thành.',
        ),
      ),
    );
  }
}
