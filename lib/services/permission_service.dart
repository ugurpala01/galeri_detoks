import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Fotoğraf erişimi için gerekli izinleri kontrol et ve iste
  static Future<bool> requestPhotoPermissions() async {
    if (Platform.isAndroid) {
      // Permission.photos: Android 13+ → READ_MEDIA_IMAGES, altı → otomatik storage'a düşer
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted || photosStatus.isLimited) return true;

      final photosResult = await Permission.photos.request();
      if (photosResult.isGranted || photosResult.isLimited) return true;

      // Android 12 ve altı için storage izni (photos desteklenmeyebilir)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted || storageStatus.isLimited) return true;

      final storageResult = await Permission.storage.request();
      if (storageResult.isGranted || storageResult.isLimited) return true;

      return false;
    }

    // iOS
    final photosStatus = await Permission.photos.status;
    if (photosStatus.isGranted || photosStatus.isLimited) return true;

    final photosResult = await Permission.photos.request();
    return photosResult.isGranted || photosResult.isLimited;
  }

  /// İzin durumunu kontrol et (sadece kontrol, isteme)
  static Future<bool> checkPhotoPermissions() async {
    if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted || photosStatus.isLimited) return true;

      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted || storageStatus.isLimited) return true;

      return false;
    }

    final photosStatus = await Permission.photos.status;
    return photosStatus.isGranted || photosStatus.isLimited;
  }

  /// Fotoğraf izni kalıcı olarak reddedilmiş mi?
  static Future<bool> isPhotoPermissionPermanentlyDenied() async {
    if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isPermanentlyDenied) return true;

      final storageStatus = await Permission.storage.status;
      if (storageStatus.isPermanentlyDenied) return true;

      return false;
    }

    final photosStatus = await Permission.photos.status;
    return photosStatus.isPermanentlyDenied;
  }
}
