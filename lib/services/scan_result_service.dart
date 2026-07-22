import 'package:hive_flutter/hive_flutter.dart';
import '../models/scan_result.dart';

const String scanResultsBoxName = 'scan_results';

class ScanResultService {
  static late Box<ScanResult> _box;

  static Future<void> init() async {
    _box = await Hive.openBox<ScanResult>(scanResultsBoxName);
  }

  static Future<void> saveResult(ScanResult result) async {
    await _box.put(result.id, result);
  }

  static ScanResult? getLatestResult() {
    if (_box.isEmpty) return null;
    final results = _box.values.toList()
      ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
    return results.first;
  }

  static List<ScanResult> getAllResults() {
    return _box.values.toList()
      ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
  }

  static Future<void> clear() async {
    await _box.clear();
  }

  static DateTime? getLastScanDate() {
    final latest = getLatestResult();
    return latest?.scanDate;
  }
}
