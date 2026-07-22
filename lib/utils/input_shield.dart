// InputShield — Comprehensive input validation library (Dart port of inputShield.js)
// Pipeline: Sanitize → Normalize (fullwidth/math-unicode/homoglyphs/leet) → Skeleton → Checks

// ─── Sanitize ────────────────────────────────────────────────────────────────

String _stripInvisible(String str) {
  // Use codeUnit-based replacement to avoid BiDi code point warnings in source
  return _stripCodePointRange(
    _stripCodePointRange(
      str.replaceAll('­', ''), // Soft hyphen
      0x200B, 0x200F,   // Zero-width chars
    ),
    0x202A, 0x202E,     // BiDi overrides LRE/RLE/PDF/LRO/RLO/RLM/LRM
  )
  // Combining diacritical marks (Zalgo) — 3+ consecutive
  .replaceAll(RegExp('[̀-ͯ]{3,}'), '');
}

String _stripCodePointRange(String str, int from, int to) {
  final buf = StringBuffer();
  for (final rune in str.runes) {
    if (rune < from || rune > to) buf.writeCharCode(rune);
  }
  return buf.toString();
}

// ─── Normalization Maps ───────────────────────────────────────────────────────

const _leetMap = {
  '0': 'o', '1': 'i', '2': 'z', '3': 'e', '4': 'a',
  '5': 's', '6': 'g', '7': 't', '8': 'b', '9': 'g',
  '@': 'a', r'$': 's', '!': 'i', '+': 't', '|': 'i',
  '(': 'c', ')': 'o', '<': 'c', '>': 'o', '/': 'l',
  r'\': 'l', '^': 'a', '%': 'o', '&': 'a',
};

const _homoglyphMap = {
  // Cyrillic
  'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'х': 'x',
  'у': 'y', 'і': 'i', 'ѕ': 's', 'ј': 'j', 'ѵ': 'v', 'ԁ': 'd',
  'ь': 'b', 'ѡ': 'w', 'м': 'm', 'н': 'h', 'к': 'k', 'т': 't',
  // Greek
  'α': 'a', 'β': 'b', 'γ': 'g', 'ε': 'e', 'ζ': 'z', 'η': 'h',
  'ι': 'i', 'κ': 'k', 'μ': 'm', 'ν': 'v', 'ο': 'o', 'ρ': 'r',
  'σ': 's', 'τ': 't', 'υ': 'u', 'χ': 'x', 'ω': 'o', 'π': 'p',
  // Latin Extended (accented → base)
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'æ': 'ae',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'œ': 'oe',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y', 'ñ': 'n', 'ç': 'c', 'ß': 'ss', 'ð': 'd', 'þ': 'th',
};

/// Normalizes Mathematical Alphanumeric Symbols (U+1D400–U+1D7FF) and circled Latin letters.
String _normalizeMathSymbols(String str) {
  // [rangeStart, count, asciiBase] — asciiBase: 65='A', 97='a'
  const ranges = [
    [0x1D400, 26, 65], [0x1D41A, 26, 97], // Mathematical Bold
    [0x1D434, 26, 65], [0x1D44E, 26, 97], // Mathematical Italic
    [0x1D468, 26, 65], [0x1D482, 26, 97], // Mathematical Bold Italic
    [0x1D4D0, 26, 65], [0x1D4EA, 26, 97], // Mathematical Bold Script
    [0x1D504, 26, 65], [0x1D51E, 26, 97], // Mathematical Fraktur
    [0x1D538, 26, 65], [0x1D552, 26, 97], // Mathematical Double-Struck
    [0x1D56C, 26, 65], [0x1D586, 26, 97], // Mathematical Bold Fraktur
    [0x1D5A0, 26, 65], [0x1D5BA, 26, 97], // Mathematical Sans-Serif
    [0x1D5D4, 26, 65], [0x1D5EE, 26, 97], // Mathematical Sans-Serif Bold
    [0x1D608, 26, 65], [0x1D622, 26, 97], // Mathematical Sans-Serif Italic
    [0x1D63C, 26, 65], [0x1D656, 26, 97], // Mathematical Sans-Serif Bold Italic
    [0x1D670, 26, 65], [0x1D68A, 26, 97], // Mathematical Monospace
  ];

  final result = StringBuffer();
  for (final rune in str.runes) {
    // Circled lowercase ⓐ–ⓩ (U+24D0–U+24E9)
    if (rune >= 0x24D0 && rune <= 0x24E9) {
      result.writeCharCode(rune - 0x24D0 + 97);
      continue;
    }
    // Circled uppercase Ⓐ–Ⓩ (U+24B6–U+24CF)
    if (rune >= 0x24B6 && rune <= 0x24CF) {
      result.writeCharCode(rune - 0x24B6 + 65);
      continue;
    }
    if (rune >= 0x1D400 && rune <= 0x1D7FF) {
      var mapped = false;
      for (final range in ranges) {
        final start = range[0], count = range[1], base = range[2];
        if (rune >= start && rune < start + count) {
          result.writeCharCode(base + (rune - start));
          mapped = true;
          break;
        }
      }
      if (!mapped) result.writeCharCode(rune);
      continue;
    }
    result.writeCharCode(rune);
  }
  return result.toString();
}

