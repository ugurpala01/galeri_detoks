import 'dart:io';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

/// Cihazdaki fotoğraf ve medya dosyalarına erişimi sağlayan servis.
class PhotoService {
  /// MediaStore'u tazele (yeni fotoğraflar için)
  static Future<void> refreshMediaStore() async {
    try {
      // Android'de MediaStore'u tazele
      const platform = MethodChannel('com.galeridetoks.app/media');
      await platform.invokeMethod('scanMedia');
    } catch (e) {
      print('MediaStore tazeleme hatası: $e');
    }
  }

  /// Galeriden görselleri yükler - strateji: önce mesajlaşma uygulamaları
  /// 
  /// [scanMode]: 
  /// - 'messages': Sadece WhatsApp, Telegram vb. mesajlaşma uygulamaları (varsayılan)
  /// - 'all': Tüm galeri
  /// - 'downloads': Sadece indirilenler
  Future<List<dynamic>> loadAllImages({
    int? maxCount, 
    String scanMode = 'messages',
  }) async {
    print('>>> loadAllImages BAŞLADI (mode: $scanMode)');
    
    // Önce MediaStore'u tazele (yeni fotoğraflar için)
    await refreshMediaStore();
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 1. MediaStore'dan dene - hedefli albümler
    final mediaStoreImages = await _loadFromMediaStore(
      maxCount: maxCount,
      scanMode: scanMode,
    );
    print('>>> MediaStore\'dan ${mediaStoreImages.length} fotoğraf');
    
    if (mediaStoreImages.isNotEmpty) {
      return mediaStoreImages;
    }
    
    // 2. MediaStore boşsa, dosya sisteminden dene (emülatör için)
    print('>>> MediaStore boş, dosya sisteminden aranıyor...');
    final fileSystemImages = await _loadFromFileSystem(scanMode: scanMode);
    print('>>> Dosya sisteminden ${fileSystemImages.length} fotoğraf');
    
    return fileSystemImages;
  }
  
  /// MediaStore API'dan fotoğraf yükle - hedefli albümler
  Future<List<AssetEntity>> _loadFromMediaStore({
    int? maxCount,
    String scanMode = 'messages',
  }) async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    print('>>> MediaStore albüm sayısı: ${albums.length}');
    
    // Hedef albüm isimleri (öncelik sırasına göre)
    final targetAlbums = _getTargetAlbums(scanMode);
    final excludedAlbums = _getExcludedAlbums();
    
    // Albümleri sınıflandır
    final prioritizedAlbums = <AssetPathEntity>[];
    final otherAlbums = <AssetPathEntity>[];
    
    print('>>> HEDEF ALBÜM ARANIYOR...');
    print('>>> Hedef listesi: $targetAlbums');
    
    for (final album in albums) {
      final nameLower = album.name.toLowerCase();
      final count = await album.assetCountAsync;
      
      print('>>>   Albüm: "${album.name}" - $count fotoğraf');
      
      // Hariç tutulanlar (tam eşleşme veya başlangıç kontrolü)
      bool isExcluded = false;
      for (final excluded in excludedAlbums) {
        if (nameLower == excluded || nameLower.startsWith(excluded + ' ')) {
          print('>>>     -> HARİÇ: $excluded');
          isExcluded = true;
          break;
        }
      }
      if (isExcluded) continue;
      
      // Hedef albümler (içeriyor mu kontrolü)
      bool isTarget = false;
      for (final target in targetAlbums) {
        if (nameLower.contains(target)) {
          print('>>>     -> HEDEF: $target');
          isTarget = true;
          break;
        }
      }
      
      if (isTarget) {
        print('>>>     -> HEDEF ALBÜM EKLENDİ: ${album.name}');
        prioritizedAlbums.add(album);
      } else if (scanMode == 'all') {
        otherAlbums.add(album);
      }
    }

    // Önce hedef albümleri, sonra diğerlerini birleştir
    final albumsToScan = [...prioritizedAlbums, ...otherAlbums];
    
    if (albumsToScan.isEmpty) {
      print('>>> Taranacak albüm bulunamadı');
      return [];
    }

    final allAssets = <AssetEntity>[];
    final seenIds = <String>{};
    
    for (final album in albumsToScan) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      
      final end = maxCount == null 
          ? count 
          : (maxCount - allAssets.length).clamp(0, count);
      
      if (end <= 0) break;
      
      final assets = await album.getAssetListRange(start: 0, end: end);
      
      for (final asset in assets) {
        if (!seenIds.contains(asset.id)) {
          seenIds.add(asset.id);
          allAssets.add(asset);
        }
      }
      
