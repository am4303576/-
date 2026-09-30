class CouponModel {
  final String id;
  final String code;
  final String? restaurantId; // null = عام لجميع المطاعم
  final String discountType; // 'percentage', 'fixed'
  final double value;
  final DateTime validUntil;
  final bool isActive;

  CouponModel({
    required this.id,
    required this.code,
    this.restaurantId,
    required this.discountType,
    required this.value,
    required this.validUntil,
    this.isActive = true,
  });

  bool get isExpired => DateTime.now().isAfter(validUntil);

  double calculateDiscount(double subtotal) {
    if (!isActive || isExpired) return 0.0;
    if (discountType == 'percentage') {
      return (subtotal * value) / 100.0;
    } else {
      return value > subtotal ? subtotal : value;
    }
  }

  factory CouponModel.fromMap(Map<String, dynamic> map, String id) {
    return CouponModel(
      id: id,
      code: map['code'] ?? '',
      restaurantId: map['restaurantId'],
      discountType: map['discountType'] ?? 'percentage',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      validUntil: map['validUntil'] != null
          ? (map['validUntil'] as dynamic).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'restaurantId': restaurantId,
      'discountType': discountType,
      'value': value,
      'validUntil': validUntil,
      'isActive': isActive,
    };
  }
}
