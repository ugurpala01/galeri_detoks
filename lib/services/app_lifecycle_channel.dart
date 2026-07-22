import 'package:flutter/services.dart';

class AppLifecycleChannel {
  static const MethodChannel _channel =
      MethodChannel('com.galeridetoks.app/lifecycle');

  /// Uygulamayı arka plana at (telefonun home tuşu gibi)
  static Future<bool> moveTaskToBack() async {
    try {
      final result = await _channel.invokeMethod('moveTaskToBack');
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
