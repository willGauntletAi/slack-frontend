import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../providers/dm_provider.dart';
import 'chat_message.dart';

class ThreadPanel extends StatefulWidget {
  final Message? parentMessage;
  final DirectMessage? dmParentMessage;
  final bool isDM;
  final VoidCallback onClose;

  const ThreadPanel({
    super.key,
    this.parentMessage,
    this.dmParentMessage,
    this.isDM = false,
    required this.onClose,
  }) : assert(parentMessage != null || dmParentMessage != null);

  @override
  State<ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends State<ThreadPanel> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSubmittingMessage = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _isSubmittingMessage = true;
    _messageController.clear();

    final authProvider = context.read<AuthProvider>();
    final parentId =
        widget.isDM ? widget.dmParentMessage!.id : widget.parentMessage!.id;
    final channelId = widget.isDM
        ? widget.dmParentMessage!.channelId
        : widget.parentMessage!.channelId;

    if (authProvider.accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _isSubmittingMessage = false;
      return;
    }

    if (widget.isDM) {
      final message = await context.read<DMProvider>().sendMessage(
            authProvider.accessToken!,
            channelId,
            text,
            parentId: parentId,
          );

      if (message == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      final message = await context.read<MessageProvider>().sendMessage(
            authProvider.accessToken!,
            channelId,
            text,
            parentId: parentId,
          );

      if (message == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    _isSubmittingMessage = false;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final threadMessages = widget.isDM
        ? context
            .watch<DMProvider>()
            .messages
            .where((m) => m.parentId == widget.dmParentMessage!.id)
            .map((m) => Message(
                id: m.id,
                content: m.content,
                createdAt: m.createdAt,
                updatedAt: m.updatedAt,
                userId: m.userId,
                username: m.username,
                channelId: m.channelId))
            .toList()
        : context
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
          if (widget.parentMessage != null)
            ChatMessage(
              text: widget.parentMessage!.content,
              isMe: widget.parentMessage!.userId == currentUser?.id,
              username: widget.parentMessage!.username,
              timestamp: widget.parentMessage!.createdAt,
              repliable: false,
            )
          else if (widget.dmParentMessage != null)
            ChatMessage(
              text: widget.dmParentMessage!.content,
              isMe: widget.dmParentMessage!.userId == currentUser?.id,
              username: widget.dmParentMessage!.username,
              timestamp: widget.dmParentMessage!.createdAt,
              repliable: false,
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
                  repliable: false,
                );
              },
            ),
          ),
          // Message input
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Reply in thread',
                        border: InputBorder.none,
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _handleSubmitted(_messageController.text),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
