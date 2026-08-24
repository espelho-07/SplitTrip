import 'package:flutter/material.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/guest_user.dart';
import '../../domain/models/trip.dart';

class JoinTripViewModel extends ChangeNotifier {
  final TripRepository tripRepo;

  String _code = '';
  bool _isJoining = false;
  String? _errorMessage;

  JoinTripViewModel({required this.tripRepo});

  String get code => _code;
  bool get isJoining => _isJoining;
  String? get errorMessage => _errorMessage;

  void setCode(String val) {
    _code = val.toUpperCase().trim();
    _errorMessage = null;
    notifyListeners();
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
