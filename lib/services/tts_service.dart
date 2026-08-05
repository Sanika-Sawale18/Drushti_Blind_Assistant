
import 'dart:async';
import 'dart:collection';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  late FlutterTts _tts;
  bool _initialized = false;
  bool _speaking = false;

  // Announcement queue — normal priority
  final Queue<String> _queue = Queue();

  bool get isSpeaking => _speaking;

  Future<void> init() async {
    if (_initialized) return;
    _tts = FlutterTts();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.50);  
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);
    await _tts.awaitSpeakCompletion(true);

    _tts.setCompletionHandler(() {
      _speaking = false;
      _drainQueue();
    });
    _tts.setErrorHandler((msg) {
      _speaking = false;
      debugPrint('TTS error: $msg');
      _drainQueue();
    });
    _tts.setCancelHandler(() {
      _speaking = false;
    });

    _initialized = true;
  }

  void speak(String text) {
    if (!_initialized || text.trim().isEmpty) return;
    // Drop stale duplicate that hasn't played yet
    if (_queue.isNotEmpty && _queue.last == text) return;
    _queue.addLast(text);
    _drainQueue();
  }

  Future<void> speakEmergency(String text) async {
    if (!_initialized) return;
    _queue.clear();
    if (_speaking) await _tts.stop();
    _speaking = true;
    await _tts.setSpeechRate(0.44);
    await _tts.speak('Warning! $text');
    await _tts.setSpeechRate(0.50);
  }

  void _drainQueue() {
    if (_speaking || _queue.isEmpty || !_initialized) return;
    final text = _queue.removeFirst();
    _speaking = true;
    _tts.speak(text);
  }

  Future<void> stop() async {
    if (!_initialized) return;
    _queue.clear();
    await _tts.stop();
    _speaking = false;
  }

  void dispose() {
    _queue.clear();
    if (_initialized) _tts.stop();
  }
}
