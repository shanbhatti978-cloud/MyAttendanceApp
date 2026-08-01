import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/db_helper.dart';
import '../../models/employee.dart';
import '../../utils/constants.dart';
import '../../utils/data_bus.dart';
import '../../utils/export_helper.dart';
import '../../utils/session.dart';

/// Individual Employee History Report — search for one employee and see
/// their complete profile plus a full date-wise attendance record with
/// summary totals (working days, present, absent, leave, percentage).
class EmployeeHistoryTab extends StatefulWidget {
  const EmployeeHistoryTab({super.key});

  @override
  State<EmployeeHistoryTab> createState() => _EmployeeHistoryTabState();
}

class _EmployeeHistoryTabState extends State<EmployeeHistoryTab> {
  final _searchCtrl = TextEditingController();
  List<Employee> _results = [];
  Employee? _selected;
  DateTime? _fromDate;
  DateTime? _toDate;
  Map<String, dynamic>? _history;
  bool _loadingHistory = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    DataBus.instance.addListener(_onDataChanged);
    _search('');
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onDataChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted && _selected != null) _loadHistory();
  }

  Future<void> _search(String query) async {
    final results = await DBHelper.instance.getEmployees(query: query);
    if (mounted) setState(() => _results = results);
  }

  Future<void> _selectEmployee(Employee e) async {
    setState(() {
      _selected = e;
      _fromDate = null;
      _toDate = null;
    });
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_selected == null) return;
    setState(() => _loadingHistory = true);
    final history = await DBHelper.instance.getEmployeeHistory(
      _selected!.id!,
      fromDate: _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null,
      toDate: _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null,
    );
    if (!mounted) return;
    setState(() {
      _history = history;
      _loadingHistory = false;
    });
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _fromDate != null && _toDate != null ? DateTimeRange(start: _fromDate!, end: _toDate!) : null,
    );
    if (range != null) {
      setState(() {
        _fromDate = range.start;
        _toDate = range.end;
      });
      _loadHistory();
    }
  }

  void _clearRange() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _loadHistory();
  }

  Future<void> _export(bool asExcel) async {
    if (_selected == null || _history == null) return;
    setState(() => _exporting = true);
    final companyName = await DBHelper.instance.getSetting('company_name', fallback: 'My Company');
    try {
      if (asExcel) {
        await ExportHelper.exportEmployeeHistoryExcel(
          employee: _selected!,
          history: _history!,
          companyName: companyName,
        );
      } else {
        await ExportHelper.exportEmployeeHistoryPdf(
          employee: _selected!,
          history: _history!,
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

    if (_selected == null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search employee by name or code',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No employees found.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final e = _results[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(e.name),
                        subtitle: Text('${e.employeeCode} • ${e.designation}'),
                        onTap: () => _selectEmployee(e),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    final history = _history;
    final records = (history?['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(_selected!.name.isNotEmpty ? _selected!.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            title: Text(_selected!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${_selected!.employeeCode} • ${_selected!.designation}\n'
                '${_selected!.department.isNotEmpty ? "Dept: ${_selected!.department}  " : ""}'
                '${_selected!.unitNumber.isNotEmpty ? "Unit: ${_selected!.unitNumber}  " : ""}'
                'Shift: ${_selected!.shift}'),
            isThreeLine: true,
            trailing: TextButton(
              onPressed: () => setState(() => _selected = null),
              child: const Text('Change'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: Text(_fromDate != null && _toDate != null
                    ? '${DateFormat('dd MMM').format(_fromDate!)} - ${DateFormat('dd MMM yyyy').format(_toDate!)}'
                    : 'All Dates'),
              ),
            ),
            if (_fromDate != null) ...[
              const SizedBox(width: 8),
              IconButton(onPressed: _clearRange, icon: const Icon(Icons.clear), tooltip: 'Clear date range'),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingHistory)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (history != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('Working Days', history['totalMarked'] - (history['weeklyRest'] as int), AppColors.primary),
              _summaryChip('Present', history['present'], AppColors.success),
              _summaryChip('Absent', history['absent'], AppColors.danger),
              _summaryChip('Leave', history['leave'], AppColors.warning),
              _summaryChip('Weekly Rest', history['weeklyRest'], AppColors.rest),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            color: AppColors.success.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.percent, color: AppColors.success),
                  const SizedBox(width: 10),
                  Text('Attendance: ${(history['percentage'] as double).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
            ),
          ),
          if (canExport) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exporting || records.isEmpty ? null : () => _export(true),
                    icon: const Icon(Icons.grid_on),
                    label: const Text('Export Excel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exporting || records.isEmpty ? null : () => _export(false),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Text('Date-Wise Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No attendance records for this period.')),
            )
          else
            ...records.map((r) {
              final status = r['status'] as String;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  dense: true,
                  title: Text(DateFormat('EEEE, dd MMM yyyy').format(DateTime.parse(r['date'] as String))),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status, style: TextStyle(color: statusColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              );
            }),
        ],
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
