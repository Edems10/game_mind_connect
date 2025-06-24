import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  void connect(String matchId) {
    final wsUrl = 'wss://game-mind-api-959217497496.europe-west1.run.app/match/ws/$matchId';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
  }

  Stream get stream {
    if (_channel == null) {
      throw Exception('WebSocket not connected');
    }
    return _channel!.stream;
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
