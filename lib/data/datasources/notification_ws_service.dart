import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:test_y_app/core/constants/env_config.dart';
import 'package:test_y_app/core/storage/storage_manager.dart';
import 'package:test_y_app/data/models/notification/notification_item.dart';

typedef NotificationWsCallback = void Function(
  NotificationItem item,
  int unreadCount,
);
typedef WsConnectionCallback = void Function(bool connected);

class NotificationWsService {
  NotificationWsService({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _pongWatchdog;
  int _reconnectAttempts = 0;
  bool _manuallyDisconnected = false;
  bool _isConnecting = false;

  NotificationWsCallback? onNotification;
  WsConnectionCallback? onConnectionChanged;

  bool get isConnected => _socket?.readyState == WebSocket.open;

  static const _heartbeatInterval = Duration(seconds: 25);
  static const _pongTimeout = Duration(seconds: 60);
  static const _maxBackoffSeconds = 30;

  Future<void> connect() async {
    if (_isConnecting || isConnected) return;
    _manuallyDisconnected = false;
    _isConnecting = true;

    final token = await StorageManager().getAccessToken();
    if (token == null || token.isEmpty) {
      _logger.w('NotificationWs: no access token, skipping connect');
      _isConnecting = false;
      return;
    }

    final wsUrl = _resolveWsUrl();
    if (wsUrl.isEmpty) {
      _logger.w('NotificationWs: WS URL not configured');
      _isConnecting = false;
      return;
    }

    final baseUri = Uri.parse(wsUrl);
    final uri = baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: {
        ...baseUri.queryParameters,
        'token': token,
      },
    );

    try {
      await _disposeSocket();
      _socket = await WebSocket.connect(uri.toString());
      _isConnecting = false;
      _reconnectAttempts = 0;
      onConnectionChanged?.call(true);
      _logger.i('NotificationWs: connected to $uri');

      _subscription = _socket!.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: _handleDisconnect,
        cancelOnError: true,
      );

      _startHeartbeat();
    } catch (e, st) {
      _isConnecting = false;
      _logger.e('NotificationWs: connect failed', error: e, stackTrace: st);
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final String text;
      if (data is String) {
        text = data;
      } else if (data is List<int>) {
        text = utf8.decode(data);
      } else {
        return;
      }

      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type']?.toString();
      if (type == 'NOTIFICATION_NEW') {
        final rawItem = decoded['data'];
        if (rawItem is Map<String, dynamic>) {
          final item = NotificationItem.fromJson(rawItem);
          final unreadCount = (decoded['unreadCount'] as num?)?.toInt() ?? 0;
          onNotification?.call(item, unreadCount);
        }
      } else if (type == 'PONG') {
        _pongWatchdog?.cancel();
        _pongWatchdog = null;
        _logger.d('NotificationWs: PONG received');
      }
    } catch (e, st) {
      _logger.w('NotificationWs: message parse error', error: e, stackTrace: st);
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendPing();
    });
  }

  void _sendPing() {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;

    socket.add(jsonEncode({'type': 'PING'}));

    _pongWatchdog?.cancel();
    _pongWatchdog = Timer(_pongTimeout, () {
      _logger.w(
        'NotificationWs: no PONG within ${_pongTimeout.inSeconds}s, forcing reconnect',
      );
      _forceReconnect();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pongWatchdog?.cancel();
    _pongWatchdog = null;
  }

  void _handleDisconnect([dynamic error]) {
    _isConnecting = false;
    _stopHeartbeat();
    onConnectionChanged?.call(false);
    if (!_manuallyDisconnected) {
      _scheduleReconnect();
    }
    _logger.w('NotificationWs: disconnected${error != null ? ' — $error' : ''}');
  }

  Future<void> _disposeSocket() async {
    await _subscription?.cancel();
    _subscription = null;
    _stopHeartbeat();
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  void _forceReconnect() {
    unawaited(_disposeSocket());
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manuallyDisconnected) return;
    _reconnectTimer?.cancel();

    _reconnectAttempts++;
    final delay = _backoffSeconds(_reconnectAttempts);
    _logger.i(
      'NotificationWs: reconnect in ${delay}s (attempt $_reconnectAttempts)',
    );
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      unawaited(connect());
    });
  }

  static int _backoffSeconds(int attempt) {
    switch (attempt) {
      case 1:
        return 3;
      case 2:
        return 5;
      case 3:
        return 10;
      default:
        return _maxBackoffSeconds;
    }
  }

  Future<void> disconnect() async {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _disposeSocket();
    _isConnecting = false;
    _reconnectAttempts = 0;
    onConnectionChanged?.call(false);
  }

  String _resolveWsUrl() => EnvConfig.notificationWsUrl;

  void dispose() {
    unawaited(disconnect());
  }
}
