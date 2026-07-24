import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static const _channel = MethodChannel('com.galeridetoks.app/battery');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> openSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openBatterySettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}