import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'permission_service.dart';

/// Real functional speech-to-text service for hands-free voice expense logging.
class VoiceSpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized;
  String get lastWords => _lastWords;

  Future<bool> initialize({
    Function(String status)? onStatus,
    Function(SpeechRecognitionError error)? onError,
  }) async {
    if (_isInitialized) return true;

    try {
      final hasPermission = await PermissionService.requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('[VoiceSpeechService] Microphone permission not granted');
        return false;
      }

      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          _isListening = _speech.isListening;
          onStatus?.call(status);
        },
        onError: (error) {
          _isListening = false;
          debugPrint('[VoiceSpeechService] Speech error: ${error.errorMsg}');
          onError?.call(error);
        },
        debugLogging: false,
      );

      return _isInitialized;
    } catch (e) {
      debugPrint('[VoiceSpeechService] SpeechToText initialization exception: $e');
      return false;
    }
  }

  Future<bool> startListening({
    required Function(String words, bool isFinal) onResult,
    Function(double soundLevel)? onSoundLevelChange,
    String? localeId,
  }) async {
    final ok = await initialize();
    if (!ok) return false;

    _lastWords = '';
    _isListening = true;

    try {
      String? chosenLocale = localeId;
      if (chosenLocale == null) {
        final locales = await _speech.locales();
        if (locales.isNotEmpty) {
          final indianOrHindi = locales.where(
            (l) => l.localeId.toLowerCase().contains('in') || l.localeId.toLowerCase().contains('hi'),
          ).firstOrNull;
          chosenLocale = indianOrHindi?.localeId ?? locales.first.localeId;
        }
      }

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastWords = result.recognizedWords;
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: onSoundLevelChange,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('[VoiceSpeechService] Error during startListening: $e');
      _isListening = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      if (_speech.isListening || _isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint('[VoiceSpeechService] Error stopping listening: $e');
    } finally {
      _isListening = false;
    }
  }

  Future<void> cancelListening() async {
    try {
      if (_speech.isListening || _isListening) {
        await _speech.cancel();
      }
    } catch (e) {
      debugPrint('[VoiceSpeechService] Error cancelling listening: $e');
    } finally {
      _isListening = false;
    }
  }
}
