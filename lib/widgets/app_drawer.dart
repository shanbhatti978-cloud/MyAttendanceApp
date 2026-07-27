import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../utils/session.dart';
import '../screens/dashboard_screen.dart';
import '../screens/employee_list_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/backup_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/login_screen.dart';

/// Shared side-drawer navigation so every screen has quick access to
/// the rest of the app without retyping this menu each time.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.factory, color: Colors.white, size: 36),
                const SizedBox(height: 8),
                const Text(AppConstants.appShortName,
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('${session.username ?? ''} (${session.role ?? ''})',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => _go(context, const DashboardScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Employee Master'),
            onTap: () => _go(context, const EmployeeListScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Daily Attendance'),
            onTap: () => _go(context, const AttendanceScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Reports'),
            onTap: () => _go(context, const ReportsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup / Restore'),
            onTap: () => _go(context, const BackupScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => _go(context, const SettingsScreen()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Logout', style: TextStyle(color: AppColors.danger)),
            onTap: () {
              session.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
