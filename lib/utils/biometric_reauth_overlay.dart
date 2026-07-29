import 'package:flutter/material.dart';

import 'biometric_helper.dart';
import 'constants.dart';

/// A full-screen lock overlay (not a route/screen navigation) shown on
/// top of whatever the user was doing when the app resumes from the
/// background. This is the same pattern banking apps use: the app
/// isn't restarted, the user's place isn't lost — they just have to
/// unlock again before they can keep interacting with it.
class BiometricReauthOverlay extends StatefulWidget {
  final VoidCallback onUnlocked;
  const BiometricReauthOverlay({super.key, required this.onUnlocked});

  @override
  State<BiometricReauthOverlay> createState() => _BiometricReauthOverlayState();
}

class _BiometricReauthOverlayState extends State<BiometricReauthOverlay> {
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    final available = await BiometricHelper.isAvailable();
    if (!available) {
      // No biometric hardware/enrollment available right now — don't
      // trap the user behind a lock they can never clear; let them in.
      widget.onUnlocked();
      return;
    }

    final success = await BiometricHelper.authenticate(
      reason: 'Unlock ${AppConstants.appShortName}',
    );

    if (!mounted) return;

    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _checking = false;
        _error = 'Fingerprint/Face not recognized. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.fingerprint, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'App Locked',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  _checking ? 'Waiting for fingerprint / face...' : 'Unlock to continue',
                  style: const TextStyle(color: Colors.black54),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
                if (!_checking)
                  ElevatedButton.icon(
                    onPressed: _tryUnlock,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('TRY AGAIN'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
