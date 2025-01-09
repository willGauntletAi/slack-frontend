import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/dm_provider.dart';
import '../providers/websocket_provider.dart';
import '../providers/typing_indicator_provider.dart';
import 'chat_message.dart';

class DMChatArea extends StatefulWidget {
  const DMChatArea({super.key});

  @override
  State<DMChatArea> createState() => _DMChatAreaState();
}

class _DMChatAreaState extends State<DMChatArea> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final DMProvider _dmProvider;
  DateTime? _lastTypingIndicatorSent;
  bool _isSubmittingMessage = false;
  static const _typingThrottleDuration = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _dmProvider = context.read<DMProvider>();
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_isSubmittingMessage) return;

    final channel = _dmProvider.selectedChannel;
    if (channel == null) return;

    final now = DateTime.now();
    if (_lastTypingIndicatorSent == null ||
        now.difference(_lastTypingIndicatorSent!) >= _typingThrottleDuration) {
      context.read<WebSocketProvider>().sendTypingIndicator(channel.id, true);
      _lastTypingIndicatorSent = now;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final channel = _dmProvider.selectedChannel;
      final authProvider = context.read<AuthProvider>();

      if (channel != null &&
          authProvider.accessToken != null &&
          !_dmProvider.isLoading &&
          _dmProvider.hasMore) {
        _dmProvider.loadMessages(
          authProvider.accessToken!,
          channel.id,
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _isSubmittingMessage = true;
    _messageController.clear();

    final authProvider = context.read<AuthProvider>();
    final channel = context.read<DMProvider>().selectedChannel;

    if (authProvider.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      _isSubmittingMessage = false;
      return;
    }

    if (channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No DM channel selected'),
          backgroundColor: Colors.red,
        ),
      );
      _isSubmittingMessage = false;
      return;
    }

    final message = await _dmProvider.sendMessage(
      authProvider.accessToken!,
      channel.id,
      text,
    );

    _isSubmittingMessage = false;

    if (message == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_dmProvider.error ?? 'Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedChannel = context.watch<DMProvider>().selectedChannel;
    final currentUser = context.watch<AuthProvider>().currentUser;
    final messages = context.watch<DMProvider>().messages;

    if (selectedChannel == null) {
      return const Center(
        child: Text('Select a conversation to start chatting'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Consumer<DMProvider>(
            builder: (context, dmProvider, _) {
              if (dmProvider.messages.isEmpty && dmProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (dmProvider.messages.isEmpty) {
                return const Center(
                  child: Text('No messages yet'),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(8.0),
                itemCount: messages.length + (dmProvider.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (dmProvider.isLoading && index == messages.length) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final message = messages[index];
                  final isMe = message.userId == currentUser?.id;

                  return ChatMessage(
                    text: message.content,
                    isMe: isMe,
                    username: message.username,
                    timestamp: message.createdAt,
                    onReply: () {
                      // TODO: Implement reply functionality
                      debugPrint('Reply to message: ${message.id}');
                    },
                  );
                },
              );
            },
          ),
        ),
        if (currentUser != null)
          Consumer<TypingIndicatorProvider>(
            builder: (context, typingProvider, _) {
              final typingUsers = typingProvider.getTypingUsernames(
                selectedChannel.id,
                currentUser.id,
              );
              if (typingUsers.isEmpty) return const SizedBox.shrink();

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                alignment: Alignment.centerLeft,
                child: Text(
                  typingUsers.length == 1
                      ? '${typingUsers.first} is typing...'
                      : typingUsers.length == 2
                          ? '${typingUsers.join(' and ')} are typing...'
                          : '${typingUsers.length} people are typing...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            },
          ),
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
                      hintText: 'Send a message',
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
        // Add padding at the bottom to prevent snackbar overlap
        const SizedBox(height: 8),
      ],
    );
  }
}
