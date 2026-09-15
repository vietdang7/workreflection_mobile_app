// Test cho lọc theo cảm xúc + xoay vòng chống lặp.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §III, §IV, §VI.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_situation_picker.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

WrSituation _sit(String code, ScaDimension dim) {
  final subgroup = switch (dim) {
    ScaDimension.s1 => 'S1',
    ScaDimension.s2 => 'S2',
    ScaDimension.c1 => 'C1',
    ScaDimension.c2 => 'C2',
    ScaDimension.a1 => 'A1',
    ScaDimension.a3 => 'A3',
    ScaDimension.pAchieve => 'Ap',
    ScaDimension.pSteady => 'Sp',
    _ => 'S1',
  };
  final pillar = switch (subgroup) {
    'S1' || 'S2' || 'Sp' => 'S',
    'C1' || 'C2' || 'Cp' => 'C',
    _ => 'A',
  };
  final mood = switch (subgroup) {
    'S1' => 'foggy',
    'S2' => 'outofsync',
    'C1' || 'C2' => 'stress',
    'A1' || 'A3' => 'tired',
    'Sp' => 'ok',
    _ => 'happy',
  };
  return WrSituation(
    code: code,
    text: 'Tình huống $code',
    scaDimension: dim,
    pillarCode: pillar,
    subgroup: subgroup,
    mood: mood,
    valence: dim.isPositive ? WrValence.tichCuc : WrValence.thachThuc,
    wave: 1,
  );
}

/// Thư viện giả đủ rộng để mọi nhánh của §4.1 đều chạm tới được.
List<WrSituation> _library() => [
  for (var i = 1; i <= 6; i++) _sit('A3-$i', ScaDimension.a3),
  for (var i = 1; i <= 6; i++) _sit('C2-$i', ScaDimension.c2),
  for (var i = 1; i <= 6; i++) _sit('A1-$i', ScaDimension.a1),
  // S1 và S2 là cụm của hai cảm xúc thêm 25/08 ("mơ hồ", "lệch nhau").
  // Thiếu một trong hai thì cụm không đủ 5, `pickSituationChoices` lùi về
  // toàn thư viện và bài test lọc-theo-cảm-xúc mất hết ý nghĩa: nó sẽ báo
  // xanh cả khi ánh xạ sai.
  for (var i = 1; i <= 6; i++) _sit('S1-$i', ScaDimension.s1),
  for (var i = 1; i <= 6; i++) _sit('S2-$i', ScaDimension.s2),
  for (var i = 1; i <= 5; i++) _sit('P-A$i', ScaDimension.pAchieve),
  for (var i = 1; i <= 5; i++) _sit('P-S$i', ScaDimension.pSteady),
];

