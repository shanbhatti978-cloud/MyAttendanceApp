import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../models/employee.dart';
import '../utils/constants.dart';
import '../utils/session.dart';
import '../widgets/access_guard.dart';

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
  late TextEditingController _fatherNameCtrl;
  late TextEditingController _cnicCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _unitCtrl;
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
    _fatherNameCtrl = TextEditingController(text: e?.fatherName ?? '');
    _cnicCtrl = TextEditingController(text: e?.cnic ?? '');
    _mobileCtrl = TextEditingController(text: e?.mobileNumber ?? '');
    _designationCtrl = TextEditingController(text: e?.designation ?? '');
    _departmentCtrl = TextEditingController(text: e?.department ?? '');
    _unitCtrl = TextEditingController(text: e?.unitNumber ?? '');
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
    _fatherNameCtrl.dispose();
    _cnicCtrl.dispose();
    _mobileCtrl.dispose();
    _designationCtrl.dispose();
    _departmentCtrl.dispose();
    _unitCtrl.dispose();
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
      fatherName: _fatherNameCtrl.text.trim(),
      cnic: _cnicCtrl.text.trim(),
      mobileNumber: _mobileCtrl.text.trim(),
      designation: _designationCtrl.text.trim(),
      department: _departmentCtrl.text.trim(),
      unitNumber: _unitCtrl.text.trim(),
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
    final canManage = context.watch<Session>().permissions.canManageEmployees;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Employee' : 'Add Employee')),
      body: AccessGuard(
        allowed: canManage,
        message: 'Only Admin accounts can add or edit employee records.',
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                title: 'Basic Information',
                icon: Icons.badge_outlined,
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
                    controller: _fatherNameCtrl,
                    decoration: const InputDecoration(labelText: 'Father Name', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cnicCtrl,
                    decoration: const InputDecoration(labelText: 'CNIC (optional)', prefixIcon: Icon(Icons.badge)),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _mobileCtrl,
                    decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _designationCtrl,
                    decoration: const InputDecoration(labelText: 'Designation *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _departmentCtrl,
                    decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.apartment)),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit Number', prefixIcon: Icon(Icons.factory)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Work Details',
                icon: Icons.work_outline,
                children: [
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
                    decoration: const InputDecoration(labelText: 'Weekly Rest Day *', prefixIcon: Icon(Icons.hotel)),
                    items: AppConstants.weekdays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setState(() => _restDay = v!),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Joining Date *', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(DateFormat('dd MMM yyyy').format(_joiningDate)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Status & Remarks',
                icon: Icons.info_outline,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status *', prefixIcon: Icon(Icons.toggle_on_outlined)),
                    items: AppConstants.employeeStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _remarksCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Remarks (optional)', prefixIcon: Icon(Icons.notes)),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _error == null
                    ? const SizedBox(height: 0)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_isEdit ? 'UPDATE EMPLOYEE' : 'SAVE EMPLOYEE'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
