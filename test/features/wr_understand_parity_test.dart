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
import 'package:workreflection_mobile/core/data/wr_reading_feedback_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_experience_reading.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
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
import 'package:workreflection_mobile/core/logic/wr_chapters.dart';

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

ScaSelfCheckResponse _check(DateTime at, {Map<String, int>? answers}) =>
    ScaSelfCheckResponse(
      userId: 'u1',
      answers: answers ?? {for (final id in _ids) id: 3},
      takenAt: at,
      structureScore: 3,
      cultureScore: 3,
      activityScore: 3,
    );

final _ids = [
  for (var i = 1; i <= 15; i++) 'scq-${i.toString().padLeft(2, '0')}',
];

/// Bộ trả lời mẫu của mockup v77 (`scaAnswers`), trên thang 1–5.
final _demoAnswers = {
  for (final e in const [4, 3, 3, 4, 3, 3, 3, 4, 3, 3, 2, 2, 3, 2, 3].indexed)
    _ids[e.$1]: e.$2,
};

/// 15 lần Mối quan hệ + 1 lần Sự rõ ràng: đủ ngưỡng 15, dom = C.
List<ReflectionEpisode> _cHeavy(DateTime now) => [
  for (var i = 0; i < 15; i++) _ep('C2-01', now.subtract(Duration(minutes: i))),
  _ep('S1-01', now.subtract(const Duration(minutes: 30))),
];

class _FakeReadingFeedback implements WrReadingFeedbackRepository {
  ReadingFeedback? latest;
  final inserted = <ReadingFeedback>[];

  @override
  Future<ReadingFeedback?> fetchLatest(String userId, String kind) async =>
      latest;

