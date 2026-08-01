import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../utils/constants.dart';
import '../utils/data_bus.dart';
import '../utils/page_transitions.dart';
import '../utils/responsive.dart';
import '../utils/session.dart';
import '../utils/time_ago.dart';
import '../widgets/app_drawer.dart';
import '../widgets/stat_card.dart';
import 'attendance_screen.dart';
import 'leave_entry_screen.dart';
import 'notifications_screen.dart';
import 'reports/reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int totalEmployees = 0;
  int unreadNotifications = 0;
  Map<String, int> todaySummary = {};
  List<int> weekTrend = []; // Present count for each of the last 7 days
  List<double> monthlyWeeklyPresent = []; // Present sum per week-of-month bucket
  List<int> leaveTrend = []; // Leave count for each of the last 14 days
  List<Map<String, dynamic>> recentActivities = [];
  bool loading = true;
  final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    DataBus.instance.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final now = DateTime.now();

    final total = await DBHelper.instance.countEmployees();
    final summary = await DBHelper.instance.getTodaySummary(today);
    final activities = await DBHelper.instance.getRecentActivities(limit: 8);
    final unread = await DBHelper.instance.countUnreadNotifications();

    // 7-day trend (single query for the whole range — not one query per day)
    final last7Start = now.subtract(const Duration(days: 6));
    final last7Data = await DBHelper.instance.getTrendData(last7Start, now);
    final trend = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      trend.add(last7Data[date]?[AppConstants.present] ?? 0);
    }

    // Monthly chart: current month, bucketed into ~weekly chunks so it
    // stays readable regardless of how many days have passed.
    final monthStart = DateTime(now.year, now.month, 1);
    final monthData = await DBHelper.instance.getTrendData(monthStart, now);
    final daysSoFar = now.difference(monthStart).inDays + 1;
    final bucketCount = (daysSoFar / 7).ceil().clamp(1, 5);
    final buckets = List<double>.filled(bucketCount, 0);
    for (int d = 0; d < daysSoFar; d++) {
      final date = DateFormat('yyyy-MM-dd').format(monthStart.add(Duration(days: d)));
      final present = monthData[date]?[AppConstants.present] ?? 0;
      final bucketIndex = (d / 7).floor().clamp(0, bucketCount - 1);
      buckets[bucketIndex] += present;
    }

    // Leave trend: last 14 days (single query for the whole range)
    final last14Start = now.subtract(const Duration(days: 13));
    final last14Data = await DBHelper.instance.getTrendData(last14Start, now);
    final leaves = <int>[];
    for (int i = 13; i >= 0; i--) {
      final date = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      leaves.add(last14Data[date]?[AppConstants.leave] ?? 0);
    }

    if (!mounted) return;
    setState(() {
      totalEmployees = total;
      unreadNotifications = unread;
      todaySummary = summary;
      weekTrend = trend;
      monthlyWeeklyPresent = buckets;
      leaveTrend = leaves;
      recentActivities = activities;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.statGridColumns(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.push(context, fadeSlideRoute(const NotificationsScreen()));
                  _load();
                },
              ),
              if (unreadNotifications > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
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
                            offset: const Offset(0, -18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GridView.count(
                                  crossAxisCount: columns,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: columns == 2 ? 1.05 : 1.15,
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
                                const SizedBox(height: 16),
                                _quickActions(context),
                                const SizedBox(height: 20),
                                _weekTrendCard(),
                                const SizedBox(height: 16),
                                _monthlyChartCard(),
                                const SizedBox(height: 16),
                                _leaveTrendCard(),
                                const SizedBox(height: 16),
                                _recentActivitiesCard(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _quickActions(BuildContext context) {
    final canManageLeave = context.read<Session>().permissions.canManageLeave;

    final actions = <Widget>[
      _quickActionButton(
        context,
        icon: Icons.bolt,
        label: 'Shift Planning',
        color: AppColors.accent,
        onTap: () => Navigator.push(context, fadeSlideRoute(const ReportsScreen())),
      ),
      if (canManageLeave)
        _quickActionButton(
          context,
          icon: Icons.event_busy,
          label: 'Leave Entry',
          color: AppColors.warning,
          onTap: () => Navigator.push(context, fadeSlideRoute(const LeaveEntryScreen())),
        ),
      _quickActionButton(
        context,
        icon: Icons.checklist,
        label: 'Attendance',
        color: AppColors.primary,
        onTap: () => Navigator.push(context, fadeSlideRoute(const AttendanceScreen())),
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }

  Widget _quickActionButton(BuildContext context,
      {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chartCard({required String title, required Widget chart}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 14),
            SizedBox(height: 150, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _weekTrendCard() {
    final maxVal = weekTrend.isEmpty ? 1.0 : weekTrend.reduce((a, b) => a > b ? a : b).toDouble();
    return _chartCard(
      title: '7-Day Attendance Trend',
      chart: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxVal <= 0 ? 10 : maxVal * 1.2,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= 7) return const SizedBox.shrink();
                  final date = DateTime.now().subtract(Duration(days: 6 - i));
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat('E').format(date), style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (int i = 0; i < weekTrend.length; i++) FlSpot(i.toDouble(), weekTrend[i].toDouble())],
              isCurved: true,
              color: AppColors.success,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: AppColors.success.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthlyChartCard() {
    final maxVal = monthlyWeeklyPresent.isEmpty
        ? 1.0
        : monthlyWeeklyPresent.reduce((a, b) => a > b ? a : b);
    return _chartCard(
      title: 'Monthly Attendance Chart (${DateFormat('MMMM').format(DateTime.now())})',
      chart: BarChart(
        BarChartData(
          maxY: maxVal <= 0 ? 10 : maxVal * 1.2,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= monthlyWeeklyPresent.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('W${i + 1}', style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(monthlyWeeklyPresent.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: monthlyWeeklyPresent[i],
                color: AppColors.primary,
                width: 22,
                borderRadius: BorderRadius.circular(4),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _leaveTrendCard() {
    final maxVal = leaveTrend.isEmpty ? 1.0 : leaveTrend.reduce((a, b) => a > b ? a : b).toDouble();
    return _chartCard(
      title: 'Leave Trend (Last 14 Days)',
      chart: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxVal <= 0 ? 5 : maxVal * 1.3,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= 14 || i % 2 != 0) return const SizedBox.shrink();
                  final date = DateTime.now().subtract(Duration(days: 13 - i));
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat('d/M').format(date), style: const TextStyle(fontSize: 9)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (int i = 0; i < leaveTrend.length; i++) FlSpot(i.toDouble(), leaveTrend[i].toDouble())],
              isCurved: true,
              color: AppColors.warning,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.warning.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _activityIcon(String iconType) {
    switch (iconType) {
      case 'employee':
        return Icons.person;
      case 'attendance':
        return Icons.checklist;
      case 'leave':
        return Icons.beach_access;
      case 'backup':
        return Icons.backup;
      default:
        return Icons.info_outline;
    }
  }

  Widget _recentActivitiesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            if (recentActivities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No activity yet.', style: TextStyle(color: Colors.black45)),
              )
            else
              ...recentActivities.map((a) {
                final time = DateTime.parse(a['timestamp'] as String);
                final iconType = a['icon_type'] as String;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_activityIcon(iconType), size: 14, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(a['description'] as String, style: const TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Text(timeAgo(time), style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
