class UserModel {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String role; // 'admin', 'manager', 'kitchen', 'captain', 'customer'
  final String? restaurantId;
  final int loyaltyPoints;
  final DateTime createdAt;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    this.restaurantId,
    this.loyaltyPoints = 0,
    required this.createdAt,
    this.fcmToken,
  });

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isKitchen => role == 'kitchen';
  bool get isCaptain => role == 'captain';
  bool get isCustomer => role == 'customer';

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'customer',
      restaurantId: map['restaurantId'],
      loyaltyPoints: map['loyaltyPoints'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'restaurantId': restaurantId,
      'loyaltyPoints': loyaltyPoints,
      'createdAt': createdAt,
      'fcmToken': fcmToken,
    };
  }
}
