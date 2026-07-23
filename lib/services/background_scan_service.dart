import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:workmanager/workmanager.dart';
import '../models/scan_result.dart';
import '../models/scan_statistics.dart';
import '../services/photo_service.dart';
import '../services/ocr_service.dart';
import '../services/keyword_matcher.dart';
import '../services/statistics_service.dart';

const backgroundScanTaskName = 'backgroundScanTask';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Arka planda tarama görevini başlat
Future<void> initBackgroundScan() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings settings =
      InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(settings);

  // Android 13+ notification izni iste
  await Permission.notification.request();

  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
}

/// Arka planda tarama görevini planla
Future<void> scheduleBackgroundScan(
  List<String> selectedKeywords,
) async {
  await Workmanager().registerOneOffTask(
    backgroundScanTaskName,
    backgroundScanTaskName,
    inputData: {'keywords': selectedKeywords},
    constraints: Constraints(
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      networkType: NetworkType.notRequired,
    ),
  );
}

/// Callback fonksiyonu (main thread'de çalışmaz, izole edilmiş)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == backgroundScanTaskName) {
      try {
        // Workmanager callback içinde Hive'ı başlat
        await Hive.initFlutter();
        Hive.registerAdapter(ScanStatisticsAdapter());
        Hive.registerAdapter(ScanResultAdapter());
        await StatisticsService.init();

        final keywords = List<String>.from(inputData?['keywords'] ?? []);
        if (keywords.isEmpty) return false;

        final photoService = PhotoService();
        final ocrService = OcrService();

        final assets = await photoService.loadAllImages();
        final total = assets.length;
        int detectedCount = 0;

        for (int i = 0; i < total; i++) {
          try {
            final asset = assets[i];
            String? path;

            if (asset is AssetEntity) {
              final file = await asset.file;
              path = file?.path;
            } else if (asset is File) {
              path = asset.path;
            }

            if (path == null) continue;

            final String text;
            if (asset is AssetEntity) {
              text = await ocrService.extractTextFromAsset(asset);
            } else {
              text = await ocrService.extractText(path);
            }

            if (KeywordMatcher.hasKeyword(text, keywords)) {
              detectedCount++;
            }
          } catch (e) {
            // Silinmiş/erişilemeyen dosyaları atla
            continue;
          }

          // %25, %50, %75'de notification göster
          final progress = ((i + 1) / total * 100).toInt();
          if (progress == 25 || progress == 50 || progress == 75) {
            await _showProgressNotification(progress, total, i + 1);
          }
        }

        ocrService.dispose();

        // İstatistik kaydet
        await StatisticsService.recordScan(
          totalScanned: total,
          detectedCount: detectedCount,
          deletedCount: 0, // Arka planda silmiyor
        );

        // Tamamlandı notification
        await _showCompletionNotification(detectedCount, total);
        return true;
      } catch (e) {
        await _showErrorNotification(e.toString());
        return false;
      }
    }
    return false;
  });
}

Future<void> _showProgressNotification(
    int progress, int total, int scanned) async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'scan_channel',
    'Galeri Taraması',
    channelDescription: 'Arka plan tarama bildirimleri',
    importance: Importance.low,
    priority: Priority.low,
    icon: '@mipmap/ic_launcher',
    ongoing: true,
    showProgress: true,
    maxProgress: 100,
  );

  NotificationDetails platformChannelSpecifics =
      const NotificationDetails(android: androidDetails);

  await notificationsPlugin.show(
    1,
    'Tarama Devam Ediyor',
    '$scanned / $total görsel tarandı (%$progress)',
    platformChannelSpecifics,
  );
}

Future<void> _showCompletionNotification(int detected, int total) async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'scan_channel',
    'Galeri Taraması',
    channelDescription: 'Arka plan tarama bildirimleri',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidDetails);

  await notificationsPlugin.show(
    1,
    'Tarama Tamamlandı',
    '$detected kutlama görseli bulundu ($total tarandı)',
    platformChannelSpecifics,
  );
}

Future<void> _showErrorNotification(String error) async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'scan_channel',
    'Galeri Taraması',
    channelDescription: 'Arka plan tarama bildirimleri',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidDetails);

  await notificationsPlugin.show(
    2,
    'Tarama Hatası',
    error,
    platformChannelSpecifics,
  );
}
