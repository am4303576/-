import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../manager/manager_dashboard_screen.dart';
import '../auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DatabaseService _db = DatabaseService();

  void _showAddRestaurantDialog() {
    final nameCtrl = TextEditingController();
    final logoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final commissionCtrl = TextEditingController(text: "10.0");
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة مطعم جديد", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "اسم المطعم")),
              const SizedBox(height: 10),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "إيميل مدير المطعم")),
              const SizedBox(height: 10),
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "رمز الدعوة الخاص بالمدير")),
              const SizedBox(height: 10),
              TextField(controller: commissionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "نسبة العمولة %")),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "رقم هاتف المطعم")),
              const SizedBox(height: 10),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: "العنوان")),
              const SizedBox(height: 10),
              TextField(controller: logoCtrl, decoration: const InputDecoration(labelText: "رابط الشعار (اختياري)")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || codeCtrl.text.isEmpty) {
                return;
              }
              final newId = DateTime.now().millisecondsSinceEpoch.toString();
              final restaurant = RestaurantModel(
                id: newId,
                name: nameCtrl.text.trim(),
                logoUrl: logoCtrl.text.trim().isNotEmpty
                    ? logoCtrl.text.trim()
                    : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500',
                managerEmail: emailCtrl.text.trim().toLowerCase(),
                commissionRate: double.tryParse(commissionCtrl.text) ?? 10.0,
                phone: phoneCtrl.text.trim(),
                address: addressCtrl.text.trim(),
              );

              await _db.addRestaurant(restaurant);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("إضافة وحفظ"),
          ),
        ],
      ),
    );
  }

  void _showEditCommissionDialog(RestaurantModel restaurant) {
    final commCtrl = TextEditingController(text: restaurant.commissionRate.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("تعديل عمولة ${restaurant.name}"),
        content: TextField(
          controller: commCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "نسبة العمولة الجديدة %"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              final newRate = double.tryParse(commCtrl.text);
              if (newRate != null) {
                await _db.updateRestaurant(restaurant.id, {'commissionRate': newRate});
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("تحديث"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة تحكم الأدمن (المالك)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "تسجيل الخروج",
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRestaurantDialog,
        icon: const Icon(Icons.add_business),
        label: const Text("إضافة مطعم جديد", style: TextStyle(fontFamily: 'Cairo')),
      ),
      body: StreamBuilder<List<RestaurantModel>>(
        stream: _db.getAllRestaurants(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final restaurants = snapshot.data ?? [];

          if (restaurants.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_mall_directory_outlined, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("التطبيق يبدأ فارغاً، لا يوجد مطاعم مضافة بعد."),
                  const SizedBox(height: 8),
                  const Text("اضغط على زر 'إضافة مطعم جديد' بالأسفل لبدء التأسيس", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final rest = restaurants[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: NetworkImage(rest.logoUrl),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rest.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text("إيميل المدير: ${rest.managerEmail}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                Text("العمولة: ${rest.commissionRate}%", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Switch(
                            value: rest.isOpen,
                            activeColor: Colors.green,
                            onChanged: (val) async {
                              await _db.updateRestaurant(rest.id, {'isOpen': val});
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.percent, size: 18),
                            label: const Text("تعديل العمولة"),
                            onPressed: () => _showEditCommissionDialog(rest),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.restaurant_menu, size: 18),
                            label: const Text("إدارة المنيو والأصناف"),
                            onPressed: () {
                              // Admin has full manager access to any restaurant
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManagerDashboardScreen(restaurantId: rest.id, asAdmin: true),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