String _stripHtml(String str) =>
    str.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String _normalizeFullwidth(String str) => str.replaceAllMapped(
    RegExp(r'[！-～]'),
    (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFF00 + 0x20));

String _normalizeHomoglyphs(String str) =>
    str.split('').map((ch) => _homoglyphMap[ch] ?? ch).join();

String _normalizeLeet(String str) =>
    str.split('').map((ch) => _leetMap[ch] ?? ch).join();

String _collapseRepeats(String str) =>
    str.replaceAllMapped(RegExp(r'(.)\1{2,}'), (m) => m.group(1)!);

/// Full normalization pipeline — internal use only.
String normalize(String input) {
  var s = input;
  s = _stripInvisible(s);
  s = _stripHtml(s);
  s = _normalizeFullwidth(s);
  s = _normalizeMathSymbols(s);
  s = _normalizeHomoglyphs(s);
  s = s.toLowerCase();
  s = _normalizeLeet(s);
  return s;
}

/// Reduces normalized string to skeleton: letters only, repeats collapsed.
String skeleton(String normalized) {
  var s = normalized.replaceAll(RegExp(r'[^a-z]'), '');
  s = _collapseRepeats(s);
  return s;
}

// ─── Word Lists ───────────────────────────────────────────────────────────────

const _profanity = {
  'fuck', 'shit', 'ass', 'asshole', 'bitch', 'bastard', 'dick', 'cock',
  'cunt', 'pussy', 'whore', 'slut', 'nigger', 'nigga', 'faggot', 'fag',
  'retard', 'kike', 'spic', 'chink', 'piss', 'crap', 'motherfucker',
  'bullshit', 'jackass', 'dumbass', 'dipshit', 'shithead', 'fucker',
  'wanker', 'twat', 'prick', 'arsehole', 'arse', 'bollock', 'sodomy',
  'rape', 'raping', 'rapist', 'pedophile', 'pedo', 'pedophilia',
  'beastiality', 'necrophilia', 'jizz', 'cum', 'cumshot', 'rimjob',
};

