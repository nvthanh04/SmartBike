/// Model tin nhắn chat
class ChatMessageModel {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isVoice; // true nếu từ giọng nói
  final bool isForwarded; // true nếu đã chuyển admin

  ChatMessageModel({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isVoice = false,
    this.isForwarded = false,
  });
}
