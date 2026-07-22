import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/photo_service.dart';
import '../services/scan_result_service.dart';
import 'scan_screen.dart';

class ScanModeScreen extends ConsumerStatefulWidget {
  const ScanModeScreen({super.key});

  @override
  ConsumerState<ScanModeScreen> createState() => _ScanModeScreenState();
}

class _ScanModeScreenState extends ConsumerState<ScanModeScreen> {
  bool _isLoading = true;
  int _newPhotoCount = 0;
  int _totalPhotoCount = 0;
  DateTime? _lastScanDate;

  @override
  void initState() {
    super.initState();
    _loadPhotoCounts();
  }

  Future<void> _loadPhotoCounts() async {
    _lastScanDate = ScanResultService.getLastScanDate();

    final photoService = PhotoService();
    final allImages = await photoService.loadAllImages();
    final total = allImages.length;

    int newCount = total;
    if (_lastScanDate != null) {
      final newImages = await photoService.loadImagesAfterDate(_lastScanDate!);
      newCount = newImages.length;
    }

    setState(() {
      _newPhotoCount = newCount;
      _totalPhotoCount = total;
      _isLoading = false;
    });
  }

  String get _formattedLastScanDate {
    if (_lastScanDate == null) return 'Hiç tarama yapılmamış';
    
    final now = DateTime.now();
    final diff = now.difference(_lastScanDate!);
    
    if (diff.inDays == 0) return 'Bugün';
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} hafta önce';
    return '${(diff.inDays / 30).floor()} ay önce';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Tarama Modu'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Son tarama bilgisi
                    if (_lastScanDate != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history_rounded,
                                    color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Son Tarama: $_formattedLastScanDate',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                    
                    Text(
                      'Tarama Modu Seçin',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hangi fotoğrafları taramak istiyorsunuz?',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Seçenek 1: Sadece yeni fotoğraflar
                    if (_lastScanDate != null)
                      _buildScanOption(
                        icon: Icons.bolt_rounded,
                        title: 'Sadece Yeni Fotoğraflar',
                        subtitle: '$_newPhotoCount yeni fotoğraf',
                        estimatedTime: '~${(_newPhotoCount / 400).ceil()} dk',
                        isRecommended: true,
                        colorScheme: colorScheme,
                        onTap: () => _startScan(incremental: true),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Seçenek 2: Tümünü tara
                    _buildScanOption(
                      icon: Icons.folder_open_rounded,
                      title: 'Tümünü Yeniden Tara',
                      subtitle: '$_totalPhotoCount fotoğraf',
                      estimatedTime: '~${(_totalPhotoCount / 400).ceil()} dk',
                      isRecommended: _lastScanDate == null,
                      colorScheme: colorScheme,
                      onTap: () => _startScan(incremental: false),
                    ),
                    
                    const Spacer(),
                    
                    // Bilgi notu
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sadece yeni fotoğraflar seçeneği, son taramadan '
                              'sonra eklenen fotoğrafları tarar ve çok daha hızlıdır.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScanOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String estimatedTime,
    required bool isRecommended,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRecommended
              ? colorScheme.primaryContainer.withOpacity(0.5)
              : colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: isRecommended
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRecommended
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isRecommended
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Önerilen',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tahmini süre: $estimatedTime',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startScan({required bool incremental}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ScanScreen(incremental: incremental),
      ),
    );
  }
}