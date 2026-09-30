import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/restaurant_model.dart';
import '../../models/order_model.dart';
import '../../models/coupon_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class CartScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  final List<OrderItem> items;
  final VoidCallback onOrderPlaced;

  const CartScreen({
    super.key,
    required this.restaurant,
    required this.items,
    required this.onOrderPlaced,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final DatabaseService _db = DatabaseService();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _couponCtrl = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isLocating = false;
  bool _isPlacingOrder = false;

  CouponModel? _appliedCoupon;
  double _discount = 0.0;
  DateTime? _scheduledTime;
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone;
    }
  }

  Future<void> _determinePosition() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _addressCtrl.text = "موقعي الحالي المحدد عبر الـ GPS (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحديد موقعك بدقة بنجاح")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تعذر تحديد الموقع تلقائياً: $e")),
      );
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;

    final coupon = await _db.getCouponByCode(code, restaurantId: widget.restaurant.id);
    if (coupon != null) {
      final subtotal = widget.items.fold<double>(0.0, (sum, i) => sum + i.total);
      setState(() {
        _appliedCoupon = coupon;
        _discount = coupon.calculateDiscount(subtotal);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم تطبيق الكوبون! تم خصم ${_discount.toStringAsFixed(2)} د.ع")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("كود الكوبون غير صحيح أو منتهي الصلاحية"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _scheduleOrderPicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _scheduledTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _placeOrder() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _addressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إكمال جميع حقول التوصيل والموقع"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final subtotal = widget.items.fold<double>(0.0, (sum, i) => sum + i.total);
      const deliveryFee = 3.0; // Fixed delivery fee
      final total = (subtotal + deliveryFee) - _discount;

      final orderNumber = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();

      final order = OrderModel(
        id: '',
        orderNumber: orderNumber,
        customerId: user?.uid ?? 'guest',
        customerName: _nameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        deliveryAddress: _addressCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        items: widget.items,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        discount: _discount,
        total: total > 0 ? total : 0,
        paymentMethod: _paymentMethod,
        status: 'sent',
        createdAt: DateTime.now(),
        scheduledFor: _scheduledTime,
      );

      await _db.createOrder(order);
      widget.onOrderPlaced();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إرسال طلبك بنجاح للمطعم!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ أثناء إرسال الطلب: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.items.fold<double>(0.0, (sum, i) => sum + i.total);
    const deliveryFee = 3.0;
    final total = (subtotal + deliveryFee) - _discount;

    return Scaffold(
      appBar: AppBar(title: const Text("سلة الطلب وإتمام الدفع")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Items summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("المطعم: ${widget.restaurant.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(),
                    ...widget.items.map((i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${i.quantity}x ${i.name}"),
                              Text("${i.total.toStringAsFixed(2)} د.ع"),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Delivery Details
            const Text("بيانات التوصيل والموقع:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "اسم المستلم")),
            const SizedBox(height: 10),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "رقم الهاتف للتواصل")),
            const SizedBox(height: 10),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: "العنوان بالتفصيل",
                suffixIcon: IconButton(
                  icon: _isLocating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location, color: Colors.deepOrange),
                  tooltip: "تحديد موقعي عبر GPS",
                  onPressed: _determinePosition,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scheduled Order
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("جدولة الطلب لوقت لاحق:", style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(_scheduledTime == null ? "الطلب الآن (فوري)" : DateFormat('hh:mm a - yyyy/MM/dd').format(_scheduledTime!)),
                  onPressed: _scheduleOrderPicker,
                ),
              ],
            ),
            const Divider(height: 24),

            // Coupon Field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponCtrl,
                    decoration: const InputDecoration(labelText: "كود الخصم (الكوبون)"),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _applyCoupon, child: const Text("تطبيق")),
              ],
            ),
            const SizedBox(height: 16),

            // Payment summary
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("المجموع الفرعي:"), Text("${subtotal.toStringAsFixed(2)} د.ع")]),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("رسوم التوصيل:"), Text("${deliveryFee.toStringAsFixed(2)} د.ع")]),
                    if (_discount > 0) ...[
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("الخصم:", style: TextStyle(color: Colors.green)), Text("-${_discount.toStringAsFixed(2)} د.ع", style: const TextStyle(color: Colors.green))]),
                    ],
                    const Divider(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text("الإجمالي المطلوب:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("${total.toStringAsFixed(2)} د.ع", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isPlacingOrder ? null : _placeOrder,
                child: _isPlacingOrder ? const CircularProgressIndicator(color: Colors.white) : const Text("تأكيد وإرسال الطلب الآن", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
