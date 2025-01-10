import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_provider.dart';
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
    return Message(
      id: json['id'],
      content: json['content'],
      parentId: json['parent_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      userId: json['user_id'],
      username: json['username'],
      channelId: json['channel_id'],
      reactions: (json['reactions'] as List?)
              ?.map((r) => MessageReaction.fromJson(r))
              .toList() ??
          [],
      attachments: (json['attachments'] as List?)
              ?.map((a) => MessageAttachment.fromJson(a))
              .toList() ??
          [],
    );
  }
}

class MessageReaction {
  final String id;
  final String emoji;
  final String messageId;
  final String userId;
  final String username;

  MessageReaction({
    required this.id,
    required this.emoji,
    required this.messageId,
    required this.userId,
    required this.username,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'],
      emoji: json['emoji'],
      messageId: json['message_id'],
      userId: json['user_id'],
      username: json['username'],
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
}

class MessageProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  final WebSocketProvider _wsProvider;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _hasBefore = true;
  bool _hasAfter = true;
  String? _currentChannelId;
  String? _error;

  MessageProvider({
    required AuthProvider authProvider,
    required WebSocketProvider wsProvider,
  })  : _authProvider = authProvider,
        _wsProvider = wsProvider;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get hasBefore => _hasBefore;
  bool get hasAfter => _hasAfter;
  String? get error => _error;

  Future<void> loadMessages(
    String channelId, {
    int limit = 50,
    String? before,
    String? after,
    String? around,
  }) async {
    if (_isLoading) return;
    final accessToken = _authProvider.accessToken;
    if (accessToken == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_currentChannelId != channelId) {
        _messages = [];
        _hasBefore = true;
        _hasAfter = true;
        _currentChannelId = channelId;
      }

      final queryParams = {
        'limit': limit.toString(),
        if (before != null) 'before': before,
        if (after != null) 'after': after,
        if (around != null) 'around': around,
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/message/channel/$channelId')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final newMessages = data.map((m) => Message.fromJson(m)).toList();

        if (after != null) {
          _messages.addAll(newMessages);
          _hasAfter = newMessages.length == limit;
        } else if (before != null) {
          _messages.insertAll(0, newMessages);
          _hasBefore = newMessages.length == limit;
        } else {
          _messages = newMessages;
          _hasBefore = newMessages.length == limit;
          _hasAfter = newMessages.length == limit;
        }
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Failed to load messages';
      }
    } catch (e) {
      _error = 'An error occurred while loading messages';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> before() async {
    if (!_hasBefore || _messages.isEmpty || _currentChannelId == null) {
      debugPrint(
          '📜 Before load skipped - hasBefore: $_hasBefore, messages empty: ${_messages.isEmpty}, channelId: $_currentChannelId');
      return;
    }
    debugPrint('📜 Loading messages before ${_messages.first.id}');
    await loadMessages(
      _currentChannelId!,
      before: _messages.first.id,
    );
  }

  Future<void> after() async {
    if (!_hasAfter || _messages.isEmpty || _currentChannelId == null) {
      debugPrint(
          '📜 After load skipped - hasAfter: $_hasAfter, messages empty: ${_messages.isEmpty}, channelId: $_currentChannelId');
      return;
    }
    debugPrint('📜 Loading messages after ${_messages.last.id}');
    await loadMessages(
      _currentChannelId!,
      after: _messages.last.id,
    );
  }

  void markMessageAsRead(String channelId, String messageId) {
    _wsProvider.sendMarkRead(channelId, messageId);
  }

  Future<Message?> sendMessage(
    String channelId,
    String content, {
    String? parentId,
    List<MessageAttachment>? attachments,
  }) async {
    final accessToken = _authProvider.accessToken;
    if (accessToken == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return null;
    }

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/message/channel/$channelId');
      debugPrint('🚀 Sending message to: $uri');

      final body = {
        'content': content,
        if (parentId != null) 'parent_id': parentId,
        if (attachments != null)
          'attachments': attachments
              .map((a) => {
                    'file_key': a.fileKey,
                    'filename': a.filename,
                    'mime_type': a.mimeType,
                    'size': a.size,
                  })
              .toList(),
      };
      debugPrint('📦 Request body: ${json.encode(body)}');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return Message.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Failed to send message';
        notifyListeners();
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending message: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'An error occurred while sending message';
      notifyListeners();
      return null;
    }
  }

  Future<MessageReaction?> addReaction(String messageId, String emoji) async {
    final accessToken = _authProvider.accessToken;
    if (accessToken == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return null;
    }

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/message/$messageId/reaction');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'emoji': emoji}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return MessageReaction.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Failed to add reaction';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'An error occurred while adding reaction';
      notifyListeners();
      return null;
    }
  }

  Future<bool> removeReaction(String messageId, String reactionId) async {
    final accessToken = _authProvider.accessToken;
    if (accessToken == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }

    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/message/$messageId/reaction/$reactionId');

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Failed to remove reaction';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'An error occurred while removing reaction';
      notifyListeners();
      return false;
    }
  }
}
