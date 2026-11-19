import 'package:flutter/foundation.dart';
import '../../data/services/local_storage_service.dart';
import '../../domain/models/currency_config.dart';

/// ViewModel managing user's default base currency preference.
/// Broadcasts changes reactively to all open screens and components.
class CurrencyViewModel extends ChangeNotifier {
  final LocalStorageService _storage;
  String _currencyCode;

  CurrencyViewModel({required LocalStorageService storage})
      : _storage = storage,
        _currencyCode = storage.getString('kith_default_currency') ?? 'INR';

  String get currencyCode => _currencyCode;
  AppCurrency get currency => AppCurrency.fromCode(_currencyCode);

  Future<void> setCurrency(String code) async {
    if (_currencyCode == code) return;
    _currencyCode = code;
    await _storage.setString('kith_default_currency', code);
    notifyListeners();
  }
}
