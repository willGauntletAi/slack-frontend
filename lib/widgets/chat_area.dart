import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/message_provider.dart';
import '../providers/typing_indicator_provider.dart';
import '../providers/scroll_retention_provider.dart';
import '../util/position_retained_scroll_physics.dart';
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
  final _scrollRetentionState = ScrollRetentionState();
  bool _isAtBottom = false;
  Message? _selectedThreadMessage;
  String? _lastLoadedChannelId;
  Timer? _scrollInactivityTimer;
  static const _scrollInactivityDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _channelProvider = context.read<ChannelProvider>();
    _messageProvider = context.read<MessageProvider>();
    _itemPositionsListener.itemPositions.addListener(_onScroll);
    _isAtBottom = _channelProvider.selectedMessageId == null;
    _updateScrollRetention();
    _channelProvider.addListener(_handleChannelChange);
    _updateScrollRetention();
    _handleChannelChange();
  }

  void _updateScrollRetention() {
    final topLevelMessages =
        _messageProvider.messages.where((m) => m.parentId == null).toList();
    final shouldRetain = (!_isAtBottom || _messageProvider.hasAfter) &&
        topLevelMessages.isNotEmpty;
    _scrollRetentionState.updateShouldRetain(shouldRetain);
  }

  void _handleChannelChange() {
    final selectedMessageId = context.read<ChannelProvider>().selectedMessageId;
    final selectedChannel = context.read<ChannelProvider>().selectedChannel;
    // Load messages only when channel changes
    if (selectedChannel != null && _lastLoadedChannelId != selectedChannel.id) {
      _lastLoadedChannelId = selectedChannel.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.accessToken != null) {
          if (selectedMessageId != null) {
            _messageProvider.loadMessages(
              selectedChannel.id,
              around: selectedMessageId,
            );
          } else {
            _messageProvider.loadMessages(selectedChannel.id);
          }
        }
      });
    }
  }

  void _onScroll() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final channel = _channelProvider.selectedChannel;
    final authProvider = context.read<AuthProvider>();
    final topLevelMessages =
        _messageProvider.messages.where((m) => m.parentId == null).toList();

    // Update scroll retention state
    _isAtBottom = _checkIfAtBottom();
    _updateScrollRetention();

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
          lastIndex >= topLevelMessages.length - 5 &&
          _messageProvider.messages.length > 10) {
        _messageProvider.before();
      }

      // Load newer messages when scrolling near top
      final firstIndex = positions.first.index;
      if (_messageProvider.hasAfter &&
          firstIndex <= 5 &&
          _messageProvider.messages.length > 10) {
        _messageProvider.after();
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

  bool _checkIfAtBottom() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return true;

    return positions.any((pos) {
      if (pos.index == 0) {
        return pos.itemLeadingEdge >= 0;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _channelProvider.removeListener(_handleChannelChange);
    _messageController.dispose();
    _scrollInactivityTimer?.cancel();
    super.dispose();
  }

  Future<bool> _handleSubmitted(
    String text,
    List<MessageAttachment> attachments,
  ) async {
    if (text.trim().isEmpty && attachments.isEmpty) return false;

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
      return false;
    }

    if (channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No channel selected'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final message = await _messageProvider.sendMessage(
      channel.id,
      text,
      attachments: attachments,
    );

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
    final currentUser = context.watch<AuthProvider>().currentUser;
    final messages = context.watch<MessageProvider>().messages;
    final selectedChannel = context.watch<ChannelProvider>().selectedChannel;

    // Use Consumer for ChannelProvider to ensure we get the latest state
    return Consumer<ChannelProvider>(
      builder: (context, channelProvider, _) {
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

        // For invited workspaces, show a message to handle the invitation in the workspace list
        if (selectedWorkspace.isInvited) {
          return const Center(
            child: Text(
                'Please handle the workspace invitation from the workspace list'),
          );
        }

        if (selectedChannel == null) {
          return const Center(
            child: Text('Select a channel to start chatting'),
          );
        }

        final topLevelMessages =
            messages.where((m) => m.parentId == null).toList();
        var selectedMessageIndex = topLevelMessages
            .indexWhere((m) => m.id == channelProvider.selectedMessageId);
        selectedMessageIndex =
            selectedMessageIndex == -1 ? 0 : selectedMessageIndex;

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
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (messageProvider.messages.isEmpty) {
                          return const Center(
                            child: Text('No messages yet'),
                          );
                        }

                        return ScrollablePositionedList.builder(
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          physics: PositionRetainedScrollPhysics(),
                          reverse: true,
                          padding: const EdgeInsets.all(8.0),
                          itemCount: topLevelMessages.length +
                              (messageProvider.isLoading ? 1 : 0),
                          initialScrollIndex: selectedMessageIndex,
                          itemBuilder: (context, index) {
                            final lastReadMessageId = context
                                .watch<ChannelProvider>()
                                .selectedChannel
                                ?.lastReadMessage;
                            if (messageProvider.isLoading &&
                                index == topLevelMessages.length) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final message = topLevelMessages[index];
                            final isMe = message.userId == currentUser?.id;
                            final isNewestMessage = index == 0;

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
                                final authProvider =
                                    context.read<AuthProvider>();
                                if (authProvider.accessToken == null) return;

                                final hasReaction = message.reactions.where(
                                    (r) =>
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
                              isLastRead: !isNewestMessage &&
                                  lastReadMessageId == message.id,
                              isSelectedMessage: message.id ==
                                  channelProvider.selectedMessageId,
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
                        if (typingUsers.isEmpty) {
                          return const SizedBox.shrink();
                        }

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
      },
    );
  }
}
