import '../../domain/models/guest_user.dart';
import '../services/auth_service.dart';

class UserRepository {
  final AuthService authService;

  UserRepository({required this.authService});

  GuestUser? getCurrentUser() {
    return authService.getCurrentUser();
  }

  Future<GuestUser> createGuestUser({
    required String displayName,
    String? avatarUrl,
  }) {
    return authService.createGuestUser(
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }

  Future<GuestUser?> recoverUser(String recoveryKey) {
    return authService.recoverUser(recoveryKey);
  }

  Future<GuestUser> linkAccount({
    required String email,
    required String provider,
    String? displayName,
  }) {
    return authService.linkToAccount(
      email: email,
      provider: provider,
      displayName: displayName,
    );
  }

  Future<GuestUser> signInWithGoogle({
    required String email,
    required String displayName,
    String? photoUrl,
    String? googleId,
  }) {
    return authService.signInWithGoogle(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      googleId: googleId,
    );
  }

  Future<void> logout() {
    return authService.logout();
  }

  String? getAppExperienceMode() {
    return authService.storage.getSavedAppExperienceMode();
  }

  Future<bool> saveAppExperienceMode(String mode) {
    return authService.storage.saveAppExperienceMode(mode);
  }
}
