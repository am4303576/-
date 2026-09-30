import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/coupon_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Restaurants ---
  Stream<List<RestaurantModel>> getActiveRestaurants() {
    return _firestore
        .collection('restaurants')
        .where('isOpen', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RestaurantModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<RestaurantModel>> getAllRestaurants() {
    return _firestore
        .collection('restaurants')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RestaurantModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addRestaurant(RestaurantModel restaurant) async {
    await _firestore.collection('restaurants').doc(restaurant.id).set(restaurant.toMap());
  }

  Future<void> updateRestaurant(String id, Map<String, dynamic> data) async {
    await _firestore.collection('restaurants').doc(id).update(data);
  }

  // --- Categories ---
  Stream<List<CategoryModel>> getCategories(String restaurantId) {
    return _firestore
        .collection('categories')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addCategory(CategoryModel category) async {
    await _firestore.collection('categories').add(category.toMap());
  }

  // --- Products ---
  Stream<List<ProductModel>> getProducts(String restaurantId, {String? categoryId}) {
    Query query = _firestore
        .collection('products')
        .where('restaurantId', isEqualTo: restaurantId);

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<void> addProduct(ProductModel product) async {
    await _firestore.collection('products').add(product.toMap());
  }

  Future<void> toggleProductAvailability(String productId, bool isAvailable) async {
    await _firestore.collection('products').doc(productId).update({
      'isAvailable': isAvailable,
    });
  }

  // --- Orders ---
  Future<String> createOrder(OrderModel order) async {
    final docRef = await _firestore.collection('orders').add(order.toMap());
    return docRef.id;
  }

  Stream<List<OrderModel>> getCustomerOrders(String customerId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<OrderModel>> getRestaurantLiveOrders(String restaurantId) {
    return _firestore
        .collection('orders')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<OrderModel>> getCaptainAvailableOrders() {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'preparing')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? captainId,
    String? captainName,
    String? captainPhone,
  }) async {
    final Map<String, dynamic> updateData = {'status': newStatus};
    if (captainId != null) updateData['captainId'] = captainId;
    if (captainName != null) updateData['captainName'] = captainName;
    if (captainPhone != null) updateData['captainPhone'] = captainPhone;

    await _firestore.collection('orders').doc(orderId).update(updateData);
  }

  Future<void> markOrderAsPrinted(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({'isPrinted': true});
  }

  Future<void> cancelOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (doc.exists && doc.data()?['status'] == 'sent') {
      await _firestore.collection('orders').doc(orderId).update({'status': 'cancelled'});
    } else {
      throw Exception("لا يمكن إلغاء الطلب بعد أن بدأ المطعم في معالجته!");
    }
  }

  // --- Coupons ---
  Future<CouponModel?> getCouponByCode(String code, {String? restaurantId}) async {
    final snapshot = await _firestore
        .collection('coupons')
        .where('code', isEqualTo: code.trim().toUpperCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final coupon = CouponModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);

    if (coupon.isExpired) return null;
    if (coupon.restaurantId != null && coupon.restaurantId != restaurantId) return null;

    return coupon;
  }
}
