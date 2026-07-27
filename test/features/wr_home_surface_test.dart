// Màn Hôm nay dựng từ dữ liệu thật — không có chuỗi minh hoạ nào cứng trong mã.
//   • "Hệ thống nhận ra" đọc lại số lần lặp thật của người dùng
//   • "Gợi ý khi …" chọn story theo trụ SCA / nhu cầu đang nổi
//   • "Insight gần nhất" là câu người dùng đã xác nhận
// Run: flutter test test/features/wr_home_surface_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_home_surface.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

WrSituation _sit(
  String code,
  String text, {
  ScaDimension dim = ScaDimension.c1,
  HumanNeed? need,
}) =>
    WrSituation(
      code: code,
      text: text,
      scaDimension: dim,
      wave: 1,
      humanNeed: need,
    );

PatternCount _pattern(String code, int count) => PatternCount(
      userId: 'u1',
      situationCode: code,
      occurrenceCount: count,
      lastSeenAt: DateTime(2026, 7, 20),
    );

WrStory _story(
  String id,
  String title, {
  ScaDimension dim = ScaDimension.c1,
  HumanNeed? need,
  String content = 'một hai ba bốn năm',
}) =>
    WrStory(
      storyId: id,
      title: title,
      scaDimension: dim,
      humanNeed: need,
      storyContent: content,
      emotionTags: const [],
      behaviorTags: const [],
      careerStages: const [],
    );

CareerMemoryEvent _readEvent(String storyId) => CareerMemoryEvent(
      id: 'e-$storyId',
      userId: 'u1',
      storyId: storyId,
      createdAt: DateTime(2026, 7, 21),
    );

