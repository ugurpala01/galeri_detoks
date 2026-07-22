import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class BatteryOptimizationService {
  /// Pil optimizasyonu devre dışı bırakılmış mı kontrol et
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// Pil optimizasyonu izni iste (doğrudan sistem dialogu açar)
  /// Bu dialog tüm Android telefonlarda (Xiaomi, Honor, Samsung vb.) standarttır
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;
    
    final result = await Permission.ignoreBatteryOptimizations.request();
    return result.isGranted;
  }

  /// Uygulama ayarlarını aç (manuel yönlendirme için)
  static Future<void> openAppSettingsPage() async {
    await openAppSettings();
  }
}
