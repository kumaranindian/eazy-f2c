/// Cleans up text read from an uploaded sheet.
class BulkProductNormalizer {
  const BulkProductNormalizer._();

  /// Known misspellings (lower-case) and their fixes. Extend as needed.
  static const Map<String, String> typoFixes = {
    'traditioanal': 'Traditional',
    'sweetner': 'Sweetener',
  };

  /// Spellings that look like variants of one word. They are not changed
  /// automatically; rows using them are flagged for the admin to decide.
  static const List<List<String>> spellingVariants = [
    ['gandhasale', 'gandasala'],
  ];

  static final RegExp _word = RegExp(r"[A-Za-z]+");
  static final RegExp _spaces = RegExp(r'\s+');

  /// Trims and collapses whitespace.
  static String tidy(String value) => value.replaceAll(_spaces, ' ').trim();

  /// Returns the tidied text with known typos fixed, and whether any typo
  /// was fixed (whitespace tidying alone is not reported).
  static ({String text, bool corrected}) fixTypos(String value) {
    final tidied = tidy(value);
    var corrected = false;
    final fixed = tidied.replaceAllMapped(_word, (match) {
      final word = match.group(0)!;
      final fix = typoFixes[word.toLowerCase()];
      if (fix == null) return word;
      corrected = true;
      if (word == word.toUpperCase()) return fix.toUpperCase();
      return fix;
    });
    return (text: fixed, corrected: corrected);
  }

  /// Lower-cased, whitespace-collapsed key used for matching names.
  static String key(String value) => tidy(value).toLowerCase();
}
