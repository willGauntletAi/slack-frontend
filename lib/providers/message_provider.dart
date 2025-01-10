import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:slack_frontend/providers/auth_provider.dart';
import 'package:slack_frontend/providers/channel_provider.dart';
import 'dart:async';
import 'dart:convert';
import '../config/api_config.dart';
import 'websocket_provider.dart';

class Message {
  final String id;
  final String content;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String username;
  final String channelId;
  final List<MessageReaction> reactions;
  final List<MessageAttachment> attachments;

  Message({
    required this.id,
    required this.content,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.username,
    required this.channelId,
    required this.reactions,
    required this.attachments,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final List<MessageReaction> reactions =
        (json['reactions'] as List<dynamic>? ?? [])
            .map((reactionJson) => MessageReaction.fromJson(reactionJson))
            .toList();

    final List<MessageAttachment> attachments =
        (json['attachments'] as List<dynamic>? ?? [])
            .map((attachmentJson) => MessageAttachment.fromJson(attachmentJson))
            .toList();

    return Message(
      id: json['id'],
      content: json['content'],
      parentId: json['parent_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      userId: json['user_id'],
      username: json['username'],
      channelId: json['channel_id'],
      reactions: reactions,
      attachments: attachments,
    );
  }
}

class MessageReaction {
  final String id;
  final String emoji;
  final String userId;
  final String username;
  final String messageId;

  MessageReaction({
    required this.id,
    required this.emoji,
    required this.userId,
    required this.username,
    required this.messageId,
  });

  // For API responses
  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'],
      emoji: json['emoji'],
      userId: json['user_id'],
      username: json['username'],
      messageId: json['message_id'],
    );
  }

  // For WebSocket events
  factory MessageReaction.fromWebSocket(
      Map<String, dynamic> json, String messageId) {
    return MessageReaction(
      id: json['id'],
      emoji: json['emoji'],
      userId: json['user_id'],
      username: json['username'],
      messageId: messageId,
    );
  }
}

class MessageAttachment {
  final String fileKey;
  final String filename;
  final String mimeType;
  final int size;

  MessageAttachment({
    required this.fileKey,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      fileKey: json['file_key'],
      filename: json['filename'],
      mimeType: json['mime_type'],
      size: json['size'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'file_key': fileKey,
      'filename': filename,
      'mime_type': mimeType,
      'size': size,
    };
  }
}

class MessageProvider with ChangeNotifier {
  final ChannelProvider channelProvider;
  final AuthProvider authProvider;
  final WebSocketProvider _wsProvider;
  StreamSubscription? _wsSubscription;
  // Map of channelId to list of messages
  final Map<String, List<Message>> _channelMessages = {};
  // Map of channelId to loading state
  final Map<String, bool> _channelLoading = {};
  // Map of channelId to error state
  final Map<String, String?> _channelErrors = {};
  // Map of channelId to last message ID
  final Map<String, String?> _channelLastMessageIds = {};
  // Map of channelId to hasMore state
  final Map<String, bool> _channelHasMore = {};
  // Set of in-progress requests (channelId + lastMessageId)
  final Set<String> _inProgressRequests = {};
  String? get _currentChannelId => channelProvider.selectedChannel?.id;

  MessageProvider(
    this.channelProvider,
    this.authProvider,
    this._wsProvider,
  ) {
    channelProvider.addListener(_handleChannelChange);
    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    _wsSubscription = _wsProvider.messageStream.listen((data) {
      switch (data['type']) {
        case 'new_message':
          debugPrint('Handling new message event');
          final messageData = data['message'] as Map<String, dynamic>;
          messageData['channel_id'] = data['channelId'];
          handleNewMessage(messageData);
          break;

        case 'message_updated':
          handleUpdatedMessage(data['message']);
          break;

        case 'message_deleted':
          handleDeletedMessage(
            data['messageId'],
            data['channelId'],
          );
          break;

        case 'reaction':
          debugPrint('Handling reaction event');
          handleReactionEvent(data);
          break;

        case 'delete_reaction':
          debugPrint('Handling delete reaction event');
          handleDeleteReactionEvent(data);
          break;
      }
    });
  }

  List<Message> get messages => _channelMessages[_currentChannelId] ?? [];
  bool get isLoading => _channelLoading[_currentChannelId] ?? false;
  String? get error => _channelErrors[_currentChannelId];
  bool get hasMore => _channelHasMore[_currentChannelId] ?? true;

