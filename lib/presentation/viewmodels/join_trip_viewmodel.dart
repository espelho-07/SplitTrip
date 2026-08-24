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

  Future<TripPreview?> fetchPreview() async {
    if (_code.length < 6) {
      _errorMessage = 'Please enter a valid 6-digit trip code';
      notifyListeners();
      return null;
    }

    _isLoadingPreview = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final p = await tripRepo.getTripPreview(_code);
      if (p == null) {
        _errorMessage = 'No trip found for code "$_code". Please check and try again.';
      }
      _preview = p;
      return p;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoadingPreview = false;
      notifyListeners();
    }
  }

  Future<Trip?> joinTrip(GuestUser user) async {
    if (_code.isEmpty) {
      _errorMessage = 'Please enter a 6-digit trip code';
      notifyListeners();
      return null;
    }

    _isJoining = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final trip = await tripRepo.joinTrip(
        inviteCodeOrId: _code,
        user: user,
      );

      if (trip == null) {
        _errorMessage = 'No trip found with this code. Please check and try again.';
      }

      return trip;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }
}