void main() {
  _resolveTests();

  // -------------------------------------------------------------------------
  // Gộp Situation về một thực thể (v2.0 §2.2), migration
  // `20260731090000_wr_situations_from_library.sql`.
  // -------------------------------------------------------------------------
  group('tình huống đã ngưng đề xuất', () {
    WrSituation retired(String code, ScaDimension dim) => WrSituation(
      code: code,
      text: 'Tình huống $code',
      scaDimension: dim,
      wave: 1,
      retiredAt: DateTime(2026, 7, 31),
    );

    test('không bao giờ lọt vào bể gợi ý', () {
      final all = [
        ..._library(),
        for (var i = 1; i <= 6; i++) retired('A3-sit-0$i', ScaDimension.a3),
      ];
      // Chạy nhiều lượt vì bể được trộn ngẫu nhiên — một lượt may mắn không
      // chứng minh được gì.
      for (var run = 0; run < 40; run++) {
        final picked = pickSituationChoices(all: all, mood: Mood.stressed);
        expect(
          picked.where((s) => s.isRetired),
          isEmpty,
          reason:
              'chip Tầng 1 cũ trùng nghĩa với mục thư viện — bày cả hai là '
              'dựng ra hai phiên bản của cùng một tình huống',
        );
      }
    });

    test('vẫn tra ngược ra nhãn được cho lịch sử đã ghi', () {
      // Đây là lý do KHÔNG xoá khỏi bảng: Episode cũ còn tham chiếu mã này, và
      // tab Hiểu mình dựng nhãn "Tình huống lặp lại" từ chính bảng này.
      final all = [retired('C2-sit-01', ScaDimension.c2)];
      final labels = {for (final s in all) s.code: s.text};
      expect(labels['C2-sit-01'], 'Tình huống C2-sit-01');
    });

    test('cả thư viện đều ngưng thì trả rỗng, không lùi về mục đã ngưng', () {
      final all = [
        for (var i = 1; i <= 6; i++) retired('A3-sit-0$i', ScaDimension.a3),
      ];
      expect(pickSituationChoices(all: all, mood: Mood.stressed), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('§III — lọc tình huống theo cảm xúc check-in', () {
    test('mỗi cảm xúc lấy ba mục cùng mood và hai mục cùng valence', () {
      final all = _library();

      for (final entry in kMoodCodes.entries) {
        final picked = pickSituationChoices(
          all: all,
          mood: entry.key,
          random: Random(1),
        );
        expect(picked, hasLength(kSituationChoiceCount));
        final sameMood = picked.where((s) => s.mood == entry.value).toList();
        expect(sameMood, hasLength(3));
        final valence = sameMood.first.explicitValence;
        expect(
          picked
              .skip(3)
              .every(
                (s) => s.mood != entry.value && s.explicitValence == valence,
              ),
          isTrue,
        );
      }
    });

    test('cảm xúc tích cực không bao giờ chạm vào chiều vấn đề', () {
      // §2.3: đây chính là lỗi nhóm P-* sinh ra để chữa. Người vừa check-in
      // "đang vui" mà nhận tình huống "Tôi lại phải làm thay" là hỏng trải
      // nghiệm, dù thuật toán vẫn "đúng".
      final all = _library();

      for (final mood in [Mood.okay, Mood.happy]) {
        final picked = pickSituationChoices(
          all: all,
          mood: mood,
          random: Random(7),
        );
        for (final s in picked) {
          expect(
            s.scaDimension.isPositive,
            isTrue,
            reason: '${mood.name} nhận phải tình huống vấn đề ${s.code}',
          );
        }
      }
    });

    test('căng thẳng và mệt mỏi cho ra hai cụm khác nhau', () {
      // Cả hai đều là năng lượng thấp, nhưng §III tách bạch: căng thẳng đi kèm
      // né tránh lên tiếng (C2), mệt mỏi đi kèm mất phương hướng (A1).
      // Gộp hai cái này lại là mất đúng phần tinh tế của bộ lọc.
      expect(kMoodDimensions[Mood.stressed], contains(ScaDimension.c2));
      expect(kMoodDimensions[Mood.tired], contains(ScaDimension.a1));
      expect(
        kMoodDimensions[Mood.stressed],
        isNot(equals(kMoodDimensions[Mood.tired])),
      );
    });

    test('không có cảm xúc thì dùng toàn bộ thư viện', () {
      // Vào thẳng từ tab, không qua check-in.
      final all = _library();
      final picked = pickSituationChoices(
        all: all,
        mood: null,
        random: Random(3),
      );
      expect(picked, hasLength(kSituationChoiceCount));
    });

    test('cụm không đủ 5 thì mở rộng ra toàn thư viện, không trả về thiếu', () {
      // §III: "nếu không đủ, mở rộng ra toàn bộ thư viện để tránh danh sách
      // trống." Thà gợi ý kém liên quan còn hơn màn hình rỗng.
      final all = [
        _sit('A3-1', ScaDimension.a3),
        _sit('C2-1', ScaDimension.c2),
        for (var i = 1; i <= 8; i++) _sit('S1-$i', ScaDimension.s1),
      ];
      final picked = pickSituationChoices(
        all: all,
        mood: Mood.stressed,
        random: Random(5),
      );
      expect(picked, hasLength(kSituationChoiceCount));
      expect(picked.any((s) => s.scaDimension == ScaDimension.s1), isTrue);
    });

    test('thư viện rỗng trả về danh sách rỗng, không ném lỗi', () {
      expect(pickSituationChoices(all: const [], mood: Mood.happy), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('§IV.1 — xoay vòng chống lặp lại', () {
    test('bốn ô còn lại ưu tiên tình huống chưa từng xuất hiện', () {
      final all = _library();
      final seen = ['A3-1', 'A3-2', 'A3-3', 'C2-1', 'C2-2'];

      final picked = pickSituationChoices(
        all: all,
        mood: Mood.stressed,
        recentIds: seen,
        random: Random(11),
      );

      // There are enough unseen rows in the strict v2 pools, so every choice
      // remains new within the first-ten window.
      for (final s in picked) {
        expect(
          seen,
          isNot(contains(s.code)),
          reason: '${s.code} vừa xem gần đây mà vẫn được gợi ý lại',
        );
      }
    });

    test('còn ít hơn 5 mục chưa xem thì cho phép lặp lại', () {
      // §4.1: "chỉ khi nhóm chưa xuất hiện có ít hơn 5 tình huống mới cho phép
      // lặp lại từ đầu." Nếu không có luật này, người dùng chăm chỉ sẽ gặp màn
      // hình trống sau khi đi hết thư viện.
      final all = _library();
      final almostAll = [
        for (var i = 1; i <= 6; i++) 'A3-$i',
        for (var i = 1; i <= 5; i++) 'C2-$i',
      ];

      final picked = pickSituationChoices(
        all: all,
        mood: Mood.stressed,
        recentIds: almostAll,
        random: Random(13),
      );
      expect(picked, hasLength(kSituationChoiceCount));
    });

    test('rememberSituation đẩy mã mới lên đầu', () {
      final result = rememberSituation('C2-01', ['A3-01', 'A1-02']);
      expect(result, ['C2-01', 'A3-01', 'A1-02']);
    });

    test('chọn lại mã cũ thì đẩy lên đầu, không nhân đôi', () {
      // Nhân đôi thì một mã chọn nhiều lần sẽ chiếm hết 30 chỗ và vô hiệu hoá
      // luôn cơ chế xoay vòng.
      final result = rememberSituation('A1-02', ['A3-01', 'A1-02', 'C2-03']);
      expect(result, ['A1-02', 'A3-01', 'C2-03']);
      expect(result.where((c) => c == 'A1-02'), hasLength(1));
    });

    test('giữ tối đa 30 mục, cắt phần cũ nhất', () {
      var recent = <String>[];
      for (var i = 1; i <= 40; i++) {
        recent = rememberSituation('code-$i', recent);
      }
      expect(recent, hasLength(kRecentSituationCapacity));
      expect(recent.first, 'code-40');
      expect(recent.last, 'code-11');
      expect(recent, isNot(contains('code-1')));
    });
  });

  // -------------------------------------------------------------------------
  // The v2 picker deliberately has no forced anchor. The recent window is a
  // diversity hint: unseen records win while the exhausted-pool path remains
  // available.
  // -------------------------------------------------------------------------
  group('§IV.1 — xoay vòng v2 không ép ô neo', () {
    test('đủ pool chưa xem thì không chọn lại mười mã gần nhất', () {
      final all = _library();
      final seen = ['C2-4', 'A3-2', 'A3-5'];

      for (var run = 0; run < 40; run++) {
        final picked = pickSituationChoices(
          all: all,
          mood: Mood.stressed,
          recentIds: seen,
        );
        expect(picked, hasLength(kSituationChoiceCount));
        expect(picked.any((s) => seen.contains(s.code)), isFalse);
        expect(
          picked.map((s) => s.code).toSet(),
          hasLength(picked.length),
          reason: 'picker must not duplicate a code',
        );
      }
    });

    test('mood pool still supplies five choices without an anchor', () {
      final all = _library();
      final picked = pickSituationChoices(
        all: all,
        mood: Mood.tired,
        recentIds: ['C2-4', 'A1-3', 'S1-1'],
        random: Random(21),
      );

      expect(picked, hasLength(kSituationChoiceCount));
      expect(picked.any((s) => s.code == 'A1-3'), isFalse);
    });

    test('chưa chọn lần nào thì không có neo, vẫn đủ 5 ô', () {
      final picked = pickSituationChoices(
        all: _library(),
        mood: Mood.stressed,
        recentIds: const [],
        random: Random(4),
      );

      expect(picked, hasLength(kSituationChoiceCount));
    });

    test('mọi mã đã chọn đều ngoài cụm vẫn đủ 5 ô', () {
      final picked = pickSituationChoices(
        all: _library(),
        mood: Mood.stressed,
        recentIds: ['S1-1', 'S1-2', 'P-A1'],
        random: Random(9),
      );

      expect(picked, hasLength(kSituationChoiceCount));
      expect(
        picked.take(3).every((s) => s.mood == kMoodCodes[Mood.stressed]),
        isTrue,
      );
      expect(
        picked.skip(3).every((s) => s.mood != kMoodCodes[Mood.stressed]),
        isTrue,
      );
    });

    test('tình huống đã ngưng đề xuất không lọt vào bể', () {
      // Lịch sử cũ đầy mã `-sit-` đã retired. Neo vào một mã như thế là bày lại
      // đúng cái chip vừa bị gỡ khỏi thư viện.
      final all = [
        ..._library(),
        WrSituation(
          code: 'C2-sit-01',
          text: 'Chip Tầng 1 cũ',
          scaDimension: ScaDimension.c2,
          wave: 1,
          retiredAt: DateTime(2026, 7, 31),
        ),
      ];

      for (var run = 0; run < 20; run++) {
        final picked = pickSituationChoices(
          all: all,
          mood: Mood.stressed,
          recentIds: ['C2-sit-01', 'A3-2'],
        );
        expect(picked.any((s) => s.isRetired), isFalse);
        expect(picked, hasLength(kSituationChoiceCount));
      }
    });

    test('exhausted pool allows repeats without duplicates in one result', () {
      final all = _library();
      final picked = pickSituationChoices(
        all: all,
        mood: Mood.stressed,
        recentIds: [
          for (var i = 1; i <= 6; i++) 'A3-$i',
          for (var i = 1; i <= 6; i++) 'C2-$i',
        ],
        random: Random(4),
      );
      expect(picked, hasLength(kSituationChoiceCount));
      expect(picked.map((s) => s.code).toSet(), hasLength(picked.length));
    });

    test('anchorSituation trả về mã gần nhất còn trong danh sách', () {
      final pool = [
        _sit('A3-1', ScaDimension.a3),
        _sit('C2-9', ScaDimension.c2),
      ];

      expect(anchorSituation(pool, ['C2-9', 'A3-1'])?.code, 'C2-9');
      expect(anchorSituation(pool, ['S1-1', 'A3-1'])?.code, 'A3-1');
      expect(anchorSituation(pool, const []), isNull);
      expect(anchorSituation(pool, ['S1-1']), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('§VI — bể Lựa chọn', () {
    const pool = [
      'Thử một cách tiếp cận khác vào lần tới',
      'Giữ nguyên cách làm hiện tại, quan sát thêm',
      'Chưa biết, cần thêm thời gian',
      'Nói chuyện với ai đó về điều này',
      'Ghi nhớ điều này để xem lại sau',
      'Đặt lời nhắc để quay lại tình huống này sau một tuần',
      'Chia sẻ điều này với người liên quan trực tiếp',
      'Không cần hành động gì, chỉ cần ghi nhận là đủ',
    ];

    test('có Practice: 4 lựa chọn, Practice luôn đứng đầu', () {
      final options = pickChoiceOptions(
        practice: 'Ghi lại một tình huống tôi thấy mình gánh thay người khác.',
        pool: pool,
        random: Random(2),
      );
      expect(options, hasLength(4));
      expect(
        options.first,
        'Ghi lại một tình huống tôi thấy mình gánh thay người khác.',
      );
    });

    test('không có Practice ("Điều khác"): 4 câu lấy hết từ bể', () {
      final options = pickChoiceOptions(
        practice: null,
        pool: pool,
        random: Random(2),
      );
      expect(options, hasLength(4));
      for (final o in options) {
        expect(pool, contains(o));
      }
    });

    test('Practice rỗng hoặc toàn khoảng trắng coi như không có', () {
      for (final blank in ['', '   ', '\n']) {
        final options = pickChoiceOptions(
          practice: blank,
          pool: pool,
          random: Random(2),
        );
        expect(options, hasLength(4));
        for (final o in options) {
          expect(pool, contains(o));
        }
      }
    });

    test('không lặp lại chính Practice trong 3 câu chung', () {
      // Practice trùng một câu trong bể mà không lọc thì người dùng thấy hai
      // dòng y hệt nhau, một dòng có nhãn "Gợi ý" một dòng không.
      const duplicated = 'Nói chuyện với ai đó về điều này';
      final options = pickChoiceOptions(
        practice: duplicated,
        pool: pool,
        random: Random(4),
      );
      expect(options.where((o) => o == duplicated), hasLength(1));
      expect(options, hasLength(4));
    });

    test('các lựa chọn không trùng nhau', () {
      for (var seed = 0; seed < 30; seed++) {
        final options = pickChoiceOptions(
          practice: 'Một hành động riêng của tình huống',
          pool: pool,
          random: Random(seed),
        );
        expect(
          options.toSet(),
          hasLength(options.length),
          reason: 'seed $seed sinh ra lựa chọn trùng',
        );
      }
    });

    test('không làm thay đổi danh sách bể gốc', () {
      final original = [...pool];
      pickChoiceOptions(practice: 'x', pool: pool, random: Random(1));
      expect(pool, original);
    });
  });
}

// ---------------------------------------------------------------------------
// Nối Situation → Story
//
// Hai bảng dùng hai hệ mã khác nhau (wr_situations: `C1-sit-01`,
// wr_stories: `C1-01`), chỉ nhóm P-* là trùng. resolveStoryFor phải bắc cầu
// được, và quan trọng nhất là bắc ỔN ĐỊNH.
// ---------------------------------------------------------------------------

WrStory _story(String id, ScaDimension dim, {String? aha}) => WrStory(
  storyId: id,
  title: 'Tiêu đề $id',
  scaDimension: dim,
  storyContent: 'Nội dung $id',
  emotionTags: const [],
  behaviorTags: const [],
  careerStages: const [],
  ahaMessage: aha ?? 'Aha của $id',
  practiceAction: 'Practice của $id',
);

void _resolveTests() {
  group('resolveStoryFor', () {
    test('trùng mã tuyệt đối thì lấy đúng story đó (nhóm P-*)', () {
      final sit = _sit('P-01', ScaDimension.pAchieve);
      final stories = [
        _story('P-01', ScaDimension.pAchieve),
        _story('P-02', ScaDimension.pAchieve),
      ];
      expect(resolveStoryFor(sit, stories)!.storyId, 'P-01');
    });

    test('không trùng mã thì trả null, không mượn story cùng chiều', () {
      final sit = _sit('C2-sit-03', ScaDimension.c2);
      final stories = [
        _story('A1-01', ScaDimension.a1),
        _story('C2-01', ScaDimension.c2),
        _story('C2-02', ScaDimension.c2),
      ];
      final found = resolveStoryFor(sit, stories);
      expect(found, isNull);
    });

    test('legacy chip không có story chính xác cũng trả null', () {
      final sit = _sit('A3-sit-05', ScaDimension.a3);
      final stories = [
        for (var i = 1; i <= 10; i++)
          _story('A3-${i.toString().padLeft(2, '0')}', ScaDimension.a3),
      ];
      final first = resolveStoryFor(sit, stories);
      for (var i = 0; i < 20; i++) {
        expect(resolveStoryFor(sit, stories), first);
      }
    });

    test('unknown story code never falls back despite matching dimension', () {
      final sit = _sit('A3-sit-05', ScaDimension.a3);
      final stories = [
        for (var i = 1; i <= 6; i++)
          _story('A3-${i.toString().padLeft(2, '0')}', ScaDimension.a3),
      ];
      expect(resolveStoryFor(sit, stories), isNull);
      expect(resolveStoryFor(sit, stories.reversed.toList()), isNull);
    });

    test('multiple unknown chips do not borrow unrelated stories', () {
      final stories = [
        for (var i = 1; i <= 10; i++)
          _story('C1-${i.toString().padLeft(2, '0')}', ScaDimension.c1),
      ];
      for (var i = 1; i <= 6; i++) {
        expect(
          resolveStoryFor(_sit('C1-sit-0$i', ScaDimension.c1), stories),
          isNull,
        );
      }
    });

    test('không có story cùng chiều thì trả null, không bịa', () {
      final sit = _sit('S3-sit-01', ScaDimension.s3);
      final stories = [_story('A1-01', ScaDimension.a1)];
      expect(resolveStoryFor(sit, stories), isNull);
    });

    test('thư viện story rỗng thì trả null', () {
      expect(
        resolveStoryFor(_sit('C1-sit-01', ScaDimension.c1), const []),
        isNull,
      );
    });
  });
}
