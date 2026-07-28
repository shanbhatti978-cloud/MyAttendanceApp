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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient welcome banner — gives the dashboard a more
                    // polished, "advanced" ERP feel at first glance.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Today\'s Overview',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Transform.translate(
                        // Pulls the stat grid slightly up so it overlaps the
                        // rounded banner edge for a layered, modern look.
                        offset: const Offset(0, -18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              // A fixed childAspectRatio previously let long
                              // labels ("Total Employees") overflow past the
                              // bottom of the card on narrower phones. Using
                              // a slightly taller ratio plus the StatCard's
                              // own 2-line/ellipsis handling guarantees the
                              // label always fits inside the box now.
                              childAspectRatio: 1.05,
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
                            const SizedBox(height: 10),
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
                  ],
                ),
              ),
            ),
    );
  }
}
