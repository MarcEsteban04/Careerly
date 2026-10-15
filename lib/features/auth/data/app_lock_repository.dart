import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UnlockResult { success, canceled, failed, lockedOut, unavailable }

/// Biometric app lock: whether it's on, and running the system prompt.
/// The Supabase session stays signed in; the lock only gates the UI.
class AppLockRepository {
  AppLockRepository([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  static const _enabledKey = 'app_lock.enabled';
  static const _offeredKey = 'app_lock.offered';

  /// Whether the device has biometrics set up that we can use.
  Future<bool> canUseBiometrics() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      // Unsupported platform (e.g. web) or plugin error.
      return false;
    }
  }

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  Future<void> setEnabled(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_enabledKey, enabled);

  /// Whether we've already asked the user to turn the lock on.
  Future<bool> wasOffered() async =>
      (await SharedPreferences.getInstance()).getBool(_offeredKey) ?? false;

  Future<void> markOffered() async =>
      (await SharedPreferences.getInstance()).setBool(_offeredKey, true);

  Future<UnlockResult> authenticate({String reason = 'Unlock Careerly'}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return ok ? UnlockResult.success : UnlockResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback =>
          UnlockResult.canceled,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          UnlockResult.lockedOut,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          UnlockResult.unavailable,
        _ => UnlockResult.failed,
      };
    } catch (_) {
      return UnlockResult.unavailable;
    }
  }
}
