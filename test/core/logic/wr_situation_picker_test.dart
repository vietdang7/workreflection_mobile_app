// Test cho lọc theo cảm xúc + xoay vòng chống lặp.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §III, §IV, §VI.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_situation_picker.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

WrSituation _sit(String code, ScaDimension dim) => WrSituation(
      code: code,
      text: 'Tình huống $code',
      scaDimension: dim,
      wave: 1,
    );

/// Thư viện giả đủ rộng để mọi nhánh của §4.1 đều chạm tới được.
List<WrSituation> _library() => [
      for (var i = 1; i <= 6; i++) _sit('A3-$i', ScaDimension.a3),
      for (var i = 1; i <= 6; i++) _sit('C2-$i', ScaDimension.c2),
      for (var i = 1; i <= 6; i++) _sit('A1-$i', ScaDimension.a1),
      for (var i = 1; i <= 6; i++) _sit('S1-$i', ScaDimension.s1),
      for (var i = 1; i <= 5; i++) _sit('P-A$i', ScaDimension.pAchieve),
      for (var i = 1; i <= 5; i++) _sit('P-S$i', ScaDimension.pSteady),
    ];

void main() {
  _resolveTests();

  // -------------------------------------------------------------------------
  group('§III — lọc tình huống theo cảm xúc check-in', () {
    test('mỗi cảm xúc chỉ lấy tình huống trong đúng cụm chiều của nó', () {
      final all = _library();

      for (final entry in kMoodDimensions.entries) {
        final picked = pickSituationChoices(
          all: all,
          mood: entry.key,
          random: Random(1),
        );
        expect(picked, hasLength(kSituationChoiceCount));
        for (final s in picked) {
          expect(
            entry.value,
            contains(s.scaDimension),
            reason: '${entry.key.name} không được gợi ý '
                '${s.code} thuộc chiều ${s.scaDimension.dbValue}',
          );
        }
      }
    });

    test('cảm xúc tích cực không bao giờ chạm vào chiều vấn đề', () {
      // §2.3: đây chính là lỗi nhóm P-* sinh ra để chữa. Người vừa check-in
      // "đang vui" mà nhận tình huống "Tôi lại phải làm thay" là hỏng trải
      // nghiệm, dù thuật toán vẫn "đúng".
      final all = _library();

      for (final mood in [Mood.okay, Mood.happy]) {
        final picked =
            pickSituationChoices(all: all, mood: mood, random: Random(7));
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
      final picked =
          pickSituationChoices(all: all, mood: null, random: Random(3));
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
    test('ưu tiên tình huống chưa từng xuất hiện', () {
      final all = _library();
      final seen = ['A3-1', 'A3-2', 'A3-3', 'C2-1', 'C2-2'];

      final picked = pickSituationChoices(
        all: all,
        mood: Mood.stressed,
        recentIds: seen,
        random: Random(11),
      );

      // Cụm stressed có 12 mục, bỏ 5 đã xem còn 7 ≥ 5 → không được lặp lại.
      for (final s in picked) {
        expect(seen, isNot(contains(s.code)),
            reason: '${s.code} vừa xem gần đây mà vẫn được gợi ý lại');
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
      final options =
          pickChoiceOptions(practice: null, pool: pool, random: Random(2));
      expect(options, hasLength(4));
      for (final o in options) {
        expect(pool, contains(o));
      }
    });

    test('Practice rỗng hoặc toàn khoảng trắng coi như không có', () {
      for (final blank in ['', '   ', '\n']) {
        final options =
            pickChoiceOptions(practice: blank, pool: pool, random: Random(2));
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
        expect(options.toSet(), hasLength(options.length),
            reason: 'seed $seed sinh ra lựa chọn trùng');
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

    test('không trùng mã thì lấy story cùng chiều', () {
      final sit = _sit('C2-sit-03', ScaDimension.c2);
      final stories = [
        _story('A1-01', ScaDimension.a1),
        _story('C2-01', ScaDimension.c2),
        _story('C2-02', ScaDimension.c2),
      ];
      final found = resolveStoryFor(sit, stories);
      expect(found, isNotNull);
      expect(found!.scaDimension, ScaDimension.c2);
    });

    test('cùng một chip luôn ra cùng một story', () {
      // Nếu bốc ngẫu nhiên, câu Aha đổi mỗi lần mở màn và người dùng không quay
      // lại được điều mình vừa đọc.
      final sit = _sit('A3-sit-05', ScaDimension.a3);
      final stories = [
        for (var i = 1; i <= 10; i++)
          _story('A3-${i.toString().padLeft(2, '0')}', ScaDimension.a3),
      ];
      final first = resolveStoryFor(sit, stories)!.storyId;
      for (var i = 0; i < 20; i++) {
        expect(resolveStoryFor(sit, stories)!.storyId, first);
      }
    });

    test('thứ tự danh sách đầu vào không làm đổi kết quả', () {
      final sit = _sit('A3-sit-05', ScaDimension.a3);
      final stories = [
        for (var i = 1; i <= 6; i++)
          _story('A3-${i.toString().padLeft(2, '0')}', ScaDimension.a3),
      ];
      final normal = resolveStoryFor(sit, stories)!.storyId;
      final reversed = resolveStoryFor(sit, stories.reversed.toList())!.storyId;
      expect(reversed, normal);
    });

    test('hai chip khác nhau cùng chiều không nhất thiết trùng story', () {
      final stories = [
        for (var i = 1; i <= 10; i++)
          _story('C1-${i.toString().padLeft(2, '0')}', ScaDimension.c1),
      ];
      final ids = {
        for (var i = 1; i <= 6; i++)
          resolveStoryFor(
            _sit('C1-sit-0$i', ScaDimension.c1),
            stories,
          )!.storyId,
      };
      // Không đòi phân biệt hoàn toàn (hash có thể đụng), nhưng gom hết 6 chip
      // vào đúng 1 story thì coi như hàm nối hỏng.
      expect(ids.length, greaterThan(1));
    });

    test('không có story cùng chiều thì trả null, không bịa', () {
      final sit = _sit('S3-sit-01', ScaDimension.s3);
      final stories = [_story('A1-01', ScaDimension.a1)];
      expect(resolveStoryFor(sit, stories), isNull);
    });

    test('thư viện story rỗng thì trả null', () {
      expect(resolveStoryFor(_sit('C1-sit-01', ScaDimension.c1), const []),
          isNull);
    });
  });
}