  void handleNewMessage(Map<String, dynamic> messageData) {
    debugPrint('Handling new message event');
    final newMessage = Message.fromJson(messageData);
    debugPrint(
        'Created new message object for channel ${newMessage.channelId}');
    debugPrint('Current channel ID: $_currentChannelId');

    final channelMessages = _channelMessages[newMessage.channelId] ?? [];
    debugPrint('Current messages in channel: ${channelMessages.length}');

    // Check if message already exists
    if (channelMessages.any((m) => m.id == newMessage.id)) {
      debugPrint(
          'Message ${newMessage.id} already exists in channel, skipping');
      return; // Skip duplicate message
    }

    // Find the correct position to insert the new message
    // Messages are ordered from newest (largest ID) to oldest (smallest ID)
    int insertIndex =
        channelMessages.indexWhere((m) => m.id.compareTo(newMessage.id) < 0);
    if (insertIndex == -1) {
      debugPrint('Adding message ${newMessage.id} to end of list');
      // If all messages have smaller IDs, append to the end
      channelMessages.add(newMessage);
    } else {
      debugPrint('Inserting message ${newMessage.id} at position $insertIndex');
      // Insert before the first message with a larger ID
      channelMessages.insert(insertIndex, newMessage);
    }
    _channelMessages[newMessage.channelId] = channelMessages;
    debugPrint('Updated messages in channel: ${channelMessages.length}');
    notifyListeners();
  }

  void handleUpdatedMessage(Map<String, dynamic> messageData) {
    final updatedMessage = Message.fromJson(messageData);
    final channelMessages = _channelMessages[updatedMessage.channelId];
    if (channelMessages != null) {
      final index =
          channelMessages.indexWhere((m) => m.id == updatedMessage.id);
      if (index != -1) {
        channelMessages[index] = updatedMessage;
        notifyListeners();
      }
    }
  }

  void handleDeletedMessage(String messageId, String channelId) {
    final channelMessages = _channelMessages[channelId];
    if (channelMessages != null) {
      channelMessages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    }
  }

  void _handleChannelChange() async {
    if (!_channelMessages.containsKey(_currentChannelId)) {
      if (authProvider.accessToken != null &&
          channelProvider.selectedChannel != null) {
        final channelId = channelProvider.selectedChannel!.id;
        _channelLoading[channelId] = false;
        _channelHasMore[channelId] = true;
        await loadMessages(authProvider.accessToken!, channelId);
      }
    }
    notifyListeners();
  }

  Future<void> loadMessages(String accessToken, String channelId,
      {int limit = 50}) async {
    debugPrint('Loading messages for channel: $channelId');

    String? lastMessageId;
    if (_channelMessages[channelId] != null &&
        _channelMessages[channelId]!.isNotEmpty) {
      lastMessageId = _channelMessages[channelId]!.last.id;
    }

    // Create a unique request identifier
    final requestId = '${channelId}_${lastMessageId ?? "initial"}';

    // Check if this exact request is already in progress
    if (_inProgressRequests.contains(requestId)) {
      debugPrint(
          'Request already in progress for channel: $channelId with lastMessageId: $lastMessageId');
      return;
    }

    _inProgressRequests.add(requestId);
    _channelLoading[channelId] = true;
    _channelErrors[channelId] = null;
    notifyListeners();

    try {
      var url = '${ApiConfig.baseUrl}/message/channel/$channelId?limit=$limit';
      if (lastMessageId != null) {
        url += '&before=$lastMessageId';
        debugPrint(
            'Fetching messages from: $url with beforeKey: $lastMessageId');
      } else {
        debugPrint('Fetching messages from: $url with no beforeKey');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('Received ${data.length} messages');
        final newMessages = data.map((json) => Message.fromJson(json)).toList();

        if (newMessages.isEmpty) {
          debugPrint('No more messages to load');
          _channelHasMore[channelId] = false;
        } else {
          final channelMessages = _channelMessages[channelId] ?? [];

          // Filter out any duplicate messages
          final existingIds = channelMessages.map((m) => m.id).toSet();
          final uniqueNewMessages =
              newMessages.where((m) => !existingIds.contains(m.id)).toList();

          debugPrint(
              'Adding ${uniqueNewMessages.length} unique messages to existing ${channelMessages.length} messages');
          channelMessages.addAll(uniqueNewMessages);

          // Sort messages by ID to ensure correct order
          channelMessages
              .sort((a, b) => int.parse(b.id).compareTo(int.parse(a.id)));

          _channelMessages[channelId] = channelMessages;
          _channelLastMessageIds[channelId] = channelMessages.last.id;
          notifyListeners();
        }

        _channelErrors[channelId] = null;
      } else {
        final error = json.decode(response.body);
        debugPrint('Error loading messages: ${error['error']}');
        _channelErrors[channelId] = error['error'] ?? 'Failed to load messages';
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      _channelErrors[channelId] = 'Network error occurred';
    } finally {
      _inProgressRequests.remove(requestId);
      _channelLoading[channelId] = false;
      notifyListeners();
    }
  }

  void clearChannel(String channelId) {
    _channelMessages.remove(channelId);
    _channelLoading.remove(channelId);
    _channelErrors.remove(channelId);
    _channelLastMessageIds.remove(channelId);
    _channelHasMore.remove(channelId);
    notifyListeners();
  }

  void clearAllChannels() {
    _channelMessages.clear();
    _channelLoading.clear();
    _channelErrors.clear();
    _channelLastMessageIds.clear();
    _channelHasMore.clear();
    notifyListeners();
  }

  Future<Message?> sendMessage(
      String accessToken, String channelId, String content,
      {String? parentId, List<MessageAttachment>? attachments}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/message/channel/$channelId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'content': content,
          if (parentId != null) 'parent_id': parentId,
          if (attachments != null)
            'attachments': attachments.map((a) => a.toJson()).toList(),
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newMessage = Message.fromJson(data);
        // Don't add the message here, it will come through WebSocket
        return newMessage;
      } else {
        final error = json.decode(response.body);
        _channelErrors[channelId] = error['error'] ?? 'Failed to send message';
        return null;
      }
    } catch (e) {
      _channelErrors[channelId] = 'Network error occurred';
      return null;
    }
  }

