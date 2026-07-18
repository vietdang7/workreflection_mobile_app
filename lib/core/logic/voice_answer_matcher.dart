// Pure transcript → numeric answer matching logic.
//
// Ported exactly from the web source:
//   - Vietnamese: src/lib/vietnamese-number-parser.ts
//   - English:    src/lib/english-number-parser.ts
//
// No Flutter dependencies — fully unit-testable in isolation.

// ---------------------------------------------------------------------------
// Vietnamese parser (port of vietnamese-number-parser.ts)
// ---------------------------------------------------------------------------

const Map<String, int> _vietNumbers = {
  // With diacritics
  'một': 1,
  'hai': 2,
  'ba': 3,
  'bốn': 4,
  'năm': 5,
  'sáu': 6,
  'bảy': 7,
  'tám': 8,
  'chín': 9,
  'mười': 10,
  // Without diacritics (common STT output)
  'mot': 1,
  'bon': 4,
  'nam': 5,
  'sau': 6,
  'bay': 7,
  'tam': 8,
  'chin': 9,
  'muoi': 10,
  // Alternative spellings
  'bầy': 7,
  'bẩy': 7,
};

/// Diacritics → ASCII mapping for characters that appear in _vietNumbers.
/// Using a top-level (non-const) map to avoid duplicate-key const errors.
final Map<String, String> _diacriticsMap = {
  'ộ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ố': 'o', 'ồ': 'o', 'ọ': 'o',
  'ơ': 'o', 'ớ': 'o', 'ờ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
  'ă': 'a', 'ắ': 'a', 'ặ': 'a', 'ằ': 'a', 'ẵ': 'a', 'ẳ': 'a',
  'â': 'a', 'ấ': 'a', 'ầ': 'a', 'ậ': 'a', 'ẫ': 'a', 'ẩ': 'a',
  'à': 'a', 'á': 'a', 'ã': 'a', 'ả': 'a', 'ạ': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ế': 'e', 'ề': 'e', 'ệ': 'e',
  'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ể': 'e', 'ễ': 'e',
  'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
  'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
  'ư': 'u', 'ứ': 'u', 'ừ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
  'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
  'đ': 'd', 'Đ': 'D',
};

/// Remove Vietnamese diacritics for fuzzy matching.
/// Port of `removeDiacritics` in vietnamese-number-parser.ts.
String _removeDiacritics(String s) {
  final buf = StringBuffer();
  for (final ch in s.runes) {
    final c = String.fromCharCode(ch);
    buf.write(_diacriticsMap[c] ?? c);
  }
  return buf.toString();
}

bool _wordInText(String word, String text) {
  final pattern = RegExp(
    r'(?:^|\s)' + RegExp.escape(word) + r'(?:\s|$)',
    caseSensitive: false,
  );
  return pattern.hasMatch(text);
}

/// Parse a Vietnamese speech transcript → number, capped at [maxValue].
/// Returns null if no valid number found.
/// Port of `parseVietnameseNumber` in vietnamese-number-parser.ts.
int? parseVietnameseNumber(String transcript, int maxValue) {
  if (transcript.isEmpty) return null;

  final cleaned = transcript.toLowerCase().trim();

  // 1. Direct digit match
  final digitMatch = RegExp(r'\b(\d+)\b').firstMatch(cleaned);
  if (digitMatch != null) {
    final num = int.parse(digitMatch.group(1)!);
    if (num >= 1 && num <= maxValue) return num;
  }

  // 2. Exact word match (with diacritics)
  for (final entry in _vietNumbers.entries) {
    if (entry.value < 1 || entry.value > maxValue) continue;
    if (_wordInText(entry.key, cleaned)) return entry.value;
  }

  // 3. Fuzzy: strip diacritics from transcript and from word
  final noDiacritics = _removeDiacritics(cleaned);
  for (final entry in _vietNumbers.entries) {
    if (entry.value < 1 || entry.value > maxValue) continue;
    final wordNorm = _removeDiacritics(entry.key);
    if (_wordInText(wordNorm, noDiacritics)) return entry.value;
  }

  return null;
}

// ---------------------------------------------------------------------------
// English parser (port of english-number-parser.ts)
// ---------------------------------------------------------------------------

