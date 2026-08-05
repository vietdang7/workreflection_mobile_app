// Các màn đọc tách khỏi tab sau Sprint D3 + Hành trình đọc từ Episode:
//   • /wr/episode/:id      — một lần nhìn lại
//   • /wr/growth/skills    — kỹ năng đã hình thành
//   • buildJourneyEntries  — trộn Episode + Career Memory event
// Run: flutter test test/features/wr_detail_screens_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_episode_detail_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_skills_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

Widget _wrap(
  Widget screen, {
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  FakeWrEpisodeRepository? episodes,
  String userId = 'u1',
}) {
  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(path: '/screen', builder: (_, __) => screen),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('PAYWALL')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider
          .overrideWithValue(content ?? FakeWrContentRepository()),
      wrIntelligenceRepositoryProvider
          .overrideWithValue(intel ?? FakeWrIntelligenceRepository()),
      wrEpisodeRepositoryProvider
          .overrideWithValue(episodes ?? FakeWrEpisodeRepository()),
      currentUserIdProvider.overrideWithValue(userId),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: router),
  );
}

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

ReflectionEpisode _episode({
  String id = 'ep-1',
  HumanMoment moment = HumanMoment.confusion,
  ExperienceState state = ExperienceState.integrated,
  String? meaning = 'Mình sợ bị đánh giá chứ không phải sợ việc khó.',
  String? action = 'Hỏi lại quản lý một câu vào sáng mai.',
  List<ReflectionPattern> done = const [
    ReflectionPattern.notice,
    ReflectionPattern.name,
  ],
  Map<String, String> notes = const {
    'notice': 'Ngực nặng khi mở email',
    'name': 'Áp lực deadline',
  },
  String? situationCode,
  DateTime? closedAt,
}) =>
    ReflectionEpisode(
      id: id,
      userId: 'u1',
      humanMoment: moment,
      state: state,
      draftMeaning: meaning,
      tinyAction: action,
      patternsDone: done,
      notes: notes,
      situationCode: situationCode,
      closedAt: closedAt ?? DateTime(2026, 7, 20),
    );

CareerMemoryEvent _event({
  String id = 'e1',
  String? behavior,
  String? reflectionText,
  DateTime? createdAt,
}) =>
    CareerMemoryEvent(
      id: id,
      userId: 'u1',
      behavior: behavior,
      reflectionText: reflectionText,
      createdAt: createdAt ?? DateTime(2026, 7, 19),
    );

PracticeTheme _theme(String id, String title) =>
    PracticeTheme(themeId: id, title: title);

