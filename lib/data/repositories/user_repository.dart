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

  Future<GuestUser> signInWithNirniq({
    required String email,
    required String displayName,
    String? photoUrl,
    String? nirniqId,
    String? googleId,
    String? supabaseUserId,
  }) {
    return authService.signInWithNirniq(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      nirniqId: nirniqId,
      googleId: googleId,
      supabaseUserId: supabaseUserId,
    );
  }

  Future<GuestUser> signInWithGoogle({
    required String email,
    required String displayName,
    String? photoUrl,
    String? googleId,
    String? supabaseUserId,
  }) {
    return authService.signInWithGoogle(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      googleId: googleId,
      supabaseUserId: supabaseUserId,
    );
  }

  Future<GuestUser> signInAsReviewer({String email = 'review.nirniq@gmail.com'}) {
    return authService.loginWithReviewerEmail(email: email);
  }

  /// Attempts to restore a session from an active Nirniq / Supabase JWT on app startup.
  Future<GuestUser?> restoreNirniqSession() {
    return authService.restoreNirniqSession();
  }

  /// Attempts to restore a session from an active Supabase JWT on app startup.
  Future<GuestUser?> restoreSupabaseSession() {
    return authService.restoreSupabaseSession();
  }

  Future<void> syncSession([GuestUser? user]) {
    return authService.syncLocalGuestSession(user);
  }

  /// Checks for reinstall scenario and restores guest session from Keystore/Supabase.
  /// Returns the restored user, or null if this is a genuine first install.
  Future<GuestUser?> restoreGuestIfNeeded() {
    return authService.restoreGuestIfNeeded();
  }

  Stream<String> get accountDeletedEvents => authService.accountDeletedEvents;

  Future<bool> validateActiveAccountStatus() {
    return authService.validateActiveAccountStatus();
  }

  Future<void> logout() {
    return authService.logout();
  }

  Future<void> deleteAccount() {
    return authService.deleteAccount();
  }

  /// Comprehensively purges all user data across local persistent databases
  /// (SQLite, SharedPreferences, SecureStorage) and remote cloud/backend servers.
  Future<void> purgeAllUserData() {
    return authService.deleteAccount();
  }

  Future<GuestUser?> updatePaymentInfo(String upiId, {String? upiQr}) {
    return authService.updatePaymentInfo(upiId, upiQr: upiQr);
  }

  Future<GuestUser> updateUserProfile({
    required String displayName,
    String? phoneNumber,
    String? avatarUrl,
    String? email,
    String? upiId,
    String? bio,
  }) {
    return authService.updateUserProfile(
      displayName: displayName,
      phoneNumber: phoneNumber,
      avatarUrl: avatarUrl,
      email: email,
      upiId: upiId,
      bio: bio,
    );
  }

  Future<String?> getUserUpi(String userId) {
    return authService.getUserUpi(userId);
  }

  String? getAppExperienceMode() {
    return authService.storage.getSavedAppExperienceMode();
  }

  Future<bool> saveAppExperienceMode(String mode) {
    return authService.storage.saveAppExperienceMode(mode);
  }

  String? getPrimaryAppMode() {
    return authService.storage.getSavedPrimaryAppMode();
  }

  Future<bool> savePrimaryAppMode(String mode) {
    return authService.storage.savePrimaryAppMode(mode);
  }

  bool hasCompletedOnboarding() {
    return authService.storage.hasCompletedOnboarding();
  }

  Future<bool> setOnboardingCompleted(bool completed) {
    return authService.storage.setOnboardingCompleted(completed);
  }

  DateTime? getLastSyncTime() {
    return authService.storage.getLastSyncTime();
  }

  Future<bool> saveLastSyncTime(DateTime time) {
    return authService.storage.saveLastSyncTime(time);
  }

  bool isAutoSyncEnabled() {
    return authService.storage.isAutoSyncEnabled();
  }

  Future<bool> setAutoSyncEnabled(bool enabled) {
    return authService.storage.setAutoSyncEnabled(enabled);
  }

  Future<String> rotateRecoveryKey() {
    return authService.rotateRecoveryKey();
  }

}
