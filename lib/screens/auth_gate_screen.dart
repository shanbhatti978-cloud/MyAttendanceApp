import 'package:flutter/material.dart';

import '../db/db_helper.dart';
import '../utils/page_transitions.dart';
import 'biometric_unlock_screen.dart';
import 'login_screen.dart';

/// The very first screen the app shows. It doesn't render anything
/// itself — it just checks whether biometric unlock is turned on and
/// routes to the right screen, so app startup always lands somewhere
/// sensible even the very first time (before biometrics are set up).
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final biometricOn = await DBHelper.instance.isBiometricEnabled();
    final account = await DBHelper.instance.getBiometricAccount();

    if (!mounted) return;

    if (biometricOn && account != null) {
      Navigator.pushReplacement(context, fadeSlideRoute(const BiometricUnlockScreen()));
    } else {
      Navigator.pushReplacement(context, fadeSlideRoute(const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Brief, branded loading state while the decision above resolves —
    // this only takes a moment (one local DB read).
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
