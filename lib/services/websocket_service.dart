import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  WebSocketService._internal();

  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;
  Completer<void>? _connectionCompleter;
  Timer? _connectionTimeout;
  StreamSubscription? _channelSubscription;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String token) async {
    if (_isConnected) {
      return;
    }

    // Clean up any existing connection
    await _cleanupConnection();

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
      _channelSubscription = _channel?.stream.listen(
        (message) {
          final data = jsonDecode(message);

          if (data['type'] == 'connected' && !_isConnected) {
            _isConnected = true;
            _connectionTimeout?.cancel();
            if (!(_connectionCompleter?.isCompleted ?? true)) {
              _connectionCompleter?.complete();
            }
            // Send connection success event
            _messageController.add({
              'type': 'connection_success',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }

          // Only broadcast the original message if it's not a connection message
          // or if it contains additional data beyond just the connection status
          if (data['type'] != 'connected' || data['userId'] != null) {
            _messageController.add(data);
          }
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

  Future<void> _cleanupConnection() async {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _connectionTimeout?.cancel();
    _connectionTimeout = null;
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void _handleDisconnect(String reason) {
    _isConnected = false;
    _connectionTimeout?.cancel();
    if (_connectionCompleter?.isCompleted == false) {
      _connectionCompleter?.completeError(reason);
    }
    _connectionCompleter = null;
    _cleanupConnection();

    // Emit connection closed event
    if (!_messageController.isClosed) {
      _messageController.add({
        'type': 'connection_closed',
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void sendTypingIndicator(String channelId, bool isDm) {
    if (!_isConnected) return;

    final message = {
      'type': 'typing',
      'channelId': channelId,
      'isDM': isDm,
    };
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      _handleDisconnect('Send error: $e');
    }
  }

  void sendPresenceSubscribe(String userId) {
    if (!_isConnected) return;

    final message = {
      'type': 'subscribe_to_presence',
      'userId': userId,
    };
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      _handleDisconnect('Send error: $e');
    }
  }

  void sendPresenceUnsubscribe(String userId) {
    if (!_isConnected) return;

    final message = {
      'type': 'unsubscribe_from_presence',
      'userId': userId,
    };
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      _handleDisconnect('Send error: $e');
    }
  }

  void sendMarkRead(String channelId, String messageId) {
    if (!_isConnected) return;

    final message = {
      'type': 'mark_read',
      'channelId': channelId,
      'messageId': messageId,
    };
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      _handleDisconnect('Send error: $e');
    }
  }

  void disconnect() {
    _handleDisconnect('Disconnected by user');
  }

  void dispose() {
    _cleanupConnection();
    // We don't close the message controller since this is a singleton
    // and the controller needs to be reused for future connections
  }
}
