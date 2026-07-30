import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// What actually happened when we asked the OS to run a biometric check.
/// Distinguishing these (instead of collapsing everything into a plain
/// bool) is what lets the UI show the RIGHT message instead of a
/// generic "not recognized" for every possible failure — which is what
/// was making a temporary Android lockout, or a busy sensor, look
/// exactly like a genuinely wrong fingerprint.
enum BiometricOutcome {
  success,
  failed, // a real non-matching fingerprint/face
  lockedOutTemporary, // too many failed attempts, Android is cooling down
  lockedOutPermanent, // too many failed attempts, device credential needed
  notAvailable, // no biometrics enrolled / hardware unavailable right now
  busy, // another biometric prompt was already in progress
  error, // anything else (unexpected platform error)
}

/// Thin wrapper around the local_auth plugin. Centralizing this here
/// means the rest of the app just calls simple methods and never has
/// to think about platform channels or exception codes directly.
class BiometricHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True while a biometric prompt is currently on screen. Checked
  /// before starting a new one so the app can NEVER show two prompts
  /// at once — Android's BiometricPrompt does not support that, and
  /// trying cancels one of them, which is the #1 cause of a biometric
  /// check failing even though the fingerprint itself was read fine.
  static bool isAuthenticating = false;

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

  /// Shows the native fingerprint/face prompt and reports back exactly
  /// what happened. Never throws — every failure path is translated
  /// into a [BiometricOutcome] the UI can react to appropriately.
  static Future<BiometricOutcome> authenticateDetailed({required String reason}) async {
    if (isAuthenticating) {
      // A prompt is already open somewhere else in the app — do NOT
      // start a second one on top of it.
      return BiometricOutcome.busy;
    }

    isAuthenticating = true;
    try {
      final success = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return success ? BiometricOutcome.success : BiometricOutcome.failed;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'LockedOut':
          return BiometricOutcome.lockedOutTemporary;
        case 'PermanentlyLockedOut':
          return BiometricOutcome.lockedOutPermanent;
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          return BiometricOutcome.notAvailable;
        default:
          return BiometricOutcome.error;
      }
    } catch (_) {
      return BiometricOutcome.error;
    } finally {
      isAuthenticating = false;
    }
  }

  /// Convenience wrapper for callers that only care about yes/no
  /// (e.g. confirming before turning biometric unlock ON).
  static Future<bool> authenticate({required String reason}) async {
    final outcome = await authenticateDetailed(reason: reason);
    return outcome == BiometricOutcome.success;
  }

  /// A short, accurate, user-facing message for every possible outcome.
  static String messageFor(BiometricOutcome outcome) {
    switch (outcome) {
      case BiometricOutcome.success:
        return '';
      case BiometricOutcome.failed:
        return 'Fingerprint/Face not recognized. Try again, or use your password.';
      case BiometricOutcome.lockedOutTemporary:
        return 'Too many attempts. Please wait a moment and try again, or use your password.';
      case BiometricOutcome.lockedOutPermanent:
        return 'Too many failed attempts. Unlock your phone with its PIN/pattern first, then try again — or use your password now.';
      case BiometricOutcome.notAvailable:
        return 'Fingerprint/Face is not available right now. Please use your password.';
      case BiometricOutcome.busy:
        return 'Please try again.';
      case BiometricOutcome.error:
        return 'Something went wrong. Please try again, or use your password.';
    }
  }
}
