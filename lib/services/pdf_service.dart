// ============================================================================
//  PDF Service — Clean Version
//  Generates account statement PDF
// ============================================================================
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class PdfService {
  static Future<void> exportStatement() async {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final shortFmt = DateFormat('dd/MM/yyyy');

    // Snapshot data (avoid closing issue)
    final userName = bank.userName.isEmpty ? 'User' : bank.userName;
    final userEmail = bank.userEmail.isEmpty ? '-' : bank.userEmail;
    final totalBalance = bank.total;
    final totalIncome = bank.income;
    final totalExpense = bank.expense;
    final txCount = bank.txs.length;
    final txs = bank.txs;

    // Header
    final headerBg = PdfColor.fromHex('#5B6EF5');
    final headerText = PdfColors.white;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // ---- Header banner ----
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Loan & Banking',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: headerText,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Account Statement',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: headerText,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      dateFmt.format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 10, color: headerText),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Ref: ST${DateTime.now().millisecondsSinceEpoch % 1000000}',
                      style: pw.TextStyle(fontSize: 9, color: headerText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ---- Account info ----
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ACCOUNT INFORMATION',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 10),
                _infoRow('Name', userName),
                _infoRow('Email', userEmail),
                _infoRow('Statement Date', shortFmt.format(DateTime.now())),
                _infoRow('Total Transactions', '$txCount'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ---- Summary ----
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _summaryCard('Total Balance', _fmtUsd(totalBalance),
                        PdfColors.blue700),
                    _summaryCard('Income', _fmtUsd(totalIncome),
                        PdfColors.green700),
                    _summaryCard('Expense', _fmtUsd(totalExpense),
                        PdfColors.red700),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ---- Transactions table ----
          pw.Text(
            'TRANSACTIONS',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),

          if (txs.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Center(
                child: pw.Text(
                  'No transactions found',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Title', 'Category', 'Amount'],
              data: txs.map((t) {
                return [
                  dateFmt.format(t.time),
                  t.title,
                  t.category,
                  '${t.isExpense ? "-" : "+"}${_fmtUsd(t.amount)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: headerBg),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              oddRowDecoration: pw.BoxDecoration(
                color: PdfColors.grey50,
              ),
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
              },
            ),

          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),

          // ---- Footer ----
          pw.Center(
            child: pw.Text(
              'This statement is generated automatically by Loan & Banking App',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Generated on ${dateFmt.format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
          ),
        ],
      ),
    );

    // Preview + save
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'statement_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ---- Helpers ----
  static String _fmtUsd(double v) {
    final s = v.abs().toStringAsFixed(2);
    final parts = s.split('.');
    final buf = StringBuffer();
    for (int i = 0; i < parts[0].length; i++) {
      if (i > 0 && (parts[0].length - i) % 3 == 0) buf.write(',');
      buf.write(parts[0][i]);
    }
    return '${v < 0 ? "-" : ""}\$${buf.toString()}.${parts[1]}';
  }

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _summaryCard(String label, String value, PdfColor color) =>
      pw.Container(
        width: 140,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
}