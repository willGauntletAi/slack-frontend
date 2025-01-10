import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import 'chat_message.dart';
import 'message_input.dart';

class ThreadPanel extends StatefulWidget {
  final Message? parentMessage;
  final bool isDM;
  final VoidCallback onClose;

  const ThreadPanel({
    super.key,
    this.parentMessage,
    this.isDM = false,
    required this.onClose,
  });

  @override
  State<ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends State<ThreadPanel> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _handleSubmitted(
    String text,
    List<MessageAttachment> attachments,
  ) async {
    if (text.trim().isEmpty && attachments.isEmpty) return false;

    _messageController.clear();

    final authProvider = context.read<AuthProvider>();
    final parentId = widget.parentMessage!.id;
    final channelId = widget.parentMessage!.channelId;

    if (authProvider.accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    final message = await context.read<MessageProvider>().sendMessage(
          channelId,
          text,
          parentId: parentId,
          attachments: attachments,
        );

    if (message == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final threadMessages = context
        .watch<MessageProvider>()
        .messages
        .where((m) => m.parentId == widget.parentMessage!.id)
        .toList();

    return Container(
      width: 400,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          // Thread header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Thread',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          // Original message
          ChatMessage(
            text: widget.parentMessage!.content,
            isMe: widget.parentMessage!.userId == currentUser?.id,
            username: widget.parentMessage!.username,
            timestamp: widget.parentMessage!.createdAt,
            userId: widget.parentMessage!.userId,
            repliable: false,
            attachments: widget.parentMessage!.attachments,
          ),
          const Divider(),
          // Thread messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(8.0),
              itemCount: threadMessages.length,
              itemBuilder: (context, index) {
                final message = threadMessages[index];
                final isMe = message.userId == currentUser?.id;

                return ChatMessage(
                  text: message.content,
                  isMe: isMe,
                  username: message.username,
                  timestamp: message.createdAt,
                  userId: message.userId,
                  repliable: false,
                  attachments: message.attachments,
                );
              },
            ),
          ),
          // Message input
          MessageInput(
            onSubmitted: _handleSubmitted,
            hintText: 'Reply in thread',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
