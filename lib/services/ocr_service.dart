import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// Google ML Kit kullanarak görsellerdeki metni tanıyan,
/// küçük önizleme ve önbellek kullanan OCR servisi.
class OcrService {
  OcrService();

  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  static const String _cacheBoxName = 'ocr_text_cache';
  Future<Box<String>>? _cacheBoxFuture;

  Future<Box<String>> _getCacheBox() {
    return _cacheBoxFuture ??= Hive.isBoxOpen(_cacheBoxName)
        ? Future.value(Hive.box<String>(_cacheBoxName))
        : Hive.openBox<String>(_cacheBoxName);
  }

  /// AssetEntity için düşük boyutlu önizleme kullanır.
  ///
  /// Bu, tam boy fotoğraf OCR'ına göre belirgin biçimde daha hızlıdır.
  /// Sonuç asset kimliğiyle önbelleğe alınır.
  Future<String> extractTextFromAsset(AssetEntity asset) async {
    final cache = await _getCacheBox();
    final cachedText = cache.get(asset.id);

    if (cachedText != null) {
      return cachedText;
    }

    File? temporaryFile;

    try {
      final thumbnailBytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(1280, 1280),
        quality: 82,
      );

      if (thumbnailBytes == null || thumbnailBytes.isEmpty) {
        return '';
      }

      final tempDirectory = await getTemporaryDirectory();
      temporaryFile = File(
        '${tempDirectory.path}/ocr_thumbnail_${asset.id.hashCode}.jpg',
      );

      await temporaryFile.writeAsBytes(thumbnailBytes, flush: true);

      final text = await extractText(temporaryFile.path);

      // Boş sonuçlar da kaydedilir; aynı görsel tekrar OCR'a gönderilmez.
      await cache.put(asset.id, text);

      return text;
    } catch (_) {
      return '';
    } finally {
      if (temporaryFile != null) {
        try {
          if (await temporaryFile.exists()) {
            await temporaryFile.delete();
          }
        } catch (_) {
          // Geçici dosya silinemese de taramayı durdurma.
        }
      }
    }
  }

  /// Dosya yolu ile gelen görseller için OCR.
  /// Bu yol emülatör/fallback senaryolarında kullanılır.
  Future<String> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (_) {
      return '';
    }
  }

  /// OCR önbelleğini temizler.
  /// İleride Ayarlar ekranına "Tarama önbelleğini temizle" butonu eklenebilir.
  Future<void> clearCache() async {
    final cache = await _getCacheBox();
    await cache.clear();
  }

  void dispose() {
    _recognizer.close();
  }
}
