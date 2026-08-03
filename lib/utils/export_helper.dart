import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/employee.dart';

/// Builds and shares Excel (.xlsx) and PDF exports for every report type
/// in the app (Monthly, Shift-Wise, Daily). Files are written to the
/// app's temp directory and then handed to the OS share sheet, so the
/// user can save them to Downloads, WhatsApp, email, Google Drive, etc.
class ExportHelper {
  // ---------------- MONTHLY REPORT ----------------

  static Future<void> exportMonthlyReportExcel({
    required List<Map<String, dynamic>> report,
    required String monthLabel,
    required String companyName,
  }) =>
      _exportSummaryExcel(
        report: report,
        companyName: companyName,
        title: 'Monthly Attendance Report - $monthLabel',
        fileName: 'RAMS_Monthly_$monthLabel',
        includeShiftColumn: false,
      );

  static Future<void> exportMonthlyReportPdf({
    required List<Map<String, dynamic>> report,
    required String monthLabel,
    required String companyName,
  }) =>
      _exportSummaryPdf(
        report: report,
        companyName: companyName,
        title: 'Monthly Attendance Report - $monthLabel',
        fileName: 'RAMS_Monthly_$monthLabel',
        includeShiftColumn: false,
      );

  // ---------------- SHIFT-WISE REPORT ----------------

  static Future<void> exportShiftReportExcel({
    required List<Map<String, dynamic>> report,
    required String shift,
    required String monthLabel,
    required String companyName,
  }) =>
      _exportSummaryExcel(
        report: report,
        companyName: companyName,
        title: 'Shift-Wise Attendance Report — $shift Shift — $monthLabel',
        fileName: 'RAMS_Shift_${shift}_$monthLabel',
        includeShiftColumn: true,
      );

  static Future<void> exportShiftReportPdf({
    required List<Map<String, dynamic>> report,
    required String shift,
    required String monthLabel,
    required String companyName,
  }) =>
      _exportSummaryPdf(
        report: report,
        companyName: companyName,
        title: 'Shift-Wise Attendance Report — $shift Shift — $monthLabel',
        fileName: 'RAMS_Shift_${shift}_$monthLabel',
        includeShiftColumn: true,
      );

  // ---------------- UNIT-WISE REPORT ----------------

  static Future<void> exportUnitReportExcel({
    required List<Map<String, dynamic>> report,
    required String unit,
    required String monthLabel,
    required String companyName,
  }) =>
      _exportSummaryExcel(
        report: report,
        companyName: companyName,
        title: 'Unit-Wise Attendance Report — Unit $unit — $monthLabel',
        fileName: 'RAMS_Unit_${unit}_$monthLabel',
        includeShiftColumn: false,
      );

  static Future<void> exportUnitReportPdf({
    required List<Map<String, dynamic>> report,
    required String unit,
    required String monthLabel,
    required String companyName,
  }) =>
      _exportSummaryPdf(
        report: report,
        companyName: companyName,
        title: 'Unit-Wise Attendance Report — Unit $unit — $monthLabel',
        fileName: 'RAMS_Unit_${unit}_$monthLabel',
        includeShiftColumn: false,
      );

  // ---------------- DEPARTMENT-WISE REPORT ----------------

  static Future<void> exportDepartmentReportExcel({
    required List<Map<String, dynamic>> report,
    required String department,
    required String monthLabel,
    required String companyName,
  }) =>
      _exportSummaryExcel(
        report: report,
        companyName: companyName,
        title: 'Department-Wise Attendance Report — $department — $monthLabel',
        fileName: 'RAMS_Dept_${department}_$monthLabel',
        includeShiftColumn: false,
      );

  static Future<void> exportDepartmentReportPdf({
    required List<Map<String, dynamic>> report,
    required String department,
    required String monthLabel,
    required String companyName,
  }) =>
      _exportSummaryPdf(
        report: report,
        companyName: companyName,
        title: 'Department-Wise Attendance Report — $department — $monthLabel',
        fileName: 'RAMS_Dept_${department}_$monthLabel',
        includeShiftColumn: false,
      );

  // ---------------- DAILY REPORT ----------------

  static Future<void> exportDailyReportExcel({
    required List<Map<String, dynamic>> report,
    required String dateLabel,
    required String companyName,
  }) async {
    final workbook = xls.Excel.createExcel();
    final sheet = workbook['Daily Report'];

    sheet.appendRow([xls.TextCellValue('$companyName - Daily Attendance Report - $dateLabel')]);
    sheet.appendRow([]);
    sheet.appendRow([
      xls.TextCellValue('Employee Code'),
      xls.TextCellValue('Name'),
      xls.TextCellValue('Designation'),
      xls.TextCellValue('Shift'),
      xls.TextCellValue('Status'),
    ]);

    for (final row in report) {
      final Employee emp = row['employee'];
      sheet.appendRow([
        xls.TextCellValue(emp.employeeCode),
        xls.TextCellValue(emp.name),
        xls.TextCellValue(emp.designation),
        xls.TextCellValue(emp.shift),
        xls.TextCellValue(row['status'] as String),
      ]);
    }

    workbook.delete('Sheet1');
    await _saveAndShareExcel(workbook, 'RAMS_Daily_$dateLabel', 'RAMS Daily Report - $dateLabel');
  }

