import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;
  Completer<void>? _connectionCompleter;
  Timer? _connectionTimeout;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String token) async {
    if (_isConnected) return;

    _connectionCompleter = Completer<void>();
    final wsUrl = Uri.parse('${ApiConfig.wsUrl}?token=$token');

    try {
      // Create the WebSocket channel
      if (kIsWeb) {
        _channel = HtmlWebSocketChannel.connect(wsUrl.toString());
      } else {
        _channel = WebSocketChannel.connect(wsUrl);
      }

      // Set up connection timeout
      _connectionTimeout?.cancel();
      _connectionTimeout = Timer(const Duration(seconds: 5), () {
        if (_connectionCompleter?.isCompleted == false) {
          _handleDisconnect('Connection timed out');
        }
      });

      // Set up message listener
      _channel?.stream.listen(
        (message) {
          final data = jsonDecode(message);

          if (data['type'] == 'connected' && !_isConnected) {
            _isConnected = true;
            _connectionTimeout?.cancel();
            if (!(_connectionCompleter?.isCompleted ?? true)) {
              _connectionCompleter?.complete();
            }
          }

          _messageController.add(data);
        },
        onError: (error) {
          _handleDisconnect('Stream error: $error');
        },
        onDone: () {
          _handleDisconnect('Connection closed');
        },
        cancelOnError: true,
      );

      await _connectionCompleter?.future;
    } catch (e) {
      _handleDisconnect('Connection error: $e');
      rethrow;
    }
  }

  void _handleDisconnect(String reason) {
    _isConnected = false;
    _connectionTimeout?.cancel();
    if (_connectionCompleter?.isCompleted == false) {
      _connectionCompleter?.completeError(reason);
    }
    _connectionCompleter = null;
    _channel?.sink.close();
    _channel = null;
  }

  void subscribeToWorkspace(String workspaceId) {
    if (!_isConnected) {
      return;
    }

    final message = {
      'type': 'subscribe',
      'workspaceId': workspaceId,
    };
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      _handleDisconnect('Send error: $e');
    }
  }

  void unsubscribeFromWorkspace(String workspaceId) {
    if (!_isConnected) return;

    final message = {
      'type': 'unsubscribe_from_workspace',
      'workspaceId': workspaceId,
    };
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      _handleDisconnect('Send error: $e');
    }
  }

  void sendMessage(String channelId, String content) {
    if (!_isConnected) return;

    final message = {
      'type': 'new_message',
      'channelId': channelId,
      'content': content,
    };
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      _handleDisconnect('Send error: $e');
    }
  }

  void dispose() {
    _connectionTimeout?.cancel();
    _handleDisconnect('Service disposed');
    _messageController.close();
  }
}
