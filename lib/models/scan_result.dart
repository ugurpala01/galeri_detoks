import 'package:hive_flutter/hive_flutter.dart';

part 'scan_result.g.dart';

@HiveType(typeId: 1)
class ScanResult {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime scanDate;

  @HiveField(2)
  final List<String> detectedAssetIds;

  @HiveField(3)
  final int totalScanned;

  @HiveField(4)
  final int detectedCount;

  @HiveField(5)
  final List<String> keywords;

  @HiveField(6)
  final int deletedCount;

  ScanResult({
    required this.id,
    required this.scanDate,
    required this.detectedAssetIds,
    required this.totalScanned,
    required this.detectedCount,
    required this.keywords,
    this.deletedCount = 0,
  });
}
