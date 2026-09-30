import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../models/order_model.dart';

class SunmiPrinterService {
  static final SunmiPrinterService _instance = SunmiPrinterService._internal();
  factory SunmiPrinterService() => _instance;
  SunmiPrinterService._internal();

  bool _isPrinterBound = false;

  Future<void> initPrinter() async {
    try {
      _isPrinterBound = await SunmiPrinter.bindingPrinter() ?? false;
      if (_isPrinterBound) {
        await SunmiPrinter.initPrinter();
      }
    } catch (e) {
      debugPrint("Sunmi printer binding failed (may be on non-Sunmi device): $e");
      _isPrinterBound = false;
    }
  }

  /// Print Customer Receipt (58mm)
  Future<void> printOrderAutomatic(OrderModel order) async {
    await printCustomerReceipt(order);
  }


  /// 2. Customer Receipt (نسخة الزبون) - 58mm
  Future<void> printCustomerReceipt(OrderModel order) async {
    try {
      await SunmiPrinter.startTransactionPrint(true);
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);

      // Restaurant & Order Info
      await SunmiPrinter.printText(
        order.restaurantName,
        style: SunmiTextStyle(bold: true, fontSize: 30),
      );
      await SunmiPrinter.printText(
        'فاتورة توصيل - وصلني',
        style: SunmiTextStyle(fontSize: 20),
      );
      await SunmiPrinter.printText(
        'طلب #${order.orderNumber}',
        style: SunmiTextStyle(bold: true, fontSize: 26),
      );
      await SunmiPrinter.printText(
        DateFormat('yyyy/MM/dd hh:mm a').format(order.createdAt),
        style: SunmiTextStyle(fontSize: 18),
      );
      await SunmiPrinter.printText('--------------------------------');

      // Customer info
      await SunmiPrinter.setAlignment(SunmiPrintAlign.RIGHT);
      await SunmiPrinter.printText('العميل: ${order.customerName}');
      await SunmiPrinter.printText('الهاتف: ${order.customerPhone}');
      await SunmiPrinter.printText('العنوان: ${order.deliveryAddress}');
      await SunmiPrinter.printText('--------------------------------');

      // Items table
      for (var item in order.items) {
        await SunmiPrinter.printText(
          '${item.quantity}x ${item.name}    ${item.total.toStringAsFixed(2)} د.ع',
          style: SunmiTextStyle(fontSize: 20),
        );
      }
      await SunmiPrinter.printText('--------------------------------');

      // Totals
      await SunmiPrinter.setAlignment(SunmiPrintAlign.RIGHT);
      await SunmiPrinter.printText('المجموع الفرعي: ${order.subtotal.toStringAsFixed(2)} د.ع');
      await SunmiPrinter.printText('رسوم التوصيل: ${order.deliveryFee.toStringAsFixed(2)} د.ع');
      if (order.discount > 0) {
        await SunmiPrinter.printText('الخصم: -${order.discount.toStringAsFixed(2)} د.ع');
      }
      await SunmiPrinter.printText(
        'الإجمالي الكلي: ${order.total.toStringAsFixed(2)} د.ع',
        style: SunmiTextStyle(bold: true, fontSize: 24),
      );
      await SunmiPrinter.printText('طريقة الدفع: ${order.paymentMethod == 'cash' ? 'الدفع نقداً' : 'إلكتروني'}');

      // QR Code for live order tracking
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printQRCode('https://wasalny.app/track/${order.id}');
      await SunmiPrinter.printText(
        'امسح الرمز لتتبع طلبك لحظياً',
        style: SunmiTextStyle(fontSize: 18),
      );

      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.submitTransactionPrint();
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      debugPrint("Sunmi printCustomerReceipt error: $e");
    }
  }

  /// 3. Daily Summary Report (تقرير نهاية اليوم والجرد) - 58mm
  Future<void> printDailyReport({
    required String restaurantName,
    required DateTime date,
    required int totalOrders,
    required double totalSales,
    required double totalDiscounts,
    required double netSales,
  }) async {
    try {
      await SunmiPrinter.startTransactionPrint(true);
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);

      await SunmiPrinter.printText('تقرير الجرد اليومي', style: SunmiTextStyle(bold: true, fontSize: 28));
      await SunmiPrinter.printText(restaurantName, style: SunmiTextStyle(fontSize: 22));
      await SunmiPrinter.printText(
        'التاريخ: ${DateFormat('yyyy/MM/dd').format(date)}',
        style: SunmiTextStyle(fontSize: 18),
      );
      await SunmiPrinter.printText('--------------------------------');

      await SunmiPrinter.setAlignment(SunmiPrintAlign.RIGHT);
      await SunmiPrinter.printText('عدد الطلبات المكتملة: $totalOrders');
      await SunmiPrinter.printText('إجمالي المبيعات: ${totalSales.toStringAsFixed(2)} د.ع');
      await SunmiPrinter.printText('إجمالي الخصومات: ${totalDiscounts.toStringAsFixed(2)} د.ع');
      await SunmiPrinter.printText(
        'صافي الإيرادات: ${netSales.toStringAsFixed(2)} د.ع',
        style: SunmiTextStyle(bold: true, fontSize: 24),
      );

      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.submitTransactionPrint();
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      debugPrint("Sunmi printDailyReport error: $e");
    }
  }
}