const _fakeNames = {
  'error', 'danger', 'warning', 'success', 'failed', 'failure',
  'loading', 'processing', 'pending', 'empty', 'blank', 'missing',
  'timeout', 'rejected', 'forbidden', 'unauthorized', 'notallowed',
  'null', 'undefined', 'none', 'nil', 'nan', 'void', 'false', 'true',
  'invalid', 'notfound', 'unknown', 'default', 'placeholder', 'exception',
  'object', 'array', 'string', 'number', 'boolean', 'function',
  'test', 'testing', 'tester', 'testuser', 'testname', 'testor', 'testaccount',
  'admin', 'administrator', 'superuser', 'root', 'sysadmin', 'superadmin',
  'user', 'username', 'name', 'myname', 'yourname', 'fullname',
  'firstname', 'lastname', 'surname', 'nickname', 'displayname', 'handlename',
  'enterhere', 'typeyourname', 'entername', 'writename', 'putname',
  'realname', 'actualname', 'changeme', 'editme', 'updateme',
  'foo', 'bar', 'baz', 'qux', 'quux', 'quuz', 'lorem', 'ipsum', 'dolor', 'amet',
  'dummy', 'fake', 'fakeuser', 'fakename', 'sample', 'example', 'demo',
  'mockup', 'mockuser', 'mockname', 'filler',
  'nobody', 'noone', 'noman', 'nowoman', 'someone', 'anyone', 'everyone',
  'anonymous', 'anon', 'incognito', 'hidden', 'private', 'secret',
  'ghost', 'shadow', 'phantom', 'invisible', 'mystery',
  'faceless', 'voiceless',
  'guest', 'visitor', 'member', 'person', 'human', 'people',
  'moderator', 'mod', 'staff', 'support', 'helpdesk', 'official',
  'bot', 'robot', 'system', 'server', 'owner', 'operator', 'service',
  'witalk', 'witalkofficial', 'witalkteam', 'witalkstaff', 'witalkmod',
  'idk', 'idc', 'lol', 'lmao', 'lmfao', 'wtf', 'omg', 'bruh', 'bro',
  'yolo', 'swag', 'drip', 'vibe', 'mood', 'lolol', 'haha', 'hahaha',
  'rofl', 'roflmao', 'smh', 'ngl', 'tbh', 'imo', 'imho', 'afk', 'gg',
  'abc', 'xyz', 'aaa', 'bbb', 'ccc', 'xxx', 'yyy', 'zzz',
  'aaaa', 'bbbb', 'cccc', 'xxxx', 'yyyy', 'zzzz', 'aaaaa', 'zzzzz',
  'nope', 'skip', 'pass', 'noname', 'nameless', 'unnamed',
  'notmyname', 'noneofyourbusiness', 'na', 'no',
  'label', 'field', 'input', 'value', 'text', 'data', 'info',
  'enter', 'type', 'write', 'fill', 'yourfullname', 'enterfullname',
};

const _keyboardWalks = [
  'qwerty', 'qwertyuiop', 'qwertyui', 'qwert', 'qwer',
  'asdfghjkl', 'asdfghj', 'asdfgh', 'asdfg', 'asdf',
  'zxcvbnm', 'zxcvbn', 'zxcvb', 'zxcv',
  'poiuytrewq', 'lkjhgfdsa', 'mnbvcxz',
  'wasd', 'hjkl', 'uiop', 'rtyu',
  'qazwsx', 'wsxedc', 'edcrfv', 'rfvtgb', 'tgbyhn', 'yhnujm',
  '12345678', '1234567', '123456', '12345', '1234', '123',
  '987654321', '98765', '9876', '01234', '0123456',
  'abcdefghij', 'abcdefghi', 'abcdefgh', 'abcdefg', 'abcdef', 'abcde',
  'zyxwvutsrq', 'zyxwvuts',
];

// ─── Bigram Language Model ────────────────────────────────────────────────────

const _commonBigrams = {
  'th','he','in','er','an','re','on','at','en','nd','ti','es','or','te',
  'of','ed','is','it','al','ar','st','to','nt','ng','se','ha','as','ou',
  'io','le','ve','co','me','de','hi','ri','ro','ic','ne','ea','ra','ce',
  'li','ch','ll','be','ma','si','om','ur','ca','el','ta','la','na','ss',
  'di','fo','ho','pe','ec','ac','et','ul','ge','ns','ly','we','ow','pr',
  'tr','ni','no','pa','fi','wi','il','su','lo','rs','un','da','wh','sh',
  'wo','sa','ld','do','so','am','oo','ay','ys','gh','bi','fe','vi','mi',
  'fr','ct','pl','bu','sp','ck','us','ei','ad','ut','ue','ee','em','ab',
  'gi','mp','ot','ig','po','ex','ry','if','tt','nk','rk','rd','rn','rm',
  'sm','sc','sk','sl','sw','tw','cl','cr','dr','fl','gl','gr','bl','br',
  'qu','ew','aw','oa','ai','au','ia','oi','ui','wa','ki','ke','ku',
};

