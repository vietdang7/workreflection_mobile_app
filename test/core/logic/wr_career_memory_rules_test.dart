// Quy tắc sinh mảnh ký ức — changelog 24/08/2026 §8.2 và §9.
//
// Run: flutter test test/core/logic/wr_career_memory_rules_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_career_memory_rules.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

final _now = DateTime(2026, 8, 25, 9);

ReflectionEpisode _story({
  required String id,
  required HumanNeed? need,
  required DateTime at,
  String? code,
  ScaDimension? dim,
  ExperienceState state = ExperienceState.integrated,
}) =>
    ReflectionEpisode(
      id: id,
      userId: 'u1',
      humanMoment: HumanMoment.confusion,
      state: state,
      humanNeed: need,
      scaDimension: dim,
      situationCode: code,
      openedAt: at,
      closedAt: at,
    );

CareerMemoryEvent _event({
  required String behavior,
  HumanNeed? need,
  DateTime? at,
}) =>
    CareerMemoryEvent(
      id: 'e',
      userId: 'u1',
      behavior: behavior,
      humanNeed: need,
      createdAt: at,
    );

const _labels = {
  'C2-01': 'Không dám nói ý kiến',
  'C2-02': 'Góp ý bị bỏ qua',
  'C2-03': 'Nói xong không ai phản hồi',
};

