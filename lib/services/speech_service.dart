import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter/foundation.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _initialized = false;

  Function(String)? onCommand;

  Future<bool> init() async {
    if (_initialized) return true;
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize(
      onError: (e) => debugPrint('Speech error: $e'),
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          // Auto-restart so we always listen
          Future.delayed(const Duration(milliseconds: 500), _listenForCommands);
        }
      },
    );
    if (available) {
      _initialized = true;
      _listenForCommands();
    }
    return available;
  }

  void _listenForCommands() {
    if (!_initialized || _isListening) return;
    _isListening = true;
    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(minutes: 30),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return;
    final command = result.recognizedWords.toLowerCase().trim();
    debugPrint('Voice command: $command');

    if (command.contains('start') || command.contains('begin') || command.contains('go')) {
      onCommand?.call('start_detection');
    } else if (command.contains('stop') || command.contains('pause') || command.contains('freeze')) {
      onCommand?.call('stop_detection');
    } else if (command.contains('exit') || command.contains('close') || command.contains('quit')) {
      onCommand?.call('exit_app');
    } else if (command.contains('repeat') || command.contains('again') || command.contains('what')) {
      onCommand?.call('repeat');
    } else if (command.contains('help')) {
      onCommand?.call('help');
    }
  }

  void stopListening() {
    _speech.stop();
    _isListening = false;
  }

  void dispose() {
    stopListening();
  }
}
