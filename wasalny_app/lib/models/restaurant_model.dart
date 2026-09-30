class RestaurantModel {
  final String id;
  final String name;
  final String logoUrl;
  final String managerEmail;
  final double commissionRate;
  final bool isOpen;
  final bool isBusy;
  final String phone;
  final String address;
  final double rating;
  final int totalOrders;
  final String? qrCodeUrl;
  final Map<String, dynamic>? workingHours;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.managerEmail,
    this.commissionRate = 10.0,
    this.isOpen = true,
    this.isBusy = false,
    required this.phone,
    required this.address,
    this.rating = 5.0,
    this.totalOrders = 0,
    this.qrCodeUrl,
    this.workingHours,
  });

  factory RestaurantModel.fromMap(Map<String, dynamic> map, String id) {
    return RestaurantModel(
      id: id,
      name: map['name'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      managerEmail: map['managerEmail'] ?? '',
      commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 10.0,
      isOpen: map['isOpen'] ?? true,
      isBusy: map['isBusy'] ?? false,
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
      qrCodeUrl: map['qrCodeUrl'],
      workingHours: map['workingHours'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'managerEmail': managerEmail,
      'commissionRate': commissionRate,
      'isOpen': isOpen,
      'isBusy': isBusy,
      'phone': phone,
      'address': address,
      'rating': rating,
      'totalOrders': totalOrders,
      'qrCodeUrl': qrCodeUrl,
      'workingHours': workingHours,
    };
  }
}
