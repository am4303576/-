import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../services/database_service.dart';

class MenuManagementScreen extends StatefulWidget {
  final String restaurantId;
  const MenuManagementScreen({super.key, required this.restaurantId});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final DatabaseService _db = DatabaseService();
  String? _selectedCategoryId;

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة قسم جديد"),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "اسم القسم (مثل: وجبات رئيسية، مقبلات، مشروبات)")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await _db.addCategory(CategoryModel(
                  id: '',
                  restaurantId: widget.restaurantId,
                  name: nameCtrl.text.trim(),
                ));
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("إضافة"),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final imgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة صنف جديد للمنيو"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "اسم الوجبة/الصنف")),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "الوصف والمكونات")),
              const SizedBox(height: 10),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "السعر (د.ع)")),
              const SizedBox(height: 10),
              TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: "رابط الصورة")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
              final product = ProductModel(
                id: '',
                restaurantId: widget.restaurantId,
                categoryId: _selectedCategoryId ?? 'default',
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text) ?? 0.0,
                imageUrl: imgCtrl.text.trim().isNotEmpty
                    ? imgCtrl.text.trim()
                    : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
              );
              await _db.addProduct(product);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("حفظ الصنف"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Categories list
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: StreamBuilder<List<CategoryModel>>(
            stream: _db.getCategories(widget.restaurantId),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text("إضافة قسم"),
                    onPressed: _showAddCategoryDialog,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("الكل"),
                    selected: _selectedCategoryId == null,
                    onSelected: (val) => setState(() => _selectedCategoryId = null),
                  ),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: _selectedCategoryId == cat.id,
                          onSelected: (val) => setState(() => _selectedCategoryId = val ? cat.id : null),
                        ),
                      )),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),

        // Products list with instant availability toggle
        Expanded(
          child: StreamBuilder<List<ProductModel>>(
            stream: _db.getProducts(widget.restaurantId, categoryId: _selectedCategoryId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data ?? [];

              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fastfood_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text("لا توجد أصناف في هذا القسم حالياً"),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("إضافة أول صنف"),
                        onPressed: _showAddProductDialog,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.imageUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                        ),
                      ),
                      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        "${product.price.toStringAsFixed(2)} د.ع\n${product.description}",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            product.isAvailable ? "متوفر" : "غير متوفر",
                            style: TextStyle(
                              fontSize: 11,
                              color: product.isAvailable ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: product.isAvailable,
                            activeColor: Colors.green,
                            onChanged: (val) async {
                              await _db.toggleProductAvailability(product.id, val);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
