import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String customerId;
  const OrderTrackingScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return StreamBuilder<List<OrderModel>>(
      stream: db.getCustomerOrders(customerId),
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
                Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text("ليس لديك طلبات سابقة حتى الآن"),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(context, order, db);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order, DatabaseService db) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("طلب #${order.orderNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(DateFormat('hh:mm a').format(order.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(order.restaurantName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            const SizedBox(height: 12),

            // Order Status Steps Tracker
            _buildTimelineTracker(order.status),
            const SizedBox(height: 14),

            // Items preview
            ...order.items.map((i) => Text("• ${i.quantity}x ${i.name}", style: const TextStyle(fontSize: 13))),
            const Divider(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("الإجمالي: ${order.total.toStringAsFixed(2)} د.ع", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                // Cancel Order Button (Only allowed if status == 'sent')
                if (order.canBeCancelled)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    onPressed: () async {
                      try {
                        await db.cancelOrder(order.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("تم إلغاء الطلب بنجاح")),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text("إلغاء الطلب"),
                  )
                else if (order.status == 'delivered')
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.star_rate, size: 16, color: Colors.amber),
                        label: const Text("تقييم"),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("شكراً لتقييمك للمطعم والكابتن!")),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text("إعادة الطلب"),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("تمت إضافة الأصناف للسلة مجدداً")),
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineTracker(String currentStatus) {
    final stages = [
      {'status': 'sent', 'label': 'تم الإرسال'},
      {'status': 'received', 'label': 'تم الاستلام'},
      {'status': 'preparing', 'label': 'جاري التجهيز'},
      {'status': 'picked_up', 'label': 'مع الكابتن'},
      {'status': 'delivered', 'label': 'تم التسليم'},
    ];

    if (currentStatus == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Center(
          child: Text("تم إلغاء هذا الطلب", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      );
    }

    final currentIndex = stages.indexWhere((s) => s['status'] == currentStatus);

    return Row(
      children: List.generate(stages.length, (index) {
        final isPassed = index <= (currentIndex == -1 ? 0 : currentIndex);
        final isCurrent = index == currentIndex;

        return Expanded(
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isPassed ? Colors.deepOrange : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isPassed
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text("${index + 1}", style: const TextStyle(fontSize: 10, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stages[index]['label']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isPassed ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
