import 'dart:isolate';
import 'dart:async';
import '../services/photo_service.dart';
import '../services/ocr_service.dart';
import '../services/keyword_matcher.dart';
import '../services/statistics_service.dart';
import 'notification_service.dart';

class BackgroundScanIsolate {
  static Isolate? _isolate;
  static ReceivePort? _receivePort;
  static StreamSubscription? _subscription;

  static Future<void> start(List<String> keywords) async {
    await stop();

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _scanEntryPoint,
      {
        'keywords': keywords,
        'sendPort': _receivePort!.sendPort,
      },
    );

    _subscription = _receivePort!.listen((message) {
      if (message is Map) {
        final type = message['type'] as String?;
        if (type == 'progress') {
          final progress = message['progress'] as int;
          final scanned = message['scanned'] as int;
          final total = message['total'] as int;
          NotificationService.showProgressNotification(progress, scanned, total);
        } else if (type == 'complete') {
          final detected = message['detected'] as int;
          final total = message['total'] as int;
          NotificationService.showCompletionNotification(detected, total);
        } else if (type == 'error') {
          NotificationService.showErrorNotification(message['error'] as String);
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
  }

  static bool get isRunning => _isolate != null;
}

@pragma('vm:entry-point')
void _scanEntryPoint(Map<String, dynamic> args) async {
  final keywords = List<String>.from(args['keywords'] as List);
  final sendPort = args['sendPort'] as SendPort;

  try {
    final photoService = PhotoService();
    final ocrService = OcrService();

    final assets = await photoService.loadAllImages();
    final total = assets.length;
    int detectedCount = 0;

    for (int i = 0; i < total; i++) {
      try {
        final asset = assets[i];
        final file = await asset.file;
        if (file == null) continue;

        final text = await ocrService.extractText(file.path);
        if (KeywordMatcher.hasKeyword(text, keywords)) {
          detectedCount++;
        }
      } catch (e) {
        continue;
      }

      final progress = ((i + 1) / total * 100).toInt();
      if (progress % 25 == 0) {
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
