import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Domain lifecycle of a Trip.
enum TripLifecycle {
  draft,
  active,
  completing,
  completed,
  settling,
  settled;

  String get displayName {
    switch (this) {
      case TripLifecycle.draft:
        return 'Draft';
      case TripLifecycle.active:
        return 'Active';
      case TripLifecycle.completing:
        return 'Finishing sync';
      case TripLifecycle.completed:
        return 'Completed';
      case TripLifecycle.settling:
        return 'Settling';
      case TripLifecycle.settled:
        return 'Settled';
    }
  }

  bool get isActive => this == TripLifecycle.active;
  bool get isCompleting => this == TripLifecycle.completing;
  bool get isCompleted => this == TripLifecycle.completed;
  bool get allowsExpenses => this == TripLifecycle.active;
  bool get isLocked => this == TripLifecycle.completed || this == TripLifecycle.settling || this == TripLifecycle.settled;
  bool get isSettlementActive => this == TripLifecycle.completed || this == TripLifecycle.settling || this == TripLifecycle.settled || this == TripLifecycle.completing;

  Color getStatusColor(bool isDark) {
    switch (this) {
      case TripLifecycle.draft:
        return isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
      case TripLifecycle.active:
        return isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
      case TripLifecycle.completing:
        return AppColors.amberAccent;
      case TripLifecycle.completed:
        return AppColors.indigoAccent;
      case TripLifecycle.settling:
        return AppColors.amberAccent;
      case TripLifecycle.settled:
        return isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
    }
  }

  static TripLifecycle fromString(String value) {
    return TripLifecycle.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TripLifecycle.active,
    );
  }
}
