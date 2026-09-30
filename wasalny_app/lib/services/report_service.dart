import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/order_model.dart';

class ReportService {
  /// Export Orders to an Excel (.xlsx) file
  static Future<String?> exportOrdersToExcel({
    required String restaurantName,
    required List<OrderModel> orders,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheetName = 'تقرير الطلبات';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Header row
      sheet.appendRow([
        TextCellValue('رقم الطلب'),
        TextCellValue('التاريخ والوقت'),
        TextCellValue('اسم العميل'),
        TextCellValue('الهاتف'),
        TextCellValue('العنوان'),
        TextCellValue('المبلغ الكلي'),
        TextCellValue('الخصم'),
        TextCellValue('طريقة الدفع'),
        TextCellValue('الحالة'),
      ]);

      // Fill data rows
      for (var order in orders) {
        sheet.appendRow([
          TextCellValue('#${order.orderNumber}'),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt)),
          TextCellValue(order.customerName),
          TextCellValue(order.customerPhone),
          TextCellValue(order.deliveryAddress),
          DoubleCellValue(order.total),
          DoubleCellValue(order.discount),
          TextCellValue(order.paymentMethod == 'cash' ? 'نقداً' : 'إلكتروني'),
          TextCellValue(order.statusArabic),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/تقرير_طلبات_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      debugPrint("Error exporting to Excel: $e");
      return null;
    }
  }

  /// Generate & Preview/Print PDF Report
  static Future<void> printPdfReport({
    required String restaurantName,
    required List<OrderModel> orders,
    required double totalSales,
    required double totalDiscounts,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'تقرير مبيعات المطعم - تطبيق وصلني',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('المطعم: $restaurantName', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}'),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('عدد الطلبات: ${orders.length}'),
                      pw.Text('إجمالي المبيعات: ${totalSales.toStringAsFixed(2)} د.ع'),
                      pw.Text('إجمالي الخصومات: ${totalDiscounts.toStringAsFixed(2)} د.ع'),
                      pw.Text('الصافي: ${(totalSales - totalDiscounts).toStringAsFixed(2)} د.ع'),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Table.fromTextArray(
                    context: context,
                    data: <List<String>>[
                      ['رقم الطلب', 'العميل', 'الهاتف', 'الإجمالي', 'الحالة'],
                      ...orders.map((o) => [
                            '#${o.orderNumber}',
                            o.customerName,
                            o.customerPhone,
                            '${o.total.toStringAsFixed(2)} د.ع',
                            o.statusArabic,
                          ]),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Wasalny_Report.pdf',
      );
    } catch (e) {
      debugPrint("Error generating PDF: $e");
    }
  }
}
