import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../domain/engine/qr_code_parser.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _sweepAnimController;
  final TextEditingController _manualInputController = TextEditingController();

  bool _isTorchOn = false;
  bool _hasCameraPermission = true;
  bool _isProcessingCode = false;

  @override
  void initState() {
    super.initState();
    _sweepAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _initCameraPermission();
  }

  Future<void> _initCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasCameraPermission = status.isGranted;
      });
    }
  }

  @override
  void dispose() {
    _sweepAnimController.dispose();
    _manualInputController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleCodeExtracted(String cleanCode) {
    if (_isProcessingCode) return;
    _isProcessingCode = true;
    HapticHelper.success();

    if (Navigator.of(context).canPop()) {
      context.pop(cleanCode);
    } else {
      context.pushReplacement('/join-trip?code=$cleanCode');
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessingCode) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        final cleanCode = QrCodeParser.extractInviteCode(rawValue);
        if (cleanCode != null) {
          _handleCodeExtracted(cleanCode);
          return;
        } else {
          // Unrecognized or non-Kith QR code: never display raw URL
          _isProcessingCode = true;
          HapticHelper.error();
          _showInvalidQrDialog();
          return;
        }
      }
    }
  }

  void _showInvalidQrDialog() {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: AppColors.negativeRedDark, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.qrInvalidTitle,
                style: AppTypography.titleSmall(isDark: isDark),
              ),
            ),
          ],
        ),
        content: Text(
          'Please scan a valid Kith group trip QR code or enter the 6-character code manually.',
          style: AppTypography.bodySmall(isDark: isDark),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullBorder),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() => _isProcessingCode = false);
                }
              });
            },
            child: Text(l10n.qrScanAgain),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Trip Code'),
        content: TextField(
          controller: _manualInputController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: 'e.g. MNL123',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final code = _manualInputController.text.trim();
              Navigator.of(ctx).pop();
              if (code.isNotEmpty) {
                final cleanCode = QrCodeParser.extractInviteCode(code);
                if (cleanCode != null) {
                  _handleCodeExtracted(cleanCode);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid 6-character trip code')),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Scan Trip Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? AppColors.amberAccent : Colors.white70,
            ),
            onPressed: () async {
              HapticHelper.light();
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white70),
            onPressed: () async {
              HapticHelper.light();
              await _scannerController.switchCamera();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Live Camera Feed or Permission Fallback
            if (_hasCameraPermission)
              Positioned.fill(
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.white54),
                            const SizedBox(height: 12),
                            const Text(
                              'Unable to initialize camera preview',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error.errorDetails?.message ?? 'Please check camera permissions in Settings.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            AppButton(
                              text: 'Enter Code Instead',
                              variant: AppButtonVariant.primary,
                              onPressed: _showManualEntryDialog,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_rounded, size: 54, color: AppColors.amberAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Permission Needed',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kith requires camera access to scan QR invite codes. Grant camera permission or enter the code manually.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Allow Camera Access',
                        variant: AppButtonVariant.primary,
                        onPressed: () async {
                          await openAppSettings();
                          _initCameraPermission();
                        },
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        text: 'Enter Code Manually',
                        variant: AppButtonVariant.secondary,
                        onPressed: _showManualEntryDialog,
                      ),
                    ],
                  ),
                ),
              ),

            // Camera Overlay & Viewfinder Framing
            if (_hasCameraPermission)
              Column(
                children: [
                  const Spacer(),

                  // Viewfinder Box
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.lgBorder,
                            border: Border.all(
                              color: AppColors.emeraldPrimary.withValues(alpha: 0.9),
                              width: 3.0,
                            ),
                          ),
                        ),

                        // Animated laser scan line
                        AnimatedBuilder(
                          animation: _sweepAnimController,
                          builder: (context, child) {
                            return Positioned(
                              top: 20 + (_sweepAnimController.value * 220),
                              child: Container(
                                width: 240,
                                height: 2.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppColors.emeraldLight,
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.emeraldLight.withValues(alpha: 0.8),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Align Label
                        Positioned(
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: AppRadius.fullBorder,
                            ),
                            child: const Text(
                              'Align QR within frame',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Hold camera steady over a friend\'s Kith QR invite code to join their trip instantly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4, shadows: [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ]),
                    ),
                  ),

                  const Spacer(),

                  // Manual Entry Shortcut
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: AppButton(
                      text: 'Enter Code Instead',
                      icon: Icons.keyboard_rounded,
                      variant: AppButtonVariant.secondary,
                      isFullWidth: true,
                      onPressed: _showManualEntryDialog,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

