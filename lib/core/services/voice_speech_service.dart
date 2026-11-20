import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'permission_service.dart';

enum VoiceDiagnosticStatus {
  idle,
  initializing,
  ready,
  listening,
  processing,
  timeout,
  noMatch,
  permissionDenied,
  micUnavailable,
  error,
}

enum VoiceInputState {
  idle,
  requestingPermission,
  listening,
  processing,
  understanding,
  confirmation,
  saving,
  success,
  error,
  cancelled,
}

/// Real functional speech-to-text service for hands-free voice expense logging.
class VoiceSpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';
  VoiceDiagnosticStatus _diagnosticStatus = VoiceDiagnosticStatus.idle;
  VoiceInputState _voiceState = VoiceInputState.idle;
  String? _userFacingError;

  final StreamController<double> _soundLevelController = StreamController<double>.broadcast();

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized;
  String get lastWords => _lastWords;
  VoiceDiagnosticStatus get diagnosticStatus => _diagnosticStatus;
  VoiceInputState get voiceState => _voiceState;
  String? get userFacingError => _userFacingError;
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  Future<bool> initialize({
    Function(String status)? onStatus,
    Function(SpeechRecognitionError error)? onError,
  }) async {
    if (_isInitialized) return true;

    try {
      _diagnosticStatus = VoiceDiagnosticStatus.initializing;
      _voiceState = VoiceInputState.requestingPermission;
      _userFacingError = null;

      final hasPermission = await PermissionService.requestMicrophonePermission();
      if (!hasPermission) {
        _diagnosticStatus = VoiceDiagnosticStatus.permissionDenied;
        _voiceState = VoiceInputState.error;
        _userFacingError = 'Microphone permission is required to use voice entry.';
        debugPrint('[VoiceSpeechService] Microphone permission not granted');
        return false;
      }

      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          _isListening = _speech.isListening;
          if (_isListening) {
            _diagnosticStatus = VoiceDiagnosticStatus.listening;
            _voiceState = VoiceInputState.listening;
          } else if (status == 'done' || status == 'notListening') {
            _diagnosticStatus = VoiceDiagnosticStatus.ready;
            _voiceState = VoiceInputState.confirmation;
          }
          onStatus?.call(status);
        },
        onError: (error) {
          _isListening = false;
          _voiceState = VoiceInputState.error;
          _handleSpeechError(error);
          onError?.call(error);
        },
        debugLogging: false,
      );

      if (_isInitialized) {
        _diagnosticStatus = VoiceDiagnosticStatus.ready;
        _voiceState = VoiceInputState.idle;
      } else {
        _diagnosticStatus = VoiceDiagnosticStatus.micUnavailable;
        _voiceState = VoiceInputState.error;
        _userFacingError = 'Speech recognition service is unavailable on this device.';
      }

      return _isInitialized;
    } catch (e) {
      _diagnosticStatus = VoiceDiagnosticStatus.error;
      _voiceState = VoiceInputState.error;
      _userFacingError = 'Could not start voice recognition. Please type instead.';
      debugPrint('[VoiceSpeechService] SpeechToText initialization exception: $e');
      return false;
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    final msg = error.errorMsg.toLowerCase();
    if (msg.contains('error_no_match') || msg.contains('no match')) {
      _diagnosticStatus = VoiceDiagnosticStatus.noMatch;
      _userFacingError = "Couldn't catch that. Tap microphone to try again.";
    } else if (msg.contains('error_speech_timeout') || msg.contains('timeout')) {
      _diagnosticStatus = VoiceDiagnosticStatus.timeout;
      _userFacingError = 'Listening timed out. Tap to speak again.';
    } else if (msg.contains('permission')) {
      _diagnosticStatus = VoiceDiagnosticStatus.permissionDenied;
      _userFacingError = 'Microphone permission denied. Please enable in Settings.';
    } else {
      _diagnosticStatus = VoiceDiagnosticStatus.error;
      _userFacingError = 'Speech recognition interrupted. Try again or type below.';
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
    _diagnosticStatus = VoiceDiagnosticStatus.listening;
    _voiceState = VoiceInputState.listening;
    _userFacingError = null;

    try {
      String? chosenLocale = localeId;
      if (chosenLocale == null) {
        final locales = await _speech.locales();
        if (locales.isNotEmpty) {
          final indianOrHindi = locales.where(
            (l) =>
                l.localeId.toLowerCase().contains('en-in') ||
                l.localeId.toLowerCase().contains('en_in') ||
                l.localeId.toLowerCase().contains('hi-in') ||
                l.localeId.toLowerCase().contains('hi_in'),
          ).firstOrNull;
          chosenLocale = indianOrHindi?.localeId ?? locales.first.localeId;
        }
      }

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastWords = result.recognizedWords;
          if (result.finalResult) {
            _diagnosticStatus = VoiceDiagnosticStatus.processing;
          }
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {
          if (!_soundLevelController.isClosed) {
            _soundLevelController.add(level);
          }
          onSoundLevelChange?.call(level);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: chosenLocale,
          pauseFor: const Duration(seconds: 5),
          listenFor: const Duration(seconds: 45),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('[VoiceSpeechService] Error during startListening: $e');
      _isListening = false;
      _diagnosticStatus = VoiceDiagnosticStatus.error;
      _userFacingError = 'Failed to start listening. Tap to retry.';
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
      _voiceState = VoiceInputState.processing;
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
      _diagnosticStatus = VoiceDiagnosticStatus.ready;
      _voiceState = VoiceInputState.cancelled;
    }
  }

  void dispose() {
    if (!_soundLevelController.isClosed) {
      _soundLevelController.close();
    }
    _voiceState = VoiceInputState.idle;
  }
}
