import 'package:flutter/material.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/enums/app_experience_mode.dart';
import '../../domain/enums/kith_app_mode.dart';
import '../../domain/models/guest_user.dart';

enum AuthState {
  uninitialized,
  authenticated,
  signedOut,
  authenticating,
  syncing,
}

class AuthViewModel extends ChangeNotifier {
  final UserRepository userRepo;
  GuestUser? _currentUser;
  AppExperienceMode _appExperienceMode = AppExperienceMode.all;
  KithAppMode _primaryAppMode = KithAppMode.trip;
  AuthState _authState = AuthState.uninitialized;
  bool _isLoading = false;
  String? _errorMessage;

  AuthViewModel({required this.userRepo});

  GuestUser? get currentUser => _currentUser;
  AppExperienceMode get appExperienceMode => _appExperienceMode;
  KithAppMode get primaryAppMode => _primaryAppMode;
  AuthState get authState => _authState;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _authState != AuthState.uninitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initSession() async {
    _isLoading = true;
    _authState = AuthState.uninitialized;
    // Yield to the event loop so that any pending widget builds complete
    // before we call notifyListeners().
    await Future<void>.value();

    try {
      // restoreGuestIfNeeded() checks SharedPreferences first (fast path),
      // then falls back to Keystore → Supabase to recover after reinstall.
      _currentUser = await userRepo.restoreGuestIfNeeded();
      _appExperienceMode = AppExperienceMode.fromKey(userRepo.getAppExperienceMode());
      _primaryAppMode = KithAppMode.fromKey(userRepo.getPrimaryAppMode());
      _authState = _currentUser != null ? AuthState.authenticated : AuthState.signedOut;
      if (_currentUser != null) {
        userRepo.syncSession(_currentUser);
      }
    } catch (e) {
      _errorMessage = e.toString();
      _authState = AuthState.signedOut;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAppExperienceMode(AppExperienceMode mode) async {
    _appExperienceMode = mode;
    await userRepo.saveAppExperienceMode(mode.key);
    notifyListeners();
  }

  Future<void> setPrimaryAppMode(KithAppMode mode) async {
    _primaryAppMode = mode;
    await userRepo.savePrimaryAppMode(mode.key);
    notifyListeners();
  }

  Future<GuestUser> createGuestSession(String displayName, [AppExperienceMode? mode]) async {
    _isLoading = true;
    _errorMessage = null;
    if (mode != null) {
      _appExperienceMode = mode;
      await userRepo.saveAppExperienceMode(mode.key);
    }
    notifyListeners();

    try {
      final user = await userRepo.createGuestUser(displayName: displayName);
      _currentUser = user;
      _authState = AuthState.authenticated;
      userRepo.syncSession(user);
      return user;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> rotateRecoveryKey() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newKey = await userRepo.rotateRecoveryKey();
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(recoveryKey: newKey);
      }
      return newKey;
    } catch (e) {
      _errorMessage = 'Could not rotate recovery key: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GuestUser?> recoverSession(String recoveryKey) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await userRepo.recoverUser(recoveryKey);
      _currentUser = user;
      if (user != null) {
        _authState = AuthState.authenticated;
        userRepo.syncSession(user);
      }
      return user;
    } catch (e) {
      _errorMessage = 'Invalid recovery key';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GuestUser?> linkAccount({
    required String email,
    String? displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await userRepo.linkAccount(
        email: email,
        provider: 'email',
        displayName: displayName,
      );
      _currentUser = user;
      _authState = AuthState.authenticated;
      return user;
    } catch (e) {
      _errorMessage = 'Could not link account: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GuestUser?> signInWithNirniq({
    required String email,
    required String displayName,
    String? photoUrl,
    String? nirniqId,
    String? googleId,
    String? supabaseUserId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _authState = AuthState.authenticating;
    notifyListeners();

    try {
      final user = await userRepo.signInWithNirniq(
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        nirniqId: nirniqId,
        googleId: googleId,
        supabaseUserId: supabaseUserId,
      );
      _currentUser = user;
      _authState = AuthState.authenticated;
      return user;
    } catch (e) {
      _errorMessage = 'Could not sign in with Nirniq Account: $e';
      _authState = AuthState.signedOut;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GuestUser?> signInWithGoogle({
    required String email,
    required String displayName,
    String? photoUrl,
    String? googleId,
    String? supabaseUserId,
  }) {
    return signInWithNirniq(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      googleId: googleId,
      supabaseUserId: supabaseUserId,
    );
  }

  /// Fast one-tap sign in for Google Play Store Review team (review.nirniq@gmail.com)
  Future<GuestUser?> signInAsReviewer({String email = 'review.nirniq@gmail.com'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await userRepo.signInAsReviewer(email: email);
      _currentUser = user;
      _authState = AuthState.authenticated;
      return user;
    } catch (e) {
      _errorMessage = 'Could not sign in as reviewer: $e';
      _authState = AuthState.signedOut;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Attempts to silently restore a Supabase session on app startup.
  /// Does NOT show loading state — this is a background restoration.
  Future<void> tryRestoreSupabaseSession() async {
    try {
      final user = await userRepo.restoreSupabaseSession();
      if (user != null && _currentUser == null) {
        _currentUser = user;
        _authState = AuthState.authenticated;
        notifyListeners();
      }
    } catch (_) {
      // Non-blocking: session restoration failure is not fatal
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await userRepo.logout();
      _currentUser = null;
      _authState = AuthState.signedOut;
    } catch (e) {
      _errorMessage = 'Could not logout: $e';
      _currentUser = null;
      _authState = AuthState.signedOut;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Permanently deletes the account and all associated cloud data.
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await userRepo.deleteAccount();
      _currentUser = null;
      _authState = AuthState.signedOut;
      return true;
    } catch (e) {
      _errorMessage = 'Could not delete account: $e';
      _currentUser = null;
      _authState = AuthState.signedOut;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GuestUser?> updatePaymentInfo(String upiId, {String? upiQr}) async {
    try {
      final updated = await userRepo.updatePaymentInfo(upiId, upiQr: upiQr);
      if (updated != null) {
        _currentUser = updated;
        notifyListeners();
      }
      return updated;
    } catch (_) {
      return null;
    }
  }

  Future<GuestUser?> updateUserProfile({
    required String displayName,
    String? phoneNumber,
    String? avatarUrl,
    String? email,
    String? upiId,
    String? bio,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await userRepo.updateUserProfile(
        displayName: displayName,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
        email: email,
        upiId: upiId,
        bio: bio,
      );
      _currentUser = updated;
      return updated;
    } catch (e) {
      _errorMessage = 'Could not update profile: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get hasCompletedOnboarding => userRepo.hasCompletedOnboarding();

  Future<void> setOnboardingCompleted(bool completed) async {
    await userRepo.setOnboardingCompleted(completed);
    notifyListeners();
  }

  DateTime? get lastSyncTime => userRepo.getLastSyncTime();

  Future<void> recordSyncCompleted() async {
    final now = DateTime.now();
    await userRepo.saveLastSyncTime(now);
    notifyListeners();
  }

  bool get isAutoSyncEnabled => userRepo.isAutoSyncEnabled();

  Future<void> setAutoSyncEnabled(bool enabled) async {
    await userRepo.setAutoSyncEnabled(enabled);
    notifyListeners();
  }
}
