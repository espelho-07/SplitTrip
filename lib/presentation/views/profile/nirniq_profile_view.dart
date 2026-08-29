import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/payment/upi_validator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/services/local_storage_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/progress/progress.dart';

/// Dedicated Nirniq Profile & User Management View.
/// Allows updating display name, phone number, email, receiving UPI ID, bio, and avatar.
class NirniqProfileView extends StatefulWidget {
  const NirniqProfileView({super.key});

  @override
  State<NirniqProfileView> createState() => _NirniqProfileViewState();
}

class _NirniqProfileViewState extends State<NirniqProfileView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _upiController;
  late TextEditingController _bioController;

  String? _selectedAvatarUrl;
  bool _isSaving = false;

  static const List<String> _suggestedAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150',
    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
  ];

  @override
  void initState() {
    super.initState();
    final authVm = context.read<AuthViewModel>();
    final storage = context.read<LocalStorageService>();
    final user = authVm.currentUser;

    final savedPhone = storage.getString('user_phone_number') ?? '';
    final savedBio = storage.getString('user_bio') ?? 'Traveler & split-trip enthusiast 🌍';
    final savedUpi = storage.getPrimaryUpiId() ?? user?.upiId ?? '';

    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: savedPhone);
    _emailController = TextEditingController(text: user?.email ?? '');
    _upiController = TextEditingController(text: savedUpi);
    _bioController = TextEditingController(text: savedBio);
    _selectedAvatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _upiController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) {
      HapticHelper.error();
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final upi = _upiController.text.trim();
    final bio = _bioController.text.trim();

    if (upi.isNotEmpty && !UpiValidator.isValidUpiId(upi)) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileErrUpi),
          backgroundColor: AppColors.negativeRedDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticHelper.medium();

    final authVm = context.read<AuthViewModel>();
    final updated = await authVm.updateUserProfile(
      displayName: name,
      phoneNumber: phone,
      avatarUrl: _selectedAvatarUrl,
      email: email,
      upiId: upi,
      bio: bio,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (updated != null) {
        HapticHelper.success();
        KithSuccessToast.show(context, l10n.profileSavedToast);
        context.pop();
      } else {
        HapticHelper.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileErrSave),
            backgroundColor: AppColors.negativeRedDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;
    final isNirniqLinked = user?.isNirniqLinked ?? false;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.profileEditTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF14B8A6)),
                    ),
                  )
                : TextButton(
                    onPressed: _handleSave,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF14B8A6),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    child: Text(l10n.actionSave),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // ─── 1. AVATAR & HEADER ──────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF14B8A6),
                            width: 2.5,
                          ),
                        ),
                        child: MemberAvatar(
                          name: _nameController.text.isEmpty ? 'Traveler' : _nameController.text,
                          avatarUrl: _selectedAvatarUrl,
                          size: 90,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF14B8A6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Preset Avatar Suggestions
                  SizedBox(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.profilePresetLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...List.generate(_suggestedAvatars.length, (idx) {
                          final url = _suggestedAvatars[idx];
                          final isSelected = _selectedAvatarUrl == url;
                          return GestureDetector(
                            onTap: () {
                              HapticHelper.selection();
                              setState(() => _selectedAvatarUrl = isSelected ? null : url);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                border: isSelected
                                    ? Border.all(color: const Color(0xFF14B8A6), width: 2)
                                    : Border.all(color: isDark ? Colors.white24 : Colors.black12),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 2. ACCOUNT STATUS BADGE ────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1418) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF14B8A6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNirniqLinked ? l10n.profileVerifiedIdentity : l10n.profileGuestLocal,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          isNirniqLinked
                              ? l10n.profileConnectedCloud
                              : l10n.profileLocalOnlyDesc,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── 3. FORM FIELDS SECTION ──────────────────────────────────
            _buildSectionCard(
              title: l10n.profilePersonalDetails.toUpperCase(),
              isDark: isDark,
              children: [
                _buildFormField(
                  label: l10n.profileNameLabel,
                  controller: _nameController,
                  icon: Icons.person_outline_rounded,
                  hint: l10n.profileNameHint,
                  isDark: isDark,
                  validator: (v) => v == null || v.trim().isEmpty ? l10n.profileNameHint : null,
                ),
                const SizedBox(height: 14),
                _buildFormField(
                  label: l10n.profilePhoneLabel,
                  controller: _phoneController,
                  icon: Icons.phone_android_rounded,
                  hint: l10n.profilePhoneHint,
                  keyboardType: TextInputType.phone,
                  isDark: isDark,
                  helperText: l10n.profilePhoneSub,
                ),
                const SizedBox(height: 14),
                _buildFormField(
                  label: l10n.profileEmailLabel,
                  controller: _emailController,
                  icon: Icons.alternate_email_rounded,
                  hint: l10n.profileEmailHint,
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _buildFormField(
                  label: l10n.profileBioLabel,
                  controller: _bioController,
                  icon: Icons.chat_bubble_outline_rounded,
                  hint: l10n.profileBioHint,
                  maxLines: 2,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ─── 4. PAYMENT & UPI CONFIG ────────────────────────────────
            _buildSectionCard(
              title: l10n.profilePaymentSection.toUpperCase(),
              isDark: isDark,
              children: [
                _buildFormField(
                  label: l10n.profileUpiLabel,
                  controller: _upiController,
                  icon: Icons.account_balance_wallet_outlined,
                  hint: l10n.profileUpiHint,
                  isDark: isDark,
                  helperText: l10n.profileUpiSub,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ─── 5. SAVE BUTTON ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.profileSaveBtn,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: maxLines > 1 ? 12.0 : 0.0),
                child: Icon(icon, size: 20, color: const Color(0xFF14B8A6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                  ),
                  decoration: KithInputDecoration.borderless(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                    ),
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
