import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../utils/biometric_helper.dart';
import '../utils/constants.dart';
import '../utils/page_transitions.dart';
import '../utils/session.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

/// Shown instead of the password login screen once the user has turned
/// on biometric unlock from Security Settings. Automatically triggers
/// the fingerprint/face prompt, and always offers a visible way back to
/// password login in case biometrics fail or aren't available right now
/// (per the "keep password login as backup" requirement).
class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({super.key});

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Try immediately on open so the common case (unlock and go) needs
    // no extra tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    // Re-entrancy guard: never let two prompts stack (also protected
    // globally by BiometricHelper.isAuthenticating, this is the local
    // screen-level mirror of that same rule).
    if (_checking) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    final available = await BiometricHelper.isAvailable();
    if (!available) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Biometric unlock is not available right now. Please use your password instead.';
      });
      return;
    }

    final outcome = await BiometricHelper.authenticateDetailed(
      reason: 'Unlock ${AppConstants.appShortName}',
    );

    if (!mounted) return;

    if (outcome == BiometricOutcome.success) {
      final account = await DBHelper.instance.getBiometricAccount();
      if (account == null) {
        setState(() {
          _checking = false;
          _error = 'No account linked to biometric unlock. Please log in with your password.';
        });
        return;
      }
      if (!mounted) return;
      context.read<Session>().login(account['username']!, account['role']!);
      Navigator.pushReplacement(context, fadeSlideRoute(const DashboardScreen()));
    } else {
      setState(() {
        _checking = false;
        _error = BiometricHelper.messageFor(outcome);
      });
      // A permanent lockout can't be cleared by tapping "Try Again" — the
      // device needs its PIN/pattern first — so send the user straight
      // to password login instead of leaving them stuck on a dead end.
      if (outcome == BiometricOutcome.lockedOutPermanent) {
        _usePasswordInstead();
      }
    }
  }

  void _usePasswordInstead() {
    Navigator.pushReplacement(context, fadeSlideRoute(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.fingerprint, size: 64, color: Colors.white),
                ),
                const SizedBox(height: 28),
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 10),
                Text(
                  _checking ? 'Waiting for fingerprint / face...' : 'Tap below to unlock',
                  style: const TextStyle(color: Colors.black54),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                  ),
                ],
                const SizedBox(height: 32),
                if (!_checking)
                  ElevatedButton.icon(
                    onPressed: _tryUnlock,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('TRY AGAIN'),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _usePasswordInstead,
                  child: const Text('Use Password Instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
