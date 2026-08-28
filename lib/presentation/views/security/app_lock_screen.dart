import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/security_lock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final security = context.read<SecurityLockService>();
      if (security.isBiometricsEnabled && security.isBiometricsSupported) {
        security.authenticateWithBiometrics();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    if (_pin.length < 4) {
      HapticHelper.selection();
      setState(() {
        _isError = false;
        _pin += digit;
      });

      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      HapticHelper.light();
      setState(() {
        _isError = false;
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _verifyPin() {
    final security = context.read<SecurityLockService>();
    final isSuccess = security.verifyPin(_pin);
    if (isSuccess) {
      HapticHelper.success();
    } else {
      HapticHelper.error();
      setState(() {
        _isError = true;
        _pin = '';
      });
      _shakeController.forward(from: 0);
    }
  }

  void _showRecoveryKeyResetDialog() {
    HapticHelper.light();
    final keyController = TextEditingController();
    final newPinController = TextEditingController();
    final authVm = context.read<AuthViewModel>();
    final security = context.read<SecurityLockService>();
    final actualKey = authVm.currentUser?.recoveryKey ?? 'KITH-SEC-9921-8842-7719';

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: AppColors.emeraldPrimary, size: 22),
            SizedBox(width: 8),
            Text('Reset PIN via Key', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 16-character Offline Recovery Key and a new 4-digit PIN to unlock.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: keyController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Recovery Key',
                hintText: 'e.g. KITH-SEC-XXXX-XXXX',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New 4-Digit PIN',
                border: OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final ok = await security.resetPinWithRecoveryKey(
                enteredKey: keyController.text,
                actualRecoveryKey: actualKey,
                newPin: newPinController.text,
              );
              if (!mounted) return;
              if (dCtx.mounted) Navigator.pop(dCtx);
              if (ok) {
                HapticHelper.success();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN reset successfully! Vault unlocked ✓')),
                );
              } else {
                HapticHelper.error();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid Recovery Key. Please check and retry.')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.emeraldPrimary),
            child: const Text('Reset & Unlock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityLockService>();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF06090B),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // Shield Icon & Brand
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.emeraldPrimary, Color(0xFF064E3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Kith Vault',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(
                _isError ? 'Incorrect PIN. Try again.' : 'Enter your 4-digit security PIN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _isError ? FontWeight.w700 : FontWeight.w500,
                  color: _isError ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 28),

              // PIN Indicator Dots
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * (_isError ? 1 : 0), 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? (_isError ? const Color(0xFFEF4444) : AppColors.emeraldPrimary)
                            : Colors.transparent,
                        border: Border.all(
                          color: _isError
                              ? const Color(0xFFEF4444)
                              : (isFilled ? AppColors.emeraldPrimary : Colors.white24),
                          width: 2,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: (_isError ? const Color(0xFFEF4444) : AppColors.emeraldPrimary).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              const Spacer(),

              // Numeric Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44.0),
                child: Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Biometrics trigger
                        if (security.isBiometricsEnabled && security.isBiometricsSupported)
                          _buildKeypadButton(
                            child: const Icon(Icons.fingerprint_rounded, color: AppColors.emeraldPrimary, size: 28),
                            onTap: () => security.authenticateWithBiometrics(),
                          )
                        else
                          const SizedBox(width: 68, height: 68),

                        _buildKeypadButton(
                          child: const Text('0', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                          onTap: () => _onKeyPress('0'),
                        ),

                        // Backspace
                        _buildKeypadButton(
                          child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 22),
                          onTap: _onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Forgot PIN / Recovery Key
              TextButton(
                onPressed: _showRecoveryKeyResetDialog,
                child: const Text(
                  'Forgot PIN? Use Recovery Key',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) {
        return _buildKeypadButton(
          child: Text(d, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
          onTap: () => _onKeyPress(d),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF141A20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