PracticeEnrollment _enrollment(String themeId, {DateTime? completedAt}) =>
    PracticeEnrollment(
      userId: 'u1',
      themeId: themeId,
      completedSteps: const [],
      completedAt: completedAt,
    );

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // buildJourneyEntries — logic thuần, không cần widget
  // ─────────────────────────────────────────────────────────────────────────

  group('buildJourneyEntries', () {
    test('chỉ Episode đã khép lại mới vào Hành trình', () {
      final entries = buildJourneyEntries(
        episodes: [
          _episode(id: 'a', state: ExperienceState.integrated),
          _episode(id: 'b', state: ExperienceState.exploring),
          _episode(id: 'c', state: ExperienceState.dormant),
        ],
        events: const [],
        situationLabels: const {},
      );

      expect(entries, hasLength(1));
      expect(entries.first.episodeId, 'a');
      expect(entries.first.label, 'PHẢN TƯ');
    });

    test('bỏ event do Episode sinh ra để không đếm hai lần', () {
      final entries = buildJourneyEntries(
        episodes: [_episode(id: 'a')],
        events: [
          _event(id: 'dup', behavior: kEpisodeBehavior, reflectionText: 'X'),
          _event(id: 'p', behavior: 'practice_step_done', reflectionText: 'Y'),
        ],
        situationLabels: const {},
      );

      expect(entries, hasLength(2));
      expect(entries.any((e) => e.title == 'X'), isFalse);
      expect(entries.any((e) => e.title == 'Y'), isTrue);
    });

    test('chưa đọc được Episode thì vẫn giữ event của Episode', () {
      final entries = buildJourneyEntries(
        episodes: const [],
        events: [
          _event(id: 'dup', behavior: kEpisodeBehavior, reflectionText: 'X'),
        ],
        situationLabels: const {},
      );

      expect(entries, hasLength(1));
      expect(entries.first.title, 'X');
      expect(entries.first.label, 'PHẢN TƯ');
    });

    test('sắp xếp mới nhất trước', () {
      final entries = buildJourneyEntries(
        episodes: [_episode(id: 'a', closedAt: DateTime(2026, 7, 10))],
        events: [
          _event(id: 'e', reflectionText: 'Mới hơn', createdAt: DateTime(2026, 7, 25)),
        ],
        situationLabels: const {},
      );

      expect(entries.first.title, 'Mới hơn');
      expect(entries.last.episodeId, 'a');
    });

    test('dùng nhãn tình huống khi Episode có situation_code', () {
      final entries = buildJourneyEntries(
        episodes: [_episode(situationCode: 'sit-01')],
        events: const [],
        situationLabels: const {'sit-01': 'Áp lực deadline'},
      );

      expect(entries.first.subtitle, 'Áp lực deadline');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Màn đọc một lần nhìn lại
  // ─────────────────────────────────────────────────────────────────────────

  group('WrEpisodeDetailScreen', () {
    testWidgets('hiện ý nghĩa, ghi chú từng bước và bước nhỏ', (tester) async {
      final repo = FakeWrEpisodeRepository()..seed([_episode()]);

      await _pumpLarge(
        tester,
        _wrap(const WrEpisodeDetailScreen(episodeId: 'ep-1'), episodes: repo),
      );

      expect(find.text('Có gì đó chưa ổn'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_episode_detail_meaning')),
        findsOneWidget,
      );
      expect(find.text('Ngực nặng khi mở email'), findsOneWidget);
      expect(find.text('Áp lực deadline'), findsOneWidget);
      expect(find.byKey(const Key('wr_episode_detail_action')), findsOneWidget);
    });

    testWidgets('không có ô nhập — đây là màn đọc', (tester) async {
      final repo = FakeWrEpisodeRepository()..seed([_episode()]);

      await _pumpLarge(
        tester,
        _wrap(const WrEpisodeDetailScreen(episodeId: 'ep-1'), episodes: repo),
      );

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('id không tồn tại → thông báo thay vì màn trắng', (
      tester,
    ) async {
      await _pumpLarge(
        tester,
        _wrap(const WrEpisodeDetailScreen(episodeId: 'khong-co')),
      );

      expect(
        find.byKey(const Key('wr_episode_detail_missing')),
        findsOneWidget,
      );
    });

    // WPA Inv.4 · WXS Inv.7 — không có trạng thái khoá vĩnh viễn.
    testWidgets('Episode đã khép vẫn mở lại được', (tester) async {
      final repo = FakeWrEpisodeRepository()..seed([_episode()]);

      await _pumpLarge(
        tester,
        _wrap(const WrEpisodeDetailScreen(episodeId: 'ep-1'), episodes: repo),
      );

      expect(find.byKey(const Key('wr_episode_reopen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_episode_reopen')));
      await tester.pumpAndSettle();

      expect(repo.episodes.single.state, ExperienceState.reactivated);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Màn kỹ năng đã hình thành
  // ─────────────────────────────────────────────────────────────────────────

  group('WrGrowthSkillsScreen', () {
    testWidgets('danh sách đang hình thành chỉ hiện 3, còn lại sau Xem thêm', (
      tester,
    ) async {
      // Khách 2026-08-04: đang theo sáu chủ đề thì mục này dài tới mức đẩy phần
      // đối chiếu với công việc xuống tận đáy màn.
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([
          for (var i = 1; i <= 6; i++) _theme('t$i', 'Chủ đề số $i'),
        ])
        ..seedEnrollments([for (var i = 1; i <= 6; i++) _enrollment('t$i')]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel),
      );

      expect(find.byKey(const Key('wr_skill_forming_t1')), findsOneWidget);
      expect(find.byKey(const Key('wr_skill_forming_t4')), findsNothing);
      expect(find.text('Xem thêm 3 chủ đề'), findsOneWidget);

      // Bấm vào chữ, không bấm vào giữa dòng: WrActionLink là một Row
      // mainAxisSize.min nên nửa phải của dòng là khoảng trống không nhận chạm.
      await tester.tap(find.text('Xem thêm 3 chủ đề'));
      await tester.pumpAndSettle();

      // Xổ ra là thấy ĐỦ, không phải một trần cắt mất dữ liệu. Phải cuộn tới
      // vì ListView chỉ dựng phần đang trong tầm nhìn.
      await tester.scrollUntilVisible(
        find.byKey(const Key('wr_skill_forming_t6')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('wr_skill_forming_t6')), findsOneWidget);
      expect(find.text('Thu gọn'), findsOneWidget);
    });

    testWidgets('ít chủ đề thì không có nút Xem thêm', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([
          for (var i = 1; i <= 3; i++) _theme('t$i', 'Chủ đề số $i'),
        ])
        ..seedEnrollments([for (var i = 1; i <= 3; i++) _enrollment('t$i')]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel),
      );

      expect(find.byKey(const Key('wr_skills_forming_more')), findsNothing);
      expect(find.byKey(const Key('wr_skill_forming_t3')), findsOneWidget);
    });

    testWidgets('chưa xong ba bước làm quen thì KHÔNG hiện bộ đếm 5 lần', (
      tester,
    ) async {
      // Ma trận Cấp bậc v1.0, Phần C mục 2: hai câu "còn N lần thực hành" và
      // "đi hết ba bước làm quen trước đã" phủ định nhau. Chưa khép giai đoạn
      // làm quen thì bộ đếm chưa phải chuyện của người dùng.
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([_theme('t1', 'Lên tiếng trong họp')])
        ..seedEnrollments([_enrollment('t1')]);
      final content = FakeWrContentRepository()
        ..seedMemoryEvents([
          _event(
            id: 'p1',
            behavior: 'practice_step_done',
            reflectionText: 'Lên tiếng trong họp — Bước 1',
          ),
        ]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel, content: content),
      );

      expect(find.byKey(const Key('wr_skill_t1')), findsNothing);
      expect(find.text('ĐANG HÌNH THÀNH'), findsOneWidget);
      expect(find.byKey(const Key('wr_skill_progress_t1')), findsNothing);
      expect(find.textContaining('lần thực hành'), findsNothing);
      expect(
        find.text('Đi hết ba bước làm quen của chủ đề này trước đã.'),
        findsOneWidget,
      );
    });

    testWidgets('xong ba bước làm quen vẫn chưa phải kỹ năng', (tester) async {
      // Luật đổi theo spec Skill Formation: ba bước là giai đoạn LÀM QUEN.
      // Bản cũ chứng nhận ngay khi ghi danh khép lại, nên ngưỡng 5 lần không
      // bao giờ có ý nghĩa.
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([_theme('t1', 'Lên tiếng trong họp')])
        ..seedEnrollments([
          _enrollment('t1', completedAt: DateTime(2026, 7, 20)),
        ]);
      final content = FakeWrContentRepository()
        ..seedMemoryEvents([
          for (var i = 0; i < 3; i++)
            _event(
              id: 'p$i',
              behavior: 'practice_step_done',
              reflectionText: 'Lên tiếng trong họp — Bước $i',
            ),
        ]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel, content: content),
      );

      expect(find.byKey(const Key('wr_skill_t1')), findsNothing);
      expect(
        // Dấu phẩy thay dấu chấm giữa — bản đối chiếu UX/UI 05/08.
        find.textContaining('3/5 lần thực hành, còn 2 lần nữa'),
        findsOneWidget,
      );
      // Đã xong làm quen thì mở nút duy trì.
      expect(find.byKey(const Key('wr_practice_maintain_t1')), findsOneWidget);
    });

    testWidgets('lặp đủ 5 lần → chứng nhận kỹ năng', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([_theme('t1', 'Lên tiếng trong họp')])
        ..seedEnrollments([_enrollment('t1')]);
      final content = FakeWrContentRepository()
        ..seedMemoryEvents([
          for (var i = 0; i < 5; i++)
            _event(
              id: 'p$i',
              behavior: 'practice_step_done',
              reflectionText: 'Lên tiếng trong họp — Bước $i',
            ),
        ]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel, content: content),
      );

      expect(find.byKey(const Key('wr_skill_t1')), findsOneWidget);
      expect(find.textContaining('1 kỹ năng'), findsOneWidget);
      expect(find.byKey(const Key('wr_skills_empty')), findsNothing);
    });

    testWidgets('bản miễn phí vẫn xem được — đây là ghi nhận', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(null)
        ..seedPracticeThemes([_theme('t1', 'Lên tiếng trong họp')])
        ..seedEnrollments([
          _enrollment('t1', completedAt: DateTime(2026, 7, 20)),
        ]);
      final content = FakeWrContentRepository()
        ..seedMemoryEvents([
          for (var i = 0; i < 5; i++)
            _event(
              id: 'p$i',
              behavior: 'practice_step_done',
              reflectionText: 'Lên tiếng trong họp — Bước $i',
            ),
        ]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel, content: content),
      );

      expect(find.byKey(const Key('wr_skill_t1')), findsOneWidget);
      expect(find.text('PAYWALL'), findsNothing);
    });

    testWidgets('bấm duy trì lần thứ 5 → ghi dấu mốc và ăn mừng', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([_theme('t1', 'Lên tiếng trong họp')])
        ..seedEnrollments([
          _enrollment('t1', completedAt: DateTime(2026, 7, 20)),
        ]);
      final content = FakeWrContentRepository()
        ..seedMemoryEvents([
          for (var i = 0; i < 4; i++)
            _event(
              id: 'p$i',
              behavior: 'practice_step_done',
              reflectionText: 'Lên tiếng trong họp — Bước $i',
            ),
        ]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel, content: content),
      );

      await tester.tap(find.byKey(const Key('wr_practice_maintain_t1')));
      await tester.pumpAndSettle();

      final behaviors =
          content.insertMemoryEventCalls.map((e) => e.behavior).toList();
      expect(behaviors, contains('practice_maintained'));
      expect(behaviors, contains('skill_certified'));
      expect(
        find.byKey(const Key('wr_skill_formed_celebration')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_skill_formed_title')), findsOneWidget);
    });

    testWidgets('đối chiếu với công việc là phần Premium', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(null)
        ..seedPracticeThemes([_theme('t1', 'Lên tiếng trong họp')])
        ..seedEnrollments([_enrollment('t1')]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel),
      );

      // Ghi nhận nỗ lực: Free. Diễn giải nó cạnh JD: Premium.
      expect(find.byKey(const Key('wr_skills_jd_lock')), findsOneWidget);
      expect(find.byKey(const Key('wr_skills_jd_match')), findsNothing);
    });
  });
}
