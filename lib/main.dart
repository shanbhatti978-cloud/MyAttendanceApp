import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'utils/constants.dart';
import 'utils/session.dart';
import 'screens/auth_gate_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RAMSApp());
}

class RAMSApp extends StatelessWidget {
  const RAMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Session(),
      child: MaterialApp(
        title: AppConstants.appShortName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        // The app is 100% offline: no HTTP client, no server, no localhost.
        // Everything runs and is stored directly on the device via SQLite.
        home: const AuthGateScreen(),
      ),
    );
  }
}