  @override
  Future<void> insert({
    required String userId,
    required String kind,
    required String readingKey,
    required Map<String, dynamic> reading,
    required bool match,
  }) async {
    inserted.add(
      ReadingFeedback(
        match: match,
        readingKey: readingKey,
        reading: reading,
        createdAt: DateTime.now(),
      ),
    );
  }
}

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

  final feedback = _FakeReadingFeedback();
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
            pillar: SelfCheckPillar.values
                .where((p) => p.name == s.uri.queryParameters['pillar'])
                .firstOrNull,
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
        wrReadingFeedbackRepositoryProvider.overrideWithValue(feedback),
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

    testWidgets('đã khép chặng mà dòng chặng vẫn ẩn (họp khách 14/10)', (
      tester,
    ) async {
      final h = _Harness(
        premium: false,
        episodes: _twoChapters(DateTime.now()),
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret'));
      await tester.pumpAndSettle();

      expect(kWrChaptersVisible, isFalse);
      expect(find.byKey(const Key('wr_exp_menu_chapter')), findsNothing);
      expect(find.text('Nhìn lại chặng 2'), findsNothing);
      // Chỉ còn dòng tổng hợp mang nhãn Premium.
      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('màn con có đầu màn riêng "Trải nghiệm của bạn" + tiêu đề', (
      tester,
    ) async {
      final h = _Harness(premium: false);
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=1'));
      await tester.pumpAndSettle();

      expect(find.text('TRẢI NGHIỆM CỦA BẠN'), findsOneWidget);
      expect(find.text('Từ những lần bạn nhìn lại'), findsOneWidget);
    });

    testWidgets('dòng khảo sát đếm số điều cản trở / nâng đỡ', (tester) async {
      final h = _Harness(
        premium: false,
        history: [_check(DateTime(2026, 9, 20, 10), answers: _demoAnswers)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret'));
      await tester.pumpAndSettle();

      expect(
        find.text('3 điều đang cản trở, 3 điều đang nâng đỡ bạn.'),
        findsOneWidget,
      );
    });
  });

  group('Từ những lần bạn nhìn lại', () {
    testWidgets('chưa đủ 15 lần: nói còn thiếu bao nhiêu, ba trụ S · C · A', (
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

      expect(_textOf(tester, 'wr_exp_reflect_lead'), contains('còn 9 lần nữa'));
      final ys = [
        for (final p in ['s', 'c', 'a'])
          tester.getTopLeft(find.byKey(Key('wr_exp_reflect_row_$p'))).dy,
      ];
      expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);
      expect(find.text('5 / 6'), findsOneWidget);
    });

    testWidgets('đủ 15 lần: chủ ngữ là người dùng, không có câu rút lại', (
      tester,
    ) async {
      final h = _Harness(premium: false, episodes: _cHeavy(DateTime.now()));
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=1'));
      await tester.pumpAndSettle();

      expect(
        _textOf(tester, 'wr_exp_reflect_lead'),
        'Trong 16 lần nhìn lại, bạn dừng lại ở Mối quan hệ nhiều hơn hai nhóm '
        'còn lại: 15 lần.',
      );
      expect(find.textContaining('chưa nói nhóm đó'), findsNothing);
    });
  });

  group('Từ điều kiện quanh bạn', () {
    testWidgets('đọc từng câu: nhãn đếm số điều, dòng phụ gọi tên', (
      tester,
    ) async {
      final h = _Harness(
        premium: false,
        history: [_check(DateTime(2026, 9, 20, 10), answers: _demoAnswers)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=2'));
      await tester.pumpAndSettle();

      expect(
        _textOf(tester, 'wr_exp_survey_lead'),
        'Trong mười lăm điều kiện quanh bạn, 3 điều đang cản trở và 3 điều '
        'đang nâng đỡ. Phần đang cản trở tập trung ở Cách làm việc.',
      );
      expect(
        _textOf(tester, 'wr_exp_survey_date'),
        contains(
          'Nguồn là mười lăm câu bạn đã trả lời, lần gần nhất ngày '
          '20/09/2026.',
        ),
      );
      expect(
        _textOf(tester, 'wr_exp_survey_label_s'),
        'Nâng đỡ nhưng chưa đều',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('wr_exp_survey_label_s')))
            .style
            ?.color,
        const Color(0xFF94681A),
      );
      expect(_textOf(tester, 'wr_exp_survey_label_a'), '3 điều đang cản trở');
      expect(
        _textOf(tester, 'wr_exp_survey_sub_a'),
        'Đang cản trở: Chưa thấy việc mình gắn với mục tiêu chung · Mục tiêu '
        'đổi mà biết muộn · và 1 điều nữa',
      );
      expect(
        _textOf(tester, 'wr_exp_survey_sub_s'),
        'Đang nâng đỡ: Trách nhiệm được làm rõ từ đầu · Thông tin đi đúng kênh '
        '· còn 3 điều chưa đều',
      );
      expect(find.textContaining('dư địa'), findsNothing);
      expect(find.byKey(const Key('wr_exp_survey_stale')), findsNothing);
    });

    testWidgets('bấm một nhóm: câu nối chuỗi + ba khối mức', (tester) async {
      final h = _Harness(
        premium: false,
        history: [_check(DateTime.now(), answers: _demoAnswers)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_exp_survey_row_a')));
      await tester.pumpAndSettle();

      expect(find.text('CÁCH LÀM VIỆC'), findsOneWidget);
      expect(
        _textOf(tester, 'wr_exp_pillar_lead'),
        startsWith('Ba điều đang cản trở ở nhóm này nối thành một chuỗi'),
      );
      expect(find.byKey(const Key('wr_exp_pillar_group_down')), findsOneWidget);
      expect(find.byKey(const Key('wr_exp_pillar_group_mid')), findsOneWidget);
      expect(find.byKey(const Key('wr_exp_pillar_group_up')), findsNothing);
      expect(find.text('Thiếu lúc để nhìn lại'), findsOneWidget);
      expect(find.text('Nhịp phối hợp của nhóm'), findsOneWidget);
    });

    testWidgets('khảo sát quá ba tháng: thêm dòng nhắc, không khoá', (
      tester,
    ) async {
      final h = _Harness(
        premium: false,
        history: [
          _check(
            DateTime.now().subtract(const Duration(days: 120)),
            answers: _demoAnswers,
          ),
        ],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=2'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_exp_survey_stale')), findsOneWidget);
      expect(find.byKey(const Key('wr_exp_survey_lead')), findsOneWidget);
    });
  });

  group('Tổng quan (Premium)', () {
    testWidgets('chưa Premium: khoá, hai phần trước vẫn miễn phí', (
      tester,
    ) async {
      final h = _Harness(premium: false, episodes: _cHeavy(DateTime.now()));
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_exp_synthesis_locked')), findsOneWidget);
    });

    testWidgets('lệch nhau: câu chứng cứ hai con số + câu liên hệ', (
      tester,
    ) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: true,
        episodes: _cHeavy(now),
        history: [_check(now, answers: _demoAnswers)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(
        _textOf(tester, 'wr_exp_overview_diverged'),
        'Chỗ bạn để tâm nhiều nhất và chỗ điều kiện đang cản trở nhiều nhất '
        'không trùng nhau.',
      );
      expect(
        _textOf(tester, 'wr_exp_overview_body'),
        'Phần lớn những gì bạn ghi lại nằm ở Mối quan hệ, 15 trong 16 lần. '
        'Trong khi đó điều kiện đang cản trở rõ nhất lại ở Cách làm việc, với '
        '3 điều.',
      );
      expect(
        _textOf(tester, 'wr_exp_overview_link'),
        contains(
          'Khi việc chưa được nối với mục tiêu chung và không có lúc nào '
          'để nhìn lại, những chuyện bạn ghi lại ở Mối quan hệ cũng khó tự '
          'nhẹ đi.',
        ),
      );
      expect(_textOf(tester, 'wr_exp_overview_start_pillar'), 'Cách làm việc');
      expect(find.byKey(const Key('wr_exp_synthesis_trend')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('wr_exp_overview_start_open')),
      );
      await tester.tap(find.byKey(const Key('wr_exp_overview_start_open')));
      await tester.pumpAndSettle();
      expect(find.text('CÁCH LÀM VIỆC'), findsOneWidget);
    });

    testWidgets('trùng nhau: hai phía cùng chỉ về một chỗ', (tester) async {
      final now = DateTime.now();
      final answers = {for (final id in _ids) id: 4}
        ..['scq-08'] = 2
        ..['scq-09'] = 1;
      final h = _Harness(
        premium: true,
        episodes: _cHeavy(now),
        history: [_check(now, answers: answers)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(
        _textOf(tester, 'wr_exp_overview_aligned'),
        'Hai phía cùng chỉ về một chỗ: Mối quan hệ.',
      );
      expect(find.byKey(const Key('wr_exp_overview_link')), findsNothing);
    });

    testWidgets('không có cản trở: nói rõ phần đáng làm là cách xoay xở', (
      tester,
    ) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: true,
        episodes: _cHeavy(now),
        history: [
          _check(now, answers: {for (final id in _ids) id: 4}),
        ],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_exp_overview_noBlock')), findsOneWidget);
      expect(_textOf(tester, 'wr_exp_overview_start_pillar'), 'Mối quan hệ');
    });

    testWidgets('"Chưa đúng lắm": ghi nhật ký, giữ bản cũ, không đổi câu', (
      tester,
    ) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: true,
        episodes: _cHeavy(now),
        history: [_check(now, answers: _demoAnswers)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('wr_exp_overview_off')));
      await tester.tap(find.byKey(const Key('wr_exp_overview_off')));
      await tester.pumpAndSettle();

      final row = h.feedback.inserted.single;
      expect(row.match, isFalse);
      expect(row.readingKey, 'diverged:c:a');
      expect(row.reading['dom'], 'c');
      expect(find.byKey(const Key('wr_exp_overview_held')), findsOneWidget);
      expect(find.textContaining('đọc lại sau 3 lần'), findsOneWidget);
      expect(find.byKey(const Key('wr_exp_overview_diverged')), findsOneWidget);
    });

    testWidgets('đang chờ đọc lại: giữ bản đã phản hồi dù dữ liệu đổi', (
      tester,
    ) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: true,
        // Một lần nhìn lại SAU phản hồi: còn chờ 2 lần nữa.
        episodes: [
          ..._cHeavy(now.subtract(const Duration(days: 2))),
          _ep('C2-01', now),
        ],
        // Khảo sát mới: hết cản trở ở mọi nhóm.
        history: [
          _check(now, answers: {for (final id in _ids) id: 4}),
        ],
      );
      h.feedback.latest = ReadingFeedback(
        match: false,
        readingKey: 'diverged:c:a',
        reading: OverviewInputs(
          dom: SelfCheckPillar.c,
          domCount: 15,
          total: 16,
          answers: _demoAnswers,
        ).toJson(),
        createdAt: now.subtract(const Duration(days: 1)),
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_exp_overview_diverged')), findsOneWidget);
      expect(find.textContaining('đọc lại sau 2 lần'), findsOneWidget);
      expect(find.byKey(const Key('wr_exp_overview_off')), findsNothing);
    });

    testWidgets('đủ 3 lần sau "Chưa đúng lắm": đọc lại, hỏi lại', (
      tester,
    ) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: true,
        episodes: [
          ..._cHeavy(now.subtract(const Duration(days: 5))),
          for (var i = 0; i < 3; i++) _ep('C2-01', now),
        ],
        history: [
          _check(now, answers: {for (final id in _ids) id: 4}),
        ],
      );
      h.feedback.latest = ReadingFeedback(
        match: false,
        readingKey: 'diverged:c:a',
        reading: const {},
        createdAt: now.subtract(const Duration(days: 1)),
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_exp_overview_noBlock')), findsOneWidget);
      expect(find.byKey(const Key('wr_exp_overview_off')), findsOneWidget);
    });

    testWidgets('chưa khảo sát: mời "Làm khảo sát"', (tester) async {
      final h = _Harness(premium: true, episodes: _cHeavy(DateTime.now()));
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

    testWidgets('có khảo sát, chưa đủ 15 lần nhìn lại: nói thiếu phía nào', (
      tester,
    ) async {
      final now = DateTime.now();
      final h = _Harness(
        premium: true,
        episodes: [_ep('C2-01', now)],
        history: [_check(now, answers: _demoAnswers)],
      );
      await tester.pumpWidget(h.app('/wr/experience-interpret?tab=3'));
      await tester.pumpAndSettle();

      expect(
        _textOf(tester, 'wr_exp_synthesis_need_reflections'),
        contains('cần 15 lần nhìn lại, bạn đã có 1 lần'),
      );
      expect(find.byKey(const Key('wr_exp_overview_start')), findsNothing);
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
      expect(find.byKey(const Key('wr_chapter_answer_error')), findsOneWidget);
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
    testWidgets('xổ ra đúng những lần đứng sau con số "n lần"', (tester) async {
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

      expect(
        find.textContaining('trong 30 lần nhìn lại gần đây'),
        findsOneWidget,
      );
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
