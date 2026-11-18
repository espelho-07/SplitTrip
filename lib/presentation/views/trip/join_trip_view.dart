import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/services/permission_service.dart';
import '../../../data/services/p2p_sync_service.dart';
import '../../../core/widgets/kith_brand.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/engine/qr_code_parser.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/join_trip_viewmodel.dart';
import '../../widgets/progress/progress.dart';
import 'qr_scanner_view.dart';
import 'widgets/join_preview_sheet.dart';

/// Master Join Trip View featuring tactile 6-character code input,
/// clipboard auto-paste, holographic QR scanner deck, and live preview sheet.
class JoinTripView extends StatefulWidget {
  final String? initialCode;
  final String? claimMemberId;
  final String? claimToken;

  const JoinTripView({
    super.key,
    this.initialCode,
    this.claimMemberId,
    this.claimToken,
  });

  @override
  State<JoinTripView> createState() => _JoinTripViewState();
}

class _JoinTripViewState extends State<JoinTripView> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _claimMemberId;
  String? _claimToken;

  @override
  void initState() {
    super.initState();
    _claimMemberId = widget.claimMemberId;
    _claimToken = widget.claimToken;
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      final sanitized = widget.initialCode!.trim().toUpperCase();
      _codeController.text = sanitized;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePreviewOrJoin(sanitized);
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    HapticHelper.selection();
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      final text = clipboardData.text!.trim();
      final parsed = QrCodeParser.parsePayload(text);
      if (parsed != null && parsed.inviteCode.isNotEmpty) {
        _claimMemberId = parsed.claimMemberId;
        _claimToken = parsed.claimToken;
        final codeToSet = parsed.inviteCode.toUpperCase();
        setState(() {
          _codeController.text = codeToSet;
        });
        if (mounted) context.read<JoinTripViewModel>().setCode(codeToSet);
        if (codeToSet.length >= 4) {
          _handlePreviewOrJoin(codeToSet);
        }
        return;
      }
      final parsedCode = QrCodeParser.extractInviteCode(text);
      final memberId = QrCodeParser.extractClaimMemberId(text);
      final token = QrCodeParser.extractClaimToken(text);
      if (memberId != null) _claimMemberId = memberId;
      if (token != null) _claimToken = token;
      final codeToSet = parsedCode ?? text.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
      if (codeToSet.isNotEmpty) {
        setState(() {
          _codeController.text = codeToSet;
        });
        if (mounted) context.read<JoinTripViewModel>().setCode(codeToSet);
        if (codeToSet.length >= 4) {
          _handlePreviewOrJoin(codeToSet);
        }
      }
    }
  }

  Future<void> _handlePreviewOrJoin([String? directCode]) async {
    _focusNode.unfocus();

    final joinVm = context.read<JoinTripViewModel>();
    final authVm = context.read<AuthViewModel>();
    final l10n = context.l10n;

    final user = authVm.currentUser;
    if (user == null) return;

    final targetCode = (directCode ?? _codeController.text).trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (targetCode.isEmpty || targetCode.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.joinErrEmpty),
          backgroundColor: AppColors.negativeRedDark,
        ),
      );
      return;
    }

    joinVm.setCode(targetCode);
    _codeController.text = targetCode;

    final preview = await joinVm.fetchPreview(targetCode);
    if (preview != null && mounted) {
      _showPreviewSheet(preview);
    } else if (mounted) {
      HapticHelper.error();
      final err = joinVm.errorMessage ?? 'This trip does not exist. Check the code and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.negativeRedDark,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleOpenQrScanner() async {
    _focusNode.unfocus();
    HapticHelper.medium();
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerView()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      final parsed = QrCodeParser.parsePayload(scannedCode);
      if (parsed != null && parsed.inviteCode.isNotEmpty) {
        _claimMemberId = parsed.claimMemberId;
        _claimToken = parsed.claimToken;
        final sanitized = parsed.inviteCode.trim().toUpperCase();
        _codeController.text = sanitized;
        _handlePreviewOrJoin(sanitized);
        return;
      }
      final memberId = QrCodeParser.extractClaimMemberId(scannedCode);
      final token = QrCodeParser.extractClaimToken(scannedCode);
      if (memberId != null) _claimMemberId = memberId;
      if (token != null) _claimToken = token;
      final sanitized = (QrCodeParser.extractInviteCode(scannedCode) ?? scannedCode).trim().toUpperCase();
      _codeController.text = sanitized;
      _handlePreviewOrJoin(sanitized);
    }
  }

  Future<void> _executeJoinFlow(String code, {String? claimMemberId, String? claimToken}) async {
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final joinVm = context.read<JoinTripViewModel>();
    final l10n = context.l10n;

    final user = authVm.currentUser;
    if (user == null) return;

    _focusNode.unfocus();

    // Upfront permission acquisition for nearby P2P auto-sync before joining
    await PermissionService.requestNearbyPermissions();
    if (!mounted) return;

    final effectiveMemberId = claimMemberId ?? _claimMemberId;
    final effectiveToken = claimToken ?? _claimToken;

    final stageNotifier = ValueNotifier<int>(0);
    final stages = [
      ProgressStage(label: l10n.joinStageValidating, description: 'Code: $code'),
      ProgressStage(label: l10n.joinStageJoining, description: user.displayName),
      ProgressStage(label: l10n.joinStageSyncing, description: l10n.tripsBalances),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => ValueListenableBuilder<int>(
        valueListenable: stageNotifier,
        builder: (ctx, activeStage, _) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: KithStageProgress(
                title: l10n.tripsJoin,
                stages: stages,
                currentStageIndex: activeStage,
              ),
            ),
          );
        },
      ),
    );

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) stageNotifier.value = 1;
    });
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) stageNotifier.value = 2;
    });

    final trip = await joinVm.joinTrip(user, code, effectiveMemberId, effectiveToken);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress

      if (trip != null) {
        await homeVm.loadTrips(user.id);
        if (mounted) {
          try {
            final p2p = Provider.of<P2PSyncService?>(context, listen: false);
            p2p?.broadcastBeacon();
          } catch (_) {}
        }
        if (mounted) {
          GoRouter.of(context).go('/trip/${trip.id}');
          KithSuccessToast.show(context, l10n.joinSuccessToast);
        }
      } else {
        HapticHelper.error();
        final err = joinVm.errorMessage ?? 'Could not join trip. Please verify the code and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.negativeRedDark,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _executeJoinFlow(code, claimMemberId: claimMemberId, claimToken: claimToken),
            ),
          ),
        );
      }
    }
  }

  void _showPreviewSheet(dynamic preview) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Consumer<JoinTripViewModel>(
          builder: (context, joinVm, child) {
            return JoinPreviewSheet(
              preview: preview,
              isJoining: joinVm.isJoining,
              initialClaimMemberId: _claimMemberId,
              initialClaimToken: _claimToken,
              onConfirmJoin: ({String? claimMemberId, String? claimToken}) async {
                Navigator.of(bottomSheetContext).pop();
                final codeToJoin = (preview.inviteCode != null && (preview.inviteCode as String).isNotEmpty)
                    ? preview.inviteCode as String
                    : (preview.tripId as String? ?? _codeController.text.trim());
                await _executeJoinFlow(
                  codeToJoin,
                  claimMemberId: claimMemberId ?? _claimMemberId,
                  claimToken: claimToken ?? _claimToken,
                );
              },
              onCancel: () {
                Navigator.of(bottomSheetContext).pop();
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final joinVm = context.watch<JoinTripViewModel>();
    final l10n = context.l10n;
    final codeText = _codeController.text;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Ambient Top-Right Radial Glow
          if (isDark)
            Positioned(
              top: -80,
              right: -50,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.emeraldLight.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                // 1. Master Top Bar
                _buildTopBar(context, isDark, l10n),

                // 2. Main Content Stream
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Header
                        Text(
                          l10n.joinTripTitle,
                          style: AppTypography.titleLarge(isDark: isDark).copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.joinTripSubtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Section 1: Tactile 6-Character Invite Code Deck
                        _buildSectionHeader(l10n.joinSecCode, isDark),
                        const SizedBox(height: 10),
                        _buildCodeInputDeck(context, isDark, l10n, codeText, joinVm),

                        const SizedBox(height: AppSpacing.xxl),

                        // Section 2: Holographic QR Scanner Deck
                        _buildSectionHeader(l10n.joinSecQr, isDark),
                        const SizedBox(height: 10),
                        _buildQrScannerDeck(context, isDark, l10n),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Glass Back Button
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              context.pop();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),

          // Master Brand Center Tag
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KithLogoMark(size: 18, isDark: isDark),
              const SizedBox(width: 8),
              Text(
                'KITH · JOIN TRIP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),

          // Balance space
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.emeraldLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildCodeInputDeck(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    String codeText,
    JoinTripViewModel joinVm,
  ) {
    return SurfaceCard(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // 6-Character Interactive Cells Matrix
          GestureDetector(
            onTap: () {
              _focusNode.requestFocus();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final char = index < codeText.length ? codeText[index] : '';
                final isCurrent = index == codeText.length;
                final isFilled = index < codeText.length;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 46,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? (isFilled ? const Color(0xFF1E2630) : const Color(0xFF12181E))
                        : (isFilled ? Colors.white : AppColors.lightSurfaceSubtle),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? AppColors.emeraldLight
                          : (isFilled
                              ? (isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong)
                              : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle)),
                      width: isCurrent ? 2.0 : 1.2,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppColors.emeraldLight.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    char,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                );
              }),
            ),
          ),

          // Hidden Input Field for Native Keystrokes
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              height: 0,
              child: TextField(
                focusNode: _focusNode,
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                autofocus: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                onChanged: (val) {
                  setState(() {});
                  joinVm.setCode(val.toUpperCase());
                  if (val.length == 6) {
                    _handlePreviewOrJoin(val.toUpperCase());
                  }
                },
                onSubmitted: (_) => _handlePreviewOrJoin(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Micro Action Chips (Paste from Clipboard & Clear)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pasteFromClipboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161D24) : AppColors.lightSurfaceSubtle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_paste_rounded, size: 14, color: AppColors.emeraldLight),
                      const SizedBox(width: 6),
                      Text(
                        l10n.joinPasteChip,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (codeText.isNotEmpty) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    HapticHelper.light();
                    setState(() => _codeController.clear());
                    joinVm.setCode('');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161D24) : AppColors.lightSurfaceSubtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        const SizedBox(width: 4),
                        Text(
                          l10n.joinClearChip,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (joinVm.errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.negativeRedDark.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.negativeRedDark.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.negativeRedDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      joinVm.errorMessage!,
                      style: const TextStyle(color: AppColors.negativeRedDark, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Primary Glowing Button
          GestureDetector(
            onTap: (joinVm.isLoadingPreview || joinVm.isJoining) ? null : () => _handlePreviewOrJoin(),
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldLight.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: (joinVm.isLoadingPreview || joinVm.isJoining)
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.joinFindTripBtn,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrScannerDeck(BuildContext context, bool isDark, AppLocalizations l10n) {
    return SurfaceCard(
      onTap: _handleOpenQrScanner,
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // Holographic Viewfinder Icon Container
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161D24) : AppColors.lightSurfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              size: 32,
              color: AppColors.emeraldLight,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.joinScanQrBtn,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan a trip invite code instantly via camera',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ],
      ),
    );
  }
}
