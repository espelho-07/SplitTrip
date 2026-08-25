import 'package:flutter/material.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/guest_user.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_preview.dart';

class JoinTripViewModel extends ChangeNotifier {
  final TripRepository tripRepo;

  String _code = '';
  TripPreview? _preview;
  bool _isLoadingPreview = false;
  bool _isJoining = false;
  String? _errorMessage;

  JoinTripViewModel({required this.tripRepo});

  String get code => _code;
  TripPreview? get preview => _preview;
  bool get isLoadingPreview => _isLoadingPreview;
  bool get isJoining => _isJoining;
  String? get errorMessage => _errorMessage;

  void setCode(String val) {
    _code = val.toUpperCase().trim();
    _errorMessage = null;
    _preview = null;
    notifyListeners();
  }

  void clearPreview() {
    _preview = null;
    notifyListeners();
  }

  String _formatError(dynamic e) {
    final str = e.toString();
    if (str.startsWith('Exception: ')) return str.substring(11);
    if (str.contains('message: ')) {
      final match = RegExp(r'message:\s*([^,\)]+)').firstMatch(str);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    return str;
  }

  Future<TripPreview?> fetchPreview([String? directCode]) async {
    final targetCode = (directCode ?? _code).trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (targetCode.length < 4) {
      _errorMessage = 'Please enter a valid trip code';
      notifyListeners();
      return null;
    }

    _isLoadingPreview = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final p = await tripRepo.getTripPreview(targetCode);
      if (p == null) {
        _errorMessage = 'No trip found for code "$targetCode". Please check and try again.';
      }
      _preview = p;
      return p;
    } catch (e) {
      _errorMessage = _formatError(e);
      return null;
    } finally {
      _isLoadingPreview = false;
      notifyListeners();
    }
  }

  Future<Trip?> joinTrip(GuestUser user, [String? directCode]) async {
    if (_isJoining) return null;

    final targetCode = (directCode ?? _code).trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (targetCode.isEmpty) {
      _errorMessage = 'Please enter a 6-character trip code';
      notifyListeners();
      return null;
    }

    _isJoining = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final trip = await tripRepo.joinTrip(
        inviteCodeOrId: targetCode,
        user: user,
      );

      return trip;
    } catch (e) {
      _errorMessage = _formatError(e);
      return null;
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }
}
