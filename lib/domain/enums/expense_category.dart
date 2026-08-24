import 'package:flutter/material.dart';

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

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ExpenseCategory.general,
    );
  }
}
