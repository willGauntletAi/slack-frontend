import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatMessage extends StatefulWidget {
  final String text;
  final bool isMe;
  final String username;
  final DateTime timestamp;
  final Function()? onReply;
  final Function(String emoji)? onReaction;
  final bool repliable;
  final Map<String, int>? reactions;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isMe,
    required this.username,
    required this.timestamp,
    this.onReply,
    this.onReaction,
    this.repliable = true,
    this.reactions,
  });

  @override
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  // Track both the active message and its overlay
  static String? _activeMessageId;
  static OverlayEntry? _activeOverlay;
  final String _messageId = UniqueKey().toString();
  final LayerLink _layerLink = LayerLink();
  bool _isHovering = false;
  bool _isMessageHovered = false; // separate state for background color
  final _overlayWidth = 200.0; // increased width to accommodate both options

  @override
  void dispose() {
    if (_messageId == _activeMessageId) {
      _removeGlobalOverlay();
    }
    super.dispose();
  }

  void _removeGlobalOverlay() {
    if (_activeOverlay != null) {
      _activeOverlay?.remove();
    }
    _activeOverlay = null;
    _activeMessageId = null;
  }

  void _showOverlay(BuildContext context) {
    // Only show reply overlay if message is repliable
    if (!widget.repliable) return;

    // Always clean up previous overlay
    _removeGlobalOverlay();

    // Set this as the active message
    _activeMessageId = _messageId;

    _activeOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: _overlayWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: Offset(-1 * _overlayWidth, -20),
          child: MouseRegion(
            onEnter: (_) {
              // Only handle enter if this is still the active message
              if (_messageId == _activeMessageId) {
                setState(() {
                  _isHovering = true;
                  _isMessageHovered = true;
                });
              }
            },
            onExit: (_) {
              if (_messageId == _activeMessageId && mounted) {
                setState(() {
                  _isHovering = false;
                  _isMessageHovered = false;
                });
                // Small delay to allow for mouse movement between message and overlay
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (!_isHovering &&
                      mounted &&
                      _messageId == _activeMessageId) {
                    _removeGlobalOverlay();
                  }
                });
              }
            },
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          widget.onReply?.call();
                          setState(() {
                            _isHovering = false;
                            _isMessageHovered = false;
                          });
                          _removeGlobalOverlay();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: const Row(
                            children: [
                              Icon(Icons.reply, size: 16),
                              SizedBox(width: 8),
                              Text('Reply', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          _showEmojiPicker(context);
                          setState(() {
                            _isHovering = false;
                            _isMessageHovered = false;
                          });
                          _removeGlobalOverlay();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: const Row(
                            children: [
                              Icon(Icons.emoji_emotions_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('React', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_activeOverlay!);
  }

  void _showEmojiPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          height: 350,
          child: Column(
            children: [
              Expanded(
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    widget.onReaction?.call(emoji.emoji);
                    Navigator.pop(context);
                  },
                  config: Config(
                    columns: 7,
                    emojiSizeMax: 28,
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    initCategory: Category.SMILEYS,
                    bgColor: Theme.of(context).colorScheme.background,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    iconColor: Colors.grey,
                    iconColorSelected: Theme.of(context).colorScheme.primary,
                    backspaceColor: Theme.of(context).colorScheme.primary,
                    skinToneDialogBgColor: Colors.white,
                    skinToneIndicatorColor: Colors.grey,
                    enableSkinTones: true,
                    recentTabBehavior: RecentTabBehavior.RECENT,
                    recentsLimit: 28,
                    noRecents: const Text(
                      'No Recent',
                      style: TextStyle(fontSize: 20, color: Colors.black26),
                      textAlign: TextAlign.center,
                    ),
                    loadingIndicator: const SizedBox.shrink(),
                    tabIndicatorAnimDuration: kTabScrollDuration,
                    categoryIcons: const CategoryIcons(),
                    buttonMode: ButtonMode.MATERIAL,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactions() {
    if (widget.reactions == null || widget.reactions!.isEmpty)
      return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      children: widget.reactions!.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.key),
              const SizedBox(width: 4),
              Text(
                entry.value.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget messageContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: _isMessageHovered
              ? Colors.grey.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(widget.timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.text,
                        style: const TextStyle(
                          color: Colors.black,
                        ),
                      ),
                      _buildReactions(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (kIsWeb) {
      return MouseRegion(
        onEnter: (_) {
          setState(() {
            _isHovering = true;
            _isMessageHovered = true;
          });
          if (widget.repliable) {
            _showOverlay(context);
          }
        },
        onExit: (_) {
          setState(() {
            _isHovering = false;
            _isMessageHovered = false;
          });
          // Small delay to allow for mouse movement between message and overlay
          Future.delayed(const Duration(milliseconds: 50), () {
            if (!_isHovering && mounted && _messageId == _activeMessageId) {
              _removeGlobalOverlay();
            }
          });
        },
        onHover: (_) {
          if (!_isMessageHovered) {
            setState(() => _isMessageHovered = true);
          }
        },
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: messageContent),
          if (widget.repliable) CompositedTransformTarget(link: _layerLink)
        ]),
      );
    } else {
      return GestureDetector(
        onLongPress: widget.repliable
            ? () {
                final RenderBox button =
                    context.findRenderObject() as RenderBox;
                final Offset offset = button.localToGlobal(Offset.zero);

                showMenu(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    offset.dx,
                    offset.dy,
                    offset.dx + button.size.width,
                    offset.dy + button.size.height,
                  ),
                  items: [
                    PopupMenuItem(
                      onTap: widget.onReply,
                      child: const Row(
                        children: [
                          Icon(Icons.reply),
                          SizedBox(width: 8),
                          Text('Reply'),
                        ],
                      ),
                    ),
                  ],
                );
              }
            : null,
        child: messageContent,
      );
    }
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey[300],
      child: Text(
        widget.username[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now().toUtc();
    final utcTimestamp = timestamp.toUtc();
    final difference = now.difference(utcTimestamp);

    if (difference.inDays > 7) {
      // Show full date for messages older than a week
      return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inSeconds > 30) {
      return '${difference.inSeconds}s ago';
    } else {
      return 'just now';
    }
  }
}
