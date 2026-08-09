import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../../data/settings_repo.dart';
import 'backup_prefs.dart';

class GoogleSignInFailure implements Exception {
  final String message;
  GoogleSignInFailure(this.message);
  @override
  String toString() => message;
}

final googleSignInProvider = Provider<GoogleSignIn>((_) {
  return GoogleSignIn(scopes: const [
    'email',
    drive.DriveApi.driveAppdataScope,
  ]);
});

class GoogleAuthNotifier extends Notifier<GoogleSignInAccount?> {
  @override
  GoogleSignInAccount? build() {
    // Offline-first: never call signInSilently() unless the user has opted in.
    final enabled = ref.watch(
        backupPrefsProvider.select((p) => p.enabled));
    if (enabled) {
      // Fire and forget; updates state when (if) it succeeds.
      // ignore: discarded_futures
      _silent();
    }
    return null;
  }

  Future<void> _silent() async {
    try {
      final gs = ref.read(googleSignInProvider);
      final acc = await gs.signInSilently();
      if (acc != null) {
        state = acc;
        // ignore: discarded_futures
        ref.read(displayNameProvider.notifier).setFromGoogle(acc.displayName);
      }
    } catch (_) {
      // ignore — no network or revoked
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final acc = await ref.read(googleSignInProvider).signIn();
      state = acc;
      if (acc != null) {
        // ignore: discarded_futures
        ref.read(displayNameProvider.notifier).setFromGoogle(acc.displayName);
      }
      return acc;
    } on PlatformException catch (e) {
      debugPrint('[google_auth] PlatformException ${e.code}: ${e.message}');
      throw GoogleSignInFailure(_translateError(e));
    } catch (e) {
      debugPrint('[google_auth] Unknown error: $e');
      throw GoogleSignInFailure(e.toString());
    }
  }

  String _translateError(PlatformException e) {
    final code = e.code;
    final msg = e.message ?? '';
    // Android Google Play Services status codes
    if (msg.contains('10:') || msg.contains('DEVELOPER_ERROR') || code == '10') {
      // Deliberately doesn't say "debug" — a release build signed with a
      // regenerated (or missing) keystore hits this too, and naming the wrong
      // keystore sends you to the wrong fingerprint.
      return 'Sign-in not configured (error 10). The signing key of this '
          "build isn't registered in Google Cloud Console — add its SHA-1 "
          'and package name to the matching OAuth client. See SETUP.md § 4.';
    }
    if (msg.contains('12500')) {
      return 'Google Play Services missing or outdated on this device.';
    }
    if (msg.contains('7:') || msg.contains('NETWORK_ERROR')) {
      return 'Network error — check your internet connection.';
    }
    if (code == 'sign_in_canceled' || msg.contains('canceled')) {
      return 'Sign-in cancelled.';
    }
    return 'Sign-in failed: $code ${e.message ?? ''}';
  }

  Future<void> signOut() async {
    try {
      await ref.read(googleSignInProvider).signOut();
    } finally {
      state = null;
    }
  }
}

final googleAuthProvider =
    NotifierProvider<GoogleAuthNotifier, GoogleSignInAccount?>(
        GoogleAuthNotifier.new);