double _bigramScore(String letters) {
  if (letters.length < 2) return 1.0;
  var hits = 0;
  for (var i = 0; i < letters.length - 1; i++) {
    if (_commonBigrams.contains(letters.substring(i, i + 2))) hits++;
  }
  return hits / (letters.length - 1);
}

// Pre-compiled profanity patterns (word-boundary safe)
final _profanityPatterns = _profanity
    .map((w) => RegExp('(?<![a-z])$w(?![a-z])'))
    .toList();

// ─── Individual Checkers ─────────────────────────────────────────────────────

bool _checkProfanity(String norm, String skel) {
  for (final re in _profanityPatterns) {
    if (re.hasMatch(norm) || re.hasMatch(skel)) return true;
  }
  return false;
}

bool _checkFakeName(String norm, String skel) {
  final clean = norm.replaceAll(RegExp(r'[^a-z]'), '');
  final cleanSkel = skel.replaceAll(RegExp(r'[^a-z]'), '');

  if (_fakeNames.contains(clean) || _fakeNames.contains(cleanSkel)) return true;

  for (final walk in _keyboardWalks) {
    if (clean == walk || cleanSkel == walk) return true;
  }

  // Fake root + trailing digits: test123, user99
  final withoutDigits = clean.replaceAll(RegExp(r'\d+$'), '');
  if (_fakeNames.contains(withoutDigits)) return true;

  // All same character: "aaaaaaa"
  if (clean.length > 1 && RegExp(r'^(.)\1+$').hasMatch(clean)) return true;

  // Near-all same character: >70% one char, length > 3
  if (clean.length > 3) {
    final freq = <String, int>{};
    for (final ch in clean.split('')) {
      freq[ch] = (freq[ch] ?? 0) + 1;
    }
    final maxFreq = freq.values.reduce((a, b) => a > b ? a : b);
    if (maxFreq / clean.length > 0.70) return true;
  }

  // Alternating 2-char: "ababab" (≥3 reps)
  if (clean.length >= 6 && RegExp(r'^(..)(\1){2,}$').hasMatch(clean)) return true;

  // Repeating 2–4 char syllable: "hahaha", "blahblah"
  if (clean.length >= 6 && RegExp(r'^(.{2,4})(\1)+$').hasMatch(clean)) return true;

  return false;
}

Map<String, dynamic> _checkGibberish(String letters, {int threshold = 5}) {
  if (letters.length < 3) return {'triggered': false, 'score': 0};

  var score = 0;
  final signals = <String>[];

  final vowels = RegExp(r'[aeiou]').allMatches(letters).length;
  final vowelRatio = vowels / letters.length;
  if (letters.length > 6) {
    if (vowelRatio < 0.10) { score += 4; signals.add('no_vowels'); }
    else if (vowelRatio < 0.18) { score += 2; signals.add('low_vowels'); }
  }

  final clusters = RegExp(r'[^aeiou]+').allMatches(letters).map((m) => m.group(0)!.length).toList();
  final maxCluster = clusters.isEmpty ? 0 : clusters.reduce((a, b) => a > b ? a : b);
  if (maxCluster >= 7) { score += 3; signals.add('long_consonant_cluster'); }
  else if (maxCluster >= 5) { score += 2; signals.add('consonant_cluster'); }

  if (letters.length > 5) {
    final bs = _bigramScore(letters);
    if (bs < 0.20) { score += 3; signals.add('low_bigram_score'); }
    else if (bs < 0.30) { score += 2; signals.add('weak_bigram_score'); }
  }

  final freq = <String, int>{};
  for (final ch in letters.split('')) { freq[ch] = (freq[ch] ?? 0) + 1; }
  final maxFreq = freq.values.reduce((a, b) => a > b ? a : b);
  if (maxFreq / letters.length > 0.50 && letters.length > 4) {
    score += 2;
    signals.add('char_dominance');
  }

  return {'triggered': score >= threshold, 'score': score, 'signals': signals};
}

