import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../models/employee.dart';
import '../utils/constants.dart';
import '../utils/session.dart';
import '../widgets/app_drawer.dart';

/// Submits a leave request that starts in "Pending" status — unlike the
/// existing Advance Leave Entry (which marks attendance immediately),
/// this goes through Admin/Supervisor approval first via the Leave
/// Requests screen, and only updates attendance once approved.
class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _searchCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  List<Employee> _results = [];
  Employee? _selected;
  String _leaveType = AppConstants.leaveTypes.first;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final results = await DBHelper.instance.getEmployees(query: query, statusFilter: 'Active');
    if (mounted) setState(() => _results = results);
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  Future<void> _submit() async {
    if (_selected == null) {
      setState(() => _message = 'Please select an employee first.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });

    final session = context.read<Session>();
    await DBHelper.instance.createLeaveRequest(
      employeeId: _selected!.id!,
      leaveType: _leaveType,
      fromDate: DateFormat('yyyy-MM-dd').format(_fromDate),
      toDate: DateFormat('yyyy-MM-dd').format(_toDate),
      reason: _reasonCtrl.text.trim(),
      appliedBy: session.username ?? '',
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = 'Leave request submitted for ${_selected!.name}. Awaiting approval.';
      _selected = null;
      _reasonCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply Leave')),
      drawer: const AppDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selected == null) ...[
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
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_message!, style: const TextStyle(color: AppColors.success)),
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
                          onTap: () => setState(() => _selected = e),
                        );
                      },
                    ),
            ),
          ] else
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
                        subtitle: Text('${_selected!.employeeCode} • ${_selected!.designation}'),
                        trailing: TextButton(
                          onPressed: () => setState(() => _selected = null),
                          child: const Text('Change'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _leaveType,
                      decoration: const InputDecoration(labelText: 'Leave Type', prefixIcon: Icon(Icons.event_note)),
                      items: AppConstants.leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _leaveType = v!),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickFromDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'From'),
                              child: Text(DateFormat('dd MMM yyyy').format(_fromDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _pickToDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'To'),
                              child: Text(DateFormat('dd MMM yyyy').format(_toDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _reasonCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Reason', prefixIcon: Icon(Icons.notes)),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      Text(_message!, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      label: Text(_saving ? 'Submitting...' : 'SUBMIT LEAVE REQUEST'),
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
