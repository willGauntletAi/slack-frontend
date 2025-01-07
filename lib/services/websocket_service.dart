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
    
    debugPrint('Connecting to WebSocket...');
    _connectionCompleter = Completer<void>();
    final wsUrl = Uri.parse('${ApiConfig.wsUrl}?token=$token');
    debugPrint('WebSocket URL: $wsUrl');
    
    try {
      // Create the WebSocket channel
      if (kIsWeb) {
        _channel = HtmlWebSocketChannel.connect(wsUrl.toString());
        debugPrint('Created HTML WebSocket channel');
      } else {
        _channel = WebSocketChannel.connect(wsUrl);
        debugPrint('Created IO WebSocket channel');
      }

      // Set up connection timeout
      _connectionTimeout?.cancel();
      _connectionTimeout = Timer(const Duration(seconds: 5), () {
        if (_connectionCompleter?.isCompleted == false) {
          debugPrint('WebSocket connection timed out');
          _handleDisconnect('Connection timed out');
        }
      });

      // Set up message listener
      _channel?.stream.listen(
        (message) {
          debugPrint('Raw WebSocket message received: $message');
          try {
            final data = jsonDecode(message);
            debugPrint('WebSocket message decoded: $data');
            
            if (data['type'] == 'connected' && !_isConnected) {
              debugPrint('Connection successful message received');
              _isConnected = true;
              _connectionTimeout?.cancel();
              if (!(_connectionCompleter?.isCompleted ?? true)) {
                _connectionCompleter?.complete();
              }
              debugPrint('Connection completer completed');
            }
            
            _messageController.add(data);
          } catch (e) {
            debugPrint('Error processing WebSocket message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
          _handleDisconnect('Stream error: $error');
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _handleDisconnect('Connection closed');
        },
        cancelOnError: true,
      );

      debugPrint('Waiting for connection to be established...');
      await _connectionCompleter?.future;
      debugPrint('Connection established successfully');
    } catch (e) {
      debugPrint('Error during WebSocket connection: $e');
      _handleDisconnect('Connection error: $e');
      rethrow;
    }
  }

  void _handleDisconnect(String reason) {
    debugPrint('Handling disconnect: $reason');
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
      debugPrint('Cannot subscribe: WebSocket not connected');
      return;
    }
    
    final message = {
      'type': 'subscribe',
      'workspaceId': workspaceId,
    };
    debugPrint('Sending workspace subscription: $message');
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error sending subscription: $e');
      _handleDisconnect('Send error: $e');
    }
  }

  void unsubscribeFromWorkspace(String workspaceId) {
    if (!_isConnected) return;
    
    final message = {
      'type': 'unsubscribe_from_workspace',
      'workspaceId': workspaceId,
    };
    debugPrint('Sending workspace unsubscription: $message');
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error sending unsubscription: $e');
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
    debugPrint('Sending message: $message');
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error sending message: $e');
      _handleDisconnect('Send error: $e');
    }
  }

  void dispose() {
    _connectionTimeout?.cancel();
    _handleDisconnect('Service disposed');
    _messageController.close();
  }
} 