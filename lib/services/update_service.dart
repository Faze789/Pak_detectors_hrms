import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Prompts the user to install a newer build when one is available on the
/// Play track they have access to (internal/closed testing or production).
///
/// Requirements for this to actually surface a prompt:
///   • The app was installed from Google Play (not sideloaded/debug).
///   • A release with a HIGHER versionCode is live on the user's track.
///
/// No-ops on web and non-Android platforms.
class UpdateService {
  /// Checks for an available update and, if found, launches an immediate
  /// (blocking, full-screen) update flow. Swallows all errors so a failed
  /// check never blocks app startup.
  static Future<void> checkForUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Immediate = forces the tester onto the latest build before they can
        // continue. Swap for the flexible flow below if you'd rather let them
        // keep using the app while it downloads:
        //   await InAppUpdate.startFlexibleUpdate();
        //   await InAppUpdate.completeFlexibleUpdate();
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      debugPrint('[UpdateService] update check failed: $e');
    }
  }
}
