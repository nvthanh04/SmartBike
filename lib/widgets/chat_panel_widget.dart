import 'package:flutter/material.dart';
import '../providers/chatbot_provider.dart';
import '../models/chat_message_model.dart';

/// Bảng chat bottom sheet
class ChatPanelWidget extends StatefulWidget {
  final ChatbotProvider provider;
  const ChatPanelWidget({super.key, required this.provider});

  @override
  State<ChatPanelWidget> createState() => _ChatPanelWidgetState();
}

class _ChatPanelWidgetState extends State<ChatPanelWidget> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _hasText = false;

  ChatbotProvider get _p => widget.provider;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      final has = _textCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _p.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
    // Nếu đang nghe voice trong panel → điền partial text
    if (_p.bubbleState == BubbleState.listening && _p.partialText.isNotEmpty) {
      _textCtrl.text = _p.partialText;
      _textCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _textCtrl.text.length),
      );
    }
  }

  @override
  void dispose() {
    _p.removeListener(_onUpdate);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    _p.sendTextMessage(text);
  }

  void _toggleMic() {
    if (_p.bubbleState == BubbleState.listening) {
      _p.stopVoiceAndSend();
    } else {
      _p.startVoiceChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(child: _buildMessageList()),
          if (_p.bubbleState == BubbleState.processing) _buildTypingIndicator(),
          _buildInputBar(bottomPadding),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF2ECC71),
                child: Icon(Icons.pedal_bike, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('SmartBike Assistant',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                tooltip: 'Cuộc trò chuyện mới',
                onPressed: _p.resetConversation,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _p.messages.length,
      itemBuilder: (context, index) {
        final msg = _p.messages[index];
        return _buildBubble(msg);
      },
    );
  }

  Widget _buildBubble(ChatMessageModel msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: EdgeInsets.only(
        bottom: 10,
        left: isUser ? 50 : 0,
        right: isUser ? 0 : 50,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Color(0xFF2ECC71),
                child: Icon(Icons.pedal_bike, color: Colors.white, size: 10),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF2ECC71) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4, offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.isVoice && isUser)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic, size: 12,
                                  color: isUser ? Colors.white70 : Colors.grey),
                              const SizedBox(width: 2),
                              Text('Giọng nói',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isUser ? Colors.white70 : Colors.grey,
                                  )),
                            ],
                          ),
                        ),
                      Text(
                        msg.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 14, height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Forwarded badge
                if (msg.isForwarded)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('📩 Đã chuyển hỗ trợ',
                          style: TextStyle(fontSize: 10, color: Colors.orange)),
                    ),
                  ),
                // Nút nghe lại (bot message)
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _p.voiceService.speak(msg.text),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.volume_up, size: 14, color: Colors.grey[400]),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 10,
            backgroundColor: Color(0xFF2ECC71),
            child: Icon(Icons.pedal_bike, color: Colors.white, size: 10),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _AnimatedDot(delay: i * 200),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(double bottomPadding) {
    final isListening = _p.bubbleState == BubbleState.listening;

    return Container(
      padding: EdgeInsets.only(
        left: 8, right: 8, top: 8,
        bottom: bottomPadding > 0 ? 8 : MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Nút micro
          GestureDetector(
            onTap: _toggleMic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isListening ? const Color(0xFFE74C3C) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic,
                color: isListening ? Colors.white : Colors.grey[700],
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // TextField
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
                border: isListening
                    ? Border.all(color: const Color(0xFFE74C3C), width: 1.5)
                    : null,
              ),
              child: TextField(
                controller: _textCtrl,
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nút gửi
          if (_hasText)
            GestureDetector(
              onTap: _sendText,
              child: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF2ECC71),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chấm nhấp nháy cho typing indicator
class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + 0.7 * _ctrl.value,
          child: Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[500],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
