class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final List<String> selectedAddons;
  final String? note;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.selectedAddons = const [],
    this.note,
  });

  double get total => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      selectedAddons: List<String>.from(map['selectedAddons'] ?? []),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'selectedAddons': selectedAddons,
      'note': note,
    };
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double? latitude;
  final double? longitude;
  final String restaurantId;
  final String restaurantName;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final String paymentMethod; // 'cash', 'online'
  final String status; // 'sent', 'received', 'preparing', 'picked_up', 'delivered', 'cancelled'
  final String? captainId;
  final String? captainName;
  final String? captainPhone;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final bool isPrinted;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.latitude,
    this.longitude,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    this.discount = 0.0,
    required this.total,
    this.paymentMethod = 'cash',
    this.status = 'sent',
    this.captainId,
    this.captainName,
    this.captainPhone,
    required this.createdAt,
    this.scheduledFor,
    this.isPrinted = false,
  });

  String get statusArabic {
    switch (status) {
      case 'sent':
        return 'تم الإرسال';
      case 'received':
        return 'تم الاستلام';
      case 'preparing':
        return 'جاري التجهيز';
      case 'picked_up':
        return 'استلمه الكابتن';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  bool get canBeCancelled => status == 'sent';

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      orderNumber: map['orderNumber'] ?? id.substring(0, 6).toUpperCase(),
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      restaurantId: map['restaurantId'] ?? '',
      restaurantName: map['restaurantName'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((x) => OrderItem.fromMap(x as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? 'cash',
      status: map['status'] ?? 'sent',
      captainId: map['captainId'],
      captainName: map['captainName'],
      captainPhone: map['captainPhone'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      scheduledFor: map['scheduledFor'] != null
          ? (map['scheduledFor'] as dynamic).toDate()
          : null,
      isPrinted: map['isPrinted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'latitude': latitude,
      'longitude': longitude,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'discount': discount,
      'total': total,
      'paymentMethod': paymentMethod,
      'status': status,
      'captainId': captainId,
      'captainName': captainName,
      'captainPhone': captainPhone,
      'createdAt': createdAt,
      'scheduledFor': scheduledFor,
      'isPrinted': isPrinted,
    };
  }
}
