import 'package:hive_flutter/hive_flutter.dart';

part 'scan_statistics.g.dart';

@HiveType(typeId: 0)
class ScanStatistics {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime scannedAt;

  @HiveField(2)
  final int totalScanned;

  @HiveField(3)
  final int totalDeleted;

  @HiveField(4)
  final int detectedCount;

  ScanStatistics({
    required this.id,
    required this.scannedAt,
    required this.totalScanned,
    required this.totalDeleted,
    required this.detectedCount,
  });

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(scannedAt);

    if (diff.inDays == 0) {
      return 'Bugün ${scannedAt.hour.toString().padLeft(2, '0')}:${scannedAt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${scannedAt.day}/${scannedAt.month}/${scannedAt.year}';
    }
  }

  double get deletionRate =>
      detectedCount > 0 ? (totalDeleted / detectedCount) * 100 : 0;
}
