import 'package:flutter/material.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/guest_user.dart';
import '../../domain/models/trip.dart';

class CreateTripViewModel extends ChangeNotifier {
  final TripRepository tripRepo;

  String _name = '';
  String? _description;
  String _emoji = '✈️';
  int _coverGradientIndex = 0;
  String _currencyCode = 'INR';
  String _tripMode = 'split_only'; // 'split_only' or 'split_and_journey'
  final List<String> _friendNames = [];
  bool _isCreating = false;
  String? _errorMessage;

  CreateTripViewModel({required this.tripRepo});

  String get name => _name;
  String? get description => _description;
  String get emoji => _emoji;
  int get coverGradientIndex => _coverGradientIndex;
  String get currencyCode => _currencyCode;
  String get tripMode => _tripMode;
  List<String> get friendNames => List.unmodifiable(_friendNames);
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;

  bool get isValid => _name.trim().isNotEmpty;

  void setName(String val) {
    _name = val;
    notifyListeners();
  }

  void setDescription(String? val) {
    _description = val;
    notifyListeners();
  }

  void setEmoji(String val) {
    _emoji = val;
    notifyListeners();
  }

  void setCoverGradientIndex(int val) {
    _coverGradientIndex = val;
    notifyListeners();
  }

  void setCurrencyCode(String val) {
    _currencyCode = val;
    notifyListeners();
  }

  void setTripMode(String mode) {
    _tripMode = mode;
    notifyListeners();
  }

  void addFriendName(String name) {
    if (name.trim().isNotEmpty && !_friendNames.contains(name.trim())) {
      _friendNames.add(name.trim());
      notifyListeners();
    }
  }

  void removeFriendName(String name) {
    _friendNames.remove(name);
    notifyListeners();
  }

  void resetForm() {
    _name = '';
    _description = null;
    _emoji = '✈️';
    _coverGradientIndex = 0;
    _currencyCode = 'INR';
    _tripMode = 'split_only';
    _friendNames.clear();
    _isCreating = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<Trip?> createTrip(GuestUser creator) async {
    if (!isValid || _isCreating) return null;
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final trip = await tripRepo.createTrip(
        name: _name,
        description: _description,
        emoji: _emoji,
        coverGradientIndex: _coverGradientIndex,
        currencyCode: _currencyCode,
        creator: creator,
        initialFriendNames: _friendNames,
        tripMode: _tripMode,
      );
      resetForm();
      return trip;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }
}
