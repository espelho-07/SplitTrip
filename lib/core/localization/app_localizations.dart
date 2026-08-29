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
  String get onboardingErrGuestFailed => translate('onboarding_err_guest_failed');
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
  String get profileNirniqConnected => translate('profile_nirniq_connected');
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
  String get authNirniqConnected => translate('profile_nirniq_connected');
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
  String get profileConnectNirniq => translate('profile_nirniq_signin');
  String get profileConnectNirniqDesc => translate('profile_nirniq_signin_desc');
  String get profileConnectedApps => translate('profile_connected_apps');
  String get profileConnectedAppsDesc => translate('profile_connected_apps_desc');
  String get profileConnectedAppsKith => translate('profile_connected_apps_kith');
  String get profileConnectedAppsFuture => translate('profile_connected_apps_future');
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
  String get payViaUpiBtn => translate('pay_via_upi_btn');
  String get payManuallyBtn => translate('pay_manually_btn');
  String get paymentInitiatedTitle => translate('payment_initiated_title');
  String paymentInitiatedDesc(String name, String amount) =>
      translate('payment_initiated_desc').replaceAll('{name}', name).replaceAll('{amount}', amount);
  String get paymentYesMarkPaid => translate('payment_yes_mark_paid');
  String get paymentNotYet => translate('payment_not_yet');
  String get paymentOfflineWarning => translate('payment_offline_warning');

  // Clean QR Scanner
  String get qrInvalidTitle => translate('qr_invalid_title');
  String get qrScanAgain => translate('qr_scan_again');
  String get qrJoinPrompt => translate('qr_join_prompt');
  String qrHostedBy(String name) => translate('qr_hosted_by').replaceAll('{name}', name);

  // Premium Onboarding & Sign-In Redesign
  String get onboardingHeroTagline => translate('onboarding_hero_tagline');
  String get onboardingHeroSub => translate('onboarding_hero_sub');
  String get onboardingNirniqBtn => translate('onboarding_nirniq_btn');
  String get onboardingNirniqSub => translate('onboarding_nirniq_sub');
  String get onboardingEcosystemNote => translate('onboarding_ecosystem_note');
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

  // Create Trip View
  String get createTripAppBarTitle => translate('create_trip_app_bar_title');
  String get createTripPreviewPlaceholder => translate('create_trip_preview_placeholder');
  String get createTripNameLabel => translate('create_trip_name_label');
  String get createTripNameHint => translate('create_trip_name_hint');
  String get createTripIconLabel => translate('create_trip_icon_label');
  String get createTripGradientLabel => translate('create_trip_gradient_label');
  String get createTripModeLabel => translate('create_trip_mode_label');
  String get createTripModeSplitOnlyTitle => translate('create_trip_mode_split_only_title');
  String get createTripModeSplitOnlySub => translate('create_trip_mode_split_only_sub');
  String get createTripModeJourneyTitle => translate('create_trip_mode_journey_title');
  String get createTripModeJourneySub => translate('create_trip_mode_journey_sub');
  String get createTripCurrencyLabel => translate('create_trip_currency_label');
  String get createTripFriendsLabel => translate('create_trip_friends_label');
  String get createTripFriendsSub => translate('create_trip_friends_sub');
  String get createTripFriendHint => translate('create_trip_friend_hint');
  String get createTripCta => translate('create_trip_cta');
  String get createTripErrName => translate('create_trip_err_name');
  String get createTripStageInit => translate('create_trip_stage_init');
  String get createTripStageInitDesc => translate('create_trip_stage_init_desc');
  String get createTripStageMember => translate('create_trip_stage_member');
  String get createTripStageMemberDesc => translate('create_trip_stage_member_desc');
  String get createTripStageSpace => translate('create_trip_stage_space');
  String get createTripStageSpaceDesc => translate('create_trip_stage_space_desc');
  String get createTripStageSync => translate('create_trip_stage_sync');
  String get createTripStageSyncDesc => translate('create_trip_stage_sync_desc');
  String get createTripProgressTitle => translate('create_trip_progress_title');
  String get createTripDiscardTitle => translate('create_trip_discard_title');
  String get createTripDiscardDesc => translate('create_trip_discard_desc');
  String get createTripDiscardKeep => translate('create_trip_discard_keep');
  String get createTripDiscardConfirm => translate('create_trip_discard_confirm');

  // Add Expense View
  String get expenseAddTitle => translate('expense_add_title');
  String get expenseEditTitle => translate('expense_edit_title');
  String get expenseAmountLabel => translate('expense_amount_label');
  String get expenseWhatForLabel => translate('expense_what_for_label');
  String get expenseWhatForHint => translate('expense_what_for_hint');
  String get expensePaidByLabel => translate('expense_paid_by_label');
  String get expenseSplitHowLabel => translate('expense_split_how_label');
  String get expenseSplitEqually => translate('expense_split_equally');
  String get expenseSplitExact => translate('expense_split_exact');
  String get expenseSplitPercentages => translate('expense_split_percentages');
  String get expenseSplitShares => translate('expense_split_shares');
  String get expenseSaveBtn => translate('expense_save_btn');
  String get expenseVoiceTab => translate('expense_voice_tab');
  String get expenseReceiptTab => translate('expense_receipt_tab');
  String get expenseManualTab => translate('expense_manual_tab');
  String get expenseVoiceTitle => translate('expense_voice_title');
  String get expenseVoiceSub => translate('expense_voice_sub');
  String get expenseVoiceTry => translate('expense_voice_try');
  String get expenseReceiptTitle => translate('expense_receipt_title');
  String get expenseReceiptSub => translate('expense_receipt_sub');
  String get expenseReceiptCamera => translate('expense_receipt_camera');
  String get expenseReceiptGallery => translate('expense_receipt_gallery');
  String get expenseReceiptSample => translate('expense_receipt_sample');
  String get expenseSplitTotalMustMatch => translate('expense_split_total_must_match');

  // Trip Detail View
  String get tripDetailTabOverview => translate('trip_detail_tab_overview');
  String get tripDetailTabSpending => translate('trip_detail_tab_spending');
  String get tripDetailTabJourney => translate('trip_detail_tab_journey');
  String get tripDetailTabExpenses => translate('trip_detail_tab_expenses');
  String get tripDetailTabPeople => translate('trip_detail_tab_people');
  String get tripDetailTabCategories => translate('trip_detail_tab_categories');
  String get tripDetailTripSpending => translate('trip_detail_trip_spending');
  String get tripDetailYourShare => translate('trip_detail_your_share');
  String get tripDetailRecentSpending => translate('trip_detail_recent_spending');
  String get tripDetailViewAllSpending => translate('trip_detail_view_all_spending');
  String get tripDetailJourneyTimeline => translate('trip_detail_journey_timeline');
  String get tripDetailViewFullJourney => translate('trip_detail_view_full_journey');
  String get tripDetailAddFirstExpense => translate('trip_detail_add_first_expense');
  String get tripDetailNoExpenses => translate('trip_detail_no_expenses');
  String get tripDetailNoExpensesSub => translate('trip_detail_no_expenses_sub');
  String get tripDetailAddFirstMoment => translate('trip_detail_add_first_moment');
  String get tripDetailNoMoments => translate('trip_detail_no_moments');
  String get tripDetailNoMomentsSub => translate('trip_detail_no_moments_sub');
  String tripDetailMembersCount(int count) => translate('trip_detail_members_count').replaceAll('{count}', count.toString());
  String get tripDetailAddFriend => translate('trip_detail_add_friend');
  String get tripDetailYou => translate('trip_detail_you');
  String get tripDetailYouSuffix => translate('trip_detail_you_suffix');
  String get tripDetailYouGetBack => translate('trip_detail_you_get_back');
  String get tripDetailYouOwe => translate('trip_detail_you_owe');
  String get tripDetailAllSettled => translate('trip_detail_all_settled');
  String get tripDetailSettleUp => translate('trip_detail_settle_up');
  String get tripDetailBtnAddExpense => translate('trip_detail_btn_add_expense');
  String get tripDetailBtnAddMoment => translate('trip_detail_btn_add_moment');
  String get tripDetailBtnSettleUp => translate('trip_detail_btn_settle_up');
  String get tripDetailFinishTrip => translate('trip_detail_finish_trip');
  String get tripDetailReopenTrip => translate('trip_detail_reopen_trip');
  String get tripDetailArchiveTrip => translate('trip_detail_archive_trip');
  String get tripDetailCatAll => translate('trip_detail_cat_all');
  String get tripDetailCatFood => translate('trip_detail_cat_food');
  String get tripDetailCatTransport => translate('trip_detail_cat_transport');
  String get tripDetailCatStay => translate('trip_detail_cat_stay');
  String get tripDetailCatFuel => translate('trip_detail_cat_fuel');
  String get tripDetailCatActivity => translate('trip_detail_cat_activity');
  String get tripDetailCatShopping => translate('trip_detail_cat_shopping');
  String get tripDetailCatOther => translate('trip_detail_cat_other');
  String get tripDetailSearchExpenses => translate('trip_detail_search_expenses');

  // Trips Home Tab
  String get tripsHomeTotalSpent => translate('trips_home_total_spent');
  String get tripsHomeGroupTrips => translate('trips_home_group_trips');
  String get tripsHomeNoTripsDesc => translate('trips_home_no_trips_desc');
  String get tripsHomeAllSettledMsg => translate('trips_home_all_settled_msg');
  String get tripsHomeNewTripBtn => translate('trips_home_new_trip_btn');
  String tripsHomeGetBackOverall(String amount) => translate('trips_home_get_back_overall').replaceAll('{amount}', amount);
  String tripsHomeOweOverall(String amount) => translate('trips_home_owe_overall').replaceAll('{amount}', amount);
  String get tripsHomeAllSettled => translate('trips_home_all_settled');
  String tripsHomeActiveCount(int count) => translate('trips_home_active_count').replaceAll('{count}', count.toString());
  String get tripsHomeSpentLabel => translate('trips_home_spent_label');
  String get tripsHomeYoursLabel => translate('trips_home_yours_label');
  String tripsHomeMembersCount(int count) => translate('trips_home_members_count').replaceAll('{count}', count.toString());
  String get tripsHomeCardSettled => translate('trips_home_card_settled');

  // Feature Under Crafting Teasers (Voice & Receipt)
  String get expenseCraftingBadge => translate('expense_crafting_badge');
  String get expenseVoiceCraftingTitle => translate('expense_voice_crafting_title');
  String get expenseVoiceCraftingDesc => translate('expense_voice_crafting_desc');
  String get expenseVoiceTagTrain => translate('expense_voice_tag_train');
  String get expenseVoiceTagDinner => translate('expense_voice_tag_dinner');
  String get expenseVoiceTagCab => translate('expense_voice_tag_cab');
  String get expenseReceiptCraftingTitle => translate('expense_receipt_crafting_title');
  String get expenseReceiptCraftingDesc => translate('expense_receipt_crafting_desc');
  String get expenseReceiptTagTotal => translate('expense_receipt_tag_total');
  String get expenseReceiptTagMerchant => translate('expense_receipt_tag_merchant');
  String get expenseReceiptTagTax => translate('expense_receipt_tag_tax');
  String get expenseCraftingNextUpdate => translate('expense_crafting_next_update');
  String get expenseCraftingSwitchManual => translate('expense_crafting_switch_manual');

  // Google Play Compliance: Account Deletion & Privacy Policy
  String get profileDeleteAccountTitle => translate('profile_delete_account_title');
  String get profileDeleteAccountDesc => translate('profile_delete_account_desc');
  String get profileDeleteDialogTitle => translate('profile_delete_dialog_title');
  String get profileDeleteDialogDesc => translate('profile_delete_dialog_desc');
  String get profileDeleteConfirmBtn => translate('profile_delete_confirm_btn');
  String get profileDeleteSuccess => translate('profile_delete_success');
  String get profilePrivacyPolicy => translate('profile_privacy_policy');
  String get profilePrivacyPolicyDesc => translate('profile_privacy_policy_desc');
  String get privacyTitle => translate('privacy_title');
  String get privacySubtitle => translate('privacy_subtitle');

  // Master FAQ & Help Center
  String get faqHeroTitle => translate('faq_hero_title');
  String get faqHeroSub => translate('faq_hero_sub');
  String get faqBadgeStats => translate('faq_badge_stats');
  String get faqSearchHint => translate('faq_search_hint');
  String faqSearchResults(int count) => translate('faq_search_results').replaceAll('{count}', count.toString());
  String get faqCatAll => translate('faq_cat_all');
  String get faqCatGettingStarted => translate('faq_cat_getting_started');
  String get faqCatSecurity => translate('faq_cat_security');
  String get faqCatPersonal => translate('faq_cat_personal');
  String get faqCatTrips => translate('faq_cat_trips');
  String get faqCatSplitting => translate('faq_cat_splitting');
  String get faqCatSettlements => translate('faq_cat_settlements');
  String get faqCatVoice => translate('faq_cat_voice');
  String get faqCatReceipts => translate('faq_cat_receipts');
  String get faqCatQr => translate('faq_cat_qr');
  String get faqCatCloud => translate('faq_cat_cloud');
  String get faqCatOffline => translate('faq_cat_offline');
  String get faqCatPrivacy => translate('faq_cat_privacy');
  String get faqCatTroubleshooting => translate('faq_cat_troubleshooting');
  String get faqHelpfulQuestion => translate('faq_helpful_question');
  String get faqHelpfulYes => translate('faq_helpful_yes');
  String get faqHelpfulNo => translate('faq_helpful_no');
  String get faqHelpfulThanks => translate('faq_helpful_thanks');
  String get faqSupportTitle => translate('faq_support_title');
  String get faqSupportDesc => translate('faq_support_desc');
  String get faqSupportEmailBtn => translate('faq_support_email_btn');
  String get faqSupportGuideBtn => translate('faq_support_guide_btn');
    String get faqCopiedEmail => translate('faq_copied_email');

  // Master Add Trip Getters
  String get createTripHeroTitle => translate('create_trip_hero_title');
  String get createTripHeroSub => translate('create_trip_hero_sub');
  String get createTripBadgeStats => translate('create_trip_badge_stats');
  String get createTripLivePreview => translate('create_trip_live_preview');
  String get createTripSecIdentity => translate('create_trip_sec_identity');
  String get createTripSecExperience => translate('create_trip_sec_experience');
  String get createTripSecCurrency => translate('create_trip_sec_currency');
  String get createTripSecCrew => translate('create_trip_sec_crew');
  String get createTripCrewOrganizer => translate('create_trip_crew_organizer');
  String createTripCrewCount(int count) => translate('create_trip_crew_count').replaceAll('{count}', count.toString());
  String get createTripModeRecommended => translate('create_trip_mode_recommended');
  String get createTripModeSplitFeature1 => translate('create_trip_mode_split_feature1');
  String get createTripModeSplitFeature2 => translate('create_trip_mode_split_feature2');
  String get createTripModeJourneyFeature1 => translate('create_trip_mode_journey_feature1');
  String get createTripModeJourneyFeature2 => translate('create_trip_mode_journey_feature2');
  String get createTripDraftingBadge => translate('create_trip_drafting_badge');
  String get createTripCtaReady => translate('create_trip_cta_ready');
    String get createTripCtaEmpty => translate('create_trip_cta_empty');

  // Master Add Expense Getters
  String get expenseSecAmount => translate('expense_sec_amount');
  String get expenseSecDetails => translate('expense_sec_details');
  String get expenseSecPayer => translate('expense_sec_payer');
  String get expenseSecSplit => translate('expense_sec_split');
  String get expenseQuickAdd => translate('expense_quick_add');
  String get expenseSelectAll => translate('expense_select_all');
  String get expenseDeselectAll => translate('expense_deselect_all');
  String get expenseYouTag => translate('expense_you_tag');
  String expenseSplitSummary(int count) => translate('expense_split_summary').replaceAll('{count}', count.toString());
  String expenseSplitMatched(String amount) => translate('expense_split_matched').replaceAll('{amount}', amount);
  String expenseSplitRemaining(String amount) => translate('expense_split_remaining').replaceAll('{amount}', amount);
  String expenseSplitExceeds(String amount) => translate('expense_split_exceeds').replaceAll('{amount}', amount);
  String get expensePctMatched => translate('expense_pct_matched');
  String expensePctTotal(String pct) => translate('expense_pct_total').replaceAll('{pct}', pct);
  String get expenseExplainSplitTitle => translate('expense_explain_split_title');
  String get expenseExplainGotIt => translate('expense_explain_got_it');
  String get expenseSaveSuccess => translate('expense_save_success');
  String get expenseZeroLossPill => translate('expense_zero_loss_pill');

  // Master Join Trip Getters
  String get joinTripTitle => translate('join_trip_title');
  String get joinTripSubtitle => translate('join_trip_subtitle');
  String get joinSecCode => translate('join_sec_code');
  String get joinSecQr => translate('join_sec_qr');
  String get joinPasteChip => translate('join_paste_chip');
  String get joinClearChip => translate('join_clear_chip');
  String get joinFindTripBtn => translate('join_find_trip_btn');
  String get joinScanQrBtn => translate('join_scan_qr_btn');
  String get joinPreviewTitle => translate('join_preview_title');
  String get joinPreviewHost => translate('join_preview_host');
  String get joinPreviewMembers => translate('join_preview_members');
  String get joinPreviewMode => translate('join_preview_mode');
  String get joinPreviewCurrency => translate('join_preview_currency');
  String get joinPreviewConfirm => translate('join_preview_confirm');
  String get joinPreviewCancel => translate('join_preview_cancel');
  String get joinStageValidating => translate('join_stage_validating');
  String get joinStageJoining => translate('join_stage_joining');
  String get joinStageSyncing => translate('join_stage_syncing');
  String get joinErrEmpty => translate('join_err_empty');
  String get joinSuccessToast => translate('join_success_toast');
  // Notifications Getters
  String get notificationsTitle => translate('notifications_title');
  String get notificationsMarkRead => translate('notifications_mark_read');
  String get notificationsEmptyTitle => translate('notifications_empty_title');
  String get notificationsEmptyDesc => translate('notifications_empty_desc');
  String get notificationsTabAll => translate('notifications_tab_all');
  String get notificationsTabExpenses => translate('notifications_tab_expenses');
  String get notificationsTabSettlements => translate('notifications_tab_settlements');
  String get notificationsTabTrips => translate('notifications_tab_trips');
  String get notificationsSettingsTitle => translate('notifications_settings_title');
  String get notificationsPushToggle => translate('notifications_push_toggle');
  String get notificationsExpenseToggle => translate('notifications_expense_toggle');
  String get notificationsSettleToggle => translate('notifications_settle_toggle');
  String get notificationsTripToggle => translate('notifications_trip_toggle');

  // Payment Methods Getters
  String get paymentsTitle => translate('payments_title');
  String get paymentsSubtitle => translate('payments_subtitle');
  String get paymentsAddUpiBtn => translate('payments_add_upi_btn');
  String get paymentsPrimaryBadge => translate('payments_primary_badge');
  String get paymentsShareQr => translate('payments_share_qr');
  String get paymentsCopyUpi => translate('payments_copy_upi');
  String get paymentsCopiedToast => translate('payments_copied_toast');
  String get paymentsSavedTitle => translate('payments_saved_title');
  String get paymentsAddSheetTitle => translate('payments_add_sheet_title');
  String get paymentsAddSheetDesc => translate('payments_add_sheet_desc');
  String get paymentsAddInputLabel => translate('payments_add_input_label');
  String get paymentsAddInputHint => translate('payments_add_input_hint');
  String get paymentsSetDefault => translate('payments_set_default');
  String get paymentsSaveBtn => translate('payments_save_btn');
  String get paymentsBankTitle => translate('payments_bank_title');
  String get paymentsBankVerified => translate('payments_bank_verified');
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
