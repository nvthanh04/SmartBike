import 'package:flutter/material.dart';
import '../providers/chatbot_provider.dart';
import 'chat_panel_widget.dart';

/// Bong bóng chat nổi - draggable, hỗ trợ text + voice
class ChatBubbleWidget extends StatefulWidget {
  final ChatbotProvider provider;
  const ChatBubbleWidget({super.key, required this.provider});

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget>
    with TickerProviderStateMixin {
  double _xPos = -1;
  double _yPos = -1;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  ChatbotProvider get _p => widget.provider;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _p.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (_p.bubbleState == BubbleState.listening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _p.removeListener(_onStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  Color get _bubbleColor {
    switch (_p.bubbleState) {
      case BubbleState.idle:
        return const Color(0xFF2ECC71);
      case BubbleState.listening:
        return const Color(0xFFE74C3C);
      case BubbleState.processing:
        return const Color(0xFF2ECC71);
      case BubbleState.speaking:
        return const Color(0xFFF39C12);
    }
  }

  Widget get _bubbleIcon {
    switch (_p.bubbleState) {
      case BubbleState.idle:
        return const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 26);
      case BubbleState.listening:
        return const Icon(Icons.mic, color: Colors.white, size: 26);
      case BubbleState.processing:
        return const SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        );
      case BubbleState.speaking:
        return const Icon(Icons.volume_up, color: Colors.white, size: 26);
    }
  }

  String? get _tooltip {
    switch (_p.bubbleState) {
      case BubbleState.listening:
        return 'Đang nghe...';
      case BubbleState.processing:
        return 'Đang xử lý...';
      case BubbleState.speaking:
        return 'Đang trả lời...';
      default:
        return null;
    }
  }

  void _onTap() {
    if (_p.bubbleState == BubbleState.speaking) {
      _p.stopSpeaking();
    } else if (_p.bubbleState == BubbleState.listening) {
      _p.stopVoiceAndSend();
    } else {
      _showChatPanel();
    }
  }

  void _onLongPress() {
    if (_p.bubbleState == BubbleState.idle) {
      _p.startVoiceChat();
    }
  }

  void _showChatPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatPanelWidget(provider: _p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    if (_xPos < 0) _xPos = screenW - 72;
    if (_yPos < 0) _yPos = screenH - 200;

    return Positioned(
      left: _xPos,
      top: _yPos,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _xPos = (_xPos + details.delta.dx).clamp(0.0, screenW - 56);
            _yPos = (_yPos + details.delta.dy).clamp(0.0, screenH - 56);
          });
        },
        onTap: _onTap,
        onLongPress: _onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tooltip
            if (_tooltip != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_tooltip!,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            // Bubble with pulse animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = _p.bubbleState == BubbleState.listening
                    ? _pulseAnimation.value
                    : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Sóng âm khi listening
                  if (_p.bubbleState == BubbleState.listening) ...[
                    _buildWave(70, 0.15),
                    _buildWave(84, 0.08),
                  ],
                  // Bong bóng chính
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _bubbleColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _bubbleColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(child: _bubbleIcon),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWave(double size, double opacity) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          width: size * _pulseAnimation.value,
          height: size * _pulseAnimation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE74C3C).withValues(alpha: opacity),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
