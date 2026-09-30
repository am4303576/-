import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class CaptainDashboardScreen extends StatefulWidget {
  const CaptainDashboardScreen({super.key});

  @override
  State<CaptainDashboardScreen> createState() => _CaptainDashboardScreenState();
}

class _CaptainDashboardScreenState extends State<CaptainDashboardScreen> {
  final DatabaseService _db = DatabaseService();

  Future<void> _openMap(double? lat, double? lng, String address) async {
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse("geo:$lat,$lng?q=$lat,$lng($address)");
    } else {
      uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback web url
      final webUrl = Uri.parse("https://maps.google.com/?q=${lat ?? 0},${lng ?? 0}");
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showCollectMoneyDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد التسليم واستلام المبلغ", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("العميل: ${order.customerName}"),
            Text("المبلغ المطلوب استلامه: ${order.total.toStringAsFixed(2)} د.ع", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
            Text("طريقة الدفع: ${order.paymentMethod == 'cash' ? 'نقداً عند الاستلام' : 'مدفوع إلكترونياً'}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              await _db.updateOrderStatus(orderId: order.id, newStatus: 'delivered');
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("تم تسليم الطلب والمبلغ"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة الكابتن (التوصيل)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _db.getCaptainAvailableOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.two_wheeler_outlined, size: 70, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("لا توجد طلبات جاهزة للتوصيل حالياً"),
                  SizedBox(height: 6),
                  Text("ستظهر الطلبات هنا فور انتهاء المطبخ من تجهيزها", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final isAssignedToMe = order.captainId == user?.uid;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("طلب #${order.orderNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Chip(
                            label: Text(order.statusArabic),
                            backgroundColor: Colors.amber.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("المطعم: ${order.restaurantName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("العميل: ${order.customerName}"),
                      Text("العنوان: ${order.deliveryAddress}"),
                      const SizedBox(height: 6),
                      Text("المبلغ الكلي: ${order.total.toStringAsFixed(2)} د.ع", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      const Divider(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          // Open Map Button (Google Maps / Waze)
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.navigation_outlined, size: 18),
                              label: const Text("فتح الخريطة"),
                              onPressed: () => _openMap(order.latitude, order.longitude, order.deliveryAddress),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Direct Call Button
                          IconButton.filledTonal(
                            icon: const Icon(Icons.phone),
                            onPressed: () => _callCustomer(order.customerPhone),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // State transitions restricted exclusively to Captain
                      if (order.status == 'preparing')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.takeout_dining),
                            label: const Text("استلمت الطلب من المطعم"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            onPressed: () async {
                              await _db.updateOrderStatus(
                                orderId: order.id,
                                newStatus: 'picked_up',
                                captainId: user?.uid,
                                captainName: user?.name,
                                captainPhone: user?.phone,
                              );
                            },
                          ),
                        )
                      else if (order.status == 'picked_up')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text("تسليم الطلب للعميل"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _showCollectMoneyDialog(order),
                          ),
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