// CLEAR_NUMBERS — match anywhere in transcript.
const Map<String, int> _clearNumbers = {
  // 0
  'zero': 0,
  // 1
  'one': 1, 'won': 1, 'wan': 1, 'run': 1, 'fun': 1, 'sun': 1, 'done': 1, 'gun': 1,
  // 2
  'two': 2, 'true': 2, 'through': 2, 'who': 2, 'blue': 2, 'clue': 2, 'crew': 2,
  'drew': 2, 'grew': 2, 'knew': 2, 'threw': 2, 'too': 2, 'ooh': 2,
  // 3
  'three': 3, 'tree': 3, 'free': 3, 'tea': 3, 'tee': 3, 'fee': 3, 'bee': 3,
  'see': 3, 'sea': 3, 'plea': 3, 'key': 3, 'knee': 3,
  // 4
  'four': 4, 'fall': 4, 'false': 4, 'force': 4, 'form': 4, 'fort': 4, 'fork': 4,
  'for': 4, 'fore': 4, 'floor': 4, 'more': 4, 'war': 4, 'door': 4, 'core': 4,
  'bore': 4, 'pour': 4, 'nor': 4, 'or': 4, 'ball': 4, 'call': 4, 'hall': 4,
  'wall': 4, 'tall': 4, 'small': 4,
  'foe': 4, 'foes': 4, 'faux': 4, 'fold': 4, 'folk': 4,
  'fought': 4, 'fault': 4,
  'fond': 4,
  'ford': 4, 'forth': 4, 'forge': 4,
  // 5
  'five': 5, 'vibe': 5, 'fly': 5, 'fine': 5,
  'find': 5, 'fight': 5, 'fire': 5, 'file': 5, 'dive': 5, 'drive': 5,
  'hive': 5, 'live': 5, 'life': 5, 'knife': 5, 'wife': 5, 'mile': 5,
  'pile': 5, 'tile': 5, 'while': 5, 'smile': 5, 'trial': 5, 'dial': 5,
  // 6
  'six': 6, 'sex': 6, 'sick': 6, 'sit': 6, 'fix': 6, 'mix': 6, 'sticks': 6,
  // 7
  'seven': 7,
  // 8
  'eight': 8, 'ate': 8, 'hate': 8, 'wait': 8, 'weight': 8, 'late': 8,
  'fate': 8, 'gate': 8, 'date': 8, 'mate': 8, 'rate': 8,
  // 9
  'nine': 9, 'none': 9, 'mine': 9,
  // 10
  'ten': 10, 'then': 10, 'pen': 10, 'when': 10, 'den': 10, 'hen': 10, 'men': 10,
};

// STRICT_TOKENS — whole-transcript match only (after stripping trailing punctuation).
const Map<String, int> _strictTokens = {
  'oh': 0,
  'on': 1,
  'to': 2, 'do': 2, 'due': 2, 'dew': 2, 'you': 2, 'boo': 2,
  'fo': 4, 'pho': 4,
  'bye': 5, 'buy': 5, 'by': 5, 'die': 5, 'pie': 5, 'high': 5, 'tie': 5,
};

// Whisper hallucination phrases — whole-transcript or substring.
const Set<String> _whisperHallucinations = {
  'thank you', 'thanks for watching', 'thanks', '[music]',
  'subscribe', 'cube', 'dream', '.', 'uh', 'um', 'hmm',
  'okay', 'ok', 'cubed', 'thank', "you're",
  'what', 'what?', 'yeah', 'cray', 'cray!',
  'you', 'your', 'yours',
  '(crowd cheering)', '(dramatic music)', '(music)', '(silence)',
  'no, no, no', 'no, no, no.',
};

const List<String> _hallucinationPhraseFragments = [
  '[blank_audio',
  'blank_audio]',
  '(crowd cheering)',
  '(dramatic music)',
  '(music)',
  '(silence)',
];

