import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'haptic_feedback_helper.dart';

class WhatsAppShareHelper {
  /// Normalizes phone number into clean international format (digits only, e.g. 919876543210).
  static String normalizePhoneNumber(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) return '';
    var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      // Default to India country code 91 for 10-digit Indian numbers
      digits = '91$digits';
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = '91${digits.substring(1)}';
    }
    return digits;
  }

  /// Attempts to launch WhatsApp with the given text message, targeting a phone number if provided.
  /// Falls back gracefully to universal web links and finally to clipboard copy if WhatsApp is unavailable.
  static Future<bool> sendWhatsAppMessage({
    required BuildContext context,
    required String text,
    String? phone,
  }) async {
    HapticHelper.medium();
    final cleanPhone = normalizePhoneNumber(phone);
    final encodedText = Uri.encodeComponent(text);

    // 1. Try direct custom scheme (whatsapp://)
    final directUri = cleanPhone.isNotEmpty
        ? Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedText')
        : Uri.parse('whatsapp://send?text=$encodedText');

    try {
      if (await canLaunchUrl(directUri)) {
        final launched = await launchUrl(directUri, mode: LaunchMode.externalNonBrowserApplication);
        if (launched) return true;
      }
    } catch (_) {}

    // 2. Try universal HTTPS redirect (https://api.whatsapp.com or https://wa.me)
    final universalUri = cleanPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$cleanPhone?text=$encodedText')
        : Uri.parse('https://api.whatsapp.com/send?text=$encodedText');

    try {
      if (await canLaunchUrl(universalUri)) {
        final launched = await launchUrl(universalUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      } else {
        // Some Android versions report false for canLaunchUrl on HTTPS, but launchUrl still succeeds
        final launched = await launchUrl(universalUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
    } catch (_) {}

    // 3. Graceful Fallback: Copy to Clipboard & Notify User
    await Clipboard.setData(ClipboardData(text: text));
    HapticHelper.light();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.content_copy_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text('Reminder copied to clipboard! Paste it into WhatsApp or Messages.'),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: const Color(0xFF4ADE80),
            onPressed: () {},
          ),
        ),
      );
    }
    return false;
  }
}
