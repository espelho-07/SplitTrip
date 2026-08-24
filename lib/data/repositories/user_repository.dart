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
  }) {
    return authService.linkToAccount(
      email: email,
      provider: provider,
    );
  }
}
