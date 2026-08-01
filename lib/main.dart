import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils/constants.dart';
import 'utils/session.dart';
import 'utils/theme_controller.dart';
import 'widgets/app_lifecycle_lock.dart';
import 'screens/auth_gate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://klavirzgxdgislqgaleb.supabase.co',
    anonKey: 'YOUR_ANON_KEY_HERE',
  );

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

            home: const AuthGateScreen(),

            builder: (context, child) =>
                AppLifecycleLock(child: child!),
          );
        },
      ),
    );
  }
}
