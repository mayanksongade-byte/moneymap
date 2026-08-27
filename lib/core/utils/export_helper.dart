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
      // Remove any emojis or special characters that might break PDF standard fonts
      final sanitized = text.replaceAll('₹', 'Rs.').split('').where((char) {
        final code = char.codeUnitAt(0);
        // Only allow standard ASCII printable characters
        return code >= 32 && code <= 126;
      }).join('');
      return sanitized.trim().isEmpty ? '-' : sanitized;
    } catch (e) {
      return '-';
    }
  }

  static Future<void> exportToExcel(List<TransactionModel> transactions) async {
    try {
      print(
          'DEBUG-EXPORT: Starting Excel export for ${transactions.length} items');
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
      final path =
          "${directory.path}/MoneyMap_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final file = File(path);

      print('DEBUG-EXPORT: Encoding excel data');
      final excelBytes = excel.encode();
      if (excelBytes != null) {
        print('DEBUG-EXPORT: Writing file to $path');
        await file.writeAsBytes(excelBytes);
        print('DEBUG-EXPORT: Invoking share sheet');
        await Share.shareXFiles([XFile(path)],
            text: 'MoneyMap Transactions Excel Export');
      }
    } catch (e) {
      print('DEBUG-EXPORT: Excel export error: $e');
      rethrow;
    }
  }

  static Future<void> exportToPdf(List<TransactionModel> transactions,
      {String? userName,
      String currencySymbol = 'Rs.',
      String? dateRange}) async {
    try {
      print(
          'DEBUG-EXPORT: Starting PDF export for ${transactions.length} items');
      final pdf = pw.Document();
      final dateFmt = DateFormat('dd MMM yyyy');

      // Handle symbols that might not render in standard PDF fonts
      final safeSymbol = currencySymbol == '₹' ? 'Rs.' : _clean(currencySymbol);

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
          header: (pw.Context context) => pw.Column(
            children: [
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
                      pw.Text('FINANCIAL STATEMENT',
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                              letterSpacing: 1.5,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generated on',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey600)),
                      pw.Text(dateFmt.format(DateTime.now()),
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 10),
            ],
          ),
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MoneyMap - Smart Finance Tracking',
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ),
          build: (pw.Context context) {
            return [
              // Report Info Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PREPARED FOR',
                          style: pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(_clean(userName ?? 'Valued User').toUpperCase(),
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (dateRange != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('REPORTING PERIOD',
                            style: pw.TextStyle(
                                fontSize: 7,
                                color: PdfColors.grey600,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Text(dateRange.toUpperCase(),
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 25),

              // Summary Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildPdfStatCard('TOTAL INCOME', totalIncome,
                      PdfColors.green800, safeSymbol),
                  _buildPdfStatCard('TOTAL EXPENSE', totalExpense,
                      PdfColors.red800, safeSymbol),
                  _buildPdfStatCard(
                      'NET BALANCE',
                      netBalance,
                      netBalance >= 0 ? PdfColors.blue800 : PdfColors.red800,
                      safeSymbol,
                      highlight: true),
                ],
              ),
              pw.SizedBox(height: 35),

              pw.Text('TRANSACTION DETAILS',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                      letterSpacing: 0.5)),
              pw.SizedBox(height: 12),

              // Transaction Table
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside:
                      pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(55), // Date
                  1: const pw.FixedColumnWidth(75), // Category
                  2: const pw.FlexColumnWidth(3), // Note
                  3: const pw.FixedColumnWidth(50), // Mode
                  4: const pw.FixedColumnWidth(70), // Amount
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border(
                          bottom: pw.BorderSide(
                              color: PdfColors.blue900, width: 1.5)),
                    ),
                    children: [
                      _buildTableCell('DATE', isHeader: true),
                      _buildTableCell('CATEGORY', isHeader: true),
                      _buildTableCell('DESCRIPTION / NOTE', isHeader: true),
                      _buildTableCell('METHOD', isHeader: true),
                      _buildTableCell('AMOUNT',
                          isHeader: true, align: pw.Alignment.centerRight),
                    ],
                  ),
                  // Table Rows
                  ...transactions.map((t) {
                    final bool isExpense = t.type.toLowerCase() == 'expense';
                    final PdfColor textColor =
                        isExpense ? PdfColors.red900 : PdfColors.green900;

                    return pw.TableRow(
                      children: [
                        _buildTableCell(DateFormat('dd/MM/yy').format(t.date),
                            fontSize: 8),
                        _buildTableCell(_clean(t.category),
                            fontSize: 8, fontWeight: pw.FontWeight.bold),
                        _buildTableCell(_clean(t.note),
                            fontSize: 8, color: PdfColors.grey700),
                        _buildTableCell(_clean(t.paymentMode).toUpperCase(),
                            fontSize: 7),
                        _buildTableCell(
                            '${isExpense ? '-' : '+'} ${t.amount.toStringAsFixed(2)}',
                            textColor: textColor,
                            fontWeight: pw.FontWeight.bold,
                            align: pw.Alignment.centerRight),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Text('*** End of Statement ***',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey400)),
              ),
            ];
          },
        ),
      );

      print('DEBUG-EXPORT: Saving PDF document');
      final bytes = await pdf.save();

      final directory = await getTemporaryDirectory();
      final path =
          "${directory.path}/MoneyMap_Report_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(path);

      print('DEBUG-EXPORT: Writing PDF file to $path');
      await file.writeAsBytes(bytes);

      print('DEBUG-EXPORT: Invoking share sheet for PDF');
      await Share.shareXFiles([XFile(path)],
          text: 'My MoneyMap Financial Report');
      print('DEBUG-EXPORT: Share sheet finished');
    } catch (e) {
      print('DEBUG-EXPORT: PDF export error: $e');
      rethrow;
    }
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    PdfColor? textColor,
    double? fontSize,
    pw.FontWeight? fontWeight,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Container(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: fontSize ?? (isHeader ? 9 : 8),
            fontWeight: fontWeight ??
                (isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
            color: isHeader
                ? PdfColors.blueGrey900
                : (textColor ?? color ?? PdfColors.black),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildPdfStatCard(
      String title, double amount, PdfColor color, String currencySymbol,
      {bool highlight = false}) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: highlight ? PdfColors.blue50 : PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(
            color: highlight ? PdfColors.blue200 : PdfColors.grey300,
            width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('$currencySymbol ',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
              pw.Text(amount.toStringAsFixed(2),
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
