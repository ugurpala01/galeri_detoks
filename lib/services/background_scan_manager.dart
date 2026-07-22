import 'dart:isolate';
import 'dart:async';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_statistics.dart';
import '../models/scan_result.dart';
import '../services/photo_service.dart';
import '../services/ocr_service.dart';
import '../services/keyword_matcher.dart';
import '../services/statistics_service.dart';

class BackgroundScanManager {
  static Isolate? _isolate;
  static ReceivePort? _receivePort;
  static StreamSubscription? _subscription;
  static final _progressController = StreamController<Map<dynamic, dynamic>>.broadcast();

  static Stream<Map<dynamic, dynamic>> get progressStream => _progressController.stream;

  static Future<void> start(List<String> keywords) async {
    await stop();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scan_running', true);
    await prefs.setInt('scan_progress', 0);
    await prefs.setInt('scan_scanned', 0);
    await prefs.setInt('scan_total', 0);

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _scanEntryPoint,
      {
        'keywords': keywords,
        'sendPort': _receivePort!.sendPort,
      },
    );

    _subscription = _receivePort!.listen((message) async {
      if (message is Map) {
        final prefs = await SharedPreferences.getInstance();

        if (message['type'] == 'progress') {
          await prefs.setInt('scan_progress', message['progress']);
          await prefs.setInt('scan_scanned', message['scanned']);
          await prefs.setInt('scan_total', message['total']);
          _progressController.add(message);
        } else if (message['type'] == 'complete') {
          await prefs.setBool('scan_running', false);
          await prefs.setInt('scan_progress', 100);
          _progressController.add(message);
        }
      }
    });
  }

  static Future<void> stop() async {
    await _subscription?.cancel();
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort = null;
    _subscription = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scan_running', false);
  }

  static Future<bool> get isRunning async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('scan_running') ?? false;
  }

  static Future<Map<String, dynamic>> get progress async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'progress': prefs.getInt('scan_progress') ?? 0,
      'scanned': prefs.getInt('scan_scanned') ?? 0,
      'total': prefs.getInt('scan_total') ?? 0,
    };
  }
}

@pragma('vm:entry-point')
void _scanEntryPoint(Map<String, dynamic> args) async {
  final keywords = List<String>.from(args['keywords'] as List);
  final sendPort = args['sendPort'] as SendPort;

  try {
    await Hive.initFlutter();
    Hive.registerAdapter(ScanStatisticsAdapter());
    Hive.registerAdapter(ScanResultAdapter());
    await StatisticsService.init();

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
        continue;
      }

      final progress = ((i + 1) / total * 100).toInt();
      if (progress % 5 == 0) {
        sendPort.send({
          'type': 'progress',
          'progress': progress,
          'scanned': i + 1,
          'total': total,
        });
      }
    }

    ocrService.dispose();

    await StatisticsService.recordScan(
      totalScanned: total,
      detectedCount: detectedCount,
      deletedCount: 0,
    );

    sendPort.send({
      'type': 'complete',
      'detected': detectedCount,
      'total': total,
    });
  } catch (e) {
    sendPort.send({
      'type': 'error',
      'error': e.toString(),
    });
  }
}
