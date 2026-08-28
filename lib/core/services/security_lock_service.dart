import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../data/services/local_storage_service.dart';

class SecurityLockService extends ChangeNotifier {
  static const String _pinHashKey = 'kith_vault_pin_hash';
  static const String _appLockKey = 'kith_app_lock_enabled';
  static const String _biometricsKey = 'kith_biometrics_enabled';

  final LocalStorageService _storage;
  final LocalAuthentication _localAuth;

  bool _isLocked = false;
  bool _isAppLockEnabled = false;
  bool _isBiometricsEnabled = false;
  bool _isBiometricsSupported = false;

  SecurityLockService(this._storage, {LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication() {
    _init();
  }

  bool get isLocked => _isLocked;
  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isBiometricsSupported => _isBiometricsSupported;
  bool get hasPin => (_storage.getString(_pinHashKey)?.isNotEmpty ?? false);

  Future<void> _init() async {
    _isAppLockEnabled = _storage.getBool(_appLockKey) ?? false;
    _isBiometricsEnabled = _storage.getBool(_biometricsKey) ?? false;
    
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      _isBiometricsSupported = isSupported && canCheck;
    } catch (_) {
      _isBiometricsSupported = false;
    }

    if (_isAppLockEnabled && hasPin) {
      _isLocked = true;
    }
    notifyListeners();
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode('kith_salt_$pin')).toString();
  }

  Future<bool> setPin(String newPin) async {
    if (newPin.length != 4) return false;
    final hash = _hashPin(newPin);
    await _storage.setString(_pinHashKey, hash);
    await setAppLockEnabled(true);
    notifyListeners();
    return true;
  }

  bool verifyPin(String enteredPin) {
    if (enteredPin.length != 4) return false;
    final storedHash = _storage.getString(_pinHashKey);
    if (storedHash == null) return false;
    final isMatch = storedHash == _hashPin(enteredPin);
    if (isMatch) {
      _isLocked = false;
      notifyListeners();
    }
    return isMatch;
  }

  Future<bool> authenticateWithBiometrics({String reason = 'Authenticate to access Kith Vault'}) async {
    if (!_isBiometricsSupported) return false;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
      );
      if (authenticated) {
        _isLocked = false;
        notifyListeners();
      }
      return authenticated;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    _isAppLockEnabled = enabled;
    await _storage.setBool(_appLockKey, enabled);
    if (!enabled) {
      _isLocked = false;
    }
    notifyListeners();
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    _isBiometricsEnabled = enabled;
    await _storage.setBool(_biometricsKey, enabled);
    notifyListeners();
  }

  Future<bool> resetPinWithRecoveryKey({
    required String enteredKey,
    required String actualRecoveryKey,
    required String newPin,
  }) async {
    final cleanEntered = enteredKey.trim().toUpperCase().replaceAll(' ', '-');
    final cleanActual = actualRecoveryKey.trim().toUpperCase().replaceAll(' ', '-');
    
    if (cleanEntered == cleanActual && newPin.length == 4) {
      await setPin(newPin);
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> removePin() async {
    await _storage.remove(_pinHashKey);
    await setAppLockEnabled(false);
    await setBiometricsEnabled(false);
    _isLocked = false;
    notifyListeners();
  }

  void lock() {
    if (_isAppLockEnabled && hasPin) {
      _isLocked = true;
      notifyListeners();
    }
  }

  void unlock() {
    _isLocked = false;
    notifyListeners();
  }
}
