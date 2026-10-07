// Tab Hành trình theo mockup v47 (script khách 06/10).
//
// Thứ tự trên tab: hero → Dấu ấn hành trình (4 mốc gần nhất) → Những gì bạn
// đã học → thẻ Trò chuyện → Dòng nhìn lại thời gian. "Góc nhìn phát triển" và
// "Xem trong Hiểu mình" đã bỏ khỏi tab.
//
// Run: flutter test test/features/wr_journey_v47_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_career_memory_rules.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Một thời điểm chắc chắn nằm trong tuần hiện tại (tuần bắt đầu Thứ Hai).
///
/// Lùi một giờ cho khỏi "tương lai", nhưng nếu lùi một giờ mà rơi sang tuần
/// trước (chạy test lúc 0 giờ sáng Thứ Hai) thì dùng chính lúc này.
DateTime _thisWeek() {
  final now = DateTime.now();
  final back = now.subtract(const Duration(hours: 1));
  return back.weekday == DateTime.sunday && now.weekday == DateTime.monday
      ? now
      : back;
}

/// Một thời điểm chắc chắn nằm ở tuần cũ.
DateTime _olderWeek() => DateTime.now().subtract(const Duration(days: 14));

CareerMemoryEvent _event({
  required String id,
  String? behavior,
  String? reflectionText,
  String? themeId,
  DateTime? createdAt,
}) => CareerMemoryEvent(
  id: id,
  userId: 'u1',
  behavior: behavior,
  reflectionText: reflectionText,
  themeId: themeId,
  createdAt: createdAt ?? _thisWeek(),
);

CareerMemoryEvent _learning(String id, String text, {DateTime? at}) => _event(
  id: id,
  behavior: kLearningBehavior,
  reflectionText: text,
  createdAt: at,
);

