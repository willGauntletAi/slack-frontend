import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../providers/message_provider.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/api_config.dart';
import '../providers/presence_provider.dart';

class ChatMessage extends StatefulWidget {
  final String text;
  final bool isMe;
  final String username;
  final DateTime timestamp;
  final Function()? onReply;
  final Function(String emoji)? onReaction;
  final bool repliable;
  final Map<String, int>? reactions;
  final Set<String>? myReactions;
  final List<MessageAttachment>? attachments;
  final String userId;
  final bool isLastRead;
  final bool isSelectedMessage;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isMe,
    required this.username,
    required this.timestamp,
    required this.userId,
    this.onReply,
    this.onReaction,
    this.repliable = true,
    this.reactions,
    this.myReactions,
    this.attachments,
    required this.isLastRead,
    this.isSelectedMessage = false,
  });

  @override
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage>
    with SingleTickerProviderStateMixin {
  // Track both the active message and its overlay
  static String? _activeMessageId;
  static OverlayEntry? _activeOverlay;
  final String _messageId = UniqueKey().toString();
  final LayerLink _layerLink = LayerLink();
  bool _isHovering = false;
  bool _isMessageHovered = false; // separate state for background color
  final _overlayWidth = 200.0; // increased width to accommodate both options
  late final PresenceProvider _presenceProvider;
  late final AnimationController _animationController;
  late final Animation<double> _fontSizeAnimation;

  @override
  void initState() {
    super.initState();
    _presenceProvider = context.read<PresenceProvider>();
    // Start tracking this user's presence when the widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _presenceProvider.startTrackingUser(widget.userId);
      }
    });

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    // Create font size animation
    _fontSizeAnimation = Tween<double>(
      begin: widget.isSelectedMessage ? 16.0 : 14.0,
      end: 14.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Start animation if this is the selected message
    if (widget.isSelectedMessage) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    if (_messageId == _activeMessageId) {
      _removeGlobalOverlay();
    }
    // Directly stop tracking the user instead of scheduling it
    _presenceProvider.stopTrackingUser(widget.userId);
    _animationController.dispose();
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
    if (!widget.repliable || !mounted) return;

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
              // Only handle enter if this is still the active message and widget is mounted
              if (_messageId == _activeMessageId && mounted) {
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
                    bgColor: Theme.of(context).colorScheme.surface,
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
    if (widget.reactions == null || widget.reactions!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      children: widget.reactions!.entries.map((entry) {
        final isMyReaction = widget.myReactions?.contains(entry.key) ?? false;
        return InkWell(
          onTap: () {
            // Call onReaction to toggle the reaction
            widget.onReaction?.call(entry.key);
          },
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMyReaction ? Colors.blue[100] : Colors.grey[200],
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
          ),
        );
      }).toList(),
    );
  }

  Future<String?> _getDownloadUrl(String fileKey) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.accessToken == null) return null;

    try {
      final encodedKey = Uri.encodeComponent(fileKey);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/file/$encodedKey/download-url'),
        headers: {
          'Authorization': 'Bearer ${authProvider.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String;
      }
    } catch (e) {}
    return null;
  }

  Widget _buildAttachments() {
    if (widget.attachments == null || widget.attachments!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.attachments!.map((attachment) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: InkWell(
            onTap: () async {
              final downloadUrl = await _getDownloadUrl(attachment.fileKey);
              if (downloadUrl != null && kIsWeb) {
                html.window.open(downloadUrl, '_blank');
              } else if (downloadUrl != null) {
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to get download URL'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              '📎 ${attachment.filename} (${_formatFileSize(attachment.size)})',
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
                      AnimatedBuilder(
                        animation: _fontSizeAnimation,
                        builder: (context, child) => Text(
                          widget.text,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: _fontSizeAnimation.value,
                          ),
                        ),
                      ),
                      if (widget.attachments != null &&
                          widget.attachments!.isNotEmpty)
                        _buildAttachments(),
                      _buildReactions(),
                      if (widget.isLastRead)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 1,
                                color: Colors.grey[300],
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                child: const Text(
                                  'Last read',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
          if (!mounted) return;
          setState(() {
            _isHovering = true;
            _isMessageHovered = true;
          });
          if (widget.repliable) {
            _showOverlay(context);
          }
        },
        onExit: (_) {
          if (!mounted) return;
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
          if (!mounted) return;
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
    return Stack(
      children: [
        CircleAvatar(
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
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Consumer<PresenceProvider>(
            builder: (context, presenceProvider, _) {
              final status = presenceProvider.getUserPresence(widget.userId);
              final isOnline = status == 'online';

              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
              );
            },
          ),
        ),
      ],
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

  @override
  void didUpdateWidget(ChatMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelectedMessage && !oldWidget.isSelectedMessage) {
      _animationController.reset();
      _animationController.forward();
    }
  }
}
