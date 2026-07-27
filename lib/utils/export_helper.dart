import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/employee.dart';

/// Builds and shares Excel (.xlsx) and PDF exports for the monthly report.
/// Files are written to the app's temp directory and then handed to the
/// OS share sheet, so the user can save them to Downloads, WhatsApp, email, etc.
class ExportHelper {
  static Future<void> exportMonthlyReportExcel({
    required List<Map<String, dynamic>> report,
    required String monthLabel,
    required String companyName,
  }) async {
    final workbook = xls.Excel.createExcel();
    final sheet = workbook['Monthly Report'];

    sheet.appendRow([xls.TextCellValue('$companyName - Monthly Attendance Report - $monthLabel')]);
    sheet.appendRow([]);
    sheet.appendRow([
      xls.TextCellValue('Employee Code'),
      xls.TextCellValue('Name'),
      xls.TextCellValue('Designation'),
      xls.TextCellValue('Present'),
      xls.TextCellValue('Absent'),
      xls.TextCellValue('Leave'),
      xls.TextCellValue('Weekly Rest'),
      xls.TextCellValue('Attendance %'),
    ]);

    for (final row in report) {
      final Employee emp = row['employee'];
      sheet.appendRow([
        xls.TextCellValue(emp.employeeCode),
        xls.TextCellValue(emp.name),
        xls.TextCellValue(emp.designation),
        xls.IntCellValue(row['present']),
        xls.IntCellValue(row['absent']),
        xls.IntCellValue(row['leave']),
        xls.IntCellValue(row['weeklyRest']),
        xls.TextCellValue('${(row['percentage'] as double).toStringAsFixed(1)}%'),
      ]);
    }

    workbook.delete('Sheet1');

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/RAMS_Report_$monthLabel.xlsx';
    final bytes = workbook.encode();
    if (bytes != null) {
      final file = File(path);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(path)], text: 'RAMS Monthly Report - $monthLabel');
    }
  }

  static Future<void> exportMonthlyReportPdf({
    required List<Map<String, dynamic>> report,
    required String monthLabel,
    required String companyName,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('Monthly Attendance Report - $monthLabel', style: const pw.TextStyle(fontSize: 13)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Code', 'Name', 'Designation', 'Present', 'Absent', 'Leave', 'Rest', '%'],
            data: report.map((row) {
              final Employee emp = row['employee'];
              return [
                emp.employeeCode,
                emp.name,
                emp.designation,
                '${row['present']}',
                '${row['absent']}',
                '${row['leave']}',
                '${row['weeklyRest']}',
                '${(row['percentage'] as double).toStringAsFixed(1)}%',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/RAMS_Report_$monthLabel.pdf';
    final file = File(path);
    await file.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(path)], text: 'RAMS Monthly Report - $monthLabel');
  }
}
