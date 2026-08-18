import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../features/home/data/models/transaction_model.dart';

class ExportHelper {
  static String _clean(String? text) {
    if (text == null || text.trim().isEmpty) return '-';
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

  static Future<void> exportToPdf(List<TransactionModel> transactions, {String? userName, String currencySymbol = 'Rs.'}) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('dd MMM yyyy');

    // Handle symbols that might not render in standard PDF fonts
    final safeSymbol = currencySymbol == '₹' ? 'Rs.' : currencySymbol;

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
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700, letterSpacing: 1.2)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(dateFmt.format(DateTime.now()),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Statement of Account', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 15),

            pw.Text('USER: ${_clean(userName ?? 'Valued User')}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),

            // Summary Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfStatCard('TOTAL INCOME', totalIncome, PdfColors.green700, safeSymbol),
                _buildPdfStatCard('TOTAL EXPENSE', totalExpense, PdfColors.red700, safeSymbol),
                _buildPdfStatCard('NET BALANCE', netBalance, 
                    netBalance >= 0 ? PdfColors.blue700 : PdfColors.red700, safeSymbol),
              ],
            ),
            pw.SizedBox(height: 25),

            pw.Text('TRANSACTION HISTORY',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 8),

            // Transaction Table with Note and Colors
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(60), // Date
                1: const pw.FixedColumnWidth(80), // Category
                2: const pw.FlexColumnWidth(2),   // Note (Flexible)
                3: const pw.FixedColumnWidth(50), // Mode
                4: const pw.FixedColumnWidth(60), // Amount
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    _buildTableCell('Date', isHeader: true),
                    _buildTableCell('Category', isHeader: true),
                    _buildTableCell('Note', isHeader: true),
                    _buildTableCell('Mode', isHeader: true),
                    _buildTableCell('Amount', isHeader: true, align: pw.Alignment.centerRight),
                  ],
                ),
                // Table Rows
                ...transactions.map((t) {
                  final bool isExpense = t.type.toLowerCase() == 'expense';
                  final PdfColor bgColor = isExpense ? PdfColors.red50 : PdfColors.green50;
                  final PdfColor textColor = isExpense ? PdfColors.red700 : PdfColors.green700;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bgColor),
                    children: [
                      _buildTableCell(DateFormat('dd/MM/yy').format(t.date), textColor: textColor),
                      _buildTableCell(_clean(t.category), textColor: textColor),
                      _buildTableCell(_clean(t.note), textColor: textColor),
                      _buildTableCell(_clean(t.paymentMode), textColor: textColor),
                      _buildTableCell(t.amount.toStringAsFixed(2), 
                          textColor: textColor, align: pw.Alignment.centerRight),
                    ],
                  );
                }),
              ],
            ),
            
            pw.SizedBox(height: 30),
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.Text('MoneyMap - Secure Financial Export',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
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

  static pw.Widget _buildTableCell(String text, {
    bool isHeader = false, 
    pw.Alignment align = pw.Alignment.centerLeft,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Container(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isHeader ? 9 : 8,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isHeader ? PdfColors.white : (textColor ?? PdfColors.black),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildPdfStatCard(String title, double amount, PdfColor color, String currencySymbol) {
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
          pw.Text('$currencySymbol ${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