/// Levenshtein distance. Port of `levenshtein` in english-number-parser.ts.
int _levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final prev = List<int>.generate(b.length + 1, (j) => j);
  final curr = List<int>.filled(b.length + 1, 0);
  for (int i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (int j = 1; j <= b.length; j++) {
      curr[j] = a[i - 1] == b[j - 1]
          ? prev[j - 1]
          : 1 + [prev[j], curr[j - 1], prev[j - 1]].reduce((x, y) => x < y ? x : y);
    }
    for (int j = 0; j <= b.length; j++) {
      prev[j] = curr[j];
    }
  }
  return curr[b.length];
}

/// Parse an English speech transcript → number, capped at [maxValue].
/// Returns null if no valid number found.
/// Port of `parseEnglishNumber` in english-number-parser.ts.
int? parseEnglishNumber(String transcript, int maxValue) {
  if (transcript.isEmpty) return null;

  final cleaned = transcript.toLowerCase().trim();
  // Strip trailing punctuation
  final tokenOnly = cleaned.replaceAll(RegExp(r'[.!?,;:]+$'), '').trim();

  // 1. Direct digit match
  final digitMatch = RegExp(r'\b(\d+)\b').firstMatch(cleaned);
  if (digitMatch != null) {
    final num = int.parse(digitMatch.group(1)!);
    if (num >= 0 && num <= maxValue) return num;
  }

  // 1.5. Multi-word hallucination short-circuit
  if (cleaned.contains(' ')) {
    for (final phrase in _whisperHallucinations) {
      if (phrase.contains(' ') && cleaned.contains(phrase)) return null;
    }
  }

  // 1.6. Hallucination marker chars: '(' = 40, '[' = 91, '♪' = 9834, '♫' = 9835
  for (final cp in cleaned.runes) {
    if (cp == 40 || cp == 91 || cp == 9834 || cp == 9835) return null;
  }

  // 1.7. Hallucination phrase fragments
  for (final fragment in _hallucinationPhraseFragments) {
    if (cleaned.contains(fragment)) return null;
  }

  // 2. CLEAR_NUMBERS — match anywhere in transcript
  for (final entry in _clearNumbers.entries) {
    if (entry.value > maxValue) continue;
    final pattern = RegExp(
      r'(?:^|[^a-z])' + RegExp.escape(entry.key) + r'(?:[^a-z]|$)',
      caseSensitive: false,
    );
    if (pattern.hasMatch(cleaned)) return entry.value;
  }

  // 3. STRICT_TOKENS — whole transcript equals token
  if (_strictTokens.containsKey(tokenOnly)) {
    final v = _strictTokens[tokenOnly]!;
    if (v <= maxValue) return v;
  }

  // 4. Hallucination blocklist (whole transcript)
  if (_whisperHallucinations.contains(cleaned) ||
      _whisperHallucinations.contains(tokenOnly)) {
    return null;
  }

  // 5. Fuzzy Levenshtein fallback — single-word transcripts only
  final singleWord = cleaned.replaceAll(RegExp(r'[^a-z]'), '');
  if (singleWord.length >= 2 && singleWord.length <= 6) {
    const targets = [
      'zero', 'one', 'two', 'three', 'four', 'five',
      'six', 'seven', 'eight', 'nine', 'ten',
    ];
    int? bestVal;
    int bestDist = 999;
    for (int v = 0; v <= maxValue && v <= 10; v++) {
      final target = targets[v];
      final d = _levenshtein(singleWord, target);
      final maxDist = target.length <= 3 ? 1 : 2;
      if (d <= maxDist && d < bestDist) {
        bestDist = d;
        bestVal = v;
      }
    }
    if (bestVal != null) return bestVal;
  }

  return null;
}

// ---------------------------------------------------------------------------
// Unified entry point
// ---------------------------------------------------------------------------

/// Match a raw STT transcript to a Likert/eNPS answer value.
///
/// [locale] should be 'vi' or 'vi-VN' for Vietnamese, anything else for English.
/// [maxValue] is the scale maximum (5 for LIKERT_5/ESI_5, 10 for eNPS).
///
/// Returns null if no match; caller shows a "không nhận diện được" snackbar.
int? matchVoiceAnswer(String transcript, int maxValue, {required String locale}) {
  final isVi = locale.startsWith('vi');
  if (isVi) {
    return parseVietnameseNumber(transcript, maxValue);
  } else {
    return parseEnglishNumber(transcript, maxValue);
  }
}