  static Future<void> exportDailyReportPdf({
    required List<Map<String, dynamic>> report,
    required String dateLabel,
    required String companyName,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('Daily Attendance Report - $dateLabel', style: const pw.TextStyle(fontSize: 13)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Code', 'Name', 'Designation', 'Shift', 'Status'],
            data: report.map((row) {
              final Employee emp = row['employee'];
              return [emp.employeeCode, emp.name, emp.designation, emp.shift, row['status'] as String];
            }).toList(),
          ),
        ],
      ),
    );
    await _saveAndSharePdf(doc, 'RAMS_Daily_$dateLabel', 'RAMS Daily Report - $dateLabel');
  }

  // ---------------- INDIVIDUAL EMPLOYEE HISTORY ----------------

  static Future<void> exportEmployeeHistoryExcel({
    required Employee employee,
    required Map<String, dynamic> history,
    required String companyName,
  }) async {
    final workbook = xls.Excel.createExcel();
    final sheet = workbook['History'];

    sheet.appendRow([xls.TextCellValue('$companyName - Employee Attendance History')]);
    sheet.appendRow([xls.TextCellValue('${employee.name} (${employee.employeeCode}) — ${employee.designation}')]);
    sheet.appendRow([]);
    sheet.appendRow([
      xls.TextCellValue('Present'),
      xls.TextCellValue('Absent'),
      xls.TextCellValue('Leave'),
      xls.TextCellValue('Weekly Rest'),
      xls.TextCellValue('Attendance %'),
    ]);
    sheet.appendRow([
      xls.IntCellValue(history['present']),
      xls.IntCellValue(history['absent']),
      xls.IntCellValue(history['leave']),
      xls.IntCellValue(history['weeklyRest']),
      xls.TextCellValue('${(history['percentage'] as double).toStringAsFixed(1)}%'),
    ]);
    sheet.appendRow([]);
    sheet.appendRow([xls.TextCellValue('Date'), xls.TextCellValue('Status')]);

    final records = (history['records'] as List).cast<Map<String, dynamic>>();
    for (final r in records) {
      sheet.appendRow([xls.TextCellValue(r['date'] as String), xls.TextCellValue(r['status'] as String)]);
    }

    workbook.delete('Sheet1');
    await _saveAndShareExcel(
        workbook, 'RAMS_History_${employee.employeeCode}', 'RAMS Employee History - ${employee.name}');
  }

  static Future<void> exportEmployeeHistoryPdf({
    required Employee employee,
    required Map<String, dynamic> history,
    required String companyName,
  }) async {
    final doc = pw.Document();
    final records = (history['records'] as List).cast<Map<String, dynamic>>();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('Employee Attendance History', style: const pw.TextStyle(fontSize: 13)),
          pw.SizedBox(height: 6),
          pw.Text('${employee.name} (${employee.employeeCode}) — ${employee.designation}'),
          pw.SizedBox(height: 10),
          pw.Text(
            'Present: ${history['present']}   Absent: ${history['absent']}   '
            'Leave: ${history['leave']}   Weekly Rest: ${history['weeklyRest']}   '
            'Attendance: ${(history['percentage'] as double).toStringAsFixed(1)}%',
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Date', 'Status'],
            data: records.map((r) => [r['date'] as String, r['status'] as String]).toList(),
          ),
        ],
      ),
    );
    await _saveAndSharePdf(
        doc, 'RAMS_History_${employee.employeeCode}', 'RAMS Employee History - ${employee.name}');
  }

  // ---------------- SHARED HELPERS ----------------

  /// Excel builder shared by Monthly and Shift-Wise reports — both use
  /// the same Present/Absent/Leave/Weekly-Rest/% column layout, only
  /// differing by whether a Shift column is included.
  static Future<void> _exportSummaryExcel({
    required List<Map<String, dynamic>> report,
    required String companyName,
    required String title,
    required String fileName,
    required bool includeShiftColumn,
  }) async {
    final workbook = xls.Excel.createExcel();
    final sheet = workbook['Report'];

    sheet.appendRow([xls.TextCellValue('$companyName - $title')]);
    sheet.appendRow([]);
    sheet.appendRow([
      xls.TextCellValue('Employee Code'),
      xls.TextCellValue('Name'),
      xls.TextCellValue('Designation'),
      if (includeShiftColumn) xls.TextCellValue('Shift'),
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
        if (includeShiftColumn) xls.TextCellValue(emp.shift),
        xls.IntCellValue(row['present']),
        xls.IntCellValue(row['absent']),
        xls.IntCellValue(row['leave']),
        xls.IntCellValue(row['weeklyRest']),
        xls.TextCellValue('${(row['percentage'] as double).toStringAsFixed(1)}%'),
      ]);
    }

    workbook.delete('Sheet1');
    await _saveAndShareExcel(workbook, fileName, title);
  }

  /// PDF builder shared by Monthly and Shift-Wise reports.
  static Future<void> _exportSummaryPdf({
    required List<Map<String, dynamic>> report,
    required String companyName,
    required String title,
    required String fileName,
    required bool includeShiftColumn,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(title, style: const pw.TextStyle(fontSize: 13)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellAlignment: pw.Alignment.centerLeft,
            headers: [
              'Code',
              'Name',
              'Designation',
              if (includeShiftColumn) 'Shift',
              'Present',
              'Absent',
              'Leave',
              'Rest',
              '%',
            ],
            data: report.map((row) {
              final Employee emp = row['employee'];
              return [
                emp.employeeCode,
                emp.name,
                emp.designation,
                if (includeShiftColumn) emp.shift,
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
    await _saveAndSharePdf(doc, fileName, title);
  }

  static Future<void> _saveAndShareExcel(xls.Excel workbook, String fileName, String shareText) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName.xlsx';
    final bytes = workbook.encode();
    if (bytes != null) {
      final file = File(path);
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: shareText));
    }
  }

  static Future<void> _saveAndSharePdf(pw.Document doc, String fileName, String shareText) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName.pdf';
    final file = File(path);
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: shareText));
  }
}
