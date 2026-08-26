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
        return '🍕';
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
        return Icons.train_outlined;
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
