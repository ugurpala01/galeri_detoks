import 'package:photo_manager/photo_manager.dart';
import 'keyword_matcher.dart';
import 'ocr_service.dart';
import 'photo_service.dart';
import '../models/scan_result.dart';
import 'scan_result_service.dart';

class ScanManager {
  static final OcrService _ocrService = OcrService();
  static final PhotoService _photoService = PhotoService();

  /// Ana tarama fonksiyonu
  static Future<void> startScan({
    required List<String> keywords,
    Function(int progress, int scanned, int total)? onProgress,
    bool incremental = false,
    DateTime? afterDate,
  }) async {
    final assets = incremental && afterDate != null
        ? await _photoService.loadImagesAfterDate(afterDate)
        : await _photoService.loadAllImages();

    final List<dynamic> detected = [];
    final List<String> detectedIds = [];

    for (int i = 0; i < assets.length; i++) {
      final asset = assets[i];
      final id = asset is AssetEntity ? asset.id : asset.path as String;
      final path = await PhotoService.getPath(asset);

      if (path == null) continue;

      final String text;
      if (asset is AssetEntity) {
        text = await _ocrService.extractTextFromAsset(asset);
      } else {
        text = await _ocrService.extractText(path);
      }

      if (KeywordMatcher.hasKeyword(text, keywords)) {
        detected.add(asset);
        detectedIds.add(id);
      }

      if (onProgress != null) {
        onProgress(((i + 1) / assets.length * 100).toInt(), i + 1, assets.length);
      }
    }

    final scanResult = ScanResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scanDate: DateTime.now(),
      detectedAssetIds: detectedIds,
      totalScanned: assets.length,
      detectedCount: detected.length,
      keywords: keywords,
    );
    await ScanResultService.saveResult(scanResult);
  }
}
