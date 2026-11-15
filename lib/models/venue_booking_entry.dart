// Nó là dữ liệu gọn cho màn "Lịch đặt sân" của chủ sân,
// đã gộp sẵn tên và số điện thoại khách.
class VenueBookingEntry {
  const VenueBookingEntry({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.status,
    this.promotionCode,
    this.customerName,
    this.customerPhone,
    this.services = const [],
  });

  final String id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final double totalPrice;
  final String status;
  final String? promotionCode;
  final String? customerName;
  final String? customerPhone;

  // Dịch vụ kèm theo khách đã chọn (rỗng nếu khách không chọn dịch vụ nào).
  final List<VenueBookingServiceItem> services;
}

// Một dịch vụ khách chọn kèm lịch đặt (từ bảng booking_services).
class VenueBookingServiceItem {
  const VenueBookingServiceItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
}
