// Tab Hiểu — các màn tầng trong đối chiếu script Sprint 2 (13/10/2026):
// Diễn giải trải nghiệm, Chặng, Danh sách lặp lại.
//
// Run: flutter test test/features/wr_understand_parity_test.dart

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
import 'package:workreflection_mobile/features/wr/presentation/wr_chapter_read_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_experience_interpret_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_patterns_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

const _situations = <WrSituation>[
  WrSituation(
    code: 'S1-01',
    text: 'Vai trò chưa rõ',
    scaDimension: ScaDimension.s1,
    wave: 1,
    pillarCode: 'S',
    subgroup: 'S1',
    mood: 'foggy',
    valence: WrValence.thachThuc,
  ),
  WrSituation(
    code: 'C2-01',
    text: 'Không dám nói',
    scaDimension: ScaDimension.c2,
    wave: 1,
    pillarCode: 'C',
    subgroup: 'C2',
    mood: 'stress',
    valence: WrValence.thachThuc,
  ),
];

ReflectionEpisode _ep(String code, DateTime at, {String? note}) =>
    ReflectionEpisode(
      userId: 'u1',
      humanMoment: HumanMoment.confusion,
      situationCode: code,
      openedAt: at,
      notes: {if (note != null) ReflectionPattern.explore.dbValue: note},
    );

ScaSelfCheckResponse _check(DateTime at, {double s = 3, double c = 3}) =>
    ScaSelfCheckResponse(
      userId: 'u1',
      answers: {for (var i = 1; i <= 15; i++) 'scq-$i': 3},
      takenAt: at,
      structureScore: s,
      cultureScore: c,
      activityScore: 3,
    );

class _Harness {
  _Harness({
    required bool premium,
    List<ReflectionEpisode> episodes = const [],
    List<ScaSelfCheckResponse> history = const [],
  }) : intel = FakeWrIntelligenceRepository()
         ..seedSelfCheckHistory(history)
         ..seedEntitlement(
           WrEntitlementRecord(
             userId: 'u1',
             plan: premium ? WrPlan.premium : WrPlan.free,
             validUntil: DateTime.now().add(const Duration(days: 30)),
           ),
         ),
       content = FakeWrContentRepository()..seedSituations(_situations),
       eps = FakeWrEpisodeRepository()..seed(episodes);

  final FakeWrIntelligenceRepository intel;
  final FakeWrContentRepository content;
  final FakeWrEpisodeRepository eps;

  Widget app(String initial) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/wr/experience-interpret',
          builder: (_, s) => WrExperienceInterpretScreen(
            initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: '/wr/chapter/:id',
          builder: (_, s) =>
              WrChapterReadScreen(chapterId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/wr/patterns',
          builder: (_, __) => const WrPatternsScreen(),
        ),
        GoRoute(
          path: '/wr/paywall',
          builder: (_, __) => const Scaffold(body: Text('PAYWALL')),
        ),
        GoRoute(
          path: '/wr/self-check',
          builder: (_, __) => const Scaffold(body: Text('SELF-CHECK')),
        ),
        GoRoute(
          path: '/wr/sca-deep-dive',
          builder: (_, __) => const Scaffold(body: Text('DEEP DIVE')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        wrIntelligenceRepositoryProvider.overrideWithValue(intel),
        wrContentRepositoryProvider.overrideWithValue(content),
        wrEpisodeRepositoryProvider.overrideWithValue(eps),
        currentUserIdProvider.overrideWithValue('u1'),
      ],
      child: MaterialApp.router(
        builder: wrTextScaleBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        routerConfig: router,
      ),
    );
  }
}

String _textOf(WidgetTester tester, String key) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(Text),
        matchRoot: true,
      ),
    )
    .data!;

