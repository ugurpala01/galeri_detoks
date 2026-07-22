import 'package:hive_flutter/hive_flutter.dart';
import '../models/scan_statistics.dart';

const String statisticsBoxName = 'scan_statistics';

class StatisticsService {
  static late Box<ScanStatistics> _box;

  static Future<void> init() async {
    _box = await Hive.openBox<ScanStatistics>(statisticsBoxName);
  }

  static Future<void> recordScan({
    required int totalScanned,
    required int detectedCount,
    required int deletedCount,
  }) async {
    final stat = ScanStatistics(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scannedAt: DateTime.now(),
      totalScanned: totalScanned,
      totalDeleted: deletedCount,
      detectedCount: detectedCount,
    );
    await _box.add(stat);
  }

  static List<ScanStatistics> getAllStats() {
    return _box.values.toList().reversed.toList();
  }

  static Future<void> clear() async {
    await _box.clear();
  }

  static int getTotalDeleted() {
    return _box.values.fold<int>(
      0,
      (sum, stat) => sum + stat.totalDeleted,
    );
  }

  static int getTotalScanned() {
    return _box.values.fold<int>(
      0,
      (sum, stat) => sum + stat.totalScanned,
    );
  }
}
