import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/voice_answer_matcher.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Vietnamese parser
  // ---------------------------------------------------------------------------
  group('parseVietnameseNumber', () {
    group('direct digit', () {
      test('digit "3" → 3', () => expect(parseVietnameseNumber('3', 5), 3));
      test('digit "10" → 10 when max=10', () => expect(parseVietnameseNumber('10', 10), 10));
      test('digit out of range → null', () => expect(parseVietnameseNumber('7', 5), null));
      test('digit "0" → null (VI range starts at 1)', () => expect(parseVietnameseNumber('0', 5), null));
    });

    group('Vietnamese number words with diacritics', () {
      test('một → 1', () => expect(parseVietnameseNumber('một', 5), 1));
      test('hai → 2', () => expect(parseVietnameseNumber('hai', 5), 2));
      test('ba → 3', () => expect(parseVietnameseNumber('ba', 5), 3));
      test('bốn → 4', () => expect(parseVietnameseNumber('bốn', 5), 4));
      test('năm → 5', () => expect(parseVietnameseNumber('năm', 5), 5));
      test('sáu → 6 (max=10)', () => expect(parseVietnameseNumber('sáu', 10), 6));
      test('bảy → 7 (max=10)', () => expect(parseVietnameseNumber('bảy', 10), 7));
      test('tám → 8 (max=10)', () => expect(parseVietnameseNumber('tám', 10), 8));
      test('chín → 9 (max=10)', () => expect(parseVietnameseNumber('chín', 10), 9));
      test('mười → 10 (max=10)', () => expect(parseVietnameseNumber('mười', 10), 10));
    });

    group('no-diacritics STT output', () {
      test('mot → 1', () => expect(parseVietnameseNumber('mot', 5), 1));
      test('bon → 4', () => expect(parseVietnameseNumber('bon', 5), 4));
      test('nam → 5', () => expect(parseVietnameseNumber('nam', 5), 5));
      test('sau → 6 (max=10)', () => expect(parseVietnameseNumber('sau', 10), 6));
      test('bay → 7 (max=10)', () => expect(parseVietnameseNumber('bay', 10), 7));
      test('tam → 8 (max=10)', () => expect(parseVietnameseNumber('tam', 10), 8));
      test('chin → 9 (max=10)', () => expect(parseVietnameseNumber('chin', 10), 9));
      test('muoi → 10 (max=10)', () => expect(parseVietnameseNumber('muoi', 10), 10));
    });

    group('alternative spellings', () {
      test('bầy → 7', () => expect(parseVietnameseNumber('bầy', 10), 7));
      test('bẩy → 7', () => expect(parseVietnameseNumber('bẩy', 10), 7));
    });

    group('mixed text', () {
      test('câu số ba → 3', () => expect(parseVietnameseNumber('câu số ba', 5), 3));
      test('tôi chọn năm → 5', () => expect(parseVietnameseNumber('tôi chọn năm', 5), 5));
    });

    group('fuzzy diacritics removal', () {
      test('muoi (no diacritics of mười) → 10', () => expect(parseVietnameseNumber('muoi', 10), 10));
    });

    group('maxValue capping', () {
      test('năm=5 capped at max=3 → null', () => expect(parseVietnameseNumber('năm', 3), null));
      test('mười=10 capped at max=5 → null', () => expect(parseVietnameseNumber('mười', 5), null));
    });

    group('garbage input', () {
      test('empty → null', () => expect(parseVietnameseNumber('', 5), null));
      test('random text → null', () => expect(parseVietnameseNumber('xin chào thế giới', 5), null));
      test('English word → null', () => expect(parseVietnameseNumber('hello', 5), null));
    });
  });

  // ---------------------------------------------------------------------------
  // English parser
  // ---------------------------------------------------------------------------
  group('parseEnglishNumber', () {
    group('direct digit', () {
      test('"1" → 1', () => expect(parseEnglishNumber('1', 5), 1));
      test('"0" → 0', () => expect(parseEnglishNumber('0', 10), 0));
      test('"10" → 10 (max=10)', () => expect(parseEnglishNumber('10', 10), 10));
      test('"6" out of range → null', () => expect(parseEnglishNumber('6', 5), null));
    });

    group('CLEAR_NUMBERS — canonical words', () {
      test('zero → 0', () => expect(parseEnglishNumber('zero', 10), 0));
      test('one → 1', () => expect(parseEnglishNumber('one', 5), 1));
      test('two → 2', () => expect(parseEnglishNumber('two', 5), 2));
      test('three → 3', () => expect(parseEnglishNumber('three', 5), 3));
      test('four → 4', () => expect(parseEnglishNumber('four', 5), 4));
      test('five → 5', () => expect(parseEnglishNumber('five', 5), 5));
      test('six → 6 (max=10)', () => expect(parseEnglishNumber('six', 10), 6));
      test('seven → 7 (max=10)', () => expect(parseEnglishNumber('seven', 10), 7));
      test('eight → 8 (max=10)', () => expect(parseEnglishNumber('eight', 10), 8));
      test('nine → 9 (max=10)', () => expect(parseEnglishNumber('nine', 10), 9));
      test('ten → 10 (max=10)', () => expect(parseEnglishNumber('ten', 10), 10));
    });

    group('CLEAR_NUMBERS — VN-accent homophones', () {
      test('foe → 4', () => expect(parseEnglishNumber('foe', 5), 4));
      test('faux → 4', () => expect(parseEnglishNumber('faux', 5), 4));
      test('too → 2', () => expect(parseEnglishNumber('too', 5), 2));
      test('tree → 3', () => expect(parseEnglishNumber('tree', 5), 3));
      test('free → 3', () => expect(parseEnglishNumber('free', 5), 3));
      test('won → 1', () => expect(parseEnglishNumber('won', 5), 1));
    });

    group('CLEAR_NUMBERS — phrase context', () {
      test('"the answer is four" → 4', () => expect(parseEnglishNumber('the answer is four', 5), 4));
      test('"I think three" → 3', () => expect(parseEnglishNumber('I think three', 5), 3));
    });

    group('STRICT_TOKENS — whole-transcript homophones', () {
      test('"bye" → 5', () => expect(parseEnglishNumber('bye', 5), 5));
      test('"Bye!" → 5 (trailing punct stripped)', () => expect(parseEnglishNumber('Bye!', 5), 5));
      test('"you" → 2', () => expect(parseEnglishNumber('you', 5), 2));
      test('"pho" → 4', () => expect(parseEnglishNumber('pho', 5), 4));
      test('"oh" → 0 (max=10)', () => expect(parseEnglishNumber('oh', 10), 0));
      test('"on" → 1', () => expect(parseEnglishNumber('on', 5), 1));
      // "bye" in a phrase should NOT match STRICT (uses CLEAR path for "five")
      // "thank you" contains "you" as substr but "you" is STRICT — no match from phrase
      test('"thank you" → null (multi-word hallucination)', () => expect(parseEnglishNumber('thank you', 5), null));
    });

    group('hallucination blocklist', () {
      test('"thank you for watching" → null', () => expect(parseEnglishNumber('thank you for watching', 5), null));
      test('"[music]" → null (marker char)', () => expect(parseEnglishNumber('[music]', 5), null));
      test('"(crowd cheering)" → null (marker char)', () => expect(parseEnglishNumber('(crowd cheering)', 5), null));
      test('"okay" → null', () => expect(parseEnglishNumber('okay', 5), null));
      test('"uh" → null', () => expect(parseEnglishNumber('uh', 5), null));
    });

    group('fuzzy Levenshtein fallback', () {
      test('"nein" → 9 (d=1 from "nine")', () => expect(parseEnglishNumber('nein', 10), 9));
      test('"treee" → 3 (d=1 from "three")', () => expect(parseEnglishNumber('treee', 5), 3));
      // "xyz" is too far from any digit word → null
      test('"xyz" → null', () => expect(parseEnglishNumber('xyz', 10), null));
    });

    group('maxValue capping', () {
      test('five=5 capped at max=3 → null', () => expect(parseEnglishNumber('five', 3), null));
      test('ten=10 capped at max=5 → null', () => expect(parseEnglishNumber('ten', 5), null));
    });

    group('garbage input', () {
      test('empty → null', () => expect(parseEnglishNumber('', 5), null));
      test('random gibberish → null', () => expect(parseEnglishNumber('asdfqwerty', 5), null));
    });
  });

  // ---------------------------------------------------------------------------
  // matchVoiceAnswer unified entry point
  // ---------------------------------------------------------------------------
  group('matchVoiceAnswer', () {
    test('VI locale routes to VI parser', () {
      expect(matchVoiceAnswer('hai', 5, locale: 'vi-VN'), 2);
    });
    test('VI locale short code routes to VI parser', () {
      expect(matchVoiceAnswer('ba', 5, locale: 'vi'), 3);
    });
    test('EN locale routes to EN parser', () {
      expect(matchVoiceAnswer('three', 5, locale: 'en-US'), 3);
    });
    test('EN locale default routes to EN parser', () {
      expect(matchVoiceAnswer('four', 5, locale: 'en'), 4);
    });
    test('no match returns null (VI)', () {
      expect(matchVoiceAnswer('hello', 5, locale: 'vi-VN'), null);
    });
    test('no match returns null (EN)', () {
      expect(matchVoiceAnswer('asdfgh', 5, locale: 'en-US'), null);
    });
  });
}
