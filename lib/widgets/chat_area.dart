import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
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
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  late final ChannelProvider _channelProvider;
  late final MessageProvider _messageProvider;
  bool _isSubmittingMessage = false;
  Message? _selectedThreadMessage;
  String? _lastScrolledChannelId;
  Timer? _scrollInactivityTimer;
  static const _scrollInactivityDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _channelProvider = context.read<ChannelProvider>();
    _messageProvider = context.read<MessageProvider>();
    _itemPositionsListener.itemPositions.addListener(_onScroll);

    // Load initial messages whenever channel or selectedMessageId changes
    _channelProvider.addListener(_handleChannelChange);
  }

  void _handleChannelChange() {
    final channel = _channelProvider.selectedChannel;
    final messageId = _channelProvider.selectedMessageId;
    final authProvider = context.read<AuthProvider>();

    if (channel != null && authProvider.accessToken != null) {
      _messageProvider.loadMessages(
        authProvider.accessToken!,
        channel.id,
        around: messageId,
      );
    }
  }

  void _onScroll() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final channel = _channelProvider.selectedChannel;
    final authProvider = context.read<AuthProvider>();
    final topLevelMessages =
        _messageProvider.messages.where((m) => m.parentId == null).toList();

    // Reset the inactivity timer
    _scrollInactivityTimer?.cancel();
    _scrollInactivityTimer = Timer(_scrollInactivityDuration, () {
      _markNewestVisibleMessageAsRead(positions, topLevelMessages);
    });

    if (channel != null &&
        authProvider.accessToken != null &&
        !_messageProvider.isLoading) {
      // Load older messages when scrolling near bottom
      final lastIndex = positions.last.index;
      if (_messageProvider.hasBefore &&
          lastIndex >= topLevelMessages.length - 5) {
        _messageProvider.before(
          authProvider.accessToken!,
          channel.id,
        );
      }

      // Load newer messages when scrolling near top
      final firstIndex = positions.first.index;
      if (_messageProvider.hasAfter && firstIndex <= 5) {
        _messageProvider.after(
          authProvider.accessToken!,
          channel.id,
        );
      }
    }
  }

  void _markNewestVisibleMessageAsRead(
    Iterable<ItemPosition> positions,
    List<Message> topLevelMessages,
  ) {
    final channel = _channelProvider.selectedChannel;
    if (channel == null || positions.isEmpty || topLevelMessages.isEmpty) {
      return;
    }

    // Find the newest visible message (lowest index since list is reversed)
    final lowestVisibleIndex = positions
        .where((pos) => pos.itemLeadingEdge < 1.0 && pos.itemTrailingEdge > 0.0)
        .map((pos) => pos.index)
        .reduce(
          (min, index) => index < min ? index : min,
        );
    final newestVisibleMessage = topLevelMessages[lowestVisibleIndex];
    if (int.parse(newestVisibleMessage.id) >
        int.parse(channel.lastReadMessage ?? '0')) {
      _messageProvider.markMessageAsRead(channel.id, newestVisibleMessage.id);
    }
  }

  void _scrollToMessage() {
    final channel = _channelProvider.selectedChannel;
    final selectedMessageId = _channelProvider.selectedMessageId;
    final topLevelMessages =
        _messageProvider.messages.where((m) => m.parentId == null).toList();

    _lastScrolledChannelId = channel?.id;
    // Only scroll if we haven't scrolled for this channel yet and there's a selected message
    if (channel == null ||
        selectedMessageId == null ||
        topLevelMessages.length < 15 ||
        _lastScrolledChannelId == channel.id) {
      return;
    }

    // Find the index of the selected message
    final selectedMessage = _messageProvider.messages.firstWhere(
        (m) => m.id == selectedMessageId,
        orElse: () => topLevelMessages.first);

    if (selectedMessage.parentId != null && _itemScrollController.isAttached) {
      final index =
          topLevelMessages.indexWhere((m) => m.id == selectedMessage.parentId);
      _itemScrollController.jumpTo(index: index);
    } else if (_itemScrollController.isAttached) {
      final index =
          topLevelMessages.indexWhere((m) => m.id == selectedMessage.id);
      _itemScrollController.jumpTo(index: index);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollInactivityTimer?.cancel();
    _channelProvider.removeListener(_handleChannelChange);
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

    // Try to scroll to selected message or last read message whenever messages or channel changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToMessage();
    });

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

                    return ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
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

                        final message = topLevelMessages[index];
                        final isMe = message.userId == currentUser?.id;

                        return ChatMessage(
                          text: message.content,
                          isMe: isMe,
                          username: message.username,
                          timestamp: message.createdAt,
                          userId: message.userId,
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
                              await _messageProvider.removeReaction(
                                  message.id, hasReaction.first.id);
                            } else {
                              await _messageProvider.addReaction(
                                  message.id, emoji);
                            }
                          },
                          reactions: _buildReactionsMap(message.reactions),
                          myReactions: _buildMyReactionsSet(
                              message.reactions, currentUser?.id),
                          attachments: message.attachments,
                          lastReadId: selectedChannel.lastReadMessage,
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
