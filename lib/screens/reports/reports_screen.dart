import 'package:flutter/material.dart';

import '../../widgets/app_drawer.dart';
import 'monthly_report_tab.dart';
import 'daily_report_tab.dart';
import 'shift_report_tab.dart';

/// Shell screen that hosts all three report types behind a tab bar.
/// Each tab is a self-contained widget with its own filters, table, and
/// export buttons — this file just wires up the navigation around them.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.calendar_view_month), text: 'Monthly'),
              Tab(icon: Icon(Icons.today), text: 'Daily'),
              Tab(icon: Icon(Icons.groups), text: 'Shift-Wise'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            MonthlyReportTab(),
            DailyReportTab(),
            ShiftReportTab(),
          ],
        ),
      ),
    );
  }
}
