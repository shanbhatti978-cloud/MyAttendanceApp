import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'utils/constants.dart';
import 'utils/session.dart';
import 'utils/supabase_config.dart';
import 'utils/theme_controller.dart';
import 'widgets/app_lifecycle_lock.dart';
import 'widgets/connectivity_sync_listener.dart';
import 'screens/auth_gate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Best-effort: if there's no internet right now, this simply fails
  // silently and the app continues running fully offline as always —
  // cloud sync activates automatically later once connectivity returns.
  await SupabaseConfig.initialize();
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
            // The app remains local-first: every screen reads/writes
            // SQLite directly and works fully offline. Cloud sync (when
            // internet is available) is a background layer on top —
            // see ConnectivitySyncListener and lib/utils/sync_service.dart.
            home: const AuthGateScreen(),
            // AppLifecycleLock wraps every screen so that resuming from the
            // background — not just a cold start — re-triggers biometric
            // unlock when it's turned on, matching banking-app behavior.
            builder: (context, child) => ConnectivitySyncListener(
              child: AppLifecycleLock(child: child!),
            ),
          );
        },
      ),
    );
  }
}
