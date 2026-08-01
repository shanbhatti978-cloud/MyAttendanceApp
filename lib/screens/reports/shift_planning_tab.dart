import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/db_helper.dart';
import '../../utils/constants.dart';
import '../../utils/data_bus.dart';
import '../../utils/page_transitions.dart';
import '../../utils/responsive.dart';
import '../../utils/session.dart';
import '../leave_entry_screen.dart';

/// Tells a supervisor, before or during a shift, exactly how much
/// manpower is actually available — overall and broken down by
/// designation — so production planning doesn't have to wait until
/// the shift has already started to find out someone is short-staffed.
class ShiftPlanningTab extends StatefulWidget {
  const ShiftPlanningTab({super.key});

  @override
  State<ShiftPlanningTab> createState() => _ShiftPlanningTabState();
}

class _ShiftPlanningTabState extends State<ShiftPlanningTab> {
  DateTime _date = DateTime.now();
  List<String> _shifts = [];
  List<String> _designations = [];
  String _shiftFilter = 'All';
  String _designationFilter = 'All';
  String _employeeQuery = '';
  Map<String, dynamic>? _report;
  Map<String, Map<String, int>> _manpowerRules = {}; // designation -> {min, max}
  bool _loading = true;

  String get _dbDate => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void initState() {
    super.initState();
    // Real-time refresh: any leave/attendance/employee change anywhere
    // in the app calls this, so the planning numbers here are always
    // current without the user having to pull-to-refresh.
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
    final shifts = await DBHelper.instance.getDistinctShifts();
    final designations = await DBHelper.instance.getDistinctDesignations();
    final rules = await DBHelper.instance.getManpowerRules();
    setState(() {
      _shifts = shifts;
      _designations = designations;
      _manpowerRules = {
        for (final r in rules)
          r['designation'] as String: {'min': r['min_required'] as int, 'max': r['max_required'] as int}
      };
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await DBHelper.instance.getShiftPlanningReport(
      _dbDate,
      shiftFilter: _shiftFilter,
      designationFilter: _designationFilter,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageLeave = context.watch<Session>().permissions.canManageLeave;
    if (_loading && _report == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final report = _report!;
    final byDesignation = (report['byDesignation'] as List).cast<Map<String, dynamic>>();
    final employees = (report['employees'] as List).cast<Map<String, dynamic>>();
    final filteredEmployees = _employeeQuery.trim().isEmpty
        ? employees
        : employees.where((row) {
            final emp = row['employee'];
            final q = _employeeQuery.toLowerCase();
            return emp.name.toLowerCase().contains(q) || emp.employeeCode.toLowerCase().contains(q);
          }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _buildFilters(canManageLeave),
          const SizedBox(height: 14),
          _buildShiftDashboard(report),
          const SizedBox(height: 18),
          if (byDesignation.length > 1) ...[
            _sectionTitle('Designation-wise Manpower'),
            const SizedBox(height: 8),
            _buildDesignationChart(byDesignation),
            const SizedBox(height: 10),
          ],
          _sectionTitle('Designation Breakdown'),
          const SizedBox(height: 8),
          ...byDesignation.map(_buildDesignationCard),
          const SizedBox(height: 18),
          _sectionTitle('Employees (${filteredEmployees.length})'),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Filter by employee name or code',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _employeeQuery = v),
          ),
          const SizedBox(height: 8),
          ...filteredEmployees.map((row) {
            final emp = row['employee'];
            final status = row['status'] as String;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                dense: true,
                title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${emp.employeeCode} • ${emp.designation}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor(status), fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary));

  Widget _buildFilters(bool canManageLeave) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today)),
                child: Text(DateFormat('EEEE, dd MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _shiftFilter,
                    decoration: const InputDecoration(labelText: 'Shift'),
                    items: ['All', ..._shifts].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      setState(() => _shiftFilter = v!);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _designationFilter,
                    decoration: const InputDecoration(labelText: 'Designation'),
                    items:
                        ['All', ..._designations].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      setState(() => _designationFilter = v!);
                      _load();
                    },
                  ),
                ),
              ],
            ),
            if (canManageLeave) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, fadeSlideRoute(const LeaveEntryScreen()));
                    _load();
                  },
                  icon: const Icon(Icons.event_busy),
                  label: const Text('Enter Leave for an Employee'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShiftDashboard(Map<String, dynamic> report) {
    final cards = [
      _MiniStat('Total', report['total'], AppColors.primary, Icons.groups),
      _MiniStat('Weekly Rest', report['weeklyRest'], AppColors.rest, Icons.hotel),
      _MiniStat('Leave', report['leave'], AppColors.warning, Icons.beach_access),
      _MiniStat('Present', report['present'], AppColors.success, Icons.check_circle),
      _MiniStat('Absent', report['absent'], AppColors.danger, Icons.cancel),
      _MiniStat('Expected Present', report['expectedPresent'], AppColors.accent, Icons.trending_up),
      _MiniStat('Available Manpower', report['availableManpower'], AppColors.primaryLight, Icons.engineering),
    ];
    return GridView.count(
      crossAxisCount: Responsive.statGridColumns(context),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: cards.map((c) => _miniStatCard(c)).toList(),
    );
  }

  Widget _miniStatCard(_MiniStat c) {
    return Container(
      decoration: BoxDecoration(
        color: c.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(c.icon, color: c.color, size: 20),
          Text('${c.value}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.color)),
          Text(c.label,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildDesignationChart(List<Map<String, dynamic>> byDesignation) {
    final maxVal = byDesignation
        .map((d) => d['total'] as int)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();
    return SizedBox(
      height: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: BarChart(
            BarChartData(
              maxY: maxVal <= 0 ? 10 : maxVal * 1.2,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= byDesignation.length) return const SizedBox.shrink();
                      final name = byDesignation[i]['designation'] as String;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(name.length > 8 ? '${name.substring(0, 8)}…' : name,
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(byDesignation.length, (i) {
                final d = byDesignation[i];
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: (d['total'] as int).toDouble(),
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 10,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  BarChartRodData(
                    toY: (d['expectedPresent'] as int).toDouble(),
                    color: AppColors.success,
                    width: 10,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesignationCard(Map<String, dynamic> d) {
    final designation = d['designation'] as String;
    final rule = _manpowerRules[designation];
    final available = d['availableManpower'] as int;
    final isShort = rule != null && available < rule['min']!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(designation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (rule != null)
                  Text('Req: ${rule['min']}-${rule['max']}',
                      style: const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
            if (isShort) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: AppColors.danger, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Shortage: $available available, ${rule['min']} required '
                        '(${rule['min']! - available} short)',
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _tag('Total', d['total'], AppColors.primary),
                _tag('Leave', d['leave'], AppColors.warning),
                _tag('Weekly Rest', d['weeklyRest'], AppColors.rest),
                _tag('Expected Present', d['expectedPresent'], AppColors.success),
                if ((d['absent'] as int) > 0) _tag('Absent', d['absent'], AppColors.danger),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $value', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _MiniStat {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  _MiniStat(this.label, this.value, this.color, this.icon);
}
