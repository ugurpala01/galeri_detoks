import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Tek bildirim ID'si - çift bildirim olmaması için
  static const int _notificationId = 100;

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'galeri_detoks_scan',
          'Galeri Detoks Tarama',
          description: 'Galeri tarama bildirimleri',
          importance: Importance.low,
        ),
      );
    }
  }

  static Future<void> showProgressNotification(int progress, int scanned, int total) async {
    final androidDetails = AndroidNotificationDetails(
      'galeri_detoks_scan',
      'Galeri Detoks Tarama',
      channelDescription: 'Galeri tarama bildirimleri',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _notificationId,
      'Galeri Detoks - Taranıyor',
      '$scanned / $total görsel tarandı (%$progress)',
      details,
    );
  }

  static Future<void> showCompletionNotification(int detected, int total) async {
    // Önce TÜM bildirimleri kapat (çift bildirim olmaması için)
    await _plugin.cancelAll();

    final androidDetails = AndroidNotificationDetails(
      'galeri_detoks_scan',
      'Galeri Detoks Tarama',
      channelDescription: 'Galeri tarama bildirimleri',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      showProgress: false,
      ongoing: false,
      autoCancel: true,
      onlyAlertOnce: true,
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _notificationId,
      'Tarama Tamamlandı',
      '$detected kutlama görseli bulundu ($total tarandı)',
      details,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