  Future<bool> updateMessage(
      String accessToken, String messageId, String content) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/message/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        // Don't update the message here, it will come through WebSocket
        return true;
      } else {
        final error = json.decode(response.body);
        if (_currentChannelId != null) {
          _channelErrors[_currentChannelId!] =
              error['error'] ?? 'Failed to update message';
        }
        return false;
      }
    } catch (e) {
      if (_currentChannelId != null) {
        _channelErrors[_currentChannelId!] = 'Network error occurred';
      }
      return false;
    }
  }

  Future<bool> deleteMessage(String accessToken, String messageId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/message/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        // Don't remove the message here, it will come through WebSocket
        return true;
      } else {
        final error = json.decode(response.body);
        if (_currentChannelId != null) {
          _channelErrors[_currentChannelId!] =
              error['error'] ?? 'Failed to delete message';
        }
        return false;
      }
    } catch (e) {
      if (_currentChannelId != null) {
        _channelErrors[_currentChannelId!] = 'Network error occurred';
      }
      return false;
    }
  }

  Future<void> addReaction(String messageId, String emoji) async {
    final accessToken = authProvider.accessToken;
    if (accessToken == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/message/$messageId/reaction'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({'emoji': emoji}),
      );

      if (response.statusCode == 201) {
        // The websocket will handle updating the UI
        debugPrint('Reaction added successfully');
      } else {
        final error = json.decode(response.body);
        debugPrint('Error adding reaction: ${error['error']}');
      }
    } catch (e) {
      debugPrint('Error adding reaction: $e');
    }
  }

  Future<void> removeReaction(String messageId, String reactionId) async {
    final accessToken = authProvider.accessToken;
    if (accessToken == null) return;

    try {
      final response = await http.delete(
        Uri.parse(
            '${ApiConfig.baseUrl}/message/$messageId/reaction/$reactionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('Reaction removed successfully');
      } else {
        final error = json.decode(response.body);
        debugPrint('Error removing reaction: ${error['error']}');
      }
    } catch (e) {
      debugPrint('Error removing reaction: $e');
    }
  }

  void handleReactionEvent(Map<String, dynamic> data) {
    final messageId = data['messageId'];
    final channelId = data['channelId'];
    final reaction = MessageReaction(
      id: data['id'],
      emoji: data['emoji'],
      userId: data['userId'],
      username: data['username'],
      messageId: messageId,
    );

    final channelMessages = _channelMessages[channelId];
    if (channelMessages != null) {
      final messageIndex = channelMessages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final message = channelMessages[messageIndex];
        final updatedReactions = List<MessageReaction>.from(message.reactions)
          ..add(reaction);

        channelMessages[messageIndex] = Message(
          id: message.id,
          content: message.content,
          parentId: message.parentId,
          createdAt: message.createdAt,
          updatedAt: message.updatedAt,
          userId: message.userId,
          username: message.username,
          channelId: message.channelId,
          reactions: updatedReactions,
          attachments: message.attachments,
        );

        notifyListeners();
      }
    }
  }

  void handleDeleteReactionEvent(Map<String, dynamic> data) {
    // Matches deleteReactionMessageSchema from ws-types.ts
    final channelId = data['channelId'];
    final reactionId = data['reactionId'];

    final channelMessages = _channelMessages[channelId];
    if (channelMessages != null) {
      // Find the message that contains this reaction
      for (var i = 0; i < channelMessages.length; i++) {
        final message = channelMessages[i];
        final reactionIndex =
            message.reactions.indexWhere((r) => r.id == reactionId);

        if (reactionIndex != -1) {
          // Found the message with this reaction
          final updatedReactions = List<MessageReaction>.from(message.reactions)
            ..removeAt(reactionIndex);

          channelMessages[i] = Message(
            id: message.id,
            content: message.content,
            parentId: message.parentId,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
            userId: message.userId,
            username: message.username,
            channelId: message.channelId,
            reactions: updatedReactions,
            attachments: message.attachments,
          );

          notifyListeners();
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    channelProvider.removeListener(_handleChannelChange);
    _wsSubscription?.cancel();
    super.dispose();
  }
}
