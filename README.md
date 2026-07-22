# Galeri Detoks

WhatsApp ve galerideki cuma mesajı, bayram tebrik kartı, kandil görseli gibi kutlama mesajlarını **OCR ile otomatik tespit edip silen** Android/iOS uygulaması.

## Özellikler

- **Akıllı Tarama**: Google ML Kit OCR ile görsellerdeki Türkçe metni tanır
- **Anahtar Kelime Eşleştirme**: Cuma, bayram, kandil, ramazan, tebrik vb. 40+ Türkçe anahtar kelime
- **Seçici Silme**: Tespit edilen görselleri önizleyip, hangileri silineceğine kullanıcı karar verir
- **Gizlilik Öncelikli**: Tüm işlemler cihaz üzerinde gerçekleşir, internet bağlantısı gerekmez
- **Material 3 UI**: Temiz, modern yeşil/mavi tema

## Ekranlar

| Ekran | Açıklama |
|---|---|
| `SplashScreen` | Açılış animasyonu, otomatik geçiş |
| `PermissionScreen` | Galeri izni isteme ve açıklama |
| `ScanScreen` | Tarama başlatma ve ilerleme göstergesi |
| `ResultScreen` | Tespit edilen görseller grid, seçme/silme |

## Kurulum

### Gereksinimler

- Flutter 3.24+ (`flutter --version`)
- Android Studio veya VS Code
- Android SDK (API 21+) veya Xcode (iOS 12+)

### Adımlar

```bash
# 1. Repoyu klonla
git clone <repo-url>
cd galeri_detoks

# 2. Bağımlılıkları yükle
flutter pub get

# 3. Android emülatör veya cihazda çalıştır
flutter run

# 4. Release APK oluştur
flutter build apk --release
```

### Android Geliştirici Modu (Windows)

Symlink desteği için Windows'ta Geliştirici Modunu etkinleştirin:
```
start ms-settings:developers
```

## Kullanılan Paketler

| Paket | Versiyon | Görev |
|---|---|---|
| `photo_manager` | ^3.6.0 | Galeri erişimi ve görsel yönetimi |
| `permission_handler` | ^11.3.1 | Runtime izin yönetimi |
| `google_mlkit_text_recognition` | ^0.13.0 | OCR ile metin tanıma |
| `flutter_riverpod` | ^2.5.1 | State management |
| `path_provider` | ^2.1.4 | Dosya sistemi yolları |

## Proje Yapısı

```
lib/
├── main.dart                    # Uygulama girişi, ProviderScope, tema
├── screens/
│   ├── splash_screen.dart       # Açılış ekranı (animasyonlu)
│   ├── permission_screen.dart   # Galeri izni ekranı
│   ├── scan_screen.dart         # Tarama ekranı (Riverpod state)
│   └── result_screen.dart       # Sonuç ve silme ekranı
└── services/
    ├── photo_service.dart       # Galeri API sarmalayıcısı
    ├── ocr_service.dart         # ML Kit OCR sarmalayıcısı
    └── keyword_matcher.dart     # Türkçe anahtar kelime motoru
```

## Android İzinler

`AndroidManifest.xml` içinde tanımlı:
- `READ_MEDIA_IMAGES` — Android 13+ (API 33+)
- `READ_EXTERNAL_STORAGE` (maxSdkVersion=32) — Android 12 ve altı
- `WRITE_EXTERNAL_STORAGE` (maxSdkVersion=29) — Android 9 ve altı

`minSdkVersion = 21` (Android 5.0 Lollipop)

## iOS İzinler

`Info.plist` içinde tanımlı:
- `NSPhotoLibraryUsageDescription` — okuma izni açıklaması
- `NSPhotoLibraryAddUsageDescription` — yazma izni açıklaması

## Desteklenen Anahtar Kelimeler

`KeywordMatcher` sınıfı aşağıdaki kategorilerde 40+ anahtar kelime içerir:

- **Haftalık**: cuma, hayırlı cumalar
- **Bayramlar**: bayram, ramazan bayramı, kurban bayramı, arefe
- **Kandiller**: regaib, miraç, berat, kadir, mevlid kandili
- **Ramazan**: ramazan, sahur, iftar
- **Genel**: tebrik, kutlu olsun, mübarek, hayırlı

## Geliştirme Notları

- OCR servisi (`OcrService`) Google ML Kit kullanır; ilk çalıştırmada ML modeli indirilir
- `KeywordMatcher.allKeywords` ile tüm anahtar kelimelere erişilebilir
- Büyük/küçük harf duyarsız eşleştirme yapılır

## Çalıştırma Komutları

```bash
flutter run                     # Debug modda çalıştır
flutter run --release           # Release modda çalıştır
flutter build apk               # APK oluştur
flutter build apk --split-per-abi  # ABI başına ayrı APK
flutter analyze                 # Kod analizi
flutter test                    # Testleri çalıştır
```
