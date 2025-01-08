import 'package:flutter/foundation.dart';
import '../services/websocket_service.dart';

class WebSocketProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  bool get isConnected => _webSocketService.isConnected;

  WebSocketProvider() {
    _webSocketService.messageStream.listen(_handleWebSocketMessage);
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    if (data['type'] == null) {
      debugPrint('WebSocket message received without type: $data');
      return;
    }
    debugPrint('WebSocket message received: $data');

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
    await _webSocketService.connect(token);
  }

  void sendMessage(String channelId, String content) {
    _webSocketService.sendMessage(channelId, content);
  }

  void sendTypingIndicator(String channelId, bool isDm) {
    _webSocketService.sendTypingIndicator(channelId, isDm);
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }
}
