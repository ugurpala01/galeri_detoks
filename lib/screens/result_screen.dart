import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/scan_result.dart';
import '../services/scan_result_service.dart';
import '../widgets/photo_preview_dialog.dart';
import 'scan_screen.dart';

class ResultScreen extends StatefulWidget {
  final List<dynamic> detectedAssets;
  final ScanResult? previousResult;
  final int totalScanned;

  const ResultScreen({
    super.key,
    required this.detectedAssets,
    this.previousResult,
    this.totalScanned = 0,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late List<bool> _selected;
  bool _isDeleting = false;
  List<dynamic> _loadedAssets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (widget.detectedAssets.isNotEmpty) {
      setState(() {
        _loadedAssets = widget.detectedAssets;
        _selected = List.filled(_loadedAssets.length, true);
        _isLoading = false;
      });
      return;
    }

    // Önceki sonuçlardan asset ID'lerini eşleştirerek yükle
    if (widget.previousResult != null &&
        widget.previousResult!.detectedAssetIds.isNotEmpty) {
      try {
        final previousIds = widget.previousResult!.detectedAssetIds.toSet();
        final matchedAssets = <dynamic>[];

        final albums = await PhotoManager.getAssetPathList(
          type: RequestType.image,
          filterOption: FilterOptionGroup(
            imageOption: const FilterOption(
              sizeConstraint: SizeConstraint(ignoreSize: true),
            ),
          ),
        );

        for (final album in albums) {
          final count = await album.assetCountAsync;
          if (count == 0) continue;

          const pageSize = 100;
          for (int start = 0; start < count; start += pageSize) {
            final end = (start + pageSize).clamp(0, count);
            final assets = await album.getAssetListRange(
              start: start,
              end: end,
            );

            for (final asset in assets) {
              if (previousIds.contains(asset.id)) {
                matchedAssets.add(asset);
              }
            }

            if (matchedAssets.length >= previousIds.length) break;
          }

          if (matchedAssets.length >= previousIds.length) break;
        }

        setState(() {
          _loadedAssets = matchedAssets;
          _selected = List.filled(_loadedAssets.length, true);
          _isLoading = false;
        });
        return;
      } catch (e) {
        // Hata durumunda boş göster
      }
    }

    setState(() {
      _loadedAssets = [];
      _selected = [];
      _isLoading = false;
    });
  }

  int get _selectedCount => _selected.where((s) => s).length;

  /// Tek bir fotoğrafı onay sormadan direkt siler
  Future<void> _deleteSingleAsset(dynamic asset) async {
    try {
      if (asset is AssetEntity) {
        await PhotoManager.editor.deleteWithIds([asset.id]);
      } else if (asset is File) {
        await asset.delete();
      }
      
      // Listeden kaldır
      setState(() {
        final index = _loadedAssets.indexOf(asset);
        if (index != -1) {
          _loadedAssets.removeAt(index);
          _selected.removeAt(index);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Görsel silindi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    setState(() => _isDeleting = true);

    final toDelete = <dynamic>[];
    for (int i = 0; i < _loadedAssets.length; i++) {
      if (_selected[i]) toDelete.add(_loadedAssets[i]);
    }

    try {
      int deletedCount = 0;
      
      // AssetEntity'leri toplu sil (tek seferde)
      final assetEntities = toDelete.whereType<AssetEntity>().toList();
      if (assetEntities.isNotEmpty) {
        await PhotoManager.editor.deleteWithIds(
          assetEntities.map((a) => a.id).toList(),
        );
        deletedCount += assetEntities.length;
      }
      
      // File'ları sil
      for (final asset in toDelete.whereType<File>()) {
        try {
          await asset.delete();
          deletedCount++;
        } catch (e) {
          print('Dosya silme hatası: $e');
        }
      }

      // Tarama sonucunu güncelle (yeni kayıt ekleme, mevcudu güncelle)
      final existingResult = widget.previousResult;
      if (existingResult != null && existingResult.id.isNotEmpty) {
        // Mevcut kaydı güncelle
        final updatedResult = ScanResult(
          id: existingResult.id,
          scanDate: existingResult.scanDate,
          detectedAssetIds: _loadedAssets.map((a) {
            if (a is AssetEntity) return a.id;
            if (a is File) return a.path;
            return a.toString();
          }).toList(),
          totalScanned: existingResult.totalScanned,
          detectedCount: _loadedAssets.length,
          deletedCount: deletedCount,
          keywords: existingResult.keywords,
        );
        await ScanResultService.saveResult(updatedResult);
      } else {
        // Yeni kayıt (ilk kez silme yapılıyorsa)
        final scanResult = ScanResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          scanDate: DateTime.now(),
          detectedAssetIds: _loadedAssets.map((a) {
            if (a is AssetEntity) return a.id;
            if (a is File) return a.path;
            return a.toString();
          }).toList(),
          totalScanned: widget.totalScanned,
          detectedCount: _loadedAssets.length,
          deletedCount: deletedCount,
          keywords: [],
        );
        await ScanResultService.saveResult(scanResult);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount görsel başarıyla silindi.'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  void _toggleAll(bool? value) {
    setState(() {
      for (int i = 0; i < _selected.length; i++) {
        _selected[i] = value ?? false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasItems = _loadedAssets.isNotEmpty;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text('Tespit Edilenler'),
          centerTitle: true,
          backgroundColor: colorScheme.surface,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Tespit Edilenler'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          if (hasItems)
            TextButton(
              onPressed: () => _toggleAll(_selectedCount == 0),
              child: Text(
                _selectedCount == _loadedAssets.length
                    ? 'Seçimi kaldır ben seçeyim'
                    : 'Tümünü Seç',
              ),
            ),
        ],
      ),
      body: hasItems
          ? _buildResultList(colorScheme)
          : _buildEmptyState(colorScheme),
      bottomNavigationBar: hasItems ? _buildBottomBar(colorScheme) : null,
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 80,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Temiz!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kutlama görseli tespit edilmedi.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              // Ana sayfaya dön - isScanning false yap
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ScanScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Yeniden Tara'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList(ColorScheme colorScheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_loadedAssets.length} olası kutlama görseli bulundu. '
                  'Silmek istediklerinizi seçin.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: _loadedAssets.length,
            itemBuilder: (context, index) {
              final asset = _loadedAssets[index];
              final isSelected = _selected[index];

              return GestureDetector(
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (_) => PhotoPreviewDialog(
                      asset: asset,
                      onDelete: () => _deleteSingleAsset(asset),
                    ),
                  );
                },
                onTap: () {
                  setState(() => _selected[index] = !isSelected);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildThumbnail(asset),
                    ),
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? colorScheme.primary
                              : Colors.white.withOpacity(0.8),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // Ana sayfaya dön - isScanning false yap
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                  (route) => false,
                );
              },
              child: const Text('Geri Dön'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: (_selectedCount == 0 || _isDeleting)
                  ? null
                  : () async {
                      // Direkt sil, onay sorma
                      await _deleteSelected();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_rounded),
              label: Text(
                _isDeleting ? 'Siliniyor...' : '$_selectedCount Görseli Sil',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(dynamic asset) {
    if (asset is AssetEntity) {
      return FutureBuilder<Uint8List?>(
        future: asset.thumbnailDataWithSize(
          const ThumbnailSize(200, 200),
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
            );
          }
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.image, color: Colors.grey),
          );
        },
      );
    } else if (asset is File) {
      return Image.file(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.image, color: Colors.grey),
          );
        },
      );
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}
