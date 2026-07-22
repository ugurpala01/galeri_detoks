/// Türkçe kutlama/dini mesaj anahtar kelimelerini kategorilere ayıran ve eşleştiren sınıf.
class KeywordMatcher {
  KeywordMatcher._();

  static const Map<String, List<String>> categories = {
    'Haftalık Kutlamalar': [
      'cuma',
      'hayırlı cumalar',
      'cumamız mübarek',
    ],
    'Bayramlar': [
      'bayram',
      'bayramınız',
      'bayramınız mübarek',
      'iyi bayramlar',
      'ramazan bayramı',
      'kurban bayramı',
      'arefe',
    ],
    'Kandil Geceleri': [
      'kandil',
      'regaib',
      'miraç',
      'berat',
      'kadir',
      'mevlid',
      'mevlid kandili',
      'berat kandili',
      'miraç kandili',
      'regaib kandili',
      'kadir gecesi',
    ],
    'Ramazan': [
      'ramazan',
      'ramazan mübarek',
      'ramazan karşılama',
      'hoş geldin ramazan',
      'hayırlı ramazanlar',
      'sahur',
      'iftar',
    ],
    'Genel Kutlama': [
      'tebrik',
      'kutlu olsun',
      'mübarek olsun',
      'mübarek',
      'hayırlı',
      'hayırlısıyla',
      'dualarla',
      'selamlar',
      'iyi geceler',
      'günaydın duası',
      'akşamınız hayırlı',
      'sabahınız',
    ],
    'Dini İfadeler': [
      'allahın selamı',
      'selam ve dua',
      'dua ile',
      'bismillah',
      'maşallah',
      'inşallah mesajı',
    ],
  };

  static List<String> get defaultKeywords {
    return categories.values.expand((list) => list).toList();
  }

  /// Verilen metinde listedeki anahtar kelime bulunup bulunmadığını kontrol eder.
  static bool hasKeyword(String text, List<String> keywords) {
    if (text.isEmpty || keywords.isEmpty) return false;
    final lower = text.toLowerCase();
    for (final keyword in keywords) {
      if (lower.contains(keyword.toLowerCase())) return true;
    }
    return false;
  }

  /// Metinde bulunan eşleşen anahtar kelimeleri döner.
  static List<String> matchedKeywords(String text, List<String> keywords) {
    if (text.isEmpty || keywords.isEmpty) return [];
    final lower = text.toLowerCase();
    return keywords
        .where((k) => lower.contains(k.toLowerCase()))
        .toList();
  }
}