Widget _wrap({
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
      GoRoute(
        path: '/wr/pattern/:code',
        builder: (_, s) =>
            Scaffold(body: Text('PATTERN ${s.pathParameters['code']}')),
      ),
      GoRoute(
        path: '/wr/story',
        builder: (_, __) => const Scaffold(body: Text('STORY')),
      ),
      GoRoute(
        path: '/wr/flow/moment',
        builder: (_, __) => const Scaffold(body: Text('MOMENT')),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider
          .overrideWithValue(content ?? FakeWrContentRepository()),
      wrIntelligenceRepositoryProvider
          .overrideWithValue(intel ?? FakeWrIntelligenceRepository()),
      wrRepositoryProvider.overrideWithValue(FakeWrRepository()),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // Logic thuần
  // -------------------------------------------------------------------------

  group('systemNotice', () {
    final situations = [_sit('s1', 'Ngại phản biện với đồng nghiệp')];

    test('chưa lặp lại thì hệ thống chưa nhận ra gì', () {
      expect(
        systemNotice(patterns: [_pattern('s1', 1)], situations: situations),
        isNull,
      );
    });

    test('đủ ngưỡng thì đọc lại đúng con số', () {
      final n = systemNotice(
        patterns: [_pattern('s1', 5)],
        situations: situations,
      );
      expect(n, isNotNull);
      expect(n!.count, 5);
      expect(
        n.sentence,
        'Đây là lần thứ 5 bạn gặp tình huống '
        'ngại phản biện với đồng nghiệp.',
      );
    });

    test('chọn tình huống lặp nhiều nhất', () {
      final n = systemNotice(
        patterns: [_pattern('s1', 3), _pattern('s2', 7)],
        situations: [...situations, _sit('s2', 'Bị giao việc gấp')],
      );
      expect(n!.situationCode, 's2');
      expect(n.count, 7);
    });
  });

  group('readingMinutes', () {
    test('tối thiểu một phút', () {
      expect(readingMinutes('ngắn'), 1);
    });

    test('ước lượng theo số từ thật', () {
      final content = List.filled(kWordsPerMinute * 3, 'từ').join(' ');
      expect(readingMinutes(content), 3);
    });
  });

  group('suggestStory', () {
    test('không có story thì không gợi ý', () {
      expect(
        suggestStory(
          stories: const [],
          patterns: const [],
          situations: const [],
          events: const [],
        ),
        isNull,
      );
    });

    test('ưu tiên story cùng trụ với tình huống đang lặp', () {
      final s = suggestStory(
        stories: [
          _story('st-a', 'Khác trụ', dim: ScaDimension.s1),
          _story('st-b', 'Cùng trụ', dim: ScaDimension.a2),
        ],
        patterns: [_pattern('s1', 4)],
        situations: [_sit('s1', 'Tình huống', dim: ScaDimension.a2)],
        events: const [],
      );
      expect(s!.story.storyId, 'st-b');
      expect(s.alreadyRead, isFalse);
    });

    test('bỏ qua story đã đọc', () {
      final s = suggestStory(
        stories: [
          _story('st-a', 'Đã đọc', dim: ScaDimension.a2),
          _story('st-b', 'Chưa đọc', dim: ScaDimension.a2),
        ],
        patterns: [_pattern('s1', 4)],
        situations: [_sit('s1', 'Tình huống', dim: ScaDimension.a2)],
        events: [_readEvent('st-a')],
      );
      expect(s!.story.storyId, 'st-b');
    });

    test('đọc hết rồi thì vẫn gợi lại, kèm dấu đã đọc', () {
      final s = suggestStory(
        stories: [_story('st-a', 'Đã đọc')],
        patterns: const [],
        situations: const [],
        events: [_readEvent('st-a')],
      );
      expect(s!.story.storyId, 'st-a');
      expect(s.alreadyRead, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Màn Hôm nay
  // -------------------------------------------------------------------------

  group('Home — bố cục theo giao diện chính', () {
    testWidgets('chưa có dữ liệu thì ba khối dưới im lặng', (tester) async {
      await _pump(tester, _wrap());

      expect(find.text('Bạn đang trải qua điều gì?'), findsOneWidget);
      expect(find.byKey(const Key('wr_home_system_notice')), findsNothing);
      expect(find.byKey(const Key('wr_home_story_suggestion')), findsNothing);
      expect(find.byKey(const Key('wr_home_latest_insight')), findsNothing);
    });

    testWidgets('Hệ thống nhận ra hiện đúng câu từ dữ liệu thật',
        (tester) async {
      final content = FakeWrContentRepository()
        ..seedSituations([_sit('s1', 'Ngại phản biện với đồng nghiệp')]);
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern('s1', 5)]);

      await _pump(tester, _wrap(content: content, intel: intel));

      expect(find.byKey(const Key('wr_home_system_notice')), findsOneWidget);
      expect(find.text('HỆ THỐNG NHẬN RA'), findsOneWidget);
      expect(
        find.textContaining('lần thứ 5 bạn gặp tình huống'),
        findsOneWidget,
      );
    });

    testWidgets('Tìm hiểu thêm mở đúng màn chi tiết của tình huống đó',
        (tester) async {
      final content = FakeWrContentRepository()
        ..seedSituations([_sit('s1', 'Ngại phản biện')]);
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern('s1', 4)]);

      await _pump(tester, _wrap(content: content, intel: intel));
      await tester.tap(find.byKey(const Key('wr_home_notice_link')));
      await tester.pumpAndSettle();

      expect(find.text('PATTERN s1'), findsOneWidget);
    });

    testWidgets('khối gợi ý lấy story thật kèm thời lượng ước lượng',
        (tester) async {
      final content = FakeWrContentRepository()
        ..seedStories([
          _story(
            'st-a',
            'Khi bạn muốn nói nhưng chọn im lặng',
            need: HumanNeed.ketNoi,
            content: List.filled(kWordsPerMinute * 5, 'từ').join(' '),
          ),
        ]);

      await _pump(tester, _wrap(content: content));

      expect(find.byKey(const Key('wr_home_story_suggestion')), findsOneWidget);
      expect(
        find.text('Khi bạn muốn nói nhưng chọn im lặng'),
        findsOneWidget,
      );
      expect(find.text('KẾT NỐI · 5 phút đọc'), findsOneWidget);
      expect(find.text('Chưa đọc'), findsOneWidget);
    });

    testWidgets('Insight gần nhất hiện câu và ngày lưu thật', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedInsights([
          WrInsight(
            userId: 'u1',
            content: 'Tôi thường im lặng vì sợ phán xét.',
            createdAt: DateTime(2026, 6, 20),
          ),
        ]);

      await _pump(tester, _wrap(intel: intel));

      expect(find.byKey(const Key('wr_home_latest_insight')), findsOneWidget);
      expect(
        find.text('"Tôi thường im lặng vì sợ phán xét."'),
        findsOneWidget,
      );
      expect(find.text('Lưu ngày 20/06'), findsOneWidget);
    });
  });
}
