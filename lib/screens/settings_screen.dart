import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/keyword_provider.dart';
import '../services/keyword_matcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustomKeyword() {
    final text = _customController.text.trim();
    if (text.isNotEmpty) {
      ref.read(selectedKeywordsProvider.notifier).addCustom(text);
      _customController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedKeywords = ref.watch(selectedKeywordsProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Tarama Ayarları'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              ref.read(selectedKeywordsProvider.notifier).resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Varsayılan ayarlara döndü')),
              );
            },
            child: const Text('Sıfırla'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Özel kelime ekleme
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customController,
                      decoration: InputDecoration(
                        hintText: 'Özel anahtar kelime ekle...',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addCustomKeyword(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _addCustomKeyword,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),

            // Seçili özet
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selectedKeywords.length} anahtar kelime seçili',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(),

            // Kategoriler + Kullanıcı Seçimi
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: KeywordMatcher.categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == KeywordMatcher.categories.length) {
                    return _buildCustomCategoryTile(colorScheme);
                  }
                  final category =
                      KeywordMatcher.categories.keys.elementAt(index);
                  return _buildCategoryTile(category, colorScheme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(String category, ColorScheme colorScheme) {
    final keywords = KeywordMatcher.categories[category]!;
    final notifier = ref.read(selectedKeywordsProvider.notifier);
    final isSelected = notifier.isCategorySelected(category);
    final isPartial = notifier.isCategoryPartiallySelected(category);

    return ExpansionTile(
      leading: Checkbox(
        value: isSelected,
        tristate: true,
        onChanged: (value) {
          if (value == null || value == false) {
            // Kısmen seçili veya seçili → hepsini kaldır
            notifier.toggleCategory(category, false);
          } else {
            notifier.toggleCategory(category, true);
          }
        },
      ),
      title: Text(
        category,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${keywords.length} kelime'),
      trailing: isPartial
          ? Icon(Icons.indeterminate_check_box_rounded,
              color: colorScheme.primary)
          : null,
      children: keywords.map((keyword) {
        final isKeywordSelected =
            ref.watch(selectedKeywordsProvider).contains(keyword);
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 72, right: 16),
          title: Text(keyword),
          trailing: isKeywordSelected
              ? Icon(Icons.check_rounded, color: colorScheme.primary, size: 20)
              : null,
          onTap: () => notifier.toggle(keyword),
        );
      }).toList(),
    );
  }

  Widget _buildCustomCategoryTile(ColorScheme colorScheme) {
    final customKeywords = ref.watch(customKeywordsProvider);
    final selectedKeywords = ref.watch(selectedKeywordsProvider);
    final notifier = ref.read(selectedKeywordsProvider.notifier);

    if (customKeywords.isEmpty) {
      return const SizedBox.shrink();
    }

    final allSelected = customKeywords.every((k) => selectedKeywords.contains(k));
    final someSelected = customKeywords.any((k) => selectedKeywords.contains(k));
    final isPartial = someSelected && !allSelected;

    return ExpansionTile(
      leading: Checkbox(
        value: allSelected,
        tristate: true,
        onChanged: (value) {
          if (value == null || value == false) {
            for (final k in customKeywords) {
              if (selectedKeywords.contains(k)) notifier.toggle(k);
            }
          } else {
            for (final k in customKeywords) {
              if (!selectedKeywords.contains(k)) notifier.toggle(k);
            }
          }
        },
      ),
      title: const Text(
        'Kullanıcı Seçimi',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${customKeywords.length} kelime'),
      trailing: isPartial
          ? Icon(Icons.indeterminate_check_box_rounded,
              color: colorScheme.primary)
          : null,
      children: customKeywords.map((keyword) {
        final isKeywordSelected = selectedKeywords.contains(keyword);
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 72, right: 16),
          title: Text(keyword),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isKeywordSelected)
                Icon(Icons.check_rounded,
                    color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: Colors.red),
                onPressed: () => notifier.removeCustom(keyword),
              ),
            ],
          ),
          onTap: () => notifier.toggle(keyword),
        );
      }).toList(),
    );
  }
}
