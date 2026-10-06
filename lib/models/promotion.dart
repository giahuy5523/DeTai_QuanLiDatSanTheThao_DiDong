/// Model Khuyến mãi - tương ứng bảng Promotions trong ERD.
/// Do admin quản lý.
/// status: "active" | "inactive"
class Promotion {
  final String promoId; // promo_id (PK)
  final String code; // code (UK)
  final String? description;
  final double discountPercent; // discount_percent
  final double? maxDiscountAmount; // max_discount_amount (null = không giới hạn)
  final double minOrderAmount; // min_order_amount
  final DateTime startDate; // start_date
  final DateTime endDate; // end_date
  final int? usageLimit; // usage_limit (null = không giới hạn)
  final int usedCount; // used_count
  final String status;
  final String createdBy; // created_by (FK -> Users, admin)

  Promotion({
    required this.promoId,
    required this.code,
    this.description,
    required this.discountPercent,
    this.maxDiscountAmount,
    this.minOrderAmount = 0,
    required this.startDate,
    required this.endDate,
    this.usageLimit,
    this.usedCount = 0,
    this.status = 'active',
    required this.createdBy,
  });

  static List<Promotion> mockList() {
    return [
      Promotion(
        promoId: 'p1',
        code: 'SAN10',
        description: 'Giảm 10% cho mọi đơn đặt sân',
        discountPercent: 10,
        maxDiscountAmount: 50000,
        minOrderAmount: 100000,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 30)),
        usageLimit: 100,
        createdBy: 'admin1',
      ),
      Promotion(
        promoId: 'p2',
        code: 'SAN20TET',
        description: 'Giảm 20% dịp Tết',
        discountPercent: 20,
        maxDiscountAmount: 100000,
        minOrderAmount: 200000,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 60)),
        usageLimit: 50,
        createdBy: 'admin1',
      ),
    ];
  }
}
