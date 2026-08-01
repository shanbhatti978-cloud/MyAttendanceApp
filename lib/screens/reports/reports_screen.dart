import 'package:flutter/material.dart';

import '../../widgets/app_drawer.dart';
import 'shift_planning_tab.dart';
import 'monthly_report_tab.dart';
import 'daily_report_tab.dart';
import 'shift_report_tab.dart';
import 'unit_report_tab.dart';
import 'department_report_tab.dart';
import 'employee_history_tab.dart';

/// Shell screen that hosts all seven report types behind a tab bar.
/// Each tab is a self-contained widget with its own filters, table, and
/// export buttons — this file just wires up the navigation around them.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.bolt), text: 'Shift Planning'),
              Tab(icon: Icon(Icons.calendar_view_month), text: 'Monthly'),
              Tab(icon: Icon(Icons.today), text: 'Daily'),
              Tab(icon: Icon(Icons.groups), text: 'Shift-Wise'),
              Tab(icon: Icon(Icons.factory), text: 'Unit-Wise'),
              Tab(icon: Icon(Icons.apartment), text: 'Department-Wise'),
              Tab(icon: Icon(Icons.person_search), text: 'Employee History'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            ShiftPlanningTab(),
            MonthlyReportTab(),
            DailyReportTab(),
            ShiftReportTab(),
            UnitReportTab(),
            DepartmentReportTab(),
            EmployeeHistoryTab(),
          ],
        ),
      ),
    );
  }
}
