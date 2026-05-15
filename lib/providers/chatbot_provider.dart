import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../services/ai_chat_service.dart';
import '../services/voice_service.dart';

/// Trạng thái bong bóng chat
enum BubbleState { idle, listening, processing, speaking }

/// Provider đồng bộ trạng thái giữa bong bóng và bảng chat
class ChatbotProvider extends ChangeNotifier {
  final AiChatService _aiService = AiChatService();
  final VoiceService _voiceService = VoiceService();

  final List<ChatMessageModel> _messages = [];
  BubbleState _bubbleState = BubbleState.idle;
  String _partialText = '';
  bool _isPanelOpen = false;

  List<ChatMessageModel> get messages => _messages;
  BubbleState get bubbleState => _bubbleState;
  String get partialText => _partialText;
  bool get isPanelOpen => _isPanelOpen;
  VoiceService get voiceService => _voiceService;

  ChatbotProvider() {
    // Tin nhắn chào mừng
    _messages.add(ChatMessageModel(
      text: 'Xin chào! Mình là SmartBike Assistant 🚲 Bạn cần giúp gì nào?',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void togglePanel() {
    _isPanelOpen = !_isPanelOpen;
    notifyListeners();
  }

  void openPanel() {
    _isPanelOpen = true;
    notifyListeners();
  }

  void closePanel() {
    _isPanelOpen = false;
    notifyListeners();
  }

  /// Gửi tin nhắn text
  Future<void> sendTextMessage(String text, {bool isVoice = false}) async {
    if (text.trim().isEmpty) return;

    // Thêm tin nhắn user
    _messages.add(ChatMessageModel(
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      isVoice: isVoice,
    ));
    _bubbleState = BubbleState.processing;
    notifyListeners();

    // Gửi tới Gemini
    final result = await _aiService.sendMessage(text.trim());
    final response = result['response'] as String;
    final needsForward = result['needsForward'] as bool;

    _messages.add(ChatMessageModel(
      text: response,
      isUser: false,
      timestamp: DateTime.now(),
      isForwarded: needsForward,
    ));

    // Nếu voice → tự động đọc
    if (isVoice) {
      _bubbleState = BubbleState.speaking;
      notifyListeners();
      await _voiceService.speak(response, onComplete: () {
        _bubbleState = BubbleState.idle;
        notifyListeners();
      });
    } else {
      _bubbleState = BubbleState.idle;
    }
    notifyListeners();
  }

  /// Bắt đầu voice chat
  Future<void> startVoiceChat() async {
    _bubbleState = BubbleState.listening;
    _partialText = '';
    notifyListeners();

    await _voiceService.startListening(
      onPartialResult: (text) {
        _partialText = text;
        notifyListeners();
      },
      onFinalResult: (text) async {
        _partialText = '';
        if (text.isNotEmpty) {
          await sendTextMessage(text, isVoice: true);
        } else {
          // Không nghe rõ
          _bubbleState = BubbleState.speaking;
          notifyListeners();
          await _voiceService.speak(
            'Không nghe rõ, bạn nói lại nhé',
            onComplete: () {
              _bubbleState = BubbleState.idle;
              notifyListeners();
            },
          );
        }
      },
    );
  }

  /// Dừng nghe + gửi ngay
  Future<void> stopVoiceAndSend() async {
    await _voiceService.stopListening();
    if (_partialText.isNotEmpty) {
      final text = _partialText;
      _partialText = '';
      await sendTextMessage(text, isVoice: true);
    } else {
      _bubbleState = BubbleState.idle;
      notifyListeners();
    }
  }

  /// Dừng đọc giọng nói
  void stopSpeaking() {
    _voiceService.stopSpeaking();
    _bubbleState = BubbleState.idle;
    notifyListeners();
  }

  /// Reset cuộc trò chuyện
  void resetConversation() {
    _aiService.resetConversation();
    _messages.clear();
    _messages.add(ChatMessageModel(
      text: 'Xin chào! Mình là SmartBike Assistant 🚲 Bạn cần giúp gì nào?',
      isUser: false,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}
