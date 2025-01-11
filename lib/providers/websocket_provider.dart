import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/websocket_service.dart';

class WebSocketProvider with ChangeNotifier {
  WebSocketService? _webSocketService;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  bool get isConnected => _webSocketService?.isConnected ?? false;

  WebSocketProvider() {
    debugPrint('🔌 WebSocketProvider: Initializing');
  }

  void _setupMessageListener() {
    _messageSubscription?.cancel();
    if (_webSocketService != null) {
      _messageSubscription =
          _webSocketService!.messageStream.listen(_handleWebSocketMessage);
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    if (data['type'] == null) {
      debugPrint('🔌 WebSocketProvider: Message received without type: $data');
      return;
    }
    debugPrint('🔌 WebSocketProvider: Message received: ${data['type']}');

    // Only handle connection state changes here
    switch (data['type']) {
      case 'connection_success':
      case 'connection_closed':
        notifyListeners();
        break;
    }
  }

  Stream<Map<String, dynamic>> get messageStream {
    if (_webSocketService == null) {
      return const Stream.empty();
    }
    return _webSocketService!.messageStream;
  }

  Future<void> connect(String token) async {
    debugPrint('🔌 WebSocketProvider: Connect requested');
    // Create new service instance if needed
    _webSocketService ??= WebSocketService();
    _setupMessageListener();
    await _webSocketService!.connect(token);
  }

  void sendTypingIndicator(String channelId, bool isDm) {
    _webSocketService?.sendTypingIndicator(channelId, isDm);
  }

  void sendPresenceSubscribe(String userId) {
    _webSocketService?.sendPresenceSubscribe(userId);
  }

  void sendPresenceUnsubscribe(String userId) {
    _webSocketService?.sendPresenceUnsubscribe(userId);
  }

  void sendMarkRead(String channelId, String messageId) {
    _webSocketService?.sendMarkRead(channelId, messageId);
  }

  void disconnect() {
    debugPrint('🔌 WebSocketProvider: Disconnecting');
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _webSocketService?.disconnect();
  }

  @override
  void dispose() {
    debugPrint('🔌 WebSocketProvider: Disposing');
    disconnect();
    super.dispose();
  }
}
