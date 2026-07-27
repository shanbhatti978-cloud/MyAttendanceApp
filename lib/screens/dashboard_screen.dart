import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/db_helper.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';
import '../widgets/stat_card.dart';
import 'attendance_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int totalEmployees = 0;
  Map<String, int> todaySummary = {};
  bool loading = true;
  final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final total = await DBHelper.instance.countEmployees();
    final summary = await DBHelper.instance.getTodaySummary(today);
    setState(() {
      totalEmployees = total;
      todaySummary = summary;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: const AppDrawer(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today: ${DateFormat('EEEE, dd MMM yyyy').format(DateTime.now())}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.25,
                      children: [
                        StatCard(
                          label: 'Total Employees',
                          value: totalEmployees,
                          color: AppColors.primary,
                          icon: Icons.people,
                        ),
                        StatCard(
                          label: 'Present Today',
                          value: todaySummary[AppConstants.present] ?? 0,
                          color: AppColors.success,
                          icon: Icons.check_circle,
                        ),
                        StatCard(
                          label: 'Absent Today',
                          value: todaySummary[AppConstants.absent] ?? 0,
                          color: AppColors.danger,
                          icon: Icons.cancel,
                        ),
                        StatCard(
                          label: 'Leave Today',
                          value: todaySummary[AppConstants.leave] ?? 0,
                          color: AppColors.warning,
                          icon: Icons.beach_access,
                        ),
                        StatCard(
                          label: 'Weekly Rest Today',
                          value: todaySummary[AppConstants.weeklyRest] ?? 0,
                          color: AppColors.rest,
                          icon: Icons.hotel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.checklist),
                        label: const Text('Go to Today\'s Attendance'),
                        onPressed: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AttendanceScreen()));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
