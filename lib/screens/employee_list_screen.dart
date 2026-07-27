import 'package:flutter/material.dart';

import '../db/db_helper.dart';
import '../models/employee.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';
import 'employee_form_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> _employees = [];
  String _query = '';
  String _statusFilter = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DBHelper.instance.getEmployees(query: _query, statusFilter: _statusFilter);
    setState(() {
      _employees = list;
      _loading = false;
    });
  }

  Future<void> _confirmDelete(Employee e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Delete "${e.name}" (${e.employeeCode})? This also removes their attendance history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DBHelper.instance.deleteEmployee(e.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Master')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Employee'),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeFormScreen()));
          _load();
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name, code, or designation',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) {
                    _query = v;
                    _load();
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Status: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _statusFilter,
                      items: ['All', ...AppConstants.employeeStatuses]
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        _statusFilter = v!;
                        _load();
                      },
                    ),
                    const Spacer(),
                    Text('${_employees.length} employee(s)', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _employees.isEmpty
                    ? const Center(child: Text('No employees found. Tap "Add Employee" to begin.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: _employees.length,
                          itemBuilder: (context, i) {
                            final e = _employees[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${e.employeeCode} • ${e.designation} • ${e.shift} shift\nRest day: ${e.weeklyRestDay}'),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      await Navigator.push(context,
                                          MaterialPageRoute(builder: (_) => EmployeeFormScreen(employee: e)));
                                      _load();
                                    } else if (v == 'delete') {
                                      _confirmDelete(e);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
