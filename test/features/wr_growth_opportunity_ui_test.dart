// Cơ hội phát triển trên tab Hành trình + màn Thông tin công việc.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §XI.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_work_info_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

final _now = DateTime(2026, 7, 28);

/// Đủ lặp lại để luật §XI dám nói một hướng — bốn lần cùng trụ C.
List<WrSituation> _situations() => const [
      WrSituation(
        code: 'C1-sit-01',
        text: 'Không được lắng nghe',
        scaDimension: ScaDimension.c1,
        wave: 1,
      ),
    ];

/// Năm lượt nhìn lại cùng chọn `C1-sit-01`.
///
/// Gieo EPISODE chứ không gieo `wr_pattern_counts`: từ 2026-07-31 luật Cơ hội
/// phát triển đọc recentSituationIds (Kiến trúc v2.0 §4.3).
FakeWrEpisodeRepository _episodes() => FakeWrEpisodeRepository()
  ..seed([
    for (var i = 0; i < 5; i++)
      ReflectionEpisode(
        id: 'e$i',
        userId: 'u1',
        humanMoment: HumanMoment.confusion,
        state: ExperienceState.integrated,
        situationCode: 'C1-sit-01',
        openedAt: _now.add(Duration(hours: i)),
      ),
  ]);

Widget _wrap(
  Widget child, {
  required FakeWrRepository repo,
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
  FakeWrEpisodeRepository? episodes,
  bool premium = false,
}) {
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final contentRepo = content ?? FakeWrContentRepository();
  if (premium) {
    intelRepo.seedEntitlement(
      WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
    );
  }

  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => child),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('Paywall')),
      ),
      GoRoute(
        path: '/wr/work-info',
        builder: (_, __) => const Scaffold(body: Text('WorkInfo')),
      ),
      GoRoute(
        path: '/wr/context-docs',
        builder: (_, __) => const Scaffold(body: Text('ContextDocs')),
      ),
      GoRoute(
        path: '/wr/jd-builder',
        builder: (_, __) => const Scaffold(body: Text('JdBuilder')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(repo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrEpisodeRepositoryProvider
          .overrideWithValue(episodes ?? FakeWrEpisodeRepository()),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}

FakeWrRepository _repo({String? roleText}) {
  final repo = FakeWrRepository();
  repo.seedProfile(
    MobileProfile(
      userId: 'u1',
      reminderEnabled: false,
      language: 'vi',
      createdAt: _now,
      updatedAt: _now,
      roleText: roleText,
    ),
  );
  return repo;
}

({
  FakeWrIntelligenceRepository intel,
  FakeWrContentRepository content,
  FakeWrEpisodeRepository episodes,
}) _withEnoughPatterns() {
  final intel = FakeWrIntelligenceRepository();
  final content = FakeWrContentRepository()..seedSituations(_situations());
  return (intel: intel, content: content, episodes: _episodes());
}

void main() {
  group('Hành trình — khối Cơ hội phát triển (§XI)', () {
    testWidgets('chưa đủ Pattern thì cả khối im lặng (§11.3)', (tester) async {
      // Không seed Pattern nào — không được hiện khung rỗng hay lời mời chung.
      await tester.pumpWidget(
        _wrap(const WrJourneyScreen(), repo: _repo(), premium: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('CƠ HỘI PHÁT TRIỂN'), findsNothing);
      expect(
        find.byKey(const Key('wr_journey_growth_opportunity')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('wr_journey_growth_opportunity_lock')),
        findsNothing,
      );
    });

    testWidgets('Free chỉ thấy khối khoá, không thấy nội dung gợi ý (§11.4)', (
      tester,
    ) async {
      // Khung test mặc định 800px không đủ cao — xem ghi chú ở test Premium bên
      // dưới. Cỡ chữ toàn app nới ra càng đẩy khối khoá ra ngoài vùng dựng lười.
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fakes = _withEnoughPatterns();
      await tester.pumpWidget(
        _wrap(
          const WrJourneyScreen(),
          repo: _repo(),
          intel: fakes.intel,
          content: fakes.content,
          episodes: fakes.episodes,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_journey_growth_opportunity_lock')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_journey_growth_opportunity')),
        findsNothing,
      );
      // Câu gợi ý thật không được lọt ra ngoài paywall.
      expect(find.textContaining('đối thoại'), findsNothing);
    });

    testWidgets('Premium thấy gợi ý, và luôn kèm ghi chú độ chính xác (§XII.7)',
        (tester) async {
      // Khung test mặc định 800px không đủ cao: từ khi các test này gieo
      // Episode thật (nguồn của recentSituationIds), dòng thời gian Hành trình
      // dài thêm và đẩy khối Cơ hội phát triển ra ngoài vùng ListView dựng lười.
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fakes = _withEnoughPatterns();
      await tester.pumpWidget(
        _wrap(
          const WrJourneyScreen(),
          repo: _repo(),
          intel: fakes.intel,
          content: fakes.content,
          episodes: fakes.episodes,
          premium: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_journey_growth_opportunity')),
        findsOneWidget,
      );
      expect(find.textContaining('đối thoại'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_journey_growth_confidence')),
        findsOneWidget,
      );
      expect(find.text(GrowthOpportunity.kConfidenceNote), findsOneWidget);
    });

    testWidgets('có dòng dẫn sang màn Thông tin công việc', (tester) async {
      // Khung test mặc định 800px không đủ cao: từ khi các test này gieo
      // Episode thật (nguồn của recentSituationIds), dòng thời gian Hành trình
      // dài thêm và đẩy khối Cơ hội phát triển ra ngoài vùng ListView dựng lười.
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fakes = _withEnoughPatterns();
      await tester.pumpWidget(
        _wrap(
          const WrJourneyScreen(),
          repo: _repo(),
          intel: fakes.intel,
          content: fakes.content,
          episodes: fakes.episodes,
          premium: true,
        ),
      );
      await tester.pumpAndSettle();

      // Tab Hành trình dài hơn sau khi thêm thẻ Diễn biến — phải cuộn tới dòng
      // rồi mới bấm được.
      await tester.ensureVisible(
        find.byKey(const Key('wr_journey_work_info_row')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_journey_work_info_row')));
      await tester.pumpAndSettle();
      expect(find.text('WorkInfo'), findsOneWidget);
    });

    testWidgets('bản đối tác đã tổng hợp thì dùng bản đó, không suy bằng luật',
        (tester) async {
      // Khung test mặc định 800px không đủ cao: từ khi các test này gieo
      // Episode thật (nguồn của recentSituationIds), dòng thời gian Hành trình
      // dài thêm và đẩy khối Cơ hội phát triển ra ngoài vùng ListView dựng lười.
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fakes = _withEnoughPatterns();
      fakes.intel.seedGrowthOpportunity(
        GrowthOpportunity(
          id: 'go-1',
          userId: 'u1',
          suggestionText: 'Gợi ý do đối tác tổng hợp.',
          confidenceNote: GrowthOpportunity.kConfidenceNote,
          basedOn: const ['C1-sit-01'],
          generatedAt: _now,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          const WrJourneyScreen(),
          repo: _repo(),
          intel: fakes.intel,
          content: fakes.content,
          episodes: fakes.episodes,
          premium: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gợi ý do đối tác tổng hợp.'), findsOneWidget);
      expect(find.textContaining('đối thoại'), findsNothing);
    });
  });

  group('Màn Thông tin công việc', () {
    testWidgets('điền sẵn mô tả đã lưu', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const WrWorkInfoScreen(),
          repo: _repo(roleText: 'trưởng nhóm nội dung'),
        ),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('wr_work_info_field')),
      );
      expect(field.controller!.text, 'trưởng nhóm nội dung');
    });

    testWidgets('lưu ghi mô tả xuống hồ sơ', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_wrap(const WrWorkInfoScreen(), repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('wr_work_info_field')),
        'quản lý dự án, làm việc với 3 phòng ban',
      );
      await tester.tap(find.byKey(const Key('wr_work_info_save')));
      await tester.pumpAndSettle();

      expect(repo.saveRoleTextCalls, hasLength(1));
      expect(
        repo.saveRoleTextCalls.single,
        'quản lý dự án, làm việc với 3 phòng ban',
      );
      expect(find.byKey(const Key('wr_work_info_saved')), findsOneWidget);
    });

    testWidgets('có lối sang Tài liệu bối cảnh (JD · CV)', (tester) async {
      await tester.pumpWidget(_wrap(const WrWorkInfoScreen(), repo: _repo()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('wr_work_info_context_docs_row')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ContextDocs'), findsOneWidget);
    });

    // Changelog 24/08/2026 §6 — lối vào duy nhất của "Viết JD cùng app".
    testWidgets('có lối sang Viết JD cùng app', (tester) async {
      await tester.pumpWidget(_wrap(const WrWorkInfoScreen(), repo: _repo()));
      await tester.pumpAndSettle();

      expect(
        find.text('Công ty chưa có JD? Cùng viết trong 5 buổi ngắn'),
        findsOneWidget,
      );
      final card = find.byKey(const Key('wr_work_info_jd_builder_card'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('JdBuilder'), findsOneWidget);
    });
  });
}
