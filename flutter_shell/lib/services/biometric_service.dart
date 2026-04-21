import 'package:local_auth/local_auth.dart';

import '../utils/logger.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } catch (e) {
      Log.w('[biometric] isAvailable failed: $e');
      return false;
    }
  }

  static Future<List<BiometricType>> enrolled() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      Log.w('[biometric] enrolled failed: $e');
      return const [];
    }
  }

  static Future<bool> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      return ok;
    } catch (e) {
      Log.w('[biometric] authenticate failed: $e');
      return false;
    }
  }
}
