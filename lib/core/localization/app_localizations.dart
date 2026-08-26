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
  String get onboardingHeroTitle => translate('onboarding_hero_title');
  String get onboardingBrandCredit => translate('onboarding_brand_credit');
  String get onboardingHeroDesc => translate('onboarding_hero_desc');
  String get onboardingQuickTour => translate('onboarding_quick_tour');
  String get onboardingFeatureVoiceTitle => translate('onboarding_feature_voice_title');
  String get onboardingFeatureVoiceSub => translate('onboarding_feature_voice_sub');
  String get onboardingFeatureMathTitle => translate('onboarding_feature_math_title');
  String get onboardingFeatureMathSub => translate('onboarding_feature_math_sub');
  String get onboardingFeatureDebtTitle => translate('onboarding_feature_debt_title');
  String get onboardingFeatureDebtSub => translate('onboarding_feature_debt_sub');
  String get onboardingPrimarySignin => translate('onboarding_primary_signin');
  String get onboardingSyncDevices => translate('onboarding_sync_devices');
  String get onboardingGoogleSignin => translate('onboarding_google_signin');
  String get onboardingOrGuest => translate('onboarding_or_guest');
  String get onboardingGuestName => translate('onboarding_guest_name');
  String get onboardingGuestDesc => translate('onboarding_guest_desc');
  String get onboardingNameHint => translate('onboarding_name_hint');
  String get onboardingGuestStart => translate('onboarding_guest_start');
  String get onboardingRecoveryPrompt => translate('onboarding_recovery_prompt');
  String get onboardingRecoveryHide => translate('onboarding_recovery_hide');
  String get onboardingRecoveryDesc => translate('onboarding_recovery_desc');
  String get onboardingRecoveryInputHint => translate('onboarding_recovery_input_hint');
  String get onboardingRestoreBtn => translate('onboarding_restore_btn');
  String get onboardingRestoringDialog => translate('onboarding_restoring_dialog');
  String get onboardingSigningInDialog => translate('onboarding_signing_in_dialog');
  String get onboardingModeSelect => translate('onboarding_mode_select');
  String get onboardingModeTripsOnly => translate('onboarding_mode_trips_only');
  String get onboardingModeTripsSub => translate('onboarding_mode_trips_sub');
  String get onboardingModePersonalOnly => translate('onboarding_mode_personal_only');
  String get onboardingModePersonalSub => translate('onboarding_mode_personal_sub');
  String get onboardingModeAll => translate('onboarding_mode_all');
  String get onboardingModeAllSub => translate('onboarding_mode_all_sub');
  String get onboardingWelcomeBack => translate('onboarding_welcome_back');
  String get onboardingWelcomeToast => translate('onboarding_welcome_toast');
  String get onboardingErrNameRequired => translate('onboarding_err_name_required');
  String get onboardingErrRecoveryRequired => translate('onboarding_err_recovery_required');
  String get onboardingErrRecoveryFailed => translate('onboarding_err_recovery_failed');

  // Tutorial Slides & Badges
  String get tutorialBadge1 => translate('tutorial_badge_1');
  String get tutorialBadge2 => translate('tutorial_badge_2');
  String get tutorialBadge3 => translate('tutorial_badge_3');
  String get tutorialBadge4 => translate('tutorial_badge_4');
  String get tutorialBadge5 => translate('tutorial_badge_5');
  String get tutorialBadge6 => translate('tutorial_badge_6');
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
  String get tutorialBtnNext => translate('tutorial_btn_next');
  String get tutorialBtnSkip => translate('tutorial_btn_skip');
  String get tutorialBtnGetStarted => translate('tutorial_btn_get_started');

  // Greetings
  String get greetingMorning => translate('greeting_morning');
  String get greetingAfternoon => translate('greeting_afternoon');
  String get greetingEvening => translate('greeting_evening');
  String get greetingTraveler => translate('greeting_traveler');

  // Personal Finance Tab
  String get personalTitle => translate('personal_title');
  String get personalAddExpense => translate('personal_add_expense');
  String get personalSpentPrefix => translate('personal_spent_prefix');
  String get personalSpentThisMonth => translate('personal_spent_this_month');
  String get personalBudget => translate('personal_budget');
  String get personalBudgetLabel => translate('personal_budget_label');
  String get personalBudgetSet => translate('personal_budget_set');
  String get personalBudgetRemaining => translate('personal_budget_remaining');
  String get personalBudgetOver => translate('personal_budget_over');
  String get personalDailyAverage => translate('personal_daily_average');
  String get personalOverBudgetBy => translate('personal_over_budget_by');
  String get personalRemainingLabel => translate('personal_remaining_label');
  String get personalNextActionDebts => translate('personal_next_action_debts');
  String get personalNextActionOver => translate('personal_next_action_over');
  String get personalNextActionWarning => translate('personal_next_action_warning');
  String get personalNextActionSync => translate('personal_next_action_sync');
  String get personalNextActionView => translate('personal_next_action_view');
  String get personalNextActionReview => translate('personal_next_action_review');
  String get personalNextActionSyncBtn => translate('personal_next_action_sync_btn');
  String get personalSecLending => translate('personal_sec_lending');
  String get personalViewAll => translate('personal_view_all');
  String get personalSecCategory => translate('personal_sec_category');
  String get personalViewDetails => translate('personal_view_details');
  String get personalSecExpenses => translate('personal_sec_expenses');
  String get personalFilter => translate('personal_filter');
  String get personalEmptyTitle => translate('personal_empty_title');
  String get personalEmptySub => translate('personal_empty_sub');
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

  // Time Filter Labels
  String get filterThisMonth => translate('filter_this_month');
  String get filterLastMonth => translate('filter_last_month');
  String get filterLast30Days => translate('filter_last_30_days');
  String get filterThisYear => translate('filter_this_year');
  String get filterAllTime => translate('filter_all_time');
  String get filterCustom => translate('filter_custom');

  // Categories
  String get catFood => translate('cat_food');
  String get catStay => translate('cat_stay');
  String get catTransport => translate('cat_transport');
  String get catShopping => translate('cat_shopping');
  String get catEntertainment => translate('cat_entertainment');
  String get catOther => translate('cat_other');

  // Lending & Borrowing View
  String get debtsTitle => translate('debts_title');
  String get debtsTabAll => translate('debts_tab_all');
  String get debtsTabLent => translate('debts_tab_lent');
  String get debtsTabBorrowed => translate('debts_tab_borrowed');
  String get debtsAddDebt => translate('debts_add_debt');
  String get debtsRecordRepayment => translate('debts_record_repayment');
  String get debtsSettleUp => translate('debts_settle_up');
  String get debtsAllClearTitle => translate('debts_all_clear_title');
  String get debtsAllClearSub => translate('debts_all_clear_sub');
  String get debtsDueDate => translate('debts_due_date');
  String get debtsMarkSettled => translate('debts_mark_settled');

  // Category Breakdown View
  String get categoryTitle => translate('category_title');
  String get categoryAllCategories => translate('category_all_categories');
  String get categoryTotalSpent => translate('category_total_spent');
  String get categoryPercentage => translate('category_percentage');

  // Add Personal Expense Sheet
  String get addExpenseModePersonal => translate('add_expense_mode_personal');
  String get addExpenseModeLent => translate('add_expense_mode_lent');
  String get addExpenseModeBorrowed => translate('add_expense_mode_borrowed');
  String get addExpenseAmount => translate('add_expense_amount');
  String get addExpenseTitleLabel => translate('add_expense_title_label');
  String get addExpenseTitleHint => translate('add_expense_title_hint');
  String get addExpensePersonLabel => translate('add_expense_person_label');
  String get addExpensePersonHint => translate('add_expense_person_hint');
  String get addExpenseCategoryLabel => translate('add_expense_category_label');
  String get addExpenseDateLabel => translate('add_expense_date_label');
  String get addExpenseNotesLabel => translate('add_expense_notes_label');
  String get addExpenseNotesHint => translate('add_expense_notes_hint');
  String get addExpenseBtnSave => translate('add_expense_btn_save');
  String get addExpenseVoiceListening => translate('add_expense_voice_listening');
  String get addExpenseVoiceTapStop => translate('add_expense_voice_tap_stop');
  String get addExpenseVoiceParsing => translate('add_expense_voice_parsing');
  String get addExpenseVoiceTip => translate('add_expense_voice_tip');
  String get addExpenseReceiptScan => translate('add_expense_receipt_scan');
  String get addExpenseReceiptProcessing => translate('add_expense_receipt_processing');
  String get addExpenseSuccess => translate('add_expense_success');
  String get addExpenseErrAmount => translate('add_expense_err_amount');
  String get addExpenseErrTitle => translate('add_expense_err_title');
  String get addExpenseErrPerson => translate('add_expense_err_person');

  // Trips & Groups
  String get tripsTitle => translate('trips_title');
  String get tripsCreate => translate('trips_create');
  String get tripsJoin => translate('trips_join');
  String get tripsJoinCode => translate('trips_join_code');
  String get tripsJoinBtn => translate('trips_join_btn');
  String get tripsMyTrips => translate('trips_my_trips');
  String get tripsActive => translate('trips_active');
  String get tripsCompleted => translate('trips_completed');
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
  String get tripsExportCsv => translate('trips_export_csv');
  String get tripsQrCode => translate('trips_qr_code');
  String get tripsAddFriendTitle => translate('trips_add_friend_title');
  String get tripsAddFriendDesc => translate('trips_add_friend_desc');
  String get tripsAddFriendHint => translate('trips_add_friend_hint');
  String get tripsAddFriendBtn => translate('trips_add_friend_btn');

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

  // Profile & Account
  String get profileTitle => translate('profile_title');
  String get profileSecAccount => translate('profile_sec_account');
  String get profileSecCloud => translate('profile_sec_cloud');
  String get profileSecRecovery => translate('profile_sec_recovery');
  String get profileSecExperience => translate('profile_sec_experience');
  String get profileSecPreferences => translate('profile_sec_preferences');
  String get profileSecHelp => translate('profile_sec_help');
  String get profileGoogleConnected => translate('profile_google_connected');
  String get profileGoogleSignin => translate('profile_google_signin');
  String get profileGoogleSigninDesc => translate('profile_google_signin_desc');
  String get profileGuestAccount => translate('profile_guest_account');
  String get profileDeviceOnly => translate('profile_device_only');
  String get profileCloudActive => translate('profile_cloud_active');
  String get profileRecoveryDesc => translate('profile_recovery_desc');
  String get profileRecoveryCopied => translate('profile_recovery_copied');
  String get profileTheme => translate('profile_theme');
  String get profileThemeSystem => translate('profile_theme_system');
  String get profileThemeLight => translate('profile_theme_light');
  String get profileThemeDark => translate('profile_theme_dark');
  String get profileLanguage => translate('profile_language');
  String get profileWidgets => translate('profile_widgets');
  String get profileWidgetsDesc => translate('profile_widgets_desc');
  String get profileHelpFaq => translate('profile_help_faq');
  String get profileHelpFaqDesc => translate('profile_help_faq_desc');
  String get profileQuickTour => translate('profile_quick_tour');
  String get profileQuickTourDesc => translate('profile_quick_tour_desc');
  String get profileSignOut => translate('profile_sign_out');
  String get profileSignOutTitle => translate('profile_sign_out_title');
  String get profileSignOutDesc => translate('profile_sign_out_desc');
  String get profileSignOutConfirm => translate('profile_sign_out_confirm');
  String get profileSignOutSuccess => translate('profile_sign_out_success');

  // Cloud Settings View
  String get cloudTitle => translate('cloud_title');
  String get cloudStatusSynced => translate('cloud_status_synced');
  String get cloudStatusPending => translate('cloud_status_pending');
  String get cloudAutoSync => translate('cloud_auto_sync');
  String get cloudAutoSyncDesc => translate('cloud_auto_sync_desc');
  String get cloudFlushQueue => translate('cloud_flush_queue');
  String get cloudRecoveryCardTitle => translate('cloud_recovery_card_title');
  String get cloudRecoveryCardDesc => translate('cloud_recovery_card_desc');
  String get cloudCopyKey => translate('cloud_copy_key');

  // Widget Gallery View
  String get widgetGalleryTitle => translate('widget_gallery_title');
  String get widgetGalleryDesc => translate('widget_gallery_desc');
  String get widgetPrivacyTitle => translate('widget_privacy_title');
  String get widgetPrivacyDesc => translate('widget_privacy_desc');
  String get widgetBtnPin => translate('widget_btn_pin');
  String get widgetLauncherHelpTitle => translate('widget_launcher_help_title');
  String get widgetLauncherHelpStep1 => translate('widget_launcher_help_step1');
  String get widgetLauncherHelpStep2 => translate('widget_launcher_help_step2');
  String get widgetLauncherHelpStep3 => translate('widget_launcher_help_step3');
  String get widgetPinSuccess => translate('widget_pin_success');
  String get widgetPinUnsupported => translate('widget_pin_unsupported');

  // Setup Guide Items
  String get guideItem1_1Title => translate('guide_item_widgets_title');
  String get guideItem1_1Desc => translate('guide_item_widgets_desc');
  String get guideItem1_1Loc => translate('guide_item_widgets_loc');
  String get guideItem1_1Act => translate('guide_item_widgets_action');
  String get guideItem1_2Title => translate('guide_item_lang_title');
  String get guideItem1_2Desc => translate('guide_item_lang_desc');
  String get guideItem1_2Loc => translate('guide_item_lang_loc');
  String get guideItem1_2Act => translate('guide_item_lang_action');
  String get guideItem1_3Title => translate('guide_item_guest_title');
  String get guideItem1_3Desc => translate('guide_item_guest_desc');
  String get guideItem1_3Loc => translate('guide_item_guest_loc');
  String get guideItem1_3Act => translate('guide_item_guest_action');
  String get guideItem1_4Title => translate('guide_item_modes_title');
  String get guideItem1_4Desc => translate('guide_item_modes_desc');
  String get guideItem1_4Loc => translate('guide_item_modes_loc');
  String get guideItem1_4Act => translate('guide_item_modes_action');

  String get guideItem2_1Title => translate('guide_item_add_expense_title');
  String get guideItem2_1Desc => translate('guide_item_add_expense_desc');
  String get guideItem2_1Loc => translate('guide_item_add_expense_loc');
  String get guideItem2_1Act => translate('guide_item_add_expense_action');
  String get guideItem2_2Title => translate('guide_item_budget_title');
  String get guideItem2_2Desc => translate('guide_item_budget_desc');
  String get guideItem2_2Loc => translate('guide_item_budget_loc');
  String get guideItem2_2Act => translate('guide_item_budget_action');
  String get guideItem2_3Title => translate('guide_item_debts_title');
  String get guideItem2_3Desc => translate('guide_item_debts_desc');
  String get guideItem2_3Loc => translate('guide_item_debts_loc');
  String get guideItem2_3Act => translate('guide_item_debts_action');
  String get guideItem2_4Title => translate('guide_item_categories_title');
  String get guideItem2_4Desc => translate('guide_item_categories_desc');
  String get guideItem2_4Loc => translate('guide_item_categories_loc');
  String get guideItem2_4Act => translate('guide_item_categories_action');

  String get guideItem3_1Title => translate('guide_item_create_trip_title');
  String get guideItem3_1Desc => translate('guide_item_create_trip_desc');
  String get guideItem3_1Loc => translate('guide_item_create_trip_loc');
  String get guideItem3_1Act => translate('guide_item_create_trip_action');
  String get guideItem3_2Title => translate('guide_item_join_trip_title');
  String get guideItem3_2Desc => translate('guide_item_join_trip_desc');
  String get guideItem3_2Loc => translate('guide_item_join_trip_loc');
  String get guideItem3_2Act => translate('guide_item_join_trip_action');
  String get guideItem3_3Title => translate('guide_item_settle_title');
  String get guideItem3_3Desc => translate('guide_item_settle_desc');
  String get guideItem3_3Loc => translate('guide_item_settle_loc');
  String get guideItem3_3Act => translate('guide_item_settle_action');

  String get guideItem4_1Title => translate('guide_item_cloud_sync_title');
  String get guideItem4_1Desc => translate('guide_item_cloud_sync_desc');
  String get guideItem4_1Loc => translate('guide_item_cloud_sync_loc');
  String get guideItem4_1Act => translate('guide_item_cloud_sync_action');
  String get guideItem4_2Title => translate('guide_item_recovery_title');
  String get guideItem4_2Desc => translate('guide_item_recovery_desc');
  String get guideItem4_2Loc => translate('guide_item_recovery_loc');
  String get guideItem4_2Act => translate('guide_item_recovery_action');
  String get guideItem4_3Title => translate('guide_item_offline_title');
  String get guideItem4_3Desc => translate('guide_item_offline_desc');
  String get guideItem4_3Loc => translate('guide_item_offline_loc');
  String get guideItem4_3Act => translate('guide_item_offline_action');

  String get guideItem5_1Title => translate('guide_item_voice_title');
  String get guideItem5_1Desc => translate('guide_item_voice_desc');
  String get guideItem5_1Loc => translate('guide_item_voice_loc');
  String get guideItem5_1Act => translate('guide_item_voice_action');
  String get guideItem5_2Title => translate('guide_item_receipt_title');
  String get guideItem5_2Desc => translate('guide_item_receipt_desc');
  String get guideItem5_2Loc => translate('guide_item_receipt_loc');
  String get guideItem5_2Act => translate('guide_item_receipt_action');

  // Hints
  String get hintExpenseTitle => translate('hint_expense_title');
  String get hintExpenseDesc => translate('hint_expense_desc');
  String get hintTripsTitle => translate('hint_trips_title');
  String get hintTripsDesc => translate('hint_trips_desc');
  String get hintGotIt => translate('hint_got_it');

  // Auth / Cloud / Profile Aliases
  String get authRecoveryKey => translate('profile_sec_recovery');
  String get authGoogleConnected => translate('profile_google_connected');
  String get authSyncStatusSynced => translate('cloud_status_synced');
  String get authSignOutTitle => translate('profile_sign_out_title');
  String get authSignOutDesc => translate('profile_sign_out_desc');
  String get authSignOutConfirm => translate('profile_sign_out_confirm');
  String get authSignOutSuccess => translate('profile_sign_out_success');
  String get authCloudSync => translate('profile_sec_cloud');
  String get statusPending => translate('cloud_status_pending');
  String get settingsTitle => translate('cloud_title');
  String get profileLocalData => translate('profile_device_only');
  String get profileConnectGoogle => translate('profile_google_signin');
  String get profileCloudSyncDesc => translate('cloud_auto_sync_desc');
  String get profileRecoverySafe => translate('profile_recovery_desc');
  String get profileAppearance => translate('profile_theme');
  String get profileFaq => translate('profile_help_faq');
  String get profileFaqDesc => translate('profile_help_faq_desc');
  String get profileTour => translate('profile_quick_tour');
  String get profileTourDesc => translate('profile_quick_tour_desc');
  String get profileFeedback => translate('feedback_title');
  String get profileSecDanger => translate('profile_sec_danger');
  String get actionReset => translate('action_reset');

  // Widgets
  String get widgetsLongPressHelp => translate('widgets_long_press_help');
  String get widgetsPinButton => translate('widget_btn_pin');
  String get widgetsGalleryHeader => translate('widget_gallery_title');
  String get widgetsGallerySub => translate('widget_gallery_desc');
  String get widgetsPrivacyTitle => translate('widget_privacy_title');
  String get widgetsPrivacyDesc => translate('widget_privacy_desc');
  String get widgetsSecAvailable => translate('widgets_sec_available');
  String get widgetsLauncherHelpTitle => translate('widget_launcher_help_title');
  String get widgetsLauncherHelpDesc => translate('widget_launcher_help_step1');

  // Actions & Dialogs
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
  String get actionRestore => translate('action_restore');
  String get dialogRestoreTitle => translate('dialog_restore_title');
  String get dialogRestoreDesc => translate('dialog_restore_desc');
  String get dialogRestoreHint => translate('dialog_restore_hint');
  String get dialogDiscardTitle => translate('dialog_discard_title');
  String get dialogDiscardKeep => translate('dialog_discard_keep');
  String get dialogDiscardConfirm => translate('dialog_discard_confirm');

  // Statuses
  String get statusLoading => translate('status_loading');
  String get statusSaving => translate('status_saving');
  String get statusSyncing => translate('status_syncing');
  String get statusRestoring => translate('status_restoring');
  String get statusSigningIn => translate('status_signing_in');
  String get statusSigningOut => translate('status_signing_out');
  String get statusSaved => translate('status_saved');
  String get statusOffline => translate('status_offline');
  String get statusErrorGeneral => translate('status_error_general');
  String get statusNoInternet => translate('status_no_internet');
  String get statusSignedInAs => translate('status_signed_in_as');

  // Settlement "Mark as Paid" & Recipient Notifications
  String get settlementMarkPaidTitle => translate('settlement_mark_paid_title');
  String settlementMarkPaidDesc(String name) => translate('settlement_mark_paid_desc').replaceAll('{name}', name);
  String get settlementMarkPaidBtn => translate('settlement_mark_paid_btn');
  String get settlementPaidSuccess => translate('settlement_paid_success');
  String get settlementNotifTitle => translate('settlement_notif_title');
  String settlementNotifBody(String name, String amount) =>
      translate('settlement_notif_body').replaceAll('{name}', name).replaceAll('{amount}', amount);

  // Clean QR Scanner
  String get qrInvalidTitle => translate('qr_invalid_title');
  String get qrScanAgain => translate('qr_scan_again');
  String get qrJoinPrompt => translate('qr_join_prompt');
  String qrHostedBy(String name) => translate('qr_hosted_by').replaceAll('{name}', name);

  // Premium Onboarding & Sign-In Redesign
  String get onboardingHeroTagline => translate('onboarding_hero_tagline');
  String get onboardingHeroSub => translate('onboarding_hero_sub');
  String get onboardingGoogleBtn => translate('onboarding_google_btn');
  String get onboardingGuestBtn => translate('onboarding_guest_btn');
  String get onboardingGuestSubtitle => translate('onboarding_guest_subtitle');
  String get onboardingRecoveryLink => translate('onboarding_recovery_link');
  String get onboardingTrustNote => translate('onboarding_trust_note');
  String get onboardingSceneBudget => translate('onboarding_scene_budget');
  String get onboardingSceneRemaining => translate('onboarding_scene_remaining');
  String get onboardingSceneTrip => translate('onboarding_scene_trip');
  String get onboardingSceneDinner => translate('onboarding_scene_dinner');
  String get onboardingSceneCab => translate('onboarding_scene_cab');
  String get onboardingSceneSplit => translate('onboarding_scene_split');
  String get onboardingSceneSettled => translate('onboarding_scene_settled');
  String get onboardingGuestSheetTitle => translate('onboarding_guest_sheet_title');
  String get onboardingGuestSheetDesc => translate('onboarding_guest_sheet_desc');
  String get onboardingGuestSheetCta => translate('onboarding_guest_sheet_cta');
  String get onboardingRecoverySheetTitle => translate('onboarding_recovery_sheet_title');
  String get onboardingRecoverySheetDesc => translate('onboarding_recovery_sheet_desc');
  String get onboardingRecoverySheetCta => translate('onboarding_recovery_sheet_cta');
  String get onboardingSigningInStatus => translate('onboarding_signing_in_status');
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