      print('>>>   ${album.name}: ${assets.length} fotoğraf eklendi');
    }

    print('>>> Toplam ${allAssets.length} fotoğraf yüklendi');
    return allAssets;
  }
  
  /// Hedef albüm isimlerini döndür
  List<String> _getTargetAlbums(String scanMode) {
    switch (scanMode) {
      case 'messages':
        return [
          'whatsapp',           // WhatsApp
          'whatsapp images',    // WhatsApp Images
          'whatsapp video',     // WhatsApp Video
          'telegram',           // Telegram
          'telegram images',    // Telegram Images
          'messenger',          // Facebook Messenger
          'signal',             // Signal
          'viber',              // Viber
          'line',               // Line
          'wechat',             // WeChat
        ];
      case 'downloads':
        return [
          'download',
          'downloads',
        ];
      case 'all':
        return []; // Tümü
      default:
        return ['whatsapp', 'telegram'];
    }
  }
  
  /// Hariç tutulacak albüm isimlerini döndür
  List<String> _getExcludedAlbums() {
    return [
      'camera',             // DCIM/Camera - kendi çektiği fotoğraflar
      'dcim',               // DCIM
      'screenshots',        // Ekran görüntüleri (opsiyonel)
      'screen recording',   // Ekran kayıtları
      'movies',             // Filmler
      'videos',             // Videolar
    ];
  }
  
  /// Dosya sisteminden fotoğraf ara (emülatör fallback)
  Future<List<File>> _loadFromFileSystem({String scanMode = 'messages'}) async {
    final List<File> images = [];
    final searchedDirs = <String>[];
    
    // Hedef dizinler (scanMode'a göre)
    final searchPaths = _getTargetPaths(scanMode);
    
    for (final basePath in searchPaths) {
      final dir = Directory(basePath);
      if (!await dir.exists()) {
        print('>>> Dizin yok: $basePath');
        continue;
      }
      
      searchedDirs.add(basePath);
      print('>>> Dizin aranıyor: $basePath');
      
      try {
        // Sadece doğrudan alt dizindeki dosyaları listele
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          if (entity is File) {
            final path = entity.path.toLowerCase();
            if (path.endsWith('.jpg') || 
                path.endsWith('.jpeg') || 
                path.endsWith('.png') ||
                path.endsWith('.webp') ||
                path.endsWith('.gif')) {
              images.add(entity);
              print('>>>   Bulundu: ${entity.path}');
            }
          } else if (entity is Directory) {
            // Alt dizinlerde de ara (sadece 1 seviye)
            try {
              await for (final subEntity in entity.list(recursive: false, followLinks: false)) {
                if (subEntity is File) {
                  final path = subEntity.path.toLowerCase();
                  if (path.endsWith('.jpg') || 
                      path.endsWith('.jpeg') || 
                      path.endsWith('.png') ||
                      path.endsWith('.webp') ||
                      path.endsWith('.gif')) {
                    images.add(subEntity);
                    print('>>>   Bulundu: ${subEntity.path}');
                  }
                }
              }
            } catch (e) {
              print('>>> Alt dizin okuma hatası: $e');
            }
          }
          
          if (images.length >= 10000) break;
        }
      } catch (e) {
        print('>>> Dizin okuma hatası ($basePath): $e');
      }
      
      if (images.isNotEmpty) break;
    }
    
    print('>>> Aranan dizinler: $searchedDirs');
    print('>>> Toplam bulunan: ${images.length} fotoğraf');
    
    // Tarihe göre sırala
    images.sort((a, b) {
      try {
        final statA = a.statSync();
        final statB = b.statSync();
        return statB.modified.compareTo(statA.modified);
      } catch (e) {
        return 0;
      }
    });
    
    return images;
  }
  
  /// Hedef dizin yollarını döndür
  List<String> _getTargetPaths(String scanMode) {
    final basePath = '/storage/emulated/0/';
    
    switch (scanMode) {
      case 'messages':
        return [
          '${basePath}Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/',
          '${basePath}WhatsApp/Media/WhatsApp Images/',
          '${basePath}Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent/',
          '${basePath}WhatsApp/Media/WhatsApp Images/Sent/',
          '${basePath}Android/media/org.telegram.messenger/Telegram/Telegram Images/',
          '${basePath}Telegram/Telegram Images/',
          '${basePath}Pictures/Messenger/',
          '${basePath}Pictures/Signal/',
        ];
      case 'downloads':
        return [
          '${basePath}Download/',
          '${basePath}Downloads/',
        ];
      case 'all':
        return [
          '${basePath}DCIM/',
          '${basePath}Pictures/',
          '${basePath}Download/',
        ];
      default:
        return ['${basePath}WhatsApp/Media/WhatsApp Images/'];
    }
  }

  /// Belirli bir albümden görselleri yükler.
  Future<List<AssetEntity>> loadImagesFromAlbum(
    AssetPathEntity album, {
    int maxCount = 1000,
  }) async {
    final count = await album.assetCountAsync;
    return album.getAssetListRange(
      start: 0,
      end: count.clamp(0, maxCount),
    );
  }

  /// Galerideki toplam görsel sayısını döner.
  Future<int> getTotalImageCount() async {
    final images = await loadAllImages();
    return images.length;
  }

  /// Belirli bir tarihten sonraki görselleri yükle
  Future<List<dynamic>> loadImagesAfterDate(DateTime date) async {
    final allImages = await loadAllImages();
    
    final filtered = [];
    for (final asset in allImages) {
      DateTime? createDate;
      
      if (asset is AssetEntity) {
        createDate = asset.createDateTime;
      } else if (asset is File) {
        try {
          createDate = asset.statSync().modified;
        } catch (e) {
          continue;
        }
      }
      
      if (createDate != null && createDate.isAfter(date)) {
        filtered.add(asset);
      }
    }
    
    return filtered;
  }
  
  /// Dosya yolunu al (AssetEntity veya File için)
  static Future<String?> getPath(dynamic asset) async {
    if (asset is AssetEntity) {
      final file = await asset.file;
      return file?.path;
    } else if (asset is File) {
      return asset.path;
    }
    return null;
  }
}
