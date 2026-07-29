import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/db_helper.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';

/// Lets a supervisor record a Leave (or any status) for an employee on
/// ANY date — today, tomorrow, next week, or a date in the past — in a
/// few taps, without having to open the full daily Attendance grid for
/// that date. Every report that depends on this data (Shift Planning,
/// Daily/Monthly/Shift-Wise reports, Dashboard) picks the change up
/// immediately via DataBus, with no manual refresh needed.
class LeaveEntryScreen extends StatefulWidget {
  const LeaveEntryScreen({super.key});

  @override
  State<LeaveEntryScreen> createState() => _LeaveEntryScreenState();
}

class _LeaveEntryScreenState extends State<LeaveEntryScreen> {
  final _searchCtrl = TextEditingController();
  List<Employee> _results = [];
  Employee? _selected;
  DateTime _date = DateTime.now();
  String _status = AppConstants.leave;
  String? _existingStatus;
  bool _saving = false;
  String? _message;

  String get _dbDate => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final results = await DBHelper.instance.getEmployees(query: query, statusFilter: 'Active');
    setState(() => _results = results);
  }

  Future<void> _selectEmployee(Employee e) async {
    setState(() => _selected = e);
    await _refreshExistingStatus();
  }

  Future<void> _refreshExistingStatus() async {
    if (_selected == null) return;
    final map = await DBHelper.instance.getAttendanceForDate(_dbDate);
    setState(() => _existingStatus = map[_selected!.id]);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Deliberately no lower/upper bound restriction — the requirement
      // is explicit that both future and past dates must be supported.
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
      await _refreshExistingStatus();
    }
  }

  Future<void> _save() async {
    if (_selected == null) {
      setState(() => _message = 'Please select an employee first.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });

    await DBHelper.instance.upsertAttendance(
      AttendanceRecord(employeeId: _selected!.id!, date: _dbDate, status: _status),
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _existingStatus = _status;
      _message = '${_selected!.name} marked as "$_status" for ${DateFormat('dd MMM yyyy').format(_date)}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advance Leave Entry')),
      drawer: const AppDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          if (_selected == null)
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
                          subtitle: Text('${e.employeeCode} • ${e.designation} • ${e.shift} shift'),
                          onTap: () => _selectEmployee(e),
                        );
                      },
                    ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: Text(_selected!.name.isNotEmpty ? _selected!.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(_selected!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${_selected!.employeeCode} • ${_selected!.designation} • ${_selected!.shift} shift'),
                        trailing: TextButton(
                          onPressed: () => setState(() {
                            _selected = null;
                            _message = null;
                          }),
                          child: const Text('Change'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today)),
                        child: Text(DateFormat('EEEE, dd MMM yyyy').format(_date)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppConstants.attendanceStatuses.map((s) {
                        final selected = _status == s;
                        return ChoiceChip(
                          label: Text(s),
                          selected: selected,
                          selectedColor: statusColor(s).withValues(alpha: 0.85),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setState(() => _status = s),
                        );
                      }).toList(),
                    ),
                    if (_existingStatus != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Already marked as "$_existingStatus" for this date. Saving will overwrite it.',
                          style: const TextStyle(color: AppColors.warning),
                        ),
                      ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      Text(_message!, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving...' : 'SAVE $_status'.toUpperCase()),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