void main() {
  group('§8.2 · STORY là đơn vị gốc', () {
    test('chỉ Episode đã khép mới tính là STORY', () {
      final list = closedStories([
        _story(id: '1', need: HumanNeed.ketNoi, at: _now),
        _story(
          id: '2',
          need: HumanNeed.ketNoi,
          at: _now,
          state: ExperienceState.exploring,
        ),
      ]);
      expect(list.map((e) => e.id), ['1']);
    });

    test('mới nhất đứng đầu', () {
      final list = closedStories([
        _story(id: 'cũ', need: null, at: _now.subtract(const Duration(days: 5))),
        _story(id: 'mới', need: null, at: _now),
      ]);
      expect(list.map((e) => e.id), ['mới', 'cũ']);
    });
  });

  group('§8.2 · Cột mốc là cờ trên STORY, không phải bản ghi riêng', () {
    test('lượt đầu tiên của cả hành trình là một cột mốc', () {
      final s = _story(id: '1', need: HumanNeed.ketNoi, at: _now);
      final text = milestoneTextForStory(story: s, previousStories: const []);
      expect(text, isNotNull);
      expect(text, contains('Lần đầu'));
    });

    test('lần đầu chạm một nhóm nhu cầu mới cũng là cột mốc', () {
      final s = _story(id: '2', need: HumanNeed.phatTrien, at: _now);
      final text = milestoneTextForStory(
        story: s,
        previousStories: [
          _story(id: '1', need: HumanNeed.ketNoi, at: _now),
        ],
      );
      expect(text, contains('sự phát triển'));
    });

    test('nhóm đã gặp rồi thì không còn là cột mốc', () {
      final s = _story(id: '3', need: HumanNeed.ketNoi, at: _now);
      expect(
        milestoneTextForStory(
          story: s,
          previousStories: [
            _story(id: '1', need: HumanNeed.ketNoi, at: _now),
            _story(id: '2', need: HumanNeed.roRang, at: _now),
          ],
        ),
        isNull,
      );
    });

    test('lượt sau mà không có nhu cầu thì không phải cột mốc', () {
      final s = _story(id: '2', need: null, at: _now);
      expect(
        milestoneTextForStory(
          story: s,
          previousStories: [_story(id: '1', need: null, at: _now)],
        ),
        isNull,
      );
    });

    test('gắn cờ theo đúng chiều thời gian, không theo thứ tự danh sách', () {
      // closedStories trả về mới-trước; luật "lần đầu" phải xét cũ-trước.
      final stories = closedStories([
        _story(
            id: 'cũ',
            need: HumanNeed.ketNoi,
            at: _now.subtract(const Duration(days: 5))),
        _story(id: 'mới', need: HumanNeed.ketNoi, at: _now),
      ]);
      final flags = milestonesByStoryId(stories);
      expect(flags.keys, ['cũ']);
    });

    test('mỗi nhóm nhu cầu chỉ có đúng một cột mốc', () {
      final stories = closedStories([
        for (var i = 0; i < 4; i++)
          _story(
            id: 's$i',
            need: i.isEven ? HumanNeed.ketNoi : HumanNeed.roRang,
            at: _now.subtract(Duration(days: 10 - i)),
          ),
      ]);
      final flags = milestonesByStoryId(stories);
      expect(flags.keys.toSet(), {'s0', 's1'});
    });
  });

  group('§8.2 · Chủ đề — 3 lần trong 14 ngày', () {
    List<ReflectionEpisode> threeIn14() => [
          for (var i = 0; i < 3; i++)
            _story(
              id: 's$i',
              need: HumanNeed.ketNoi,
              at: _now.subtract(Duration(days: i * 4)),
            ),
        ];

    test('đủ ba lần trong cửa sổ thì sinh chủ đề', () {
      final stories = threeIn14();
      final theme = themeForStory(
        story: stories.first,
        stories: stories,
        existingThemeNeeds: const {},
        now: _now,
      );
      expect(theme, isNotNull);
      expect(theme!.behavior, kThemeBehavior);
      expect(theme.need, HumanNeed.ketNoi);
      expect(theme.text, contains('sự kết nối'));
      expect(theme.text, contains('3'));
    });

    test('hai lần thì chưa', () {
      final stories = threeIn14().take(2).toList();
      expect(
        themeForStory(
          story: stories.first,
          stories: stories,
          existingThemeNeeds: const {},
          now: _now,
        ),
        isNull,
      );
    });

    test('ba lần nhưng trải quá 14 ngày thì chưa', () {
      final stories = [
        _story(id: 'a', need: HumanNeed.ketNoi, at: _now),
        _story(
            id: 'b',
            need: HumanNeed.ketNoi,
            at: _now.subtract(const Duration(days: 20))),
        _story(
            id: 'c',
            need: HumanNeed.ketNoi,
            at: _now.subtract(const Duration(days: 30))),
      ];
      expect(
        themeForStory(
          story: stories.first,
          stories: stories,
          existingThemeNeeds: const {},
          now: _now,
        ),
        isNull,
      );
    });

    // Không chặn thì mỗi lượt mới lại đẻ thêm một dòng "chủ đề vừa nổi lên"
    // giống hệt dòng trước.
    test('nhóm đã có chủ đề rồi thì không sinh trùng', () {
      final stories = threeIn14();
      expect(
        themeForStory(
          story: stories.first,
          stories: stories,
          existingThemeNeeds: const {HumanNeed.ketNoi},
          now: _now,
        ),
        isNull,
      );
    });

    test('lượt không có nhu cầu thì không sinh chủ đề', () {
      final s = _story(id: 'x', need: null, at: _now);
      expect(
        themeForStory(
          story: s,
          stories: [s],
          existingThemeNeeds: const {},
          now: _now,
        ),
        isNull,
      );
    });

    test('needCountWithin chỉ đếm đúng nhóm và đúng cửa sổ', () {
      final stories = [
        _story(id: 'a', need: HumanNeed.ketNoi, at: _now),
        _story(id: 'b', need: HumanNeed.roRang, at: _now),
        _story(
            id: 'c',
            need: HumanNeed.ketNoi,
            at: _now.subtract(const Duration(days: 40))),
      ];
      expect(needCountWithin(stories, HumanNeed.ketNoi, now: _now), 1);
    });
  });

  group('§9 · Khung "Chuyển biến trong một chủ đề"', () {
    test('lấy STORY đầu và STORY gần nhất trong cùng nhóm', () {
      final stories = closedStories([
        _story(
            id: 'a',
            need: HumanNeed.ketNoi,
            code: 'C2-01',
            at: _now.subtract(const Duration(days: 10))),
        _story(
            id: 'b',
            need: HumanNeed.ketNoi,
            code: 'C2-02',
            at: _now.subtract(const Duration(days: 5))),
        _story(id: 'c', need: HumanNeed.ketNoi, code: 'C2-03', at: _now),
      ]);
      final text = themeProgressNarrative(
        stories: stories,
        need: HumanNeed.ketNoi,
        situationLabels: _labels,
        now: _now,
      );
      expect(text, isNotNull);
      expect(text, contains('Không dám nói ý kiến'));
      expect(text, contains('Nói xong không ai phản hồi'));
      expect(text, contains('sự kết nối'));
    });

    test('chưa đủ ba STORY trong nhóm thì im lặng', () {
      final stories = closedStories([
        _story(id: 'a', need: HumanNeed.ketNoi, code: 'C2-01', at: _now),
      ]);
      expect(
        themeProgressNarrative(
          stories: stories,
          need: HumanNeed.ketNoi,
          situationLabels: _labels,
          now: _now,
        ),
        isNull,
      );
    });

    test('ba lần cùng một tình huống thì không có "chuyển biến" nào để kể', () {
      final stories = closedStories([
        for (var i = 0; i < 3; i++)
          _story(
            id: 's$i',
            need: HumanNeed.ketNoi,
            code: 'C2-01',
            at: _now.subtract(Duration(days: i)),
          ),
      ]);
      expect(
        themeProgressNarrative(
          stories: stories,
          need: HumanNeed.ketNoi,
          situationLabels: _labels,
          now: _now,
        ),
        isNull,
      );
    });
  });

  group('§9 · Khung "Một khoảng lặng đáng chú ý"', () {
    test('nhóm từng là chủ đề mà vắng đủ lâu thì được nói ra', () {
      final stories = closedStories([
        _story(
          id: 'a',
          need: HumanNeed.ketNoi,
          at: _now.subtract(const Duration(days: 30)),
        ),
      ]);
      final text = quietGapNarrative(
        stories: stories,
        pastThemeNeeds: const {HumanNeed.ketNoi},
        now: _now,
      );
      expect(text, isNotNull);
      expect(text, contains('30'));
      expect(text, contains('sự kết nối'));
    });

    test('mới vắng vài ngày thì chưa phải khoảng lặng', () {
      final stories = closedStories([
        _story(
          id: 'a',
          need: HumanNeed.ketNoi,
          at: _now.subtract(const Duration(days: 5)),
        ),
      ]);
      expect(
        quietGapNarrative(
          stories: stories,
          pastThemeNeeds: const {HumanNeed.ketNoi},
          now: _now,
        ),
        isNull,
      );
    });

    test('nhóm chưa từng là chủ đề thì không xét', () {
      final stories = closedStories([
        _story(
          id: 'a',
          need: HumanNeed.roRang,
          at: _now.subtract(const Duration(days: 60)),
        ),
      ]);
      expect(
        quietGapNarrative(
          stories: stories,
          pastThemeNeeds: const {},
          now: _now,
        ),
        isNull,
      );
    });
  });

  group('§8.2 · Insight chạy theo lịch riêng', () {
    List<ReflectionEpisode> five() => [
          for (var i = 0; i < 5; i++)
            _story(
              id: 's$i',
              need: HumanNeed.ketNoi,
              at: _now.subtract(Duration(days: i)),
            ),
        ];

    test('chưa có Insight nào: đủ 5 lượt thì tới kỳ', () {
      expect(
        insightDue(lastInsightAt: null, stories: five(), now: _now),
        isTrue,
      );
      expect(
        insightDue(
          lastInsightAt: null,
          stories: five().take(4).toList(),
          now: _now,
        ),
        isFalse,
      );
    });

    test('đủ 14 ngày kể từ Insight trước là tới kỳ, dù ít lượt', () {
      expect(
        insightDue(
          lastInsightAt: _now.subtract(const Duration(days: 14)),
          stories: [_story(id: 'a', need: null, at: _now)],
          now: _now,
        ),
        isTrue,
      );
    });

    test('chưa đủ 14 ngày và chưa đủ 5 lượt mới thì chưa tới kỳ', () {
      expect(
        insightDue(
          lastInsightAt: _now.subtract(const Duration(days: 3)),
          stories: five().take(2).toList(),
          now: _now,
        ),
        isFalse,
      );
    });

    test('chỉ đếm lượt SAU Insight gần nhất', () {
      final last = _now.subtract(const Duration(days: 2));
      final stories = [
        // Năm lượt cũ, đều trước Insight gần nhất.
        for (var i = 0; i < 5; i++)
          _story(
            id: 'old$i',
            need: HumanNeed.ketNoi,
            at: _now.subtract(Duration(days: 10 + i)),
          ),
        _story(id: 'new', need: HumanNeed.ketNoi, at: _now),
      ];
      expect(
        insightDue(lastInsightAt: last, stories: stories, now: _now),
        isFalse,
      );
    });

    test('tới kỳ nhưng không khung nào nói được gì thì không sinh Insight rỗng',
        () {
      expect(
        periodicInsight(
          stories: five(),
          themeNeeds: const {},
          situationLabels: const {},
          lastInsightAt: null,
          now: _now,
        ),
        isNull,
      );
    });

    test('khung lệch pha được truyền vào thì dùng lại nguyên văn', () {
      final draft = periodicInsight(
        stories: five(),
        themeNeeds: const {},
        situationLabels: const {},
        lastInsightAt: null,
        now: _now,
        selfAwarenessGapText: 'Bạn tự đánh giá phần này đang phát triển, nhưng…',
      );
      expect(draft, isNotNull);
      expect(draft!.behavior, kInsightBehavior);
      expect(draft.text, startsWith('Bạn tự đánh giá'));
    });

    test('chủ đề đang chạy được ưu tiên hơn khung lệch pha', () {
      final stories = closedStories([
        _story(
            id: 'a',
            need: HumanNeed.ketNoi,
            code: 'C2-01',
            at: _now.subtract(const Duration(days: 6))),
        _story(
            id: 'b',
            need: HumanNeed.ketNoi,
            code: 'C2-02',
            at: _now.subtract(const Duration(days: 3))),
        _story(id: 'c', need: HumanNeed.ketNoi, code: 'C2-03', at: _now),
        _story(id: 'd', need: HumanNeed.roRang, at: _now),
        _story(id: 'e', need: HumanNeed.roRang, at: _now),
      ]);
      final draft = periodicInsight(
        stories: stories,
        themeNeeds: const {HumanNeed.ketNoi},
        situationLabels: _labels,
        lastInsightAt: null,
        now: _now,
        selfAwarenessGapText: 'CÂU LỆCH PHA',
      );
      expect(draft!.text, isNot(contains('CÂU LỆCH PHA')));
      expect(draft.text, contains('Không dám nói ý kiến'));
    });
  });

  group('Gộp: chạy sau mỗi STORY mới', () {
    // Đây là chỗ dễ sai nhất: ghi thêm một hàng cho cột mốc thì lượt Reflection
    // đầu tiên của một người hoá thành hai mảnh ký ức.
    test('lượt đầu tiên không ghi thêm mảnh nào', () {
      final s = _story(id: '1', need: HumanNeed.ketNoi, at: _now);
      final drafts = memoryFragmentsAfterStory(
        stories: [s],
        pastEvents: const [],
        situationLabels: _labels,
        now: _now,
      );
      expect(drafts, isEmpty);
    });

    test('lượt thứ ba cùng nhóm sinh thêm chủ đề', () {
      final stories = closedStories([
        for (var i = 0; i < 3; i++)
          _story(
            id: 's$i',
            need: HumanNeed.ketNoi,
            code: 'C2-0${i + 1}',
            at: _now.subtract(Duration(days: i * 2)),
          ),
      ]);
      final drafts = memoryFragmentsAfterStory(
        stories: stories,
        pastEvents: const [],
        situationLabels: _labels,
        now: _now,
      );
      expect(drafts.map((d) => d.behavior), contains(kThemeBehavior));
      // Nhóm đã gặp ở hai lượt trước → không còn cột mốc "lần đầu nhóm".
      expect(drafts.map((d) => d.behavior), isNot(contains(kMilestoneBehavior)));
    });

    test('không sinh trùng khi chủ đề đã được ghi từ lượt trước', () {
      final stories = closedStories([
        for (var i = 0; i < 4; i++)
          _story(
            id: 's$i',
            need: HumanNeed.ketNoi,
            code: 'C2-0${(i % 3) + 1}',
            at: _now.subtract(Duration(days: i)),
          ),
      ]);
      final drafts = memoryFragmentsAfterStory(
        stories: stories,
        pastEvents: [
          _event(
            behavior: kThemeBehavior,
            need: HumanNeed.ketNoi,
            at: _now.subtract(const Duration(days: 1)),
          ),
        ],
        situationLabels: _labels,
        now: _now,
      );
      expect(drafts.map((d) => d.behavior), isNot(contains(kThemeBehavior)));
    });

    test('Insight gần đây thì lượt này không sinh Insight nữa', () {
      final stories = closedStories([
        for (var i = 0; i < 6; i++)
          _story(
            id: 's$i',
            need: HumanNeed.ketNoi,
            code: 'C2-0${(i % 3) + 1}',
            at: _now.subtract(Duration(days: i)),
          ),
      ]);
      final drafts = memoryFragmentsAfterStory(
        stories: stories,
        pastEvents: [
          _event(
            behavior: kThemeBehavior,
            need: HumanNeed.ketNoi,
            at: _now.subtract(const Duration(days: 3)),
          ),
          _event(
            behavior: kInsightBehavior,
            at: _now.subtract(const Duration(days: 1)),
          ),
        ],
        situationLabels: _labels,
        now: _now,
      );
      expect(drafts.map((d) => d.behavior), isNot(contains(kInsightBehavior)));
    });
  });

  group('§9 · biến thể câu chữ', () {
    test('cùng dữ liệu luôn cho cùng một câu', () {
      final stories = closedStories([
        for (var i = 0; i < 3; i++)
          _story(
            id: 's$i',
            need: HumanNeed.ketNoi,
            code: 'C2-0${i + 1}',
            at: _now.subtract(Duration(days: i)),
          ),
      ]);
      String? run() => themeProgressNarrative(
            stories: stories,
            need: HumanNeed.ketNoi,
            situationLabels: _labels,
            now: _now,
          );
      expect(run(), run());
    });

    test('pickVariant xoay vòng và không bao giờ ra ngoài danh sách', () {
      const variants = ['a', 'b'];
      expect(pickVariant(variants, 0), 'a');
      expect(pickVariant(variants, 1), 'b');
      expect(pickVariant(variants, 2), 'a');
      expect(pickVariant(variants, -3), 'b');
    });
  });

  // ── Dòng chi tiết — cột `detail` của mockup v16 ─────────────────────────
  //
  // Tầng chữ thứ ba: VÌ SAO mảnh này có mặt ở đây. Cả ba loại được sinh thêm
  // đều do hệ thống tự gắn, nên không nói ra luật thì người dùng mở Career
  // Memory và thấy những dòng không rõ từ đâu ra.

  group('needCountThisMonth', () {
    test('đếm theo THÁNG LỊCH, không phải cửa sổ 30 ngày', () {
      final target = _story(
        id: 'x',
        need: HumanNeed.ketNoi,
        at: DateTime(2026, 8, 20),
      );
      final stories = [
        target,
        // Cùng nhóm, cùng tháng → tính.
        _story(id: 'a', need: HumanNeed.ketNoi, at: DateTime(2026, 8, 2)),
        // Cùng nhóm nhưng tháng trước → KHÔNG tính, dù chỉ cách 5 ngày.
        _story(id: 'b', need: HumanNeed.ketNoi, at: DateTime(2026, 7, 31)),
        // Khác nhóm → không tính.
        _story(id: 'c', need: HumanNeed.roRang, at: DateTime(2026, 8, 5)),
      ];

      expect(needCountThisMonth(target, stories), 2);
    });

    test('không đếm những lượt xảy ra SAU nó', () {
      // Mảnh ký ức của ngày 3 không được nói "lần thứ 5" nhờ những lượt xảy ra
      // sau đó — người dùng đọc lại dòng thời gian theo chiều thời gian.
      final target = _story(
        id: 'x',
        need: HumanNeed.ketNoi,
        at: DateTime(2026, 8, 3),
      );
      final stories = [
        _story(id: 'sau', need: HumanNeed.ketNoi, at: DateTime(2026, 8, 20)),
        target,
      ];

      expect(needCountThisMonth(target, stories), 1);
    });

    test('không có nhóm thì 0', () {
      final target = _story(id: 'x', need: null, at: DateTime(2026, 8, 3));
      expect(needCountThisMonth(target, [target]), 0);
    });
  });

  group('memoryDetailForStory', () {
    test('cột mốc nói rõ là hệ thống tự gắn, không phải mình tự đánh dấu', () {
      final s = _story(
        id: 'x',
        need: HumanNeed.ketNoi,
        at: DateTime(2026, 8, 20),
      );
      final text = memoryDetailForStory(
        story: s,
        countThisMonth: 1,
        milestoneText: 'Lần đầu tiên bạn dừng lại.',
      );

      expect(text, contains('Lần đầu tiên bạn dừng lại.'));
      expect(text, contains('Cột mốc được gắn tự động'));
    });

    test('nói nhóm nhu cầu, và số lần trong tháng khi đã lặp', () {
      final s = _story(
        id: 'x',
        need: HumanNeed.ketNoi,
        at: DateTime(2026, 8, 20),
      );

      expect(
        memoryDetailForStory(story: s, countThisMonth: 3),
        contains('lần thứ 3 trong tháng'),
      );
    });

    test('lần đầu trong tháng thì KHÔNG nói "lần thứ 1"', () {
      // "Lần thứ 1" không nói lên điều gì, chỉ làm câu dài thêm.
      final s = _story(
        id: 'x',
        need: HumanNeed.ketNoi,
        at: DateTime(2026, 8, 20),
      );

      expect(
        memoryDetailForStory(story: s, countThisMonth: 1),
        isNot(contains('lần thứ')),
      );
    });

    test('không có nhóm và không phải cột mốc thì trả chuỗi rỗng', () {
      // Rỗng chứ không phải một câu chung chung: màn hình bỏ hẳn dòng chi tiết
      // đi còn hơn mở ra một khoảng trống có đường kẻ.
      final s = _story(id: 'x', need: null, at: DateTime(2026, 8, 20));
      expect(memoryDetailForStory(story: s, countThisMonth: 0), '');
    });
  });

  // ── Chủ đề phải quét MỌI nhóm ────────────────────────────────────────────
  //
  // `themeForStory` chỉ hỏi về nhóm của đúng lượt vừa khép — đọc chặt theo §8.2
  // ("dim này đã lặp đủ 3 lần trong 14 ngày chưa?"). Hệ quả đo được trên DB
  // thật: 57 lượt đã khép, 0 dòng `career_theme`.

  group('themesDue', () {
    List<ReflectionEpisode> fourKetNoi() => [
          for (var i = 0; i < 4; i++)
            _story(
              id: 'k$i',
              need: HumanNeed.ketNoi,
              at: _now.subtract(Duration(days: i + 1)),
            ),
        ];

    test('nhóm đủ ngưỡng vẫn ra chủ đề dù lượt mới nhất thuộc nhóm khác', () {
      // Đây là trường hợp bị bỏ sót: bốn lượt về "được lắng nghe" rồi một lượt
      // về "rõ ràng". `themeForStory` chỉ hỏi về "rõ ràng" — chưa đủ ba — nên
      // nhóm thứ nhất không bao giờ được hỏi tới.
      final stories = [
        _story(id: 'moi', need: HumanNeed.roRang, at: _now),
        ...fourKetNoi(),
      ];

      final out = themesDue(
        stories: stories,
        existingThemeNeeds: const {},
        now: _now,
      );

      expect(out, hasLength(1));
      expect(out.single.need, HumanNeed.ketNoi);
      expect(out.single.behavior, kThemeBehavior);
    });

    test('lịch sử có sẵn từ trước cũng sinh được chủ đề', () {
      // Bản 24/08 chỉ chạy tiến, nên người đã nhìn lại hai chục lần trước ngày
      // luật này chạy vẫn thấy Career Memory trống trơn.
      final out = themesDue(
        stories: fourKetNoi(),
        existingThemeNeeds: const {},
        now: _now,
      );

      expect(out.map((d) => d.need), [HumanNeed.ketNoi]);
    });

    test('không sinh trùng nhóm đã có chủ đề', () {
      final out = themesDue(
        stories: fourKetNoi(),
        existingThemeNeeds: const {HumanNeed.ketNoi},
        now: _now,
      );

      expect(out, isEmpty);
    });

    test('một lần gọi không sinh hai chủ đề cho cùng một nhóm', () {
      final out = themesDue(
        stories: [...fourKetNoi(), ...fourKetNoi()],
        existingThemeNeeds: const {},
        now: _now,
      );

      expect(out, hasLength(1));
    });

    test('nhiều nhóm cùng đủ ngưỡng thì ra nhiều chủ đề, thứ tự ổn định', () {
      final stories = [
        ...fourKetNoi(),
        for (var i = 0; i < 3; i++)
          _story(
            id: 'r$i',
            need: HumanNeed.roRang,
            at: _now.subtract(Duration(days: i + 1)),
          ),
      ];

      List<HumanNeed?> run() => themesDue(
            stories: stories,
            existingThemeNeeds: const {},
            now: _now,
          ).map((d) => d.need).toList();

      // Theo thứ tự khai báo enum, không theo thứ tự gặp trong dữ liệu — cùng
      // một lịch sử phải luôn cho ra cùng một thứ tự.
      expect(run(), [HumanNeed.roRang, HumanNeed.ketNoi]);
      expect(run(), run());
    });

    test('KHÔNG hạ ngưỡng: dưới 3 lần trong 14 ngày thì im lặng', () {
      final stories = [
        for (var i = 0; i < 2; i++)
          _story(
            id: 'k$i',
            need: HumanNeed.ketNoi,
            at: _now.subtract(Duration(days: i + 1)),
          ),
      ];

      expect(
        themesDue(stories: stories, existingThemeNeeds: const {}, now: _now),
        isEmpty,
      );
    });

    test('lượt ngoài cửa sổ 14 ngày không được tính vào ngưỡng', () {
      final stories = [
        _story(id: 'a', need: HumanNeed.ketNoi, at: _now),
        _story(id: 'b', need: HumanNeed.ketNoi, at: _now),
        _story(
          id: 'cu',
          need: HumanNeed.ketNoi,
          at: _now.subtract(const Duration(days: 40)),
        ),
      ];

      expect(
        themesDue(stories: stories, existingThemeNeeds: const {}, now: _now),
        isEmpty,
      );
    });
  });

  group('memoryFragmentsAfterStory — sau khi quét mọi nhóm', () {
    test('sinh chủ đề cho nhóm cũ, không phụ thuộc nhóm của lượt vừa khép', () {
      final stories = [
        _story(id: 'moi', need: HumanNeed.roRang, at: _now),
        for (var i = 0; i < 3; i++)
          _story(
            id: 'k$i',
            need: HumanNeed.ketNoi,
            at: _now.subtract(Duration(days: i + 1)),
          ),
      ];

      final drafts = memoryFragmentsAfterStory(
        stories: stories,
        pastEvents: const [],
        situationLabels: const {},
        now: _now,
      );

      expect(
        drafts.where((d) => d.behavior == kThemeBehavior).map((d) => d.need),
        contains(HumanNeed.ketNoi),
      );
    });

    test('khung "Lệch pha tự nhận thức" được dùng khi có câu truyền vào', () {
      // Trước bản này tham số `selfAwarenessGapText` có mặt trong chữ ký nhưng
      // KHÔNG ai truyền, nên một trong bốn khung của §9 chưa bao giờ chạy.
      final stories = [
        for (var i = 0; i < kInsightEveryStories; i++)
          _story(
            id: 's$i',
            need: HumanNeed.thichNghi,
            at: _now.subtract(Duration(days: i + 1)),
          ),
      ];

      final drafts = memoryFragmentsAfterStory(
        stories: stories,
        pastEvents: const [],
        situationLabels: const {},
        now: _now,
        selfAwarenessGapText: 'Bạn tự đánh giá phần này là ổn, nhưng…',
      );

      final insight =
          drafts.where((d) => d.behavior == kInsightBehavior).toList();
      expect(insight, hasLength(1));
      expect(insight.single.text, contains('tự đánh giá'));
    });
  });

  group('câu luật của Chủ đề và Insight', () {
    test('nói đúng ngưỡng đang chạy trong code', () {
      // Ghép từ hằng số chứ không chép tay: đổi ngưỡng mà quên sửa câu chữ là
      // app nói một đằng làm một nẻo.
      expect(kThemeDetail, contains('$kThemeMinCount lần'));
      expect(kThemeDetail, contains('$kThemeWindowDays ngày'));
      expect(kInsightDetail, contains('$kInsightEveryDays ngày'));
      expect(kInsightDetail, contains('$kInsightEveryStories lượt'));
    });

    test('nói rõ Insight tổng hợp từ nhiều lượt, không phải một lượt', () {
      expect(kInsightDetail, contains('không phải từ một'));
    });
  });
}
