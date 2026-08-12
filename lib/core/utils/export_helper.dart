import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../features/home/data/models/transaction_model.dart';

class ExportHelper {
  // Enhanced cleaning to handle nulls and unsupported characters (ASCII 32-126 only)
  static String _clean(String? text) {
    if (text == null || text.trim().isEmpty) return '-';
    // Replace common symbols and filter out non-ASCII to prevent PDF crashes
    try {
      final sanitized = text.replaceAll('₹', 'Rs.').split('').where((char) {
        final code = char.codeUnitAt(0);
        return code >= 32 && code <= 126;
      }).join('');
      return sanitized.isEmpty ? '-' : sanitized;
    } catch (e) {
      return '-';
    }
  }

  static Future<void> exportToExcel(List<TransactionModel> transactions) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Transactions'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        TextCellValue('Date'),
        TextCellValue('Type'),
        TextCellValue('Category'),
        TextCellValue('Mode'),
        TextCellValue('Amount'),
        TextCellValue('Note'),
      ]);

      for (var t in transactions) {
        sheetObject.appendRow([
          TextCellValue(DateFormat('yyyy-MM-dd').format(t.date)),
          TextCellValue(t.type.toUpperCase()),
          TextCellValue(t.category),
          TextCellValue(t.paymentMode),
          DoubleCellValue(t.amount),
          TextCellValue(t.note),
        ]);
      }

      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/MoneyMap_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final file = File(path);
      final excelBytes = excel.encode();
      if (excelBytes != null) {
        await file.writeAsBytes(excelBytes);
        await Share.shareXFiles([XFile(path)], text: 'MoneyMap Transactions Excel Export');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> exportToPdf(List<TransactionModel> transactions, {String? userName}) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('dd MMM yyyy');

    final totalIncome = transactions
        .where((t) => t.type.toLowerCase() == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = transactions
        .where((t) => t.type.toLowerCase() == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
    final netBalance = totalIncome - totalExpense;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('Page ${context.pageNumber}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MONEYMAP',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text('FINANCIAL REPORT',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, letterSpacing: 1.2)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(dateFmt.format(DateTime.now()),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Statement of Account', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 15),

            // Prepared For
            pw.Text('USER: ${_clean(userName ?? 'Valued User')}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),

            // Summary Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfStatCard('TOTAL INCOME', totalIncome, PdfColors.green700),
                _buildPdfStatCard('TOTAL EXPENSE', totalExpense, PdfColors.red700),
                _buildPdfStatCard('NET BALANCE', netBalance, 
                    netBalance >= 0 ? PdfColors.blue700 : PdfColors.red700),
              ],
            ),
            pw.SizedBox(height: 25),

            // Table of Transactions
            pw.Text('TRANSACTION HISTORY',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: <String>['Date', 'Category', 'Mode', 'Type', 'Amount'],
              data: transactions.map((t) => <String>[
                DateFormat('dd/MM/yy').format(t.date),
                _clean(t.category),
                _clean(t.paymentMode),
                t.type.toUpperCase(),
                t.amount.toStringAsFixed(2),
              ]).toList(),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellHeight: 25,
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
            ),
            
            pw.SizedBox(height: 30),
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.Text('MoneyMap - Secure Financial Export',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          ];
        },
      ),
    );

    try {
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/MoneyMap_Report_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(path)], text: 'My MoneyMap Financial Report');
    } catch (e) {
      rethrow;
    }
  }

  static pw.Widget _buildPdfStatCard(String title, double amount, PdfColor color) {
    return pw.Container(
      width: 155,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text('Rs. ${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
