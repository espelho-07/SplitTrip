import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kith Custom Signature Notification Sound Tests', () {
    test('1. Android raw resource kith_notification.wav exists and is valid PCM WAV', () async {
      final file = File('android/app/src/main/res/raw/kith_notification.wav');
      expect(file.existsSync(), true, reason: 'kith_notification.wav must exist in android raw resources');

      final bytes = await file.readAsBytes();
      expect(bytes.length > 1000, true);

      // Verify RIFF and WAVE header
      final riff = String.fromCharCodes(bytes.sublist(0, 4));
      final wave = String.fromCharCodes(bytes.sublist(8, 12));
      expect(riff, 'RIFF');
      expect(wave, 'WAVE');

      // Byte 22: channels (1 = mono, 2 = stereo)
      final byteData = ByteData.sublistView(bytes);
      final channels = byteData.getUint16(22, Endian.little);
      final sampleRate = byteData.getUint32(24, Endian.little);
      final bitsPerSample = byteData.getUint16(34, Endian.little);

      expect(channels, 1, reason: 'Mono is optimal for mobile phone speakers');
      expect(sampleRate, 44100, reason: 'Standard 44.1kHz sample rate');
      expect(bitsPerSample, 16, reason: '16-bit PCM for crisp quality without distortion');

      // Duration: data size in bytes / (sampleRate * channels * bitsPerSample / 8)
      final dataSize = bytes.length - 44; // approx header size
      final durationSeconds = dataSize / (sampleRate * channels * (bitsPerSample / 8));
      expect(durationSeconds >= 0.5 && durationSeconds <= 1.2, true,
          reason: 'Duration must be between 0.5s and 1.2s (actual: ${durationSeconds.toStringAsFixed(2)}s)');
    });

    test('2. Flutter assets audio file exists and matches android raw resource', () async {
      final rawFile = File('android/app/src/main/res/raw/kith_notification.wav');
      final assetFile = File('assets/audio/kith_notification.wav');

      expect(assetFile.existsSync(), true);
      expect(rawFile.existsSync(), true);

      final rawBytes = await rawFile.readAsBytes();
      final assetBytes = await assetFile.readAsBytes();

      expect(assetBytes.length, rawBytes.length);
      expect(assetBytes, equals(rawBytes));
    });

    test('3. KithNotificationHelper.kt contains soundUri and audioAttributes configuration', () {
      final ktFile = File('android/app/src/main/kotlin/com/nirniq/kith/KithNotificationHelper.kt');
      expect(ktFile.existsSync(), true);
      final content = ktFile.readAsStringSync();

      expect(content.contains('R.raw.kith_notification'), true);
      expect(content.contains('setSound(soundUri, audioAttributes)'), true);
      expect(content.contains('AudioAttributes.CONTENT_TYPE_SONIFICATION'), true);
      expect(content.contains('AudioAttributes.USAGE_NOTIFICATION'), true);
      expect(content.contains('kith_activity'), true);
      expect(content.contains('kith_payments'), true);
    });
  });
}
