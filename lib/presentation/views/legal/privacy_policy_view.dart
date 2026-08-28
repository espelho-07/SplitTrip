import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/surface_card.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.privacyTitle),
            Text(
              'Kith by Nirniq',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.darkSurfaceCard, AppColors.darkSurfaceSubtle]
                      : [AppColors.emeraldPrimary.withValues(alpha: 0.08), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.xlBorder,
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_outlined, color: AppColors.emeraldPrimary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.privacyTitle,
                              style: AppTypography.titleMedium(isDark: isDark),
                            ),
                            Text(
                              'Effective Date: August 2026',
                              style: AppTypography.bodySmall(isDark: isDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Kith is designed with a strict privacy-first architecture. We minimize data collection, operate with zero ad-trackers, and ensure you retain complete ownership of your personal financial records.',
                    style: AppTypography.bodyMedium(isDark: isDark),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 1. DATA WE COLLECT
            _buildSection(
              title: '1. Information We Collect',
              icon: Icons.inventory_2_outlined,
              isDark: isDark,
              items: [
                'Account Information: When you sign in with Google or create an account, we receive your email address, display name, and avatar URL to authenticate your session across devices.',
                'Guest Credentials: If you use Guest Mode, an anonymous identifier and cryptographic Recovery Key are generated strictly to restore your session.',
                'User-Provided Expenses & Trips: Expense titles, amounts, split ratios, trip names, and categories that you manually enter into the app.',
                'Diagnostic & Sync State: Sync queue metadata and timestamps required to synchronize offline edits when internet connection is restored.',
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // 2. DATA WE DO NOT COLLECT
            _buildSection(
              title: '2. Data We NEVER Collect',
              icon: Icons.block_outlined,
              isDark: isDark,
              highlightColor: AppColors.roseAccent,
              items: [
                'NO Bank Logins or Credit Card Numbers: Kith never asks for or stores real banking credentials or payment card details.',
                'NO Location Tracking: Kith does not access or track your GPS location.',
                'NO Background Audio or Microphone Snooping: The microphone is only active in the foreground during explicit user voice capture.',
                'NO Contacts or Biometrics: We do not harvest your phone contact book or store biometric data.',
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // 3. PURPOSE OF DATA USE
            _buildSection(
              title: '3. How We Use Your Data',
              icon: Icons.tune_rounded,
              isDark: isDark,
              items: [
                'App Functionality: Calculating mathematical splits, computing net balances, tracking personal budgets, and providing offline-first access.',
                'Cross-Device Synchronization: Encrypting and syncing your trips and personal ledgers across your authorized devices.',
                'Security & Fraud Prevention: Rate-limiting session recovery attempts to protect account keys from brute force attacks.',
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // 4. FINANCIAL SERVICES DISCLAIMER
            _buildSection(
              title: '4. Financial Services Disclaimer',
              icon: Icons.account_balance_outlined,
              isDark: isDark,
              items: [
                'Kith is an informational manual expense tracking and mathematical split utility.',
                'Kith is NOT a bank, Non-Banking Financial Company (NBFC), money transmitter, lender, or payment processor.',
                'Marking a payment as "Paid" or "Settled" in Kith is a manual user declaration of an offline transaction and does NOT execute, process, or verify a real-world bank transfer.',
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // 5. DATA RETENTION & ACCOUNT DELETION
            _buildSection(
              title: '5. Account & Data Deletion',
              icon: Icons.delete_forever_outlined,
              isDark: isDark,
              highlightColor: Colors.redAccent,
              items: [
                'In-App Immediate Deletion: You can permanently delete your account, trips, expenses, and cloud backups at any time directly from Profile → Delete Account & Cloud Data.',
                'Web Deletion Request: You may also request complete data purging by emailing support@kith.app with your registered email or recovery key.',
                'Instant Purge: When an account is deleted, all cloud sessions, personal expenses, debts, repayments, and group memberships are immediately purged from our servers.',
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // 6. THIRD-PARTY INFRASTRUCTURE
            _buildSection(
              title: '6. Third-Party Sub-Processors',
              icon: Icons.cloud_outlined,
              isDark: isDark,
              items: [
                'Google Cloud & Firebase: Used for OAuth 2.0 authentication and app distribution.',
                'Supabase / PostgreSQL: Encrypted cloud database for multi-device synchronization.',
                'Zero Advertising SDKs: Kith contains zero third-party advertising SDKs, ad-trackers, or data brokers.',
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // 7. CHILDREN PRIVACY
            _buildSection(
              title: '7. Children’s Privacy',
              icon: Icons.child_care_rounded,
              isDark: isDark,
              items: [
                'Kith is not directed at children under the age of 13. We do not knowingly collect personal information from children.',
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // 8. CONTACT DEVELOPER
            _buildSection(
              title: '8. Contact & Developer Details',
              icon: Icons.mail_outline_rounded,
              isDark: isDark,
              items: [
                'Developer: Nirniq Technologies',
                'Product: Kith Expense & Trip Ledger',
                'Email: support@kith.app / contact@nirniq.dev',
                'Website: https://kith.app',
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            AppButton(
              text: l10n.actionDone,
              variant: AppButtonVariant.primary,
              isFullWidth: true,
              onPressed: () => Navigator.pop(context),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required bool isDark,
    Color? highlightColor,
  }) {
    final color = highlightColor ?? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary);

    return SurfaceCard(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
