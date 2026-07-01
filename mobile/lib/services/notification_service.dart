import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _permissionGranted = false;

  static const _channelId = 'messenger_channel';
  static const _channel = AndroidNotificationChannel(
    _channelId,
    'Messenger',
    description: 'New messages and chat invitations',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_channel);
      final granted = await androidPlugin?.requestNotificationsPermission();
      _permissionGranted = granted ?? false;
      if (!_permissionGranted) {
        final status = await Permission.notification.request();
        _permissionGranted = status.isGranted;
      }
    } else {
      _permissionGranted = true;
    }

    _initialized = true;
  }

  static Future<bool> ensurePermission() async {
    await init();
    if (kIsWeb) return false;
    if (_permissionGranted) return true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      _permissionGranted = granted ?? false;
      if (!_permissionGranted) {
        final status = await Permission.notification.request();
        _permissionGranted = status.isGranted;
      }
    }
    return _permissionGranted;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();
    if (!await ensurePermission()) {
      debugPrint('Notification permission denied');
      return;
    }

    await _plugin.show(
      id.abs(),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
