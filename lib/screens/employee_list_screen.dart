import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../models/employee.dart';
import '../utils/constants.dart';
import '../utils/page_transitions.dart';
import '../utils/responsive.dart';
import '../utils/session.dart';
import '../widgets/app_drawer.dart';
import 'employee_form_screen.dart';

enum _SortBy { name, code, designation }

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> _employees = [];
  String _query = '';
  String _statusFilter = 'All';
  _SortBy _sortBy = _SortBy.name;
  bool _sortAscending = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DBHelper.instance.getEmployees(query: _query, statusFilter: _statusFilter);
    _sortList(list);
    setState(() {
      _employees = list;
      _loading = false;
    });
  }

  void _sortList(List<Employee> list) {
    int compare(Employee a, Employee b) {
      switch (_sortBy) {
        case _SortBy.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortBy.code:
          return a.employeeCode.toLowerCase().compareTo(b.employeeCode.toLowerCase());
        case _SortBy.designation:
          return a.designation.toLowerCase().compareTo(b.designation.toLowerCase());
      }
    }

    list.sort(_sortAscending ? compare : (a, b) => compare(b, a));
  }

  void _applySort() {
    setState(() => _sortList(_employees));
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

  String _sortLabel(_SortBy s) {
    switch (s) {
      case _SortBy.name:
        return 'Name';
      case _SortBy.code:
        return 'Employee ID';
      case _SortBy.designation:
        return 'Designation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.listGridColumns(context);
    final canManage = context.watch<Session>().permissions.canManageEmployees;
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Master')),
      drawer: const AppDrawer(),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add Employee'),
              onPressed: () async {
                await Navigator.push(context, fadeSlideRoute(const EmployeeFormScreen()));
                _load();
              },
            )
          : null,
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
                    Tooltip(
                      message: 'Sort by ${_sortLabel(_sortBy)} (${_sortAscending ? "A-Z" : "Z-A"})',
                      child: PopupMenuButton<_SortBy>(
                        icon: const Icon(Icons.sort),
                        onSelected: (v) {
                          if (v == _sortBy) {
                            _sortAscending = !_sortAscending;
                          } else {
                            _sortBy = v;
                            _sortAscending = true;
                          }
                          _applySort();
                        },
                        itemBuilder: (_) => _SortBy.values
                            .map((s) => PopupMenuItem(
                                  value: s,
                                  child: Row(
                                    children: [
                                      if (s == _sortBy)
                                        Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16)
                                      else
                                        const SizedBox(width: 16),
                                      const SizedBox(width: 8),
                                      Text(_sortLabel(s)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${_employees.length}', style: const TextStyle(color: Colors.black54)),
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
                        child: columns == 1
                            ? ListView.builder(
                                padding: const EdgeInsets.only(bottom: 90),
                                itemCount: _employees.length,
                                itemBuilder: (context, i) => _employeeCard(_employees[i], i, canManage),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.only(bottom: 90, left: 8, right: 8),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 128,
                                  crossAxisSpacing: 4,
                                ),
                                itemCount: _employees.length,
                                itemBuilder: (context, i) => _employeeCard(_employees[i], i, canManage),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _employeeCard(Employee e, int index, bool canManage) {
    return TweenAnimationBuilder<double>(
      // Subtle fade+rise entry animation, staggered slightly per row so
      // the list feels alive without being distracting.
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index.clamp(0, 10) * 30)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 8), child: child),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${e.employeeCode} • ${e.designation} • ${e.shift} shift\nRest day: ${e.weeklyRestDay}',
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          // View-only roles (Supervisor/Viewer) never see edit/delete —
          // employee master management is Admin-only.
          trailing: canManage
              ? PopupMenuButton<String>(
                  tooltip: 'More actions',
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await Navigator.push(context, fadeSlideRoute(EmployeeFormScreen(employee: e)));
                      _load();
                    } else if (v == 'delete') {
                      _confirmDelete(e);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}
