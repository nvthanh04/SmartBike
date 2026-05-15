// File này không còn sử dụng trực tiếp.
// Chatbot logic đã chuyển sang:
// - lib/services/ai_chat_service.dart (Gemini AI)
// - lib/services/voice_service.dart (STT + TTS)
// - lib/providers/chatbot_provider.dart (state management)
//
// Giữ file để backward compatibility, nhưng không import firebase_ai nữa.
export 'ai_chat_service.dart';
