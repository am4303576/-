import 'package:flutter/material.dart';
import '../../models/restaurant_model.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';
import 'cart_screen.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  const RestaurantMenuScreen({super.key, required this.restaurant});

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final DatabaseService _db = DatabaseService();
  final List<OrderItem> _cart = [];

  void _addToCart(ProductModel product) {
    int quantity = 1;
    final List<String> selectedAddons = [];
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(product.description, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Text("${product.price.toStringAsFixed(2)} د.ع", style: const TextStyle(fontSize: 18, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              if (product.addons.isNotEmpty) ...[
                const Text("الإضافات:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...product.addons.map((addon) => CheckboxListTile(
                      title: Text("${addon.name} (+${addon.price} د.ع)"),
                      value: selectedAddons.contains(addon.name),
                      onChanged: (val) {
                        setSheetState(() {
                          if (val == true) {
                            selectedAddons.add(addon.name);
                          } else {
                            selectedAddons.remove(addon.name);
                          }
                        });
                      },
                    )),
              ],
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: "ملاحظات إضافية (اختياري)"),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: quantity > 1 ? () => setSheetState(() => quantity--) : null,
                      ),
                      Text("$quantity", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setSheetState(() => quantity++),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _cart.add(OrderItem(
                          productId: product.id,
                          name: product.name,
                          price: product.price,
                          quantity: quantity,
                          selectedAddons: selectedAddons,
                          note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                        ));
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text("إضافة للسلة (${(product.price * quantity).toStringAsFixed(2)} د.ع)"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartTotal = _cart.fold<double>(0.0, (sum, i) => sum + i.total);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurant.name),
      ),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartScreen(
                      restaurant: widget.restaurant,
                      items: _cart,
                      onOrderPlaced: () {
                        setState(() => _cart.clear());
                      },
                    ),
                  ),
                );
              },
              backgroundColor: Theme.of(context).primaryColor,
              icon: const Icon(Icons.shopping_bag),
              label: Text("عرض السلة (${_cart.length}) • ${cartTotal.toStringAsFixed(2)} د.ع"),
            )
          : null,
      body: StreamBuilder<List<ProductModel>>(
        stream: _db.getProducts(widget.restaurant.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return const Center(child: Text("قائمة الطعام قيد التجهيز قريباً"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      product.imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40),
                    ),
                  ),
                  title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text("${product.price.toStringAsFixed(2)} د.ع", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: product.isAvailable
                      ? IconButton.filled(
                          icon: const Icon(Icons.add),
                          onPressed: () => _addToCart(product),
                        )
                      : const Text("غير متوفر", style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