Widget _wrap({
  List<CareerMemoryEvent> events = const [],
  List<ReflectionEpisode> episodes = const [],
  List<PracticeTheme> themes = const [],
  bool premium = false,
}) {
  final content = FakeWrContentRepository()..seedMemoryEvents(events);
  final episodeRepo = FakeWrEpisodeRepository()..seed(episodes);
  final intel = FakeWrIntelligenceRepository()..seedPracticeThemes(themes);
  if (premium) {
    intel.seedEntitlement(
      WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
    );
  }

  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => const WrJourneyScreen()),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, s) =>
            Scaffold(body: Text('PAYWALL ${s.uri.queryParameters['trigger']}')),
      ),
      GoRoute(
        path: '/wr/career-memory',
        builder: (_, __) => const Scaffold(body: Text('CAREER_MEMORY')),
      ),
      GoRoute(
        path: '/wr/ask',
        builder: (_, __) => const Scaffold(body: Text('ASK')),
      ),
      GoRoute(
        path: '/wr/journey/narrative',
        builder: (_, __) => const Scaffold(body: Text('NARRATIVE')),
      ),
      GoRoute(
        path: '/wr/episode/:id',
        builder: (_, s) =>
            Scaffold(body: Text('EPISODE ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('PROFILE')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(content),
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      wrEpisodeRepositoryProvider.overrideWithValue(episodeRepo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
    ),
  );
}

/// Khung cao để ListView dựng hết cả tab — các bài dưới đây so vị trí và đếm
/// khối, không kiểm cuộn.
Future<void> _pumpTall(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Finder _timeline(int i) => find.byKey(Key('wr_journey_timeline_$i'));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // Bố cục
  // ───────────────────────────────────────────────────────────────────────────

  group('Bố cục v47', () {
    testWidgets('hero → Dấu ấn → Những gì bạn đã học → Trò chuyện → Dòng nhìn '
        'lại thời gian', (tester) async {
      await _pumpTall(
        tester,
        _wrap(events: [_learning('l1', 'Hỏi rõ trước khi nhận việc')]),
      );

      final hero = _top(tester, find.byKey(const Key('wr_journey_hero')));
      final memory = _top(tester, find.text('Dấu ấn hành trình'));
      final learned = _top(tester, find.text('Những gì bạn đã học'));
      final ask = _top(tester, find.byKey(const Key('wr_journey_ask_card')));
      final narrative = _top(
        tester,
        find.byKey(const Key('wr_journey_narrative_card')),
      );

      expect(hero, lessThan(memory));
      expect(memory, lessThan(learned));
      expect(learned, lessThan(ask));
      expect(ask, lessThan(narrative));

      expect(find.text('Hành trình của bạn'), findsOneWidget);
      expect(
        find.text(
          'Nhìn lại những gì đã ở lại, để thấy mình đã thật sự đi qua điều gì.',
        ),
        findsOneWidget,
      );
      expect(find.text('DÒNG NHÌN LẠI THỜI GIAN'), findsOneWidget);
    });

    for (final premium in const [false, true]) {
      testWidgets(
        '${premium ? 'Premium' : 'Free'}: các khối đã bỏ không còn trên tab',
        (tester) async {
          await _pumpTall(
            tester,
            _wrap(
              premium: premium,
              events: [
                for (var i = 0; i < 6; i++)
                  _event(id: 'e$i', reflectionText: 'Ghi chú $i'),
              ],
            ),
          );

          for (final key in const [
            'wr_journey_growth_opportunity',
            'wr_journey_growth_opportunity_lock',
            'wr_journey_discover_row',
            'wr_journey_memory_breakdown',
            'wr_journey_work_info_row',
            'wr_journey_memory_lock',
          ]) {
            expect(
              find.byKey(Key(key), skipOffstage: false),
              findsNothing,
              reason: '$key đã bỏ theo mockup v47',
            );
          }
          expect(find.text('Xem trong Hiểu mình'), findsNothing);
          expect(find.text('CAREER MEMORY'), findsNothing);
          expect(find.textContaining('Còn 2 ghi nhận nữa'), findsNothing);
        },
      );
    }
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Dấu ấn hành trình
  // ───────────────────────────────────────────────────────────────────────────

  group('Dấu ấn hành trình', () {
    testWidgets('con số đếm MỌI ghi nhận, dòng thời gian chỉ 4 mốc', (
      tester,
    ) async {
      final base = _thisWeek();
      await _pumpTall(
        tester,
        _wrap(
          events: [
            for (var i = 0; i < 6; i++)
              _event(
                id: 'e$i',
                reflectionText: 'Ghi chú $i',
                createdAt: base.subtract(Duration(minutes: i)),
              ),
          ],
        ),
      );

      expect(
        tester
            .widget<Text>(find.byKey(const Key('wr_journey_memory_count')))
            .data,
        '6 ghi nhận đã lưu',
      );
      for (var i = 0; i < kJourneyPreviewCount; i++) {
        expect(_timeline(i), findsOneWidget);
      }
      expect(_timeline(kJourneyPreviewCount), findsNothing);
      // Mới nhất trước.
      expect(
        find.descendant(of: _timeline(0), matching: find.text('Ghi chú 0')),
        findsOneWidget,
      );
      expect(find.text('Ghi chú 5'), findsNothing);
      expect(
        find.byKey(const Key('wr_journey_memory_see_all')),
        findsOneWidget,
      );
    });

    testWidgets('chưa có gì: thẻ trống, không có nút xem toàn bộ', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap());

      expect(find.text('0 ghi nhận đã lưu'), findsOneWidget);
      expect(find.byKey(const Key('wr_journey_memory_empty')), findsOneWidget);
      expect(
        find.textContaining('Nhật ký sự nghiệp của bạn chưa có ghi nhận nào'),
        findsOneWidget,
      );
      expect(_timeline(0), findsNothing);
      expect(find.byKey(const Key('wr_journey_memory_see_all')), findsNothing);
    });

    testWidgets('nút "Xem toàn bộ lịch sử" mở màn Career Memory đầy đủ', (
      tester,
    ) async {
      await _pumpTall(
        tester,
        _wrap(
          events: [_event(id: 'e1', reflectionText: 'Một')],
        ),
      );

      expect(find.text('Xem toàn bộ lịch sử'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('wr_journey_memory_see_all')));
      expect(find.text('CAREER_MEMORY'), findsOneWidget);
    });

    testWidgets('mốc Episode mở ra có lối đọc lại lần nhìn lại đó', (
      tester,
    ) async {
      await _pumpTall(
        tester,
        _wrap(
          episodes: [
            ReflectionEpisode(
              id: 'ep-1',
              userId: 'u1',
              humanMoment: HumanMoment.confusion,
              state: ExperienceState.integrated,
              draftMeaning: 'Mình cần hỏi rõ hơn.',
              openedAt: _thisWeek(),
              closedAt: _thisWeek(),
            ),
          ],
        ),
      );

      expect(find.text('Đọc lại lần nhìn lại này'), findsNothing);
      await _tap(tester, _timeline(0));
      expect(find.text('“Mình cần hỏi rõ hơn.”'), findsOneWidget);

      await _tap(tester, find.text('Đọc lại lần nhìn lại này'));
      expect(find.text('EPISODE ep-1'), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Những gì bạn đã học + nội dung các loại mốc mới
  // ───────────────────────────────────────────────────────────────────────────

  group('Những gì bạn đã học', () {
    testWidgets('Cột mốc lần đầu thử: tên chủ đề lấy từ thư viện chủ đề', (
      tester,
    ) async {
      await _pumpTall(
        tester,
        _wrap(
          themes: const [
            PracticeTheme(themeId: 'pt-x', title: 'Dám lên tiếng'),
          ],
          events: [
            _event(
              id: 'm1',
              behavior: kMilestoneBehavior,
              themeId: 'pt-x',
              // Tên đóng băng lúc ghi — phải nhường cho tên trong thư viện.
              reflectionText: 'Tên cũ đã đóng băng',
            ),
          ],
        ),
      );

      const title = 'Lần đầu thử một cách khác: Dám lên tiếng';
      // Một ở dòng thời gian, một ở "Những gì bạn đã học".
      expect(find.text(title), findsNWidgets(2));
      expect(
        find.descendant(of: _timeline(0), matching: find.text(title)),
        findsOneWidget,
      );
      expect(find.text('CỘT MỐC'), findsNWidgets(2));
      expect(find.textContaining('Tên cũ đã đóng băng'), findsNothing);
      // Thẻ học hiện đoạn trích luôn; dòng thời gian thì chưa.
      expect(
        find.text('Bạn đã thử bước đầu tiên của chủ đề này.'),
        findsOneWidget,
      );
      expect(
        find.text('“Bạn đã thử bước đầu tiên của chủ đề này.”'),
        findsNothing,
      );
      expect(find.byKey(const Key('wr_journey_learned_empty')), findsNothing);
    });

    testWidgets('bài học vừa ghi: tiêu đề cố định + lời người dùng', (
      tester,
    ) async {
      await _pumpTall(
        tester,
        _wrap(events: [_learning('l1', 'Hỏi rõ trước khi nhận việc')]),
      );

      expect(find.text('Bạn vừa học được điều hữu ích'), findsNWidgets(2));
      // Lời người dùng nằm ở thẻ học; ở dòng thời gian nó là đoạn trích ẩn.
      expect(find.text('Hỏi rõ trước khi nhận việc'), findsOneWidget);
      expect(find.text('“Hỏi rõ trước khi nhận việc”'), findsNothing);

      await _tap(tester, _timeline(0));
      expect(find.text('“Hỏi rõ trước khi nhận việc”'), findsOneWidget);
    });

    testWidgets('bước thực hành xong: "Thực hành: ‹việc›" + ĐIỀU ĐÃ THỬ', (
      tester,
    ) async {
      await _pumpTall(
        tester,
        _wrap(
          events: [
            _event(
              id: 'p1',
              behavior: 'practice_step_done',
              reflectionText:
                  'Dám lên tiếng · Nhận diện: Quan sát lúc muốn im lặng',
            ),
          ],
        ),
      );

      expect(
        find.text('Thực hành: Quan sát lúc muốn im lặng'),
        findsNWidgets(2),
      );
      expect(find.text('ĐIỀU ĐÃ THỬ'), findsOneWidget);
      // Nhãn loại trên dòng thời gian vẫn là THỰC HÀNH.
      expect(
        find.descendant(of: _timeline(0), matching: find.text('THỰC HÀNH')),
        findsOneWidget,
      );
      expect(
        find.text('Bạn đã thử: Quan sát lúc muốn im lặng.'),
        findsOneWidget,
      );
      // Nhãn giai đoạn "Nhận diện:" không lọt vào câu.
      expect(find.textContaining('Nhận diện:'), findsNothing);
    });

    testWidgets('nhiều nhất 3 thẻ, lấy 3 điều mới nhất', (tester) async {
      final base = _thisWeek();
      await _pumpTall(
        tester,
        _wrap(
          events: [
            for (var i = 0; i < 5; i++)
              _learning(
                'l$i',
                'Bài học $i',
                at: base.subtract(Duration(minutes: i)),
              ),
          ],
        ),
      );

      // Lời người dùng chỉ hiện ở thẻ học (dòng thời gian ẩn đoạn trích).
      expect(find.text('Bài học 0'), findsOneWidget);
      expect(find.text('Bài học 1'), findsOneWidget);
      expect(find.text('Bài học 2'), findsOneWidget);
      expect(find.text('Bài học 3'), findsNothing);
      expect(find.text('Bài học 4'), findsNothing);
      // 4 mốc trên dòng thời gian + 3 thẻ học.
      expect(find.text('Bạn vừa học được điều hữu ích'), findsNWidgets(7));
    });

    testWidgets('chưa có điều gì đã học: thẻ trống', (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          events: [_event(id: 'e1', reflectionText: 'Chỉ là ghi chú')],
        ),
      );

      expect(find.byKey(const Key('wr_journey_learned_empty')), findsOneWidget);
      expect(
        find.text(
          'Những điều bạn học được sẽ xuất hiện ở đây sau khi chúng thực sự '
          'xảy ra.',
        ),
        findsOneWidget,
      );
      expect(find.text('ĐIỀU ĐÃ THỬ'), findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Khoá theo tuần cho bản miễn phí
  // ───────────────────────────────────────────────────────────────────────────

  group('Free khoá mốc ngoài tuần này', () {
    List<CareerMemoryEvent> events() => [
      _learning('new', 'Bài học tuần này', at: _thisWeek()),
      _learning('old', 'Bài học tuần cũ', at: _olderWeek()),
    ];

    testWidgets('mốc tuần cũ khoá ở cả dòng thời gian lẫn thẻ học', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap(events: events()));

      // Mới trước: mốc 0 là tuần này, mốc 1 là tuần cũ.
      expect(
        find.descendant(of: _timeline(0), matching: find.text('Chạm để xem')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _timeline(1),
          matching: find.text('Premium · Mở khoá'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _timeline(1),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
      // Một ở dòng thời gian, một ở thẻ học của mốc tuần cũ.
      expect(find.text('Premium · Mở khoá'), findsNWidgets(2));
      // Lời người dùng tuần cũ không lọt ra đâu cả.
      expect(find.textContaining('Bài học tuần cũ'), findsNothing);
      // Tuần này thì đọc được.
      expect(find.text('Bài học tuần này'), findsOneWidget);

      await _tap(tester, _timeline(0));
      expect(find.text('“Bài học tuần này”'), findsOneWidget);
      expect(find.textContaining('Bài học tuần cũ'), findsNothing);
    });

    testWidgets('mốc tuần cũ giấu luôn tiêu đề, vì tiêu đề có thể là lời người '
        'dùng', (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          events: [
            _event(
              id: 'd1',
              behavior: 'decision',
              reflectionText: 'Tôi quyết định rời đi',
              createdAt: _olderWeek(),
            ),
          ],
        ),
      );

      expect(find.textContaining('Tôi quyết định rời đi'), findsNothing);
      expect(
        find.descendant(
          of: _timeline(0),
          matching: find.text('Nội dung đã khoá'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('chạm mốc khoá trên dòng thời gian mở paywall career_memory', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap(events: events()));

      await _tap(tester, _timeline(1));
      expect(find.text('PAYWALL career_memory'), findsOneWidget);
      expect(find.textContaining('Bài học tuần cũ'), findsNothing);
    });

    testWidgets('chạm "Premium · Mở khoá" ở thẻ học mở paywall career_memory', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap(events: events()));

      // Thẻ học nằm dưới dòng thời gian → cái cuối là của thẻ học.
      await _tap(tester, find.text('Premium · Mở khoá').last);
      expect(find.text('PAYWALL career_memory'), findsOneWidget);
    });

    testWidgets('Premium: mốc tuần cũ mở ra bình thường', (tester) async {
      await _pumpTall(tester, _wrap(events: events(), premium: true));

      expect(find.text('Premium · Mở khoá'), findsNothing);
      expect(find.text('Bài học tuần cũ'), findsOneWidget);

      await _tap(tester, _timeline(1));
      expect(find.text('“Bài học tuần cũ”'), findsOneWidget);
      expect(find.textContaining('PAYWALL'), findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Thẻ Trò chuyện + Dòng nhìn lại thời gian
  // ───────────────────────────────────────────────────────────────────────────

  group('Trò chuyện và Dòng nhìn lại thời gian', () {
    testWidgets('thẻ Trò chuyện mở trợ lý chat', (tester) async {
      await _pumpTall(tester, _wrap());

      expect(find.text('Trò chuyện về hành trình của bạn'), findsOneWidget);
      expect(find.text('Bắt đầu trò chuyện'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('wr_journey_ask_row')));
      expect(find.text('ASK'), findsOneWidget);
    });

    testWidgets('Free: khối khoá, nút mở paywall ai_insight', (tester) async {
      await _pumpTall(tester, _wrap());

      expect(
        find.byKey(const Key('wr_journey_narrative_lock')),
        findsOneWidget,
      );
      expect(find.text('PHÂN TÍCH BỊ KHÓA'), findsOneWidget);
      expect(
        find.text(
          'Mở khóa bản đầy đủ để nhìn lại toàn bộ bức tranh thay đổi của bạn '
          'qua từng giai đoạn.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_journey_narrative_expand')),
        findsNothing,
      );

      await _tap(tester, find.byKey(const Key('wr_journey_narrative_row')));
      expect(find.text('PAYWALL ai_insight'), findsOneWidget);
    });

    testWidgets('Premium: dòng dẫn mở màn Diễn biến riêng', (tester) async {
      await _pumpTall(tester, _wrap(premium: true));

      expect(find.byKey(const Key('wr_journey_narrative_lock')), findsNothing);
      expect(find.text('Đọc toàn bộ diễn biến'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('wr_journey_narrative_row')));
      expect(find.text('NARRATIVE'), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Luật thuần
  // ───────────────────────────────────────────────────────────────────────────

  group('buildJourneyEntries / groupJourneyByWeekAndDay', () {
    test(
      'Cột mốc không tra được tên chủ đề thì không để dấu hai chấm treo',
      () {
        final entries = buildJourneyEntries(
          episodes: const [],
          events: [
            _event(id: 'm1', behavior: kMilestoneBehavior, themeId: 'pt-gone'),
          ],
          situationLabels: const {},
        );
        expect(entries.single.title, 'Lần đầu thử một cách khác');
      },
    );

    test('mốc giờ UTC được xếp theo ngày giờ máy', () {
      // Supabase trả `created_at` dạng UTC. 22:00 UTC Chủ Nhật là sáng Thứ
      // Hai ở Việt Nam: phải gom theo ngày giờ máy, như nhãn ngày đang hiện.
      final utc = DateTime.utc(2026, 10, 4, 22);
      JourneyEntry entry(DateTime at) => JourneyEntry(
        at: at,
        label: 'X',
        title: 'T',
        color: const Color(0xFF000000),
      );
      final now = DateTime(2026, 10, 20);
      final fromUtc = groupJourneyByWeekAndDay([entry(utc)], now: now);
      final fromLocal = groupJourneyByWeekAndDay([
        entry(utc.toLocal()),
      ], now: now);
      expect(fromUtc.single.label, fromLocal.single.label);
      expect(
        fromUtc.single.weeks.single.label,
        fromLocal.single.weeks.single.label,
      );
      expect(
        fromUtc.single.weeks.single.days.single.label,
        fromLocal.single.weeks.single.days.single.label,
      );
    });
  });
}
