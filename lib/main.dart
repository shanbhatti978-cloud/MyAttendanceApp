import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'utils/constants.dart';
import 'utils/session.dart';
import 'utils/theme_controller.dart';
import 'widgets/app_lifecycle_lock.dart';
import 'screens/auth_gate_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RAMSApp());
}

class RAMSApp extends StatelessWidget {
  const RAMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Session()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: AppConstants.appShortName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeController.mode,
            // The app is 100% offline: no HTTP client, no server, no localhost.
            // Everything runs and is stored directly on the device via SQLite.
            home: const AuthGateScreen(),
            // AppLifecycleLock wraps every screen so that resuming from the
            // background — not just a cold start — re-triggers biometric
            // unlock when it's turned on, matching banking-app behavior.
            builder: (context, child) => AppLifecycleLock(child: child!),
          );
        },
      ),
    );
  }
}
