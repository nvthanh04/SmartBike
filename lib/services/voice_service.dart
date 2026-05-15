import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// Service xử lý giọng nói: Speech-to-Text + Text-to-Speech
class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  VoiceService() {
    _initTts();
  }

  /// Khởi tạo TTS
  Future<void> _initTts() async {
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  /// Khởi tạo STT (gọi 1 lần)
  Future<bool> initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('STT Error: ${error.errorMsg}');
          _isListening = false;
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );
      return _speechAvailable;
    } catch (e) {
      debugPrint('STT init error: $e');
      return false;
    }
  }

  /// Bắt đầu nghe giọng nói
  Future<void> startListening({
    required Function(String) onPartialResult,
    required Function(String) onFinalResult,
  }) async {
    if (!_speechAvailable) {
      _speechAvailable = await initSpeech();
    }
    if (!_speechAvailable) {
      onFinalResult('');
      return;
    }

    _isListening = true;
    String lastResult = '';

    await _speech.listen(
      onResult: (result) {
        lastResult = result.recognizedWords;
        if (result.finalResult) {
          _isListening = false;
          onFinalResult(lastResult);
        } else {
          onPartialResult(lastResult);
        }
      },
      localeId: 'vi-VN',
      pauseFor: const Duration(seconds: 3),
      listenMode: stt.ListenMode.dictation,
    );
  }

  /// Dừng nghe
  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  /// Đọc text bằng giọng nói
  Future<void> speak(String text, {Function? onComplete}) async {
    _isSpeaking = true;
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });
    await _tts.speak(text);
  }

  /// Dừng đọc
  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    await _tts.stop();
  }

  void dispose() {
    _speech.stop();
    _tts.stop();
  }
}