Map<String, dynamic>? _checkSuspiciousPattern(String original, String norm) {
  if (RegExp(r'@[a-z0-9]+\.[a-z]{2,}').hasMatch(norm)) {
    return {'triggered': true, 'reason': 'email_pattern'};
  }
  if (RegExp(r'(https?:|www\.|\.com|\.net|\.org|\.io|\.co\b|\.me\b|\.app\b)').hasMatch(norm)) {
    return {'triggered': true, 'reason': 'url_pattern'};
  }
  final digitsOnly = original.replaceAll(RegExp(r'[\s\-().+]'), '');
  if (RegExp(r'\d{7,}').hasMatch(digitsOnly)) {
    return {'triggered': true, 'reason': 'phone_pattern'};
  }
  final specialChars = RegExp(r"[^a-zA-Z0-9\s'\-\.]").allMatches(original).length;
  if (specialChars > 3) {
    return {'triggered': true, 'reason': 'excessive_special_chars'};
  }
  return null;
}

Map<String, dynamic>? _checkStructure(String input, int minLength, int maxLength) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return {'reason': 'empty', 'message': 'Cannot be empty'};
  if (trimmed.length < minLength) {
    return {'reason': 'too_short', 'message': 'Must be at least $minLength character${minLength > 1 ? 's' : ''}'};
  }
  if (trimmed.length > maxLength) {
    return {'reason': 'too_long', 'message': 'Must be at most $maxLength characters'};
  }
  if (RegExp(r'^\d+$').hasMatch(trimmed)) {
    return {'reason': 'all_digits', 'message': 'Cannot be all numbers'};
  }
  if (RegExp(r'^[^a-zA-ZÀ-ɏЀ-ӿऀ-ॿ]+$').hasMatch(trimmed)) {
    return {'reason': 'no_letters', 'message': 'Must contain at least one letter'};
  }
  return null;
}

// ─── Public Validators ────────────────────────────────────────────────────────

class ValidationResult {
  final bool isValid;
  final String? reason;
  final String message;

  const ValidationResult({required this.isValid, this.reason, this.message = ''});

  static const valid = ValidationResult(isValid: true);
}

/// Validate a display name or full name (strict — runs full pipeline).
ValidationResult validateName(String? name, {int minLength = 2, int maxLength = 40}) {
  if (name == null || name.isEmpty) {
    return const ValidationResult(isValid: false, reason: 'empty', message: 'Name cannot be empty');
  }

  final structure = _checkStructure(name, minLength, maxLength);
  if (structure != null) {
    return ValidationResult(isValid: false, reason: structure['reason'], message: structure['message'] as String);
  }

  if (!RegExp(r'^[\p{L}]', unicode: true).hasMatch(name.trim())) {
    return const ValidationResult(isValid: false, reason: 'invalid_start', message: 'Name must start with a letter');
  }

  final norm = normalize(name);
  final skel = skeleton(norm);
  final lettersOnly = skel.replaceAll(RegExp(r'[^a-z]'), '');

  if (_checkProfanity(norm, skel)) {
    return const ValidationResult(isValid: false, reason: 'profanity', message: 'Name contains inappropriate language');
  }
  if (_checkFakeName(norm, skel)) {
    return const ValidationResult(isValid: false, reason: 'fake_name', message: 'Please enter a real name');
  }
  final suspicious = _checkSuspiciousPattern(name, norm);
  if (suspicious != null) {
    return ValidationResult(isValid: false, reason: suspicious['reason'] as String, message: 'Name contains invalid content');
  }
  if (lettersOnly.length >= 3) {
    final gibberish = _checkGibberish(lettersOnly, threshold: 5);
    if (gibberish['triggered'] == true) {
      return const ValidationResult(isValid: false, reason: 'gibberish', message: 'Name appears to be gibberish');
    }
  }

  return ValidationResult.valid;
}

