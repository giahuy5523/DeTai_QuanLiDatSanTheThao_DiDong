/// Model Khuyến mãi - tương ứng bảng Promotions trong ERD.
class Promotion {
  final String id;
  final String code;
  final double discountPercent;
  final DateTime expiryDate;
  final bool isActive;

  Promotion({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.expiryDate,
    this.isActive = true,
  });

  static List<Promotion> mockList() {
    return [
      Promotion(
        id: 'p1',
        code: 'SAN10',
        discountPercent: 10,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      ),
      Promotion(
        id: 'p2',
        code: 'SAN20TET',
        discountPercent: 20,
        expiryDate: DateTime.now().add(const Duration(days: 60)),
      ),
    ];
  }
}