/// Hai chặng khép xong: chặng 1 ba tháng trước, chặng 2 vừa khép.
List<ReflectionEpisode> _twoChapters(DateTime now) {
  final t0 = now.subtract(const Duration(days: 100));
  DateTime d(int i) => t0.add(Duration(days: i));
  return [
    for (var i = 0; i < 6; i++) _ep('S1-01', d(i)),
    for (var i = 0; i < 2; i++) _ep('C2-01', d(6 + i)),
    for (var i = 0; i < 8; i++) _ep('C2-01', d(43 + i)),
    _ep('S1-01', d(52)),
  ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 2400);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetDevicePixelRatio();
    view.resetPhysicalSize();
  });

  group('Diễn giải trải nghiệm — mục lục', () {
    testWidgets('chưa có chặng thì ẩn dòng chặng; Premium không thấy nhãn', (
      tester,
    ) async {
      final h = _Harness(premium: true);
      await tester.pumpWidget(h.app('/wr/experience-interpret'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_exp_menu_chapter')), findsNothing);
      expect(find.textContaining('chặng 3'), findsNothing);
      expect(find.text('Premium'), findsNothing);
    });

    testWidgets('free thấy nhãn Premium; dòng chặng lấy chặng thật gần nhất', (
      tester,
    ) async {
      final h = _Harness(
        premium: false,
        episodes: _twoChapters(DateTime.now()),
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_exp_menu_chapter')), findsOneWidget);
      expect(find.text('Nhìn lại chặng 2'), findsOneWidget);
      // Dòng chặng + dòng tổng hợp.
      expect(find.text('Premium'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('wr_exp_menu_chapter')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_chapter_read_locked')), findsOneWidget);
    });

    testWidgets('màn con có đầu màn riêng "Diễn giải" + tiêu đề', (
      tester,
    ) async {
      final h = _Harness(premium: false);
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=1'));
      await tester.pumpAndSettle();

      expect(find.text('DIỄN GIẢI'), findsOneWidget);
      expect(find.textContaining('Theo những lần nhìn lại'), findsOneWidget);
      expect(find.text('Trải nghiệm của bạn'), findsNothing);
    });
  });

  group('Theo những lần nhìn lại / Theo khảo sát', () {
    testWidgets('ba trụ đúng tên script, đúng thứ tự S · C · A', (
      tester,
    ) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: false,
        episodes: [
          for (var i = 0; i < 5; i++)
            _ep('C2-01', now.subtract(Duration(days: i))),
          _ep('S1-01', now),
        ],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=1'));
      await tester.pumpAndSettle();

      final ys = [
        for (final p in ['s', 'c', 'a'])
          tester.getTopLeft(find.byKey(Key('wr_exp_reflect_row_$p'))).dy,
      ];
      expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);
      expect(find.text('Sự rõ ràng'), findsOneWidget);
      expect(find.text('Mối quan hệ'), findsWidgets);
      expect(find.text('Cách làm việc'), findsOneWidget);
      expect(find.text('5 / 6'), findsOneWidget);
    });

    testWidgets('theo khảo sát có dòng ngày, mức giữa màu #B8862F', (
      tester,
    ) async {
      final h = _Harness(
        premium: false,
        history: [_check(DateTime(2026, 9, 20, 10), s: 3.2)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=2'));
      await tester.pumpAndSettle();

      expect(
        _textOf(tester, 'wr_exp_survey_date'),
        'Khảo sát gần nhất: 20/09/2026',
      );
      final mid = tester.widget<Text>(find.text('Ổn, còn dư địa').first);
      expect(mid.style?.color, const Color(0xFFB8862F));
    });
  });

  group('Tổng hợp từ hệ thống (Premium)', () {
    List<ReflectionEpisode> cHeavy(DateTime now) => [
      for (var i = 0; i < 6; i++) _ep('C2-01', now.subtract(Duration(days: i))),
      _ep('S1-01', now),
    ];

    testWidgets('trụ nổi trội tự chấm chưa ổn: hai nguồn KHỚP', (tester) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: true,
        episodes: cHeavy(now),
        history: [_check(now, c: 2.0)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(
        _textOf(tester, 'wr_exp_synthesis_lead'),
        'Mối quan hệ là nhóm bạn quay lại nhiều nhất, 6 trong 7 lần nhìn lại.',
      );
      expect(
        _textOf(tester, 'wr_exp_synthesis_aligned'),
        contains('Hai nguồn đang nói cùng một chuyện'),
      );
      expect(find.byKey(const Key('wr_exp_synthesis_trend')), findsOneWidget);
    });

    testWidgets('trụ nổi trội tự chấm tốt: hai nguồn LỆCH', (tester) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: true,
        episodes: cHeavy(now),
        history: [_check(now, c: 4.4)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(
        _textOf(tester, 'wr_exp_synthesis_diverged'),
        contains('Hai nguồn đang lệch nhau'),
      );
    });

    testWidgets('chưa khảo sát: mời "Làm khảo sát"', (tester) async {
      final h = _Harness(premium: true, episodes: cHeavy(DateTime.now()));
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_exp_synthesis_need_survey')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('wr_exp_synthesis_take_survey')));
      await tester.pumpAndSettle();
      expect(find.text('SELF-CHECK'), findsOneWidget);
    });
  });

  group('Chặng', () {
    testWidgets('trả lời câu hỏi cuối chặng ghi một Cột mốc vào Hành trình', (
      tester,
    ) async {
      final h = _Harness(premium: true, episodes: _twoChapters(DateTime.now()));
      await tester.pumpWidget(h.app('/wr/chapter/ch2'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chapter_faded')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('wr_chapter_answer_real')),
      );
      await tester.tap(find.byKey(const Key('wr_chapter_answer_real')));
      await tester.pumpAndSettle();

      final ev = h.content.insertMemoryEventCalls.single;
      expect(ev.behavior, kMilestoneBehavior);
      expect(ev.reflectionText, contains('Chặng 2'));
      expect(ev.reflectionText, contains('Chuyện đó đã nhẹ đi thật.'));
      expect(find.text('ĐÃ GHI VÀO HÀNH TRÌNH'), findsOneWidget);
    });

    testWidgets('ghi hỏng thì KHÔNG nói "đã ghi vào hành trình"', (
      tester,
    ) async {
      final h = _Harness(premium: true, episodes: _twoChapters(DateTime.now()));
      await tester.pumpWidget(h.app('/wr/chapter/ch2'));
      await tester.pumpAndSettle();

      h.content.nextError = Exception('offline');
      await tester.ensureVisible(
        find.byKey(const Key('wr_chapter_answer_unnoticed')),
      );
      await tester.tap(find.byKey(const Key('wr_chapter_answer_unnoticed')));
      await tester.pumpAndSettle();

      expect(find.text('ĐÃ GHI VÀO HÀNH TRÌNH'), findsNothing);
      expect(
        find.byKey(const Key('wr_chapter_answer_error')),
        findsOneWidget,
      );
    });

    testWidgets('chưa đủ dữ liệu thì không bày chặng mẫu', (tester) async {
      final h = _Harness(premium: true);
      await tester.pumpWidget(h.app('/wr/chapter/ch3'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chapter_read_empty')), findsOneWidget);
      expect(find.text('Tháng 8 đến tháng 10'), findsNothing);
    });
  });

  group('Danh sách lặp lại', () {
    testWidgets('xổ ra đúng những lần đứng sau con số "n lần"', (
      tester,
    ) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: false,
        episodes: [
          // 30 lần gần nhất: C2-01 ba lần, S1-01 27 lần.
          for (var i = 0; i < 3; i++)
            _ep('C2-01', now.subtract(Duration(days: i)), note: 'gần $i'),
          for (var i = 0; i < 27; i++)
            _ep('S1-01', now.subtract(Duration(days: 3 + i))),
          // Ngoài cửa sổ 30: không được xổ ra.
          _ep('C2-01', now.subtract(const Duration(days: 90)), note: 'cũ'),
        ],
      );
      await tester.pumpWidget(h.app('/wr/patterns'));
      await tester.pumpAndSettle();

      expect(find.textContaining('trong 30 lần nhìn lại gần đây'), findsOneWidget);
      expect(find.text('3 lần'), findsOneWidget);
      await tester.tap(find.text('Không dám nói'));
      await tester.pumpAndSettle();

      expect(find.text('“gần 0”'), findsOneWidget);
      expect(find.text('“gần 2”'), findsOneWidget);
      expect(find.text('“cũ”'), findsNothing);
    });

    testWidgets('không có Episode thì không có dữ liệu mẫu nào', (
      tester,
    ) async {
      final h = _Harness(premium: false);
      await tester.pumpWidget(h.app('/wr/patterns'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Anh T nhắc lại'), findsNothing);
      expect(find.textContaining('lần nhìn lại gần đây'), findsNothing);
    });
  });
}