/// Validate general text input (bio, comment, caption).
ValidationResult validateInput(
  String? input, {
  int minLength = 1,
  int maxLength = 500,
  bool allowProfanity = false,
  bool checkGibberish = false,
}) {
  if (input == null || input.isEmpty) {
    return const ValidationResult(isValid: false, reason: 'empty', message: 'Input cannot be empty');
  }

  final structure = _checkStructure(input, minLength, maxLength);
  if (structure != null) {
    return ValidationResult(isValid: false, reason: structure['reason'], message: structure['message'] as String);
  }

  final norm = normalize(input);
  final skel = skeleton(norm);

  if (!allowProfanity && _checkProfanity(norm, skel)) {
    return const ValidationResult(isValid: false, reason: 'profanity', message: 'Input contains inappropriate language');
  }

  if (checkGibberish) {
    final lettersOnly = skel.replaceAll(RegExp(r'[^a-z]'), '');
    if (lettersOnly.length >= 4) {
      final gibberish = _checkGibberish(lettersOnly, threshold: 7);
      if (gibberish['triggered'] == true) {
        return const ValidationResult(isValid: false, reason: 'gibberish', message: 'Input appears to be gibberish');
      }
    }
  }

  return ValidationResult.valid;
}

/// Validate a username / handle.
ValidationResult validateUsername(String? username, {int minLength = 3, int maxLength = 30}) {
  if (username == null || username.isEmpty) {
    return const ValidationResult(isValid: false, reason: 'empty', message: 'Username cannot be empty');
  }
  if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username)) {
    return const ValidationResult(
      isValid: false,
      reason: 'invalid_chars',
      message: 'Username may only contain letters, numbers, . _ -',
    );
  }
  return validateName(username, minLength: minLength, maxLength: maxLength);
}

/// Validate multiple fields at once.
Map<String, ValidationResult> validateFields(Map<String, Map<String, dynamic>> fields) {
  final results = <String, ValidationResult>{};
  for (final entry in fields.entries) {
    final value = entry.value['value'] as String?;
    final type = entry.value['type'] as String? ?? 'input';
    final opts = entry.value['options'] as Map<String, dynamic>? ?? {};

    if (type == 'name') {
      results[entry.key] = validateName(
        value,
        minLength: opts['minLength'] as int? ?? 2,
        maxLength: opts['maxLength'] as int? ?? 40,
      );
    } else if (type == 'username') {
      results[entry.key] = validateUsername(
        value,
        minLength: opts['minLength'] as int? ?? 3,
        maxLength: opts['maxLength'] as int? ?? 30,
      );
    } else {
      results[entry.key] = validateInput(
        value,
        minLength: opts['minLength'] as int? ?? 1,
        maxLength: opts['maxLength'] as int? ?? 500,
        allowProfanity: opts['allowProfanity'] as bool? ?? false,
        checkGibberish: opts['checkGibberish'] as bool? ?? false,
      );
    }
  }
  return results;
}

bool allValid(Map<String, ValidationResult> results) =>
    results.values.every((r) => r.isValid);

/// Debug helper — returns all intermediate signals for a given input.
Map<String, dynamic> inspect(String input, {String type = 'name'}) {
  final norm = normalize(input);
  final skel = skeleton(norm);
  final lettersOnly = skel.replaceAll(RegExp(r'[^a-z]'), '');
  final threshold = type == 'input' ? 7 : 5;
  final gibberish = _checkGibberish(lettersOnly, threshold: threshold);

  return {
    'original': input,
    'normalized': norm,
    'skeleton': skel,
    'lettersOnly': lettersOnly,
    'bigramScore': double.parse(_bigramScore(lettersOnly).toStringAsFixed(3)),
    'gibberishScore': gibberish['score'],
    'gibberishSignals': gibberish['signals'],
    'checks': {
      'profanity': _checkProfanity(norm, skel),
      'fakeName': _checkFakeName(norm, skel),
      'suspiciousPattern': _checkSuspiciousPattern(input, norm) != null,
      'gibberish': gibberish['triggered'],
    },
  };
}
