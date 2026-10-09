class Promotion {
  final String id;
  final String code;
  final double discountPercent;
  final DateTime expiryDate;
  final bool isActive;

  // Số lượt sử dụng mã khuyến mãi
  int usedCount;

  Promotion({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.expiryDate,
    this.isActive = true,
    this.usedCount = 0,
  });

  bool isExpiredAt(DateTime now) => !now.isBefore(
    DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    ).add(const Duration(days: 1)),
  );

  bool isValidAt(DateTime now) =>
      isActive &&
      !isExpiredAt(now) &&
      discountPercent.isFinite &&
      discountPercent > 0 &&
      discountPercent <= 100;

  static List<Promotion> mockList() {
    return [
      Promotion(
        id: 'p1',
        code: 'SAN10',
        discountPercent: 10,
        expiryDate: DateTime.now().add(
          const Duration(days: 30),
        ),
      ),
      Promotion(
        id: 'p2',
        code: 'SAN20TET',
        discountPercent: 20,
        expiryDate: DateTime.now().add(
          const Duration(days: 60),
        ),
      ),
    ];
  }
}