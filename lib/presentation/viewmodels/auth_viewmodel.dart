import 'package:flutter/material.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/guest_user.dart';

class AuthViewModel extends ChangeNotifier {
  final UserRepository userRepo;
  GuestUser? _currentUser;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthViewModel({required this.userRepo});

  GuestUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initSession() async {
    _isLoading = true;
    // Yield to the event loop so that any pending widget builds complete
    // before we call notifyListeners(). This prevents the
    // "setState() called during build" assertion when initSession() is
    // invoked synchronously from a widget's initState().
    await Future<void>.value();

    try {
      _currentUser = userRepo.getCurrentUser();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GuestUser> createGuestSession(String displayName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await userRepo.createGuestUser(displayName: displayName);
      _currentUser = user;
      return user;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
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
      return user;
    } catch (e) {
      _errorMessage = 'Invalid recovery key';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
