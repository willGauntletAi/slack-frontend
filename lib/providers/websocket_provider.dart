import 'package:flutter/foundation.dart';
import '../services/websocket_service.dart';
import 'typing_indicator_provider.dart';
import 'message_provider.dart';

class WebSocketProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  final TypingIndicatorProvider _typingIndicatorProvider;
  final MessageProvider _messageProvider;
  bool get isConnected => _webSocketService.isConnected;

  WebSocketProvider(this._typingIndicatorProvider, this._messageProvider) {
    _webSocketService.messageStream.listen(_handleWebSocketMessage);
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    if (data['type'] == null) {
      debugPrint('WebSocket message received: $data');
      return;
    }
    debugPrint('WebSocket message received: $data');
    switch (data['type']) {
      case 'typing':
        _typingIndicatorProvider.userStartedTyping(
          data['channelId'],
          data['userId'],
          data['username'],
        );
        break;

      case 'new_message':
        debugPrint('Handling new message event');
        final messageData = data['message'] as Map<String, dynamic>;
        messageData['channel_id'] = data['channelId'];
        _messageProvider.handleNewMessage(messageData);
        break;

      case 'message_updated':
        _messageProvider.handleUpdatedMessage(data['message']);
        break;

      case 'message_deleted':
        _messageProvider.handleDeletedMessage(
          data['messageId'],
          data['channelId'],
        );
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
