import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/db_helper.dart';
import '../../models/employee.dart';
import '../../utils/constants.dart';
import '../../utils/data_bus.dart';
import '../../utils/export_helper.dart';
import '../../utils/session.dart';

class UnitReportTab extends StatefulWidget {
  const UnitReportTab({super.key});

  @override
  State<UnitReportTab> createState() => _UnitReportTabState();
}

class _UnitReportTabState extends State<UnitReportTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<String> _availableUnits = [];
  String? _selectedUnit;
  List<Map<String, dynamic>> _report = [];
  bool _loading = true;
  bool _exporting = false;
  bool _sortByPercentage = false;
  bool _sortAscending = true;

  String get _monthLabel => DateFormat('MMMM yyyy').format(_month);

  @override
  void initState() {
    super.initState();
    DataBus.instance.addListener(_onDataChanged);
    _init();
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _init() async {
    final units = await DBHelper.instance.getDistinctUnits();
    setState(() {
      _availableUnits = units;
      _selectedUnit = units.isNotEmpty ? units.first : null;
    });
    if (_selectedUnit != null) await _load();
    setState(() => _loading = false);
  }

  Future<void> _load() async {
    if (_selectedUnit == null) return;
    setState(() => _loading = true);
    final report = await DBHelper.instance.getMonthlyReport(
      _month.year,
      _month.month,
      unitFilter: _selectedUnit!,
    );
    _applySort(report);
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  void _applySort(List<Map<String, dynamic>> list) {
    int compare(Map<String, dynamic> a, Map<String, dynamic> b) {
      if (_sortByPercentage) {
        return (a['percentage'] as double).compareTo(b['percentage'] as double);
      }
      final Employee ea = a['employee'];
      final Employee eb = b['employee'];
      return ea.name.toLowerCase().compareTo(eb.name.toLowerCase());
    }

    list.sort(_sortAscending ? compare : (a, b) => compare(b, a));
  }

  void _toggleSort(bool byPercentage) {
    setState(() {
      if (_sortByPercentage == byPercentage) {
        _sortAscending = !_sortAscending;
      } else {
        _sortByPercentage = byPercentage;
        _sortAscending = true;
      }
      _applySort(_report);
    });
  }

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Future<void> _export(bool asExcel) async {
    if (_selectedUnit == null) return;
    setState(() => _exporting = true);
    final companyName = await DBHelper.instance.getSetting('company_name', fallback: 'My Company');
    try {
      if (asExcel) {
        await ExportHelper.exportUnitReportExcel(
          report: _report,
          unit: _selectedUnit!,
          monthLabel: _monthLabel.replaceAll(' ', '_'),
          companyName: companyName,
        );
      } else {
        await ExportHelper.exportUnitReportPdf(
          report: _report,
          unit: _selectedUnit!,
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
    final canExport = context.watch<Session>().permissions.canExportReports;

    if (_availableUnits.isEmpty && !_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No employees with a Unit Number assigned yet. Add a Unit Number in Employee Master first.',
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
                  const Icon(Icons.factory, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Unit: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedUnit,
                      items: _availableUnits.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedUnit = v);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (canExport)
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
        if (!_loading && _report.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Sort by:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Name'),
                  selected: !_sortByPercentage,
                  onSelected: (_) => _toggleSort(false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Attendance %'),
                  selected: _sortByPercentage,
                  onSelected: (_) => _toggleSort(true),
                ),
                const Spacer(),
                Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: AppColors.primary),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _report.isEmpty
                  ? const Center(child: Text('No employees in this unit.'))
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
