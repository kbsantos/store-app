import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportingExportService {
  static Future<void> saveCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final data = <List<String>>[headers, ...rows];
    final csv = data.map((row) => row.map(_csv).join(',')).join('\r\n');
    await _save(filename, Uint8List.fromList(utf8.encode(csv)));
  }

  /// Excel-compatible HTML workbook. Excel opens .xls files directly and this
  /// avoids adding another dependency to the Store Management app.
  static Future<void> saveExcel({
    required String filename,
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final html = StringBuffer()
      ..writeln('<html><head><meta charset="utf-8"></head><body>')
      ..writeln('<h2>${_html(title)}</h2>')
      ..writeln('<table border="1"><thead><tr>');
    for (final header in headers) {
      html.writeln('<th>${_html(header)}</th>');
    }
    html.writeln('</tr></thead><tbody>');
    for (final row in rows) {
      html.writeln('<tr>');
      for (final value in row) {
        html.writeln('<td>${_html(value)}</td>');
      }
      html.writeln('</tr>');
    }
    html.writeln('</tbody></table></body></html>');
    await _save(filename, Uint8List.fromList(utf8.encode(html.toString())));
  }

  static Future<void> savePdf({
    required String filename,
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellPadding: const pw.EdgeInsets.all(5),
          ),
        ],
      ),
    );
    await _save(filename, await document.save());
  }

  static Future<void> printReport({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) async {
        final document = pw.Document();
        document.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (_) => [
              pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 14),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellPadding: const pw.EdgeInsets.all(5),
              ),
            ],
          ),
        );
        return document.save();
      },
    );
  }

  static Future<void> _save(String filename, Uint8List bytes) async {
    final result = await FilePicker.saveFile(
      dialogTitle: 'Save sales report',
      fileName: filename,
      bytes: bytes,
      mimeType: _mimeType(filename),
    );
    if (kDebugMode) {
      debugPrint('Sales report saved: $result');
    }
  }

  static String _mimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    return 'application/octet-stream';
  }

  static String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static String _html(String value) => const HtmlEscape().convert(value);
}
