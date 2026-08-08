import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../features/home/data/models/transaction_model.dart';

class ExportHelper {
  static Future<void> exportToExcel(List<TransactionModel> transactions) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Transactions'];
    excel.delete('Sheet1');

    // Headers
    List<CellValue?> headers = [
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Category'),
      TextCellValue('Mode'),
      TextCellValue('Amount'),
      TextCellValue('Note'),
    ];
    sheetObject.appendRow(headers);

    // Data rows
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
    final path = "${directory.path}/MoneyMap_Transactions_${DateTime.now().millisecondsSinceEpoch}.xlsx";
    final file = File(path);
    final excelBytes = excel.encode();
    if (excelBytes != null) {
      await file.writeAsBytes(excelBytes);
      await Share.shareXFiles([XFile(path)], text: 'My MoneyMap Transactions');
    }
  }

  static Future<void> exportToPdf(List<TransactionModel> transactions, {String? userName}) async {
    final pdf = pw.Document();

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
        build: (pw.Context context) {
          return [
            // Professional Bank-style Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MONEYMAP',
                        style: pw.TextStyle(
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.Text('SMART FINANCE TRACKER',
                        style: pw.TextStyle(
                            fontSize: 9, 
                            letterSpacing: 2,
                            color: PdfColors.blue700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('STATEMENT OF ACCOUNT',
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Generated on: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1.5, color: PdfColors.grey300),
            pw.SizedBox(height: 15),

            // User Info Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CUSTOMER DETAILS',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(userName ?? 'Valued User',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('REPORT PERIOD',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('All Time Activity',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            // Financial Summary Boxes (Horizontal)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard('TOTAL CREDITS', totalIncome, PdfColors.green700),
                _buildSummaryCard('TOTAL DEBITS', totalExpense, PdfColors.red700),
                _buildSummaryCard('NET POSITION', netBalance, 
                    netBalance >= 0 ? PdfColors.blue800 : PdfColors.red800),
              ],
            ),
            pw.SizedBox(height: 30),

            // Transactions Table
            pw.Text('TRANSACTION HISTORY',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Category', 'Mode', 'Type', 'Amount', 'Note'],
              data: transactions.map((t) {
                return [
                  DateFormat('dd/MM/yy').format(t.date),
                  t.category,
                  t.paymentMode.toUpperCase(),
                  t.type.toUpperCase(),
                  t.amount.toStringAsFixed(2),
                  t.note,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                  color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              cellHeight: 28,
              cellStyle: const pw.TextStyle(fontSize: 8),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(55),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FixedColumnWidth(65),
                3: const pw.FixedColumnWidth(50),
                4: const pw.FixedColumnWidth(65),
                5: const pw.FlexColumnWidth(2),
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerLeft,
              },
            ),

            pw.Spacer(),
            
            // Footer Branding & Disclaimer
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MoneyMap Finance Report - Secure & Private',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                pw.Text('Generated via MoneyMap Mobile App',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          );
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/MoneyMap_Statement_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(path)], text: 'My MoneyMap Financial Statement');
  }

  static pw.Widget _buildSummaryCard(String title, double amount, PdfColor color) {
    return pw.Container(
      width: 160,
      height: 50,
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 6,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                bottomLeft: pw.Radius.circular(6),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title.toUpperCase(), 
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('₹ ${amount.toStringAsFixed(2)}', 
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
