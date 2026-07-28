import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/db_helper.dart';
import '../../models/employee.dart';
import '../../utils/constants.dart';
import '../../utils/export_helper.dart';

class MonthlyReportTab extends StatefulWidget {
  const MonthlyReportTab({super.key});

  @override
  State<MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends State<MonthlyReportTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _report = [];
  bool _loading = true;
  bool _exporting = false;

  String get _monthLabel => DateFormat('MMMM yyyy').format(_month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await DBHelper.instance.getMonthlyReport(_month.year, _month.month);
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Future<void> _export(bool asExcel) async {
    setState(() => _exporting = true);
    final companyName = await DBHelper.instance.getSetting('company_name', fallback: 'My Company');
    try {
      if (asExcel) {
        await ExportHelper.exportMonthlyReportExcel(
            report: _report, monthLabel: _monthLabel.replaceAll(' ', '_'), companyName: companyName);
      } else {
        await ExportHelper.exportMonthlyReportPdf(
            report: _report, monthLabel: _monthLabel.replaceAll(' ', '_'), companyName: companyName);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _report.fold<Map<String, num>>(
      {'present': 0, 'absent': 0, 'leave': 0, 'weeklyRest': 0},
      (acc, r) {
        acc['present'] = acc['present']! + r['present'] as int;
        acc['absent'] = acc['absent']! + r['absent'] as int;
        acc['leave'] = acc['leave']! + r['leave'] as int;
        acc['weeklyRest'] = acc['weeklyRest']! + r['weeklyRest'] as int;
        return acc;
      },
    );

    return Column(
      children: [
        Container(
          color: AppColors.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
              Expanded(
                child: Text(_monthLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
            ],
          ),
        ),
        if (!_loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _summaryChip('Present', totals['present']!, AppColors.success),
                _summaryChip('Absent', totals['absent']!, AppColors.danger),
                _summaryChip('Leave', totals['leave']!, AppColors.warning),
                _summaryChip('Weekly Rest', totals['weeklyRest']!, AppColors.rest),
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
                  ? const Center(child: Text('No employees to report on yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _report.length,
                      itemBuilder: (context, i) {
                        final row = _report[i];
                        final Employee emp = row['employee'];
                        final pct = (row['percentage'] as double);
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('P:${row['present']}  A:${row['absent']}  '
                                'L:${row['leave']}  WR:${row['weeklyRest']}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${pct.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: pct >= 90
                                          ? AppColors.success
                                          : pct >= 75
                                              ? AppColors.warning
                                              : AppColors.danger,
                                    )),
                                const Text('Attend.', style: TextStyle(fontSize: 10, color: Colors.black45)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, num value, Color color) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.12),
      label: Text('$label: $value', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
