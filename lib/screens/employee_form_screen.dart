import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/db_helper.dart';
import '../models/employee.dart';
import '../utils/constants.dart';

/// Handles BOTH "Add Employee" and "Edit Employee" — pass an existing
/// [employee] to edit, or leave it null to create a new one.
class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;
  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _shiftCtrl;
  late TextEditingController _remarksCtrl;
  late String _restDay;
  late String _status;
  late DateTime _joiningDate;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _codeCtrl = TextEditingController(text: e?.employeeCode ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _designationCtrl = TextEditingController(text: e?.designation ?? '');
    _shiftCtrl = TextEditingController(text: e?.shift ?? AppConstants.shifts.first);
    _remarksCtrl = TextEditingController(text: e?.remarks ?? '');
    _restDay = e?.weeklyRestDay ?? 'Sunday';
    _status = e?.status ?? 'Active';
    _joiningDate = e != null ? DateTime.parse(e.joiningDate) : DateTime.now();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _designationCtrl.dispose();
    _shiftCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final emp = Employee(
      id: widget.employee?.id,
      employeeCode: _codeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      designation: _designationCtrl.text.trim(),
      shift: _shiftCtrl.text.trim(),
      weeklyRestDay: _restDay,
      joiningDate: DateFormat('yyyy-MM-dd').format(_joiningDate),
      status: _status,
      remarks: _remarksCtrl.text.trim(),
    );

    try {
      if (_isEdit) {
        await DBHelper.instance.updateEmployee(emp);
      } else {
        await DBHelper.instance.insertEmployee(emp);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      // Most likely a UNIQUE constraint failure on employee_code
      setState(() => _error = 'Could not save. Employee ID "${_codeCtrl.text}" may already be in use.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Employee' : 'Add Employee')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: 'Employee ID *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Employee Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _designationCtrl,
                decoration: const InputDecoration(labelText: 'Designation *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shiftCtrl,
                decoration: InputDecoration(
                  labelText: 'Shift *',
                  helperText: 'Pick a suggestion or type a custom shift name',
                  prefixIcon: const Icon(Icons.schedule),
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: 'Suggestions',
                    onSelected: (v) => setState(() => _shiftCtrl.text = v),
                    itemBuilder: (_) => AppConstants.shifts
                        .map((s) => PopupMenuItem(value: s, child: Text(s)))
                        .toList(),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _restDay,
                decoration: const InputDecoration(labelText: 'Weekly Rest Day *'),
                items: AppConstants.weekdays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => _restDay = v!),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Joining Date *'),
                  child: Text(DateFormat('dd MMM yyyy').format(_joiningDate)),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status *'),
                items: AppConstants.employeeStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remarks (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isEdit ? 'UPDATE EMPLOYEE' : 'SAVE EMPLOYEE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
