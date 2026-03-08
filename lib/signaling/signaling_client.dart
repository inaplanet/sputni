import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/app_logger.dart';
import 'signaling_message.dart';

typedef MessageCallback = void Function(SignalingMessage message);
typedef ErrorCallback = void Function(Object error, [StackTrace? stackTrace]);
typedef VoidCallback = void Function();

class SignalingClient {
  SignalingClient({
    required this.serverUrl,
    this.reconnectDelay = const Duration(seconds: 2),
    this.maxReconnectAttempts = 5,
  });

  final String serverUrl;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  int _reconnectAttempts = 0;
  bool _manualClose = false;

  MessageCallback? onMessage;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  ErrorCallback? onError;

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    _manualClose = false;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      onConnected?.call();
      _reconnectAttempts = 0;

      _subscription = _channel!.stream.listen(
        _handleRawMessage,
        onError: (Object error, StackTrace stackTrace) {
          AppLogger.error('WebSocket stream error', error, stackTrace);
          onError?.call(error, stackTrace);
          _handleDisconnect();
        },
        onDone: _handleDisconnect,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to connect to signaling server', error, stackTrace);
      onError?.call(error, stackTrace);
      _scheduleReconnect();
    }
  }

  void send(SignalingMessage message) {
    final channel = _channel;
    if (channel == null) {
      onError?.call(StateError('Cannot send before signaling is connected'));
      return;
    }
    channel.sink.add(message.encode());
  }

  Future<void> disconnect() async {
    _manualClose = true;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    onDisconnected?.call();
  }

  void _handleRawMessage(dynamic data) {
    if (data is! String) {
      onError?.call(FormatException('Unexpected signaling payload type: ${data.runtimeType}'));
      return;
    }

    try {
      final message = SignalingMessage.decode(data);
      onMessage?.call(message);
    } catch (error, stackTrace) {
      AppLogger.error('Failed to parse signaling message', error, stackTrace);
      onError?.call(error, stackTrace);
    }
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    onDisconnected?.call();

    if (!_manualClose) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      onError?.call(StateError('Max reconnect attempts reached'));
      return;
    }
    _reconnectAttempts += 1;
    Future<void>.delayed(reconnectDelay, connect);
  }
}
