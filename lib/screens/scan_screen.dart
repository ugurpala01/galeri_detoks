import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/scan_result.dart';
import '../providers/keyword_provider.dart';
import '../services/keyword_matcher.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/permission_service.dart';
import '../services/photo_service.dart';
import '../services/scan_result_service.dart';
import '../services/statistics_service.dart';
import 'history_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

/// Tarama durum provider'lari
final isScanningProvider = StateProvider<bool>((ref) => false);
final scanProgressProvider = StateProvider<double>((ref) => 0.0);
final scanPhaseProvider = StateProvider<int>((ref) => 0);
final scanStatusProvider = StateProvider<String>((ref) => '');
final shouldCancelScanProvider = StateProvider<bool>((ref) => false);
final estimatedTimeProvider = StateProvider<String>((ref) => '');

class ScanScreen extends ConsumerStatefulWidget {
  final bool incremental;

  const ScanScreen({super.key, this.incremental = false});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  ScanResult? _latestResult;
  int? _newPhotoCount;
  List<dynamic> _pendingDetectedAssets = [];
  int _pendingTotalScanned = 0;
  AppLifecycleState? _appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLatestResult().then((_) {
      if (widget.incremental && _latestResult != null) {
        _startScan(incremental: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appState = state);

    if (state == AppLifecycleState.resumed && _pendingDetectedAssets.isNotEmpty) {
      _navigateToResult(_pendingDetectedAssets, _pendingTotalScanned);
      _pendingDetectedAssets = [];
      _pendingTotalScanned = 0;
    }
  }

  Future<void> _loadLatestResult() async {
    final latest = ScanResultService.getLatestResult();
    if (latest == null) {
      setState(() => _latestResult = null);
      return;
    }

    final lastScanDate = latest.scanDate;
    final newPhotos = await PhotoService().loadUnscannedImages(
      afterDate: lastScanDate,
      scannedAssetIds: latest.scannedAssetIds.toSet(),
    );

    setState(() {
      _latestResult = latest;
      _newPhotoCount = newPhotos.length;
    });
  }

  Future<void> _startScan({bool incremental = false}) async {
    final hasPhoto = await PermissionService.checkPhotoPermissions();
    if (!hasPhoto) {
      ref.read(scanStatusProvider.notifier).state =
          'Galeri izni gerekli. Ayarlardan izin verin.';
      return;
    }

    final keywords = ref.read(selectedKeywordsProvider);
    if (keywords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('En az bir anahtar kelime secmelisiniz.'),
          ),
        );
      }
      return;
    }

    ref.read(isScanningProvider.notifier).state = true;
    ref.read(scanProgressProvider.notifier).state = 0.0;
    ref.read(scanPhaseProvider.notifier).state = 1;
    ref.read(scanStatusProvider.notifier).state = 'Fotograflar yukleniyor...';
    ref.read(estimatedTimeProvider.notifier).state = '';
    ref.read(shouldCancelScanProvider.notifier).state = false;

    final ocrService = OcrService();
    final detected = <dynamic>[];
    final detectedIds = <String>[];
    final scannedIds = <String>[];
    final previouslyScannedIds =
        _latestResult?.scannedAssetIds.toSet() ?? <String>{};
    ScanResult? result;

    try {
      final assets = incremental && _latestResult != null
          ? await PhotoService().loadUnscannedImages(
              afterDate: _latestResult!.scanDate,
              scannedAssetIds: _latestResult!.scannedAssetIds.toSet(),
            )
          : await PhotoService().loadAllImages();

      final total = assets.length;
      final startTime = DateTime.now();

      if (total == 0) {
        ref.read(scanStatusProvider.notifier).state =
            'Taranacak fotograf bulunamadi.';
        ref.read(isScanningProvider.notifier).state = false;
        ref.read(scanPhaseProvider.notifier).state = 0;
        return;
      }

      ref.read(scanStatusProvider.notifier).state = 'Gorseller taraniyor...';

      for (int i = 0; i < total; i++) {
        if (_shouldCancel()) {
          _resetScanState();
          return;
        }

        final asset = assets[i];
        final id = asset is AssetEntity ? asset.id : asset.path as String;
        scannedIds.add(id);
        String? path;

        if (asset is AssetEntity) {
          final file = await asset.file;
          path = file?.path;
        } else if (asset is File) {
          path = asset.path;
        }

        if (path == null) continue;

        String text;
        if (asset is AssetEntity) {
          text = await ocrService.extractTextFromAsset(asset);
        } else {
          text = await ocrService.extractText(path);
        }

        if (KeywordMatcher.hasKeyword(text, keywords)) {
          detected.add(asset);
          detectedIds.add(id);
        }

        final progress = (i + 1) / total;
        ref.read(scanProgressProvider.notifier).state = progress;
        ref.read(scanStatusProvider.notifier).state =
            '${i + 1} / $total fotograf tarandi';

        final elapsed = DateTime.now().difference(startTime);
        if (i > 0 && i % 10 == 0) {
          final avgPerItem = elapsed.inMilliseconds / (i + 1);
          final remainingMs = (avgPerItem * (total - i - 1)).toInt();
          final remaining = Duration(milliseconds: remainingMs);
          ref.read(estimatedTimeProvider.notifier).state =
              'Tahmini kalan sure: ${_formatDuration(remaining)}';
        }

        if (i % 5 == 0) {
          await NotificationService.showProgressNotification(
            (progress * 100).toInt(),
            i + 1,
            total,
          );
        }
      }

      result = ScanResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        scanDate: DateTime.now(),
        detectedAssetIds: detectedIds,
        scannedAssetIds: {
          ...previouslyScannedIds,
          ...scannedIds,
        }.toList(),
        totalScanned: total,
        detectedCount: detected.length,
        keywords: List<String>.from(keywords),
      );
      await ScanResultService.saveResult(result);

