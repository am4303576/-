class CategoryModel {
  final String id;
  final String restaurantId;
  final String name;
  final int orderIndex;

  CategoryModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.orderIndex = 0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      restaurantId: map['restaurantId'] ?? '',
      name: map['name'] ?? '',
      orderIndex: (map['orderIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'name': name,
      'orderIndex': orderIndex,
    };
  }
}

class ProductAddon {
  final String name;
  final double price;

  ProductAddon({required this.name, required this.price});

  factory ProductAddon.fromMap(Map<String, dynamic> map) {
    return ProductAddon(
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'price': price};
}

class ProductModel {
  final String id;
  final String restaurantId;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final List<ProductAddon> addons;

  ProductModel({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.isAvailable = true,
    this.addons = const [],
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      restaurantId: map['restaurantId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      addons: (map['addons'] as List<dynamic>?)
              ?.map((x) => ProductAddon.fromMap(x as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'addons': addons.map((x) => x.toMap()).toList(),
    };
  }
}
