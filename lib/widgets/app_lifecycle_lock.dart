import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../utils/biometric_helper.dart';
import '../utils/biometric_reauth_overlay.dart';
import '../utils/session.dart';

/// Wraps the entire app (via MaterialApp's `builder`) so that resuming
/// from the background — not just a cold start — re-triggers biometric
/// unlock when it's enabled. This is what makes the fingerprint prompt
/// behave consistently "every time the app is opened", matching how
/// banking/payment apps behave, rather than only protecting the very
/// first launch.
class AppLifecycleLock extends StatefulWidget {
  final Widget child;
  const AppLifecycleLock({super.key, required this.child});

  @override
  State<AppLifecycleLock> createState() => _AppLifecycleLockState();
}

class _AppLifecycleLockState extends State<AppLifecycleLock> with WidgetsBindingObserver {
  bool _locked = false;
  bool _wasPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // IMPORTANT: only `paused` means the app was genuinely sent to the
    // background. `inactive` is a much more transient state that also
    // fires for things like the fingerprint sensor's own system prompt,
    // incoming calls, or the notification shade — treating it the same
    // as `paused` was causing a SECOND biometric prompt to be triggered
    // on top of the first one the moment the fingerprint sheet opened,
    // which is what produced the endless "Try Again" loop.
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    } else if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      _maybeLock();
    }
  }

  Future<void> _maybeLock() async {
    // Never stack a second prompt on top of one that's already showing.
    if (BiometricHelper.isAuthenticating || _locked) return;

    final session = context.read<Session>();
    if (!session.isLoggedIn) return; // nothing to protect on the login/unlock screens themselves

    final enabled = await DBHelper.instance.isBiometricEnabled();
    if (!mounted || !enabled) return;

    setState(() => _locked = true);
  }

  void _unlock() {
    setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: BiometricReauthOverlay(onUnlocked: _unlock),
          ),
      ],
    );
  }
}
