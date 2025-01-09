import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/websocket_service.dart';

class WebSocketProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  bool get isConnected => _webSocketService.isConnected;

  WebSocketProvider() {
    debugPrint('🔌 WebSocketProvider: Initializing');
    _setupMessageListener();
  }

  void _setupMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription =
        _webSocketService.messageStream.listen(_handleWebSocketMessage);
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

  Stream<Map<String, dynamic>> get messageStream =>
      _webSocketService.messageStream;

  Future<void> connect(String token) async {
    debugPrint('🔌 WebSocketProvider: Connect requested');
    await _webSocketService.connect(token);
  }

  void sendTypingIndicator(String channelId, bool isDm) {
    _webSocketService.sendTypingIndicator(channelId, isDm);
  }

  @override
  void dispose() {
    debugPrint('🔌 WebSocketProvider: Disposing');
    _messageSubscription?.cancel();
    super.dispose();
  }
}
