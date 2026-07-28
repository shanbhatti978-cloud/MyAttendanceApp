import 'package:local_auth/local_auth.dart';

/// Thin wrapper around the local_auth plugin. Centralizing this here
/// means the rest of the app just calls simple methods and never has
/// to think about platform channels, exceptions, or availability checks.
class BiometricHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True if this device has fingerprint/face hardware AND the user has
  /// actually enrolled at least one fingerprint/face in Android Settings.
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Shows the native fingerprint/face prompt. Returns true only on a
  /// genuine successful match — any error, cancellation, or "no
  /// biometrics enrolled" case safely returns false instead of throwing,
  /// so callers can always fall back to password login.
  static Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
