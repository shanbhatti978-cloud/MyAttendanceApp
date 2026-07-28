import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../utils/biometric_helper.dart';
import '../utils/constants.dart';
import '../utils/session.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _loading = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await BiometricHelper.isAvailable();
    final enabled = await DBHelper.instance.isBiometricEnabled();
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool turnOn) async {
    setState(() => _message = null);
    final session = context.read<Session>();

    if (turnOn) {
      if (!_biometricAvailable) {
        setState(() => _message =
            'No fingerprint or face unlock is set up on this phone yet. Add one in your phone\'s Settings > Security first.');
        return;
      }
      final confirmed = await BiometricHelper.authenticate(
        reason: 'Confirm your fingerprint/face to enable biometric unlock',
      );
      if (!confirmed) {
        setState(() => _message = 'Could not confirm your fingerprint/face. Biometric unlock was not enabled.');
        return;
      }
      await DBHelper.instance.enableBiometric(session.username!, session.role!);
      setState(() {
        _biometricEnabled = true;
        _message = 'Biometric unlock enabled. Next time you open the app, use your fingerprint/face instead of typing a password.';
      });
    } else {
      await DBHelper.instance.disableBiometric();
      setState(() {
        _biometricEnabled = false;
        _message = 'Biometric unlock turned off. You will need your password to log in.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.fingerprint, color: AppColors.primary, size: 32),
                    title: const Text('Fingerprint / Face Unlock', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _biometricAvailable
                          ? 'Open the app instantly using your fingerprint or face, instead of typing a password every time.'
                          : 'Not available — set up a fingerprint or face in your phone\'s Settings > Security first.',
                    ),
                    value: _biometricEnabled,
                    onChanged: _biometricAvailable ? _toggle : null,
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: (_biometricEnabled ? AppColors.success : AppColors.warning).withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_message!),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your password always keeps working as a backup — if biometric '
                            'unlock ever fails or your phone doesn\'t recognize your fingerprint, '
                            'just tap "Use Password Instead" on the unlock screen.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
