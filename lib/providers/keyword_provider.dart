import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/keyword_matcher.dart';

/// Kullanıcının eklediği özel anahtar kelimeler.
final customKeywordsProvider = StateProvider<List<String>>((ref) => []);

/// Kullanıcının seçtiği anahtar kelimeler (varsayılan + özel).
final selectedKeywordsProvider =
    StateNotifierProvider<SelectedKeywordsNotifier, List<String>>(
  (ref) => SelectedKeywordsNotifier(ref),
);

class SelectedKeywordsNotifier extends StateNotifier<List<String>> {
  final Ref _ref;

  SelectedKeywordsNotifier(this._ref)
      : super(KeywordMatcher.defaultKeywords);

  List<String> get _customKeywords => _ref.read(customKeywordsProvider);

  void _updateCustomKeywords(List<String> updated) {
    _ref.read(customKeywordsProvider.notifier).state = updated;
  }

  void toggle(String keyword) {
    if (state.contains(keyword)) {
      state = state.where((k) => k != keyword).toList();
    } else {
      state = [...state, keyword];
    }
  }

  void addCustom(String keyword) {
    final trimmed = keyword.trim().toLowerCase();
    if (trimmed.isEmpty) return;

    // Özel listeye ekle
    final currentCustom = [..._customKeywords];
    if (!currentCustom.contains(trimmed)) {
      currentCustom.add(trimmed);
      _updateCustomKeywords(currentCustom);
    }

    // Seçili listeye de ekle
    if (!state.contains(trimmed)) {
      state = [...state, trimmed];
    }
  }

  void removeCustom(String keyword) {
    // Özel listeden kaldır
    final currentCustom = _customKeywords.where((k) => k != keyword).toList();
    _updateCustomKeywords(currentCustom);

    // Seçili listeden de kaldır
    state = state.where((k) => k != keyword).toList();
  }

  void resetToDefaults() {
    _updateCustomKeywords([]);
    state = KeywordMatcher.defaultKeywords;
  }

  void toggleCategory(String category, bool selected) {
    final categoryKeywords = KeywordMatcher.categories[category] ?? [];
    if (selected) {
      final newKeywords = categoryKeywords
          .where((k) => !state.contains(k))
          .toList();
      state = [...state, ...newKeywords];
    } else {
      state = state.where((k) => !categoryKeywords.contains(k)).toList();
    }
  }

  bool isCategorySelected(String category) {
    final categoryKeywords = KeywordMatcher.categories[category] ?? [];
    if (categoryKeywords.isEmpty) return false;
    return categoryKeywords.every((k) => state.contains(k));
  }

  bool isCategoryPartiallySelected(String category) {
    final categoryKeywords = KeywordMatcher.categories[category] ?? [];
    final selectedCount =
        categoryKeywords.where((k) => state.contains(k)).length;
    return selectedCount > 0 && selectedCount < categoryKeywords.length;
  }
}
