import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';

class SocketService {
  io.Socket? _socket;
  final listeners = <String, List<Function>>{};

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    disconnect();
    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) => _emit('connected', null));
    _socket!.onDisconnect((_) => _emit('disconnected', null));

    for (final event in [
      'message:new',
      'message:updated',
      'message:deleted',
      'message:status',
      'typing:start',
      'typing:stop',
      'invite:received',
      'group-invite:received',
      'poll:updated',
      'chat:created',
      'notification',
    ]) {
      _socket!.on(event, (data) => _emit(event, data));
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void on(String event, Function callback) {
    listeners.putIfAbsent(event, () => []).add(callback);
  }

  void off(String event, Function callback) {
    listeners[event]?.remove(callback);
  }

  void _emit(String event, dynamic data) {
    for (final cb in listeners[event] ?? []) {
      cb(data);
    }
  }

  void joinChat(String chatId) => _socket?.emit('chat:join', chatId);
  void typingStart(String chatId) => _socket?.emit('typing:start', {'chatId': chatId});
  void typingStop(String chatId) => _socket?.emit('typing:stop', {'chatId': chatId});
}
