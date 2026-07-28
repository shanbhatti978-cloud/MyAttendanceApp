import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/db_helper.dart';
import '../../models/employee.dart';
import '../../utils/constants.dart';
import '../../utils/export_helper.dart';

class DailyReportTab extends StatefulWidget {
  const DailyReportTab({super.key});

  @override
  State<DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<DailyReportTab> {
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _report = [];
  bool _loading = true;
  bool _exporting = false;

  String get _dateLabel => DateFormat('dd MMM yyyy').format(_date);
  String get _dbDate => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await DBHelper.instance.getDailyReport(_dbDate);
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  Future<void> _export(bool asExcel) async {
    setState(() => _exporting = true);
    final companyName = await DBHelper.instance.getSetting('company_name', fallback: 'My Company');
    try {
      if (asExcel) {
        await ExportHelper.exportDailyReportExcel(
            report: _report, dateLabel: _dbDate, companyName: companyName);
      } else {
        await ExportHelper.exportDailyReportPdf(
            report: _report, dateLabel: _dbDate, companyName: companyName);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{
      AppConstants.present: 0,
      AppConstants.absent: 0,
      AppConstants.leave: 0,
      AppConstants.weeklyRest: 0,
      'Not Marked': 0,
    };
    for (final row in _report) {
      final s = row['status'] as String;
      totals[s] = (totals[s] ?? 0) + 1;
    }

    return Column(
      children: [
        Container(
          color: AppColors.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.all(12),
          child: InkWell(
            onTap: _pickDate,
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(_dateLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const Spacer(),
                const Text('Tap to change', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (!_loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _summaryChip('Present', totals[AppConstants.present]!, AppColors.success),
                _summaryChip('Absent', totals[AppConstants.absent]!, AppColors.danger),
                _summaryChip('Leave', totals[AppConstants.leave]!, AppColors.warning),
                _summaryChip('Weekly Rest', totals[AppConstants.weeklyRest]!, AppColors.rest),
                if (totals['Not Marked']! > 0)
                  _summaryChip('Not Marked', totals['Not Marked']!, Colors.grey),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exporting || _report.isEmpty ? null : () => _export(true),
                  icon: const Icon(Icons.grid_on),
                  label: const Text('Export Excel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exporting || _report.isEmpty ? null : () => _export(false),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _report.isEmpty
                  ? const Center(child: Text('No active employees to report on yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _report.length,
                      itemBuilder: (context, i) {
                        final row = _report[i];
                        final Employee emp = row['employee'];
                        final status = row['status'] as String;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${emp.employeeCode} • ${emp.designation} • ${emp.shift} shift'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor(status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor(status).withValues(alpha: 0.4)),
                              ),
                              child: Text(status,
                                  style: TextStyle(color: statusColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, int value, Color color) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.12),
      label: Text('$label: $value', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
