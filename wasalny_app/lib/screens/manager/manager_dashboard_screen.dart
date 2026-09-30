import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/restaurant_model.dart';
import '../../services/database_service.dart';
import '../../services/order_alert_service.dart';
import '../../services/sunmi_printer_service.dart';
import '../../services/report_service.dart';
import 'menu_management_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final String restaurantId;
  final bool asAdmin;

  const ManagerDashboardScreen({
    super.key,
    required this.restaurantId,
    this.asAdmin = false,
  });

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _db = DatabaseService();
  final OrderAlertService _alertService = OrderAlertService();
  final SunmiPrinterService _printerService = SunmiPrinterService();

  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initServices();
  }

  Future<void> _initServices() async {
    await _alertService.init();
    await _alertService.enableKeepScreenOn();
    await _printerService.initPrinter();
  }

  @override
  void dispose() {
    _alertService.disableKeepScreenOn();
    _alertService.stopAlarm();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.asAdmin ? "إدارة المطعم (بصلاحية الأدمن)" : "لوحة تحكم مدير المطعم"),
        actions: [
          // Toggle Busy State
          Row(
            children: [
              Text(
                _isBusy ? "مشغول" : "متاح",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _isBusy ? Colors.red : Colors.green,
                ),
              ),
              Switch(
                value: !_isBusy,
                activeColor: Colors.green,
                inactiveThumbColor: Colors.red,
                onChanged: (val) async {
                  setState(() => _isBusy = !val);
                  await _db.updateRestaurant(widget.restaurantId, {'isBusy': !val});
                },
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: "الطلبات الحية"),
            Tab(icon: Icon(Icons.restaurant_menu), text: "المنيو والأصناف"),
            Tab(icon: Icon(Icons.analytics_outlined), text: "التقارير والجرد"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveOrdersTab(),
          MenuManagementScreen(restaurantId: widget.restaurantId),
          _buildReportsTab(),
        ],
      ),
    );
  }

  // --- 1. Live Orders View with Sound & Sunmi Print ---
  Widget _buildLiveOrdersTab() {
    return StreamBuilder<List<OrderModel>>(
      stream: _db.getRestaurantLiveOrders(widget.restaurantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];

        // Check if there is any new order in 'sent' state to trigger alarm
        final hasNewPendingOrder = orders.any((o) => o.status == 'sent');
        if (hasNewPendingOrder) {
          final pendingOrder = orders.firstWhere((o) => o.status == 'sent');
          _alertService.startAlarm(pendingOrder.id);
        } else {
          _alertService.stopAlarm();
        }

        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text("لا توجد طلبات واردة حالياً"),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final isNew = order.status == 'sent';

            return Card(
              color: isNew ? Colors.orange.shade50 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isNew ? BorderSide(color: Colors.orange.shade400, width: 2) : BorderSide.none,
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: isNew,
                onExpansionChanged: (expanded) {
                  // Stop alarm when manager opens/acknowledges the order
                  if (expanded && isNew) {
                    _alertService.stopAlarm();
                  }
                },
                leading: CircleAvatar(
                  backgroundColor: isNew ? Colors.orange : Colors.grey.shade200,
                  foregroundColor: isNew ? Colors.white : Colors.black87,
                  child: Text("#${order.orderNumber}"),
                ),
                title: Text(
                  "${order.customerName} - ${order.total.toStringAsFixed(2)} د.ع",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "الحالة: ${order.statusArabic} • ${DateFormat('hh:mm a').format(order.createdAt)}",
                  style: TextStyle(
                    color: isNew ? Colors.deepOrange : Colors.grey.shade700,
                    fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text("الهاتف: ${order.customerPhone}"),
                        Text("العنوان: ${order.deliveryAddress}"),
                        const SizedBox(height: 8),
                        const Text("الأصناف المطلوبة:", style: TextStyle(fontWeight: FontWeight.bold)),
                        ...order.items.map((i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text("• ${i.quantity}x ${i.name} (${i.total.toStringAsFixed(2)} د.ع)"),
                            )),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Sunmi Thermal Print Button
                            OutlinedButton.icon(
                              icon: const Icon(Icons.print, size: 18),
                              label: const Text("طباعة 58mm"),
                              onPressed: () async {
                                await _printerService.printOrderAutomatic(order);
                                await _db.markOrderAsPrinted(order.id);
                              },
                            ),
                            // Order State Progression
                            if (order.status == 'sent')
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                onPressed: () async {
                                  await _alertService.stopAlarm();
                                  await _db.updateOrderStatus(orderId: order.id, newStatus: 'received');
                                  await _printerService.printOrderAutomatic(order);
                                },
                                child: const Text("استلام الطلب"),
                              )
                            else if (order.status == 'received')
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                                onPressed: () async {
                                  await _db.updateOrderStatus(orderId: order.id, newStatus: 'preparing');
                                },
                                child: const Text("بدء التجهيز بالمطبخ"),
                              )
                            else if (order.status == 'preparing')
                              const Chip(
                                label: Text("بانتظار استلام الكابتن", style: TextStyle(color: Colors.purple)),
                                backgroundColor: Color(0xFFF3E5F5),
                              )
                            else
                              Chip(
                                label: Text(order.statusArabic),
                                backgroundColor: Colors.green.shade50,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- 3. Daily Audit & Reports Tab ---
  Widget _buildReportsTab() {
    return StreamBuilder<List<OrderModel>>(
      stream: _db.getRestaurantLiveOrders(widget.restaurantId),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        final completedOrders = orders.where((o) => o.status == 'delivered').toList();
        final totalSales = completedOrders.fold<double>(0.0, (sum, o) => sum + o.total);
        final totalDiscounts = completedOrders.fold<double>(0.0, (sum, o) => sum + o.discount);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text("ملخص مبيعات اليوم", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard("إجمالي الطلبات", "${completedOrders.length}", Colors.blue),
                          _buildStatCard("المبيعات", "${totalSales.toStringAsFixed(2)} د.ع", Colors.green),
                          _buildStatCard("الخصومات", "${totalDiscounts.toStringAsFixed(2)} د.ع", Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text("طباعة تقرير الجرد اليومي (Sunmi 58mm)"),
                onPressed: () async {
                  await _printerService.printDailyReport(
                    restaurantName: "مطعم وصلني",
                    date: DateTime.now(),
                    totalOrders: completedOrders.length,
                    totalSales: totalSales,
                    totalDiscounts: totalDiscounts,
                    netSales: totalSales - totalDiscounts,
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                label: const Text("تصدير تقرير PDF"),
                onPressed: () async {
                  await ReportService.printPdfReport(
                    restaurantName: "مطعم وصلني",
                    orders: completedOrders,
                    totalSales: totalSales,
                    totalDiscounts: totalDiscounts,
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.table_view, color: Colors.green),
                label: const Text("تصدير إلى ملف Excel (.xlsx)"),
                onPressed: () async {
                  final path = await ReportService.exportOrdersToExcel(
                    restaurantName: "مطعم وصلني",
                    orders: completedOrders,
                  );
                  if (path != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("تم حفظ التقرير في: $path")),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
