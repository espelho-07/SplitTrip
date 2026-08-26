import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'translations/en.dart';
import 'translations/gu.dart';
import 'translations/hi.dart';

/// Centralized localization service for Kith.
class AppLocalizations {
  final Locale locale;
  late final Map<String, String> _localizedStrings;

  AppLocalizations(this.locale) {
    switch (locale.languageCode) {
      case 'hi':
        _localizedStrings = hiTranslations;
        break;
      case 'gu':
        _localizedStrings = guTranslations;
        break;
      case 'en':
      default:
        _localizedStrings = enTranslations;
        break;
    }
  }

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return instance ?? AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// Retrieve a localized string by key with automatic English fallback
  String translate(String key) {
    return _localizedStrings[key] ?? enTranslations[key] ?? key;
  }

  // --- Type-Safe String Accessors ---

  // Language Selection
  String get languageSelectTitle => translate('language_select_title');
  String get languageSelectSubtitle => translate('language_select_subtitle');
  String get languageContinue => translate('language_continue');
  String get languageCurrent => translate('language_current');
  String get languageChangeSuccess => translate('language_change_success');

  // Navigation & Tabs
  String get tabExpense => translate('tab_expense');
  String get tabTrips => translate('tab_trips');
  String get tabPersonal => translate('tab_personal');
  String get navProfile => translate('nav_profile');
  String get navSettings => translate('nav_settings');
  String get navSetupGuide => translate('nav_setup_guide');

  // Onboarding & Welcome
  String get onboardingTitle => translate('onboarding_title');
  String get onboardingSubtitle => translate('onboarding_subtitle');
  String get onboardingGoogleSignin => translate('onboarding_google_signin');
  String get onboardingGuestStart => translate('onboarding_guest_start');
  String get onboardingNameHint => translate('onboarding_name_hint');
  String get onboardingRecoveryPrompt => translate('onboarding_recovery_prompt');
  String get onboardingRecoveryHide => translate('onboarding_recovery_hide');
  String get onboardingModeSelect => translate('onboarding_mode_select');
  String get onboardingModeTripsOnly => translate('onboarding_mode_trips_only');
  String get onboardingModeTripsSub => translate('onboarding_mode_trips_sub');
  String get onboardingModePersonalOnly => translate('onboarding_mode_personal_only');
  String get onboardingModePersonalSub => translate('onboarding_mode_personal_sub');
  String get onboardingModeAll => translate('onboarding_mode_all');
  String get onboardingModeAllSub => translate('onboarding_mode_all_sub');

  // Tutorial Slides
  String get tutorialSlide1Title => translate('tutorial_slide_1_title');
  String get tutorialSlide1Desc => translate('tutorial_slide_1_desc');
  String get tutorialSlide2Title => translate('tutorial_slide_2_title');
  String get tutorialSlide2Desc => translate('tutorial_slide_2_desc');
  String get tutorialSlide3Title => translate('tutorial_slide_3_title');
  String get tutorialSlide3Desc => translate('tutorial_slide_3_desc');
  String get tutorialSlide4Title => translate('tutorial_slide_4_title');
  String get tutorialSlide4Desc => translate('tutorial_slide_4_desc');
  String get tutorialSlide5Title => translate('tutorial_slide_5_title');
  String get tutorialSlide5Desc => translate('tutorial_slide_5_desc');
  String get tutorialSlide6Title => translate('tutorial_slide_6_title');
  String get tutorialSlide6Desc => translate('tutorial_slide_6_desc');

  // Personal Finance
  String get personalTitle => translate('personal_title');
  String get personalAddExpense => translate('personal_add_expense');
  String get personalSpentThisMonth => translate('personal_spent_this_month');
  String get personalBudget => translate('personal_budget');
  String get personalBudgetSet => translate('personal_budget_set');
  String get personalBudgetRemaining => translate('personal_budget_remaining');
  String get personalBudgetOver => translate('personal_budget_over');
  String get personalDebtsTitle => translate('personal_debts_title');
  String get personalDebtsSub => translate('personal_debts_sub');
  String get personalYouAreOwed => translate('personal_you_are_owed');
  String get personalYouOwe => translate('personal_you_owe');
  String get personalNetBalance => translate('personal_net_balance');
  String get personalRecordRepayment => translate('personal_record_repayment');
  String get personalRecentTransactions => translate('personal_recent_transactions');
  String get personalCategories => translate('personal_categories');
  String get personalNoExpenses => translate('personal_no_expenses');
  String get personalNoExpensesSub => translate('personal_no_expenses_sub');
  String get personalLent => translate('personal_lent');
  String get personalBorrowed => translate('personal_borrowed');
  String get personalSettled => translate('personal_settled');

