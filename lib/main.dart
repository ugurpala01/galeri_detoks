import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // Yeni eklendi

import 'models/scan_statistics.dart';
import 'models/scan_result.dart';
import 'services/statistics_service.dart';
import 'services/scan_result_service.dart';
import 'services/notification_service.dart';
import 'screens/permission_screen.dart';

void main() async {
  // 1. Flutter ve Veritabanı Başlatma
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  Hive.registerAdapter(ScanStatisticsAdapter());
  Hive.registerAdapter(ScanResultAdapter());
  
  await StatisticsService.init();
  await ScanResultService.init();
  await NotificationService.init();
  await NotificationService.cancelAll();

  // 2. Arka Plan Servisini Başlatma (Yeni eklendi)
  _initForegroundTask();
  
  runApp(
    const ProviderScope(
      child: GaleriDetoksApp(),
    ),
  );
}

/// Android/iOS Arka Plan Servis Yapılandırması
void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'galeri_detoks_scan',
      channelName: 'Galeri Detoks Tarama',
      channelDescription: 'Fotoğraf tarama işlemi arka planda devam ediyor.',
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

class GaleriDetoksApp extends StatelessWidget {
  const GaleriDetoksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galeri Detoks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const PermissionScreen(),
    );
  }
}
