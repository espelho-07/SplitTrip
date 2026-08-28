import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/security_lock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';

class SetPinSheet extends StatefulWidget {
  final VoidCallback? onPinSet;
  const SetPinSheet({super.key, this.onPinSet});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SetPinSheet(),
    );
  }

  @override
  State<SetPinSheet> createState() => _SetPinSheetState();
}

class _SetPinSheetState extends State<SetPinSheet> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  void _onKeyPress(String digit) {
    HapticHelper.selection();
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += digit;
          if (_pin.length == 4) {
            _isConfirming = true;
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += digit;
          if (_confirmPin.length == 4) {
            _handleComplete();
          }
        }
      }
    });
  }

  void _onBackspace() {
    HapticHelper.light();
    setState(() {
      _errorMessage = null;
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _handleComplete() async {
    if (_pin == _confirmPin) {
      final security = context.read<SecurityLockService>();
      await security.setPin(_pin);
      HapticHelper.success();
      if (mounted) {
        Navigator.pop(context, true);
        widget.onPinSet?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App Lock PIN set successfully 🔒 ✓')),
        );
      }
    } else {
      HapticHelper.error();
      setState(() {
        _errorMessage = 'PINs do not match. Please start over.';
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activePin = _isConfirming ? _confirmPin : _pin;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.shield_rounded, color: AppColors.emeraldPrimary, size: 36),
            const SizedBox(height: 10),
            Text(
              _isConfirming ? 'Confirm 4-Digit PIN' : 'Create 4-Digit Security PIN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? (_isConfirming ? 'Re-enter your PIN to verify' : 'This PIN protects your Kith offline vault on launch'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: _errorMessage != null ? FontWeight.w700 : FontWeight.w500,
                color: _errorMessage != null ? const Color(0xFFEF4444) : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            const SizedBox(height: 20),

            // Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final isFilled = i < activePin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppColors.emeraldPrimary : Colors.transparent,
                    border: Border.all(color: isFilled ? AppColors.emeraldPrimary : Colors.grey.withValues(alpha: 0.5), width: 2),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _buildKeyRow(['1', '2', '3'], isDark),
                  const SizedBox(height: 12),
                  _buildKeyRow(['4', '5', '6'], isDark),
                  const SizedBox(height: 12),
                  _buildKeyRow(['7', '8', '9'], isDark),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 60, height: 60),
                      _buildKeyButton('0', isDark, () => _onKeyPress('0')),
                      _buildIconButton(Icons.backspace_outlined, isDark, _onBackspace),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildKeyButton(d, isDark, () => _onKeyPress(d))).toList(),
    );
  }

  Widget _buildKeyButton(String text, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF141A20) : const Color(0xFFF1F5F9),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF141A20) : const Color(0xFFF1F5F9),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: isDark ? Colors.white70 : Colors.black54, size: 20),
      ),
    );
  }
}