      await StatisticsService.recordScan(
        totalScanned: total,
        detectedCount: detected.length,
        deletedCount: 0,
      );

      ref.read(isScanningProvider.notifier).state = false;
      ref.read(scanPhaseProvider.notifier).state = 0;
      ref.read(scanProgressProvider.notifier).state = 0.0;
      ref.read(scanStatusProvider.notifier).state = '';
      ref.read(estimatedTimeProvider.notifier).state = '';
      ref.read(shouldCancelScanProvider.notifier).state = false;

      await NotificationService.showCompletionNotification(
        detected.length,
        total,
      );

      if (mounted && _appState == AppLifecycleState.resumed) {
        await _navigateToResult(detected, total);
        _loadLatestResult();
      } else {
        _pendingDetectedAssets = detected;
        _pendingTotalScanned = total;
      }
    } catch (e) {
      ref.read(scanStatusProvider.notifier).state = 'Hata: $e';
      ref.read(isScanningProvider.notifier).state = false;
      ref.read(scanPhaseProvider.notifier).state = 0;
      ref.read(scanProgressProvider.notifier).state = 0.0;
      ref.read(estimatedTimeProvider.notifier).state = '';
      ref.read(shouldCancelScanProvider.notifier).state = false;
      await NotificationService.showErrorNotification(e.toString());
    } finally {
      ocrService.dispose();
      if (mounted && ref.read(isScanningProvider)) {
        ref.read(isScanningProvider.notifier).state = false;
      }
    }
  }

  Future<void> _navigateToResult(List<dynamic> detected, int total) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          detectedAssets: detected,
          previousResult: _latestResult,
          totalScanned: total,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours} sa ${duration.inMinutes.remainder(60)} dk';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} dk ${duration.inSeconds.remainder(60)} sn';
    } else {
      return '${duration.inSeconds} sn';
    }
  }

  void _resetScanState() {
    ref.read(scanStatusProvider.notifier).state = 'Tarama iptal edildi.';
    ref.read(isScanningProvider.notifier).state = false;
    ref.read(scanPhaseProvider.notifier).state = 0;
    ref.read(scanProgressProvider.notifier).state = 0.0;
    ref.read(estimatedTimeProvider.notifier).state = '';
    ref.read(shouldCancelScanProvider.notifier).state = false;
    NotificationService.cancelAll();
  }

  bool _shouldCancel() => ref.read(shouldCancelScanProvider);

  @override
  Widget build(BuildContext context) {
    final isScanning = ref.watch(isScanningProvider);
    final scanProgress = ref.watch(scanProgressProvider);
    final scanStatus = ref.watch(scanStatusProvider);
    final estimatedTime = ref.watch(estimatedTimeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeri Detoks'),
        actions: [
          if (!isScanning)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Gecmis',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
          if (!isScanning)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Tarama Ayarlari',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cikis',
            onPressed: () async {
              if (ref.read(isScanningProvider)) {
                final shouldExit = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Tarama Devam Ediyor'),
                    content: const Text(
                      'Tarama sonlanacak ve cikis yapilacak. Emin misiniz?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Iptal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Cikis'),
                      ),
                    ],
                  ),
                );

                if (shouldExit != true) return;

                ref.read(shouldCancelScanProvider.notifier).state = true;
              }

              SystemNavigator.pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_latestResult != null && !isScanning) ...[
                _buildLastScanCard(),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isScanning) ...[
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.search_rounded,
                            size: 56,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        scanStatus,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Taraniyor...',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: scanProgress,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(scanProgress * 100).toInt()}%',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      if (estimatedTime.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          estimatedTime,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ] else ...[
                      Icon(
                        Icons.photo_library_outlined,
                        size: 80,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Galerinizi Tarayin',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'WhatsApp ve galerideki kutlama mesaji gorsellerini bulup temizleyin.',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              if (isScanning) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(shouldCancelScanProvider.notifier).state = true;
                      ref.read(scanStatusProvider.notifier).state =
                          'Iptal ediliyor...';
                      NotificationService.cancelAll();
                    },
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text(
                      'Iptal Et',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _startScan(),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text(
                      'Taramayi Baslat',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                if (_latestResult != null &&
                    _newPhotoCount != null &&
                    _newPhotoCount! > 0) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _startScan(incremental: true),
                      icon: const Icon(Icons.update_rounded),
                      label: Text(
                        'Yeni Fotograflari Tara ($_newPhotoCount yeni)',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastScanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Son Tarama',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tarih: ${_latestResult!.scanDate.day}/${_latestResult!.scanDate.month}/${_latestResult!.scanDate.year}',
            ),
            Text('Toplam: ${_latestResult!.totalScanned} fotograf'),
            Text(
              'Bulunan: ${_latestResult!.detectedCount} kutlama gorseli',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
