import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';

/// Categories for group travel & everyday social expenses.
enum ExpenseCategory {
  transport,
  food,
  stay,
  drinks,
  activities,
  shopping,
  groceries,
  general;

  String localizedName(AppLocalizations l10n) {
    switch (this) {
      case ExpenseCategory.transport:
        return l10n.catTransport;
      case ExpenseCategory.food:
      case ExpenseCategory.drinks:
        return l10n.catFood;
      case ExpenseCategory.stay:
        return l10n.catStay;
      case ExpenseCategory.activities:
        return l10n.catEntertainment;
      case ExpenseCategory.shopping:
      case ExpenseCategory.groceries:
        return l10n.catShopping;
      case ExpenseCategory.general:
        return l10n.catOther;
    }
  }

  String get displayName {
    switch (this) {
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.food:
        return 'Food & Dining';
      case ExpenseCategory.stay:
        return 'Stay & Hotel';
      case ExpenseCategory.drinks:
        return 'Drinks & Cafe';
      case ExpenseCategory.activities:
        return 'Activities';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.groceries:
        return 'Groceries';
      case ExpenseCategory.general:
        return 'General';
    }
  }

  String get emoji {
    switch (this) {
      case ExpenseCategory.transport:
        return '🚆';
      case ExpenseCategory.food:
        return '🍔';
      case ExpenseCategory.stay:
        return '🏨';
      case ExpenseCategory.drinks:
        return '☕';
      case ExpenseCategory.activities:
        return '🏄';
      case ExpenseCategory.shopping:
        return '🛍️';
      case ExpenseCategory.groceries:
        return '🛒';
      case ExpenseCategory.general:
        return '💳';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.transport:
        return Icons.directions_car_outlined;
      case ExpenseCategory.food:
        return Icons.restaurant_outlined;
      case ExpenseCategory.stay:
        return Icons.hotel_outlined;
      case ExpenseCategory.drinks:
        return Icons.local_bar_outlined;
      case ExpenseCategory.activities:
        return Icons.sports_tennis_outlined;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_outlined;
      case ExpenseCategory.groceries:
        return Icons.shopping_cart_outlined;
      case ExpenseCategory.general:
        return Icons.receipt_long_outlined;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.transport:
        return const Color(0xFF3B82F6); // Blue
      case ExpenseCategory.food:
        return const Color(0xFFF97316); // Orange
      case ExpenseCategory.stay:
        return const Color(0xFF8B5CF6); // Purple
      case ExpenseCategory.drinks:
        return const Color(0xFFEC4899); // Pink
      case ExpenseCategory.activities:
        return const Color(0xFF10B981); // Emerald
      case ExpenseCategory.shopping:
        return const Color(0xFFEAB308); // Amber
      case ExpenseCategory.groceries:
        return const Color(0xFF06B6D4); // Cyan
      case ExpenseCategory.general:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// Intelligently predicts an appropriate ExpenseCategory based on title keywords.
  static ExpenseCategory? predictFromTitle(String? title) {
    if (title == null || title.trim().isEmpty) return null;
    final lower = title.toLowerCase();

    // Drinks / Cafe keywords (Checked first so cafe/chai/coffee takes priority over snacks)
    if (_matches(lower, [
      'drink', 'drinks', 'beer', 'wine', 'bar', 'cocktail', 'cocktails',
      'pub', 'starbucks', 'boba', 'juice', 'daru', 'alcohol', 'liquor',
      'coffee', 'cafe', 'chai', 'tea', 'tapri', 'brewery', 'mocktail'
    ])) {
      return ExpenseCategory.drinks;
    }

    // Food keywords
    if (_matches(lower, [
      'dinner', 'lunch', 'breakfast', 'brunch', 'burger', 'pizza', 'biryani',
      'swiggy', 'zomato', "domino's", 'dominos', 'mcdonald', 'kfc', 'subway',
      'restaurant', 'dhaba', 'food', 'khana', 'snack', 'thali', 'roti',
      'paneer', 'chicken', 'dosa', 'samosa', 'chaat', 'dessert', 'bakery',
      'sweet', 'sweets', 'ice cream', 'icecream'
    ])) {
      return ExpenseCategory.food;
    }

    // Transport / Fuel keywords
    if (_matches(lower, [
      'petrol', 'fuel', 'diesel', 'cng', 'uber', 'ola', 'cab', 'taxi',
      'flight', 'airfare', 'indigo', 'air india', 'spicejet', 'vistara',
      'train', 'irctc', 'railway', 'metro', 'bus', 'toll', 'fastag',
      'parking', 'auto', 'rickshaw', 'rapido', 'ferry', 'boat ride',
      'scooter rent', 'car rent', 'car rental', 'bike rental'
    ])) {
      return ExpenseCategory.transport;
    }

    // Stay / Hotel keywords
    if (_matches(lower, [
      'hotel', 'resort', 'airbnb', 'stay', 'room', 'hostel', 'lodge',
      'villa', 'oyo', 'taj', 'marriott', 'hyatt', 'radisson', 'booking.com',
      'homestay', 'guesthouse', 'cottage', 'tent', 'campsite'
    ])) {
      return ExpenseCategory.stay;
    }

    // Activities / Entertainment keywords
    if (_matches(lower, [
      'ticket', 'tickets', 'entry', 'movie', 'cinema', 'museum', 'theme park',
      'water park', 'boating', 'scuba', 'diving', 'trekking', 'safari',
      'bowling', 'game', 'arcade', 'pass', 'concert', 'show', 'amusement',
      'rafting', 'bungee', 'kayaking', 'sightseeing'
    ])) {
      return ExpenseCategory.activities;
    }

    // Groceries keywords
    if (_matches(lower, [
      'groceries', 'grocery', 'supermarket', 'blinkit', 'zepto', 'instamart',
      'dmart', 'bigbasket', 'milk', 'vegetables', 'veggies', 'fruits',
      'water bottle', 'water cans', 'ration', 'eggs', 'bread', 'kirana'
    ])) {
      return ExpenseCategory.groceries;
    }

    // Shopping keywords
    if (_matches(lower, [
      'shopping', 'clothes', 'zara', 'h&m', 'mall', 'shoes', 'souvenir',
      'souvenirs', 'gift', 'gifts', 'amazon', 'flipkart', 'myntra',
      'uniqlo', 'dress', 'shirt', 'sunglasses', 't-shirt'
    ])) {
      return ExpenseCategory.shopping;
    }

    return null;
  }

  static bool _matches(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ExpenseCategory.general,
    );
  }

  static ExpenseCategory fromName(String? value) {
    if (value == null || value.isEmpty) return ExpenseCategory.general;
    return fromString(value);
  }
}
