import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/message_provider.dart';
import '../providers/websocket_provider.dart';
import '../providers/typing_indicator_provider.dart';
import 'chat_message.dart';
import 'thread_panel.dart';
import 'message_input.dart';

class ChatArea extends StatefulWidget {
  const ChatArea({super.key});

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChannelProvider _channelProvider;
  late final MessageProvider _messageProvider;
  DateTime? _lastTypingIndicatorSent;
  bool _isSubmittingMessage = false;
  Message? _selectedThreadMessage;
  static const _typingThrottleDuration = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _channelProvider = context.read<ChannelProvider>();
    _messageProvider = context.read<MessageProvider>();
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_isSubmittingMessage) return;

    final channel = _channelProvider.selectedChannel;
    if (channel == null) return;

    final now = DateTime.now();
    if (_lastTypingIndicatorSent == null ||
        now.difference(_lastTypingIndicatorSent!) >= _typingThrottleDuration) {
      context.read<WebSocketProvider>().sendTypingIndicator(channel.id, false);
      _lastTypingIndicatorSent = now;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final channel = _channelProvider.selectedChannel;
      final authProvider = context.read<AuthProvider>();

      if (channel != null &&
          authProvider.accessToken != null &&
          !_messageProvider.isLoading &&
          _messageProvider.hasMore) {
        _messageProvider.loadMessages(
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

  Future<bool> _handleSubmitted(
    String text,
    List<MessageAttachment> attachments,
  ) async {
    if (text.trim().isEmpty && attachments.isEmpty) return false;

    _isSubmittingMessage = true;
    _messageController.clear();

    final authProvider = context.read<AuthProvider>();
    final channel = context.read<ChannelProvider>().selectedChannel;

    if (authProvider.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      _isSubmittingMessage = false;
      return false;
    }

    if (channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No channel selected'),
          backgroundColor: Colors.red,
        ),
      );
      _isSubmittingMessage = false;
      return false;
    }

    final message = await _messageProvider.sendMessage(
      authProvider.accessToken!,
      channel.id,
      text,
      attachments: attachments,
    );

    _isSubmittingMessage = false;

    if (message == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_messageProvider.error ?? 'Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  Map<String, int> _buildReactionsMap(List<MessageReaction> reactions) {
    final Map<String, int> reactionCounts = {};
    for (final reaction in reactions) {
      reactionCounts[reaction.emoji] =
          (reactionCounts[reaction.emoji] ?? 0) + 1;
    }
    return reactionCounts;
  }

  Set<String> _buildMyReactionsSet(
      List<MessageReaction> reactions, String? userId) {
    if (userId == null) return {};
    return reactions
        .where((reaction) => reaction.userId == userId)
        .map((reaction) => reaction.emoji)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final selectedWorkspace =
        context.watch<WorkspaceProvider>().selectedWorkspace;
    final selectedChannel = context.watch<ChannelProvider>().selectedChannel;
    final currentUser = context.watch<AuthProvider>().currentUser;
    final messages = context.watch<MessageProvider>().messages;

    if (selectedWorkspace == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.workspaces_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Welcome to Slack Clone!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select a workspace to start chatting\nor create your own',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // Show accept/reject buttons for invited workspaces
    if (selectedWorkspace.isInvited) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mail_outline,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              'Invitation to ${selectedWorkspace.name}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    if (authProvider.accessToken != null) {
                      final success =
                          await context.read<WorkspaceProvider>().acceptInvite(
                                authProvider.accessToken!,
                                selectedWorkspace.id,
                              );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Joined ${selectedWorkspace.name}'
                                  : context.read<WorkspaceProvider>().error ??
                                      'Failed to join workspace',
                            ),
                            backgroundColor:
                                success ? Colors.green : Colors.red,
                          ),
                        );

                        if (success) {
                          // Fetch channels for the newly joined workspace
                          await context.read<ChannelProvider>().fetchChannels(
                                authProvider.accessToken!,
                                selectedWorkspace.id,
                              );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Accept Invite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    if (authProvider.accessToken != null) {
                      final success =
                          await context.read<WorkspaceProvider>().rejectInvite(
                                authProvider.accessToken!,
                                selectedWorkspace.id,
                              );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Rejected invitation to ${selectedWorkspace.name}'
                                  : context.read<WorkspaceProvider>().error ??
                                      'Failed to reject invitation',
                            ),
                            backgroundColor: success ? null : Colors.red,
                          ),
                        );

                        if (success) {
                          // Clear the channels since we rejected the workspace
                          context.read<ChannelProvider>().clearChannels();
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Reject Invite'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (selectedChannel == null) {
      return const Center(
        child: Text('Select a channel to start chatting'),
      );
    }

    final topLevelMessages = messages.where((m) => m.parentId == null).toList();
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Consumer<MessageProvider>(
                  builder: (context, messageProvider, _) {
                    if (messageProvider.messages.isEmpty &&
                        messageProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (messageProvider.messages.isEmpty) {
                      return const Center(
                        child: Text('No messages yet'),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(8.0),
                      itemCount: topLevelMessages.length +
                          (messageProvider.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (messageProvider.isLoading &&
                            index == topLevelMessages.length) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        // Filter out messages with a parent_id and get the message at the current index
                        final message = topLevelMessages[index];
                        final isMe = message.userId == currentUser?.id;

                        return ChatMessage(
                          text: message.content,
                          isMe: isMe,
                          username: message.username,
                          timestamp: message.createdAt,
                          onReply: () {
                            setState(() {
                              _selectedThreadMessage = message;
                            });
                          },
                          onReaction: (emoji) async {
                            final authProvider = context.read<AuthProvider>();
                            if (authProvider.accessToken == null) return;

                            final hasReaction = message.reactions.where((r) =>
                                r.userId == currentUser?.id &&
                                r.emoji == emoji);

                            if (hasReaction.isNotEmpty) {
                              // Remove reaction - pass the reaction ID
                              await _messageProvider.removeReaction(
                                  message.id, hasReaction.first.id);
                            } else {
                              // Add reaction
                              await _messageProvider.addReaction(
                                  message.id, emoji);
                            }
                          },
                          reactions: _buildReactionsMap(message.reactions),
                          myReactions: _buildMyReactionsSet(
                              message.reactions, currentUser?.id),
                          attachments: message.attachments,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
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
              MessageInput(
                onSubmitted: _handleSubmitted,
                hintText: 'Send a message',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (_selectedThreadMessage != null)
          ThreadPanel(
            parentMessage: _selectedThreadMessage,
            onClose: () {
              setState(() {
                _selectedThreadMessage = null;
              });
            },
          ),
      ],
    );
  }
}