  // Categories
  String get catFood => translate('cat_food');
  String get catStay => translate('cat_stay');
  String get catTransport => translate('cat_transport');
  String get catShopping => translate('cat_shopping');
  String get catEntertainment => translate('cat_entertainment');
  String get catOther => translate('cat_other');

  // Trips
  String get tripsTitle => translate('trips_title');
  String get tripsCreate => translate('trips_create');
  String get tripsJoin => translate('trips_join');
  String get tripsJoinCode => translate('trips_join_code');
  String get tripsJoinBtn => translate('trips_join_btn');
  String get tripsMyTrips => translate('trips_my_trips');
  String get tripsNoTrips => translate('trips_no_trips');
  String get tripsNoTripsSub => translate('trips_no_trips_sub');
  String get tripsMembers => translate('trips_members');
  String get tripsAddMember => translate('trips_add_member');
  String get tripsAddExpense => translate('trips_add_expense');
  String get tripsInviteCode => translate('trips_invite_code');
  String get tripsInviteCopied => translate('trips_invite_copied');
  String get tripsShareLink => translate('trips_share_link');
  String get tripsBalances => translate('trips_balances');
  String get tripsSettleUp => translate('trips_settle_up');
  String get tripsAllSettled => translate('trips_all_settled');
  String get tripsActivity => translate('trips_activity');
  String get tripsJourney => translate('trips_journey');
  String get tripsAddMoment => translate('trips_add_moment');
  String get tripsSplitEqual => translate('trips_split_equal');
  String get tripsSplitExact => translate('trips_split_exact');
  String get tripsSplitShares => translate('trips_split_shares');
  String get tripsSplitPercentage => translate('trips_split_percentage');
  String get tripsPaidBy => translate('trips_paid_by');
  String get tripsForMembers => translate('trips_for_members');

  // Setup Guide
  String get guideTitle => translate('guide_title');
  String get guideSubtitle => translate('guide_subtitle');
  String get guideWhereToFind => translate('guide_where_to_find');
  String get guideBtnOpen => translate('guide_btn_open');
  String get guideSecGettingStarted => translate('guide_sec_getting_started');
  String get guideSecPersonal => translate('guide_sec_personal');
  String get guideSecTrips => translate('guide_sec_trips');
  String get guideSecCloud => translate('guide_sec_cloud');
  String get guideSecVoice => translate('guide_sec_voice');
  String get guideSecSettings => translate('guide_sec_settings');

  // Auth & Cloud
  String get authGoogleConnected => translate('auth_google_connected');
  String get authGuestAccount => translate('auth_guest_account');
  String get authDataOnDevice => translate('auth_data_on_device');
  String get authSignInPrompt => translate('auth_sign_in_prompt');
  String get authSignOut => translate('auth_sign_out');
  String get authSignOutTitle => translate('auth_sign_out_title');
  String get authSignOutDesc => translate('auth_sign_out_desc');
  String get authSignOutConfirm => translate('auth_sign_out_confirm');
  String get authSignOutSuccess => translate('auth_sign_out_success');
  String get authSyncStatusSynced => translate('auth_sync_status_synced');
  String get authSyncStatusPending => translate('auth_sync_status_pending');
  String get authCloudSync => translate('auth_cloud_sync');
  String get authRecoveryKey => translate('auth_recovery_key');

  // Contextual Tooltips
  String get hintExpenseTitle => translate('hint_expense_title');
  String get hintExpenseDesc => translate('hint_expense_desc');
  String get hintTripsTitle => translate('hint_trips_title');
  String get hintTripsDesc => translate('hint_trips_desc');
  String get hintBudgetTitle => translate('hint_budget_title');
  String get hintBudgetDesc => translate('hint_budget_desc');
  String get hintDebtsTitle => translate('hint_debts_title');
  String get hintDebtsDesc => translate('hint_debts_desc');
  String get hintGotIt => translate('hint_got_it');

  // Actions
  String get actionSave => translate('action_save');
  String get actionCancel => translate('action_cancel');
  String get actionDone => translate('action_done');
  String get actionNext => translate('action_next');
  String get actionSkip => translate('action_skip');
  String get actionRetry => translate('action_retry');
  String get actionEdit => translate('action_edit');
  String get actionDelete => translate('action_delete');
  String get actionConfirm => translate('action_confirm');
  String get actionSearch => translate('action_search');
  String get actionBack => translate('action_back');
  String get actionClose => translate('action_close');

  // Statuses
  String get statusLoading => translate('status_loading');
  String get statusSyncing => translate('status_syncing');
  String get statusRestoring => translate('status_restoring');
  String get statusSaved => translate('status_saved');
  String get statusOffline => translate('status_offline');
  String get statusErrorGeneral => translate('status_error_general');
  String get statusNoInternet => translate('status_no_internet');
  String get statusSignedInAs => translate('status_signed_in_as');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Helper extension for BuildContext to access AppLocalizations effortlessly.
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
