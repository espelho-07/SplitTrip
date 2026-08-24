import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../domain/engine/qr_code_parser.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> with SingleTickerProviderStateMixin {
  bool _isTorchOn = false;
  final TextEditingController _manualInputController = TextEditingController();
  late AnimationController _sweepAnimController;

  @override
  void initState() {
    super.initState();
    _sweepAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweepAnimController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _onCodeDetected(String rawCode) {
    final cleanCode = QrCodeParser.extractInviteCode(rawCode);
    if (cleanCode != null) {
      HapticHelper.success();
      context.pop(cleanCode);
    } else {
      HapticHelper.light();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unrecognized QR code or link format')),
      );
    }
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
                _onCodeDetected(code);
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Scan Trip Invite', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? AppColors.amberAccent : Colors.white70,
            ),
            onPressed: () {
              HapticHelper.light();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Viewfinder scanning frame
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: AppRadius.lgBorder,
                      border: Border.all(
                        color: AppColors.emeraldPrimary.withValues(alpha: 0.8),
                        width: 2.5,
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
                          height: 2,
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
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Camera viewfinder overlay label
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: AppRadius.fullBorder,
                      ),
                      child: const Text(
                        'Align QR within frame',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Hold camera steady over a friend\'s Kith QR invite code to join their trip instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ),

            const Spacer(),

            // Manual Code Entry fallback
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
      ),
    );
  }
}
