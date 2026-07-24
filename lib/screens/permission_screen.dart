import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/battery_optimization_service.dart';
import '../services/permission_service.dart';
import 'scan_mode_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isLoading = false;
  bool _photoGranted = false;
  bool _notifGranted = false;
  bool _photoPermanentlyDenied = false;
  bool _batteryOptimized = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPhoto = await PermissionService.checkPhotoPermissions();
    final hasNotif = await Permission.notification.status;
    final batteryOptimized =
        !(await BatteryOptimizationService.isIgnoringBatteryOptimizations());

    if (hasPhoto && hasNotif.isGranted) {
      _navigateToScanMode();
      return;
    }

    if (mounted) {
      setState(() {
        _photoGranted = hasPhoto;
        _notifGranted = hasNotif.isGranted;
        _batteryOptimized = batteryOptimized;
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isLoading = true);

    // 1) Fotoğraf izni
    final hasPhoto = await PermissionService.requestPhotoPermissions();

    // 2) Bildirim izni
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }
    final notifGranted = await Permission.notification.status;
    final batteryOptimized =
        !(await BatteryOptimizationService.isIgnoringBatteryOptimizations());

    // Fotoğraf kalıcı olarak reddedilmiş mi?
    final photoPermanentlyDenied = hasPhoto
        ? false
        : await PermissionService.isPhotoPermissionPermanentlyDenied();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _photoGranted = hasPhoto;
        _notifGranted = notifGranted.isGranted;
        _photoPermanentlyDenied = photoPermanentlyDenied;
        _batteryOptimized = batteryOptimized;
      });
    }

    // Her iki izin de varsa devam et
    if (hasPhoto) {
      _navigateToScanMode();
    }
  }

  void _navigateToScanMode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ScanModeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  size: 55,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Galeri Erişimi',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Galeri Detoks, WhatsApp ve galerinizde biriken kutlama '
                'mesajı görsellerini tespit etmek için fotoğraflarınıza '
                'erişim gerektirir.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // İzin durumları
              _buildPermissionStatus(
                icon: Icons.photo_library_outlined,
                title: 'Fotoğraf Erişimi',
                subtitle: _photoGranted
                    ? 'İzin verildi'
                    : _photoPermanentlyDenied
                        ? 'Kalıcı olarak reddedildi'
                        : 'Galerinizdeki görselleri taramak için gerekli',
                granted: _photoGranted,
                permanentlyDenied: _photoPermanentlyDenied,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 12),
              _buildPermissionStatus(
                icon: Icons.notifications_outlined,
                title: 'Bildirimler',
                subtitle: _notifGranted
                    ? 'İzin verildi'
                    : 'Tarama ilerlemesini görmek için gerekli',
                granted: _notifGranted,
                permanentlyDenied: false,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 12),
              _buildPermissionItem(
                icon: Icons.visibility_off_rounded,
                title: 'Gizlilik Öncelikli',
                subtitle: 'Verileriniz cihazınızdan çıkmaz',
                colorScheme: colorScheme,
              ),
              if (_batteryOptimized) ...[
                const SizedBox(height: 12),
                _buildBatteryOptimizationItem(colorScheme),
              ],

              const Spacer(),

              if (_photoPermanentlyDenied)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Fotoğraf izni kalıcı olarak reddedildi. Ayarlardan etkinleştirin.',
                    style: TextStyle(color: colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : (_photoPermanentlyDenied
                          ? () => openAppSettings()
                          : _requestAllPermissions),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _photoPermanentlyDenied
                              ? Icons.settings_rounded
                              : Icons.lock_open_rounded,
                        ),
                  label: Text(
                    _isLoading
                        ? 'İzinler kontrol ediliyor...'
                        : _photoPermanentlyDenied
                            ? 'Ayarları Aç'
                            : 'İzin Ver ve Başla',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionStatus({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required bool permanentlyDenied,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: granted
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : permanentlyDenied
                ? colorScheme.errorContainer.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted
              ? colorScheme.primary.withOpacity(0.3)
              : permanentlyDenied
                  ? colorScheme.error.withOpacity(0.3)
                  : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            granted
                ? Icons.check_circle_rounded
                : permanentlyDenied
                    ? Icons.cancel_rounded
                    : icon,
            color: granted
                ? colorScheme.primary
                : permanentlyDenied
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: granted
                        ? colorScheme.primary
                        : permanentlyDenied
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryOptimizationItem(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.battery_alert_rounded, color: colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Arka plan taraması için öneri',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pil tasarrufu tarama devam ederken uygulamayı durdurabilir. '
                  'Pil ayarlarından Galeri Detoks için kısıtlamayı kaldırabilirsiniz.',
                  style: TextStyle(
                    color: colorScheme.onTertiaryContainer,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await BatteryOptimizationService.openSettings();
                    if (!mounted) return;
                    final optimized =
                        !(await BatteryOptimizationService
                            .isIgnoringBatteryOptimizations());
                    setState(() => _batteryOptimized = optimized);
                  },
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Pil ayarlarını aç'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
