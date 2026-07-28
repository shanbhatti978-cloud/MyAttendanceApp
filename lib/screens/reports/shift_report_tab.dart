import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/db_helper.dart';
import '../../models/employee.dart';
import '../../utils/constants.dart';
import '../../utils/export_helper.dart';

class ShiftReportTab extends StatefulWidget {
  const ShiftReportTab({super.key});

  @override
  State<ShiftReportTab> createState() => _ShiftReportTabState();
}

class _ShiftReportTabState extends State<ShiftReportTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<String> _availableShifts = [];
  String? _selectedShift;
  List<Map<String, dynamic>> _report = [];
  bool _loading = true;
  bool _exporting = false;

  String get _monthLabel => DateFormat('MMMM yyyy').format(_month);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final shifts = await DBHelper.instance.getDistinctShifts();
    setState(() {
      _availableShifts = shifts;
      _selectedShift = shifts.isNotEmpty ? shifts.first : null;
    });
    if (_selectedShift != null) await _load();
    setState(() => _loading = false);
  }

  Future<void> _load() async {
    if (_selectedShift == null) return;
    setState(() => _loading = true);
    final report = await DBHelper.instance.getMonthlyReport(
      _month.year,
      _month.month,
      shiftFilter: _selectedShift!,
    );
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
    if (_selectedShift == null) return;
    setState(() => _exporting = true);
    final companyName = await DBHelper.instance.getSetting('company_name', fallback: 'My Company');
    try {
      if (asExcel) {
        await ExportHelper.exportShiftReportExcel(
          report: _report,
          shift: _selectedShift!,
          monthLabel: _monthLabel.replaceAll(' ', '_'),
          companyName: companyName,
        );
      } else {
        await ExportHelper.exportShiftReportPdf(
          report: _report,
          shift: _selectedShift!,
          monthLabel: _monthLabel.replaceAll(' ', '_'),
          companyName: companyName,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_availableShifts.isEmpty && !_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No employees with a shift assigned yet. Add employees in Employee Master first.',
              textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: AppColors.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              Row(
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
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.groups, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Shift: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedShift,
                      items: _availableShifts
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedShift = v);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _report.isEmpty
                  ? const Center(child: Text('No employees on this shift.'))
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
                            subtitle: Text('${emp.employeeCode} • ${emp.designation}\n'
                                'P:${row['present']}  A:${row['absent']}  L:${row['leave']}  WR:${row['weeklyRest']}'),
                            isThreeLine: true,
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
}
