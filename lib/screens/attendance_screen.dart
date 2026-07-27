import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/db_helper.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Employee> _employees = [];
  // Working copy of today's statuses, keyed by employee id
  final Map<int, String> _statuses = {};
  bool _loading = true;
  bool _saving = false;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final employees = await DBHelper.instance.getEmployees(statusFilter: 'Active');
    final existing = await DBHelper.instance.getAttendanceForDate(_dateStr);
    final weekdayName = AppConstants.weekdays[_selectedDate.weekday - 1];

    _statuses.clear();
    for (final e in employees) {
      if (existing.containsKey(e.id)) {
        // Already saved for this date -> load it (never silently overwrite)
        _statuses[e.id!] = existing[e.id]!;
      } else if (e.weeklyRestDay == weekdayName) {
        // Auto Weekly Rest requirement
        _statuses[e.id!] = AppConstants.weeklyRest;
      } else {
        // Default Present requirement
        _statuses[e.id!] = AppConstants.present;
      }
    }

    setState(() {
      _employees = employees;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final records = _statuses.entries
        .map((e) => AttendanceRecord(employeeId: e.key, date: _dateStr, status: e.value))
        .toList();
    // upsertAttendance uses UNIQUE(employee_id, date) ON CONFLICT REPLACE,
    // so re-saving the same day never creates duplicate rows.
    await DBHelper.instance.saveAllAttendance(records);
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attendance saved for ${DateFormat('dd MMM yyyy').format(_selectedDate)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Attendance')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _saveAll,
        icon: _saving
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save),
        label: const Text('Save All'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: _pickDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const Spacer(),
                  const Text('Tap to change', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _employees.isEmpty
                    ? const Center(child: Text('No active employees. Add employees first.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90, top: 6),
                        itemCount: _employees.length,
                        itemBuilder: (context, i) {
                          final e = _employees[i];
                          final status = _statuses[e.id] ?? AppConstants.present;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text('${e.employeeCode} • ${e.shift} shift',
                                      style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: AppConstants.attendanceStatuses.map((s) {
                                      final selected = status == s;
                                      return ChoiceChip(
                                        label: Text(s),
                                        selected: selected,
                                        selectedColor: statusColor(s).withValues(alpha: 0.85),
                                        labelStyle: TextStyle(
                                          color: selected ? Colors.white : Colors.black87,
                                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        onSelected: (_) => setState(() => _statuses[e.id!] = s),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
