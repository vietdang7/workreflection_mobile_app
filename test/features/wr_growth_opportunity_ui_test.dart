// Cơ hội phát triển trên tab Hành trình (v47: đã bỏ) + màn Thông tin công việc.
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
      wrEpisodeRepositoryProvider.overrideWithValue(
        episodes ?? FakeWrEpisodeRepository(),
      ),
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
})
_withEnoughPatterns() {
  final intel = FakeWrIntelligenceRepository();
  final content = FakeWrContentRepository()..seedSituations(_situations());
  return (intel: intel, content: content, episodes: _episodes());
}

void main() {
  // Mockup v47 (script khách 06/10) bỏ khối "Góc nhìn phát triển" và dòng
  // dẫn sang Thông tin công việc khỏi tab Hành trình. Luật §XI
  // (`wrGrowthOpportunityProvider`) vẫn dùng ở nơi khác; ở đây chỉ kiểm khối
  // đó KHÔNG còn trên tab, kể cả khi đủ dữ liệu.
  group('Hành trình — không còn khối Cơ hội phát triển (v47)', () {
    void expectNoGrowthBlock() {
      expect(find.text('CƠ HỘI PHÁT TRIỂN'), findsNothing);
      for (final key in const [
        'wr_journey_growth_opportunity',
        'wr_journey_growth_opportunity_lock',
        'wr_journey_growth_confidence',
        'wr_journey_work_info_row',
      ]) {
        expect(
          find.byKey(Key(key), skipOffstage: false),
          findsNothing,
          reason: '$key phải bị bỏ khỏi tab Hành trình',
        );
      }
    }

    for (final premium in const [false, true]) {
      testWidgets(
        '${premium ? 'Premium' : 'Free'} đủ Pattern vẫn không thấy khối này',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 6000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final fakes = _withEnoughPatterns();
          // Có cả bản đối tác đã tổng hợp — vẫn không được hiện trên tab.
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
              premium: premium,
            ),
          );
          await tester.pumpAndSettle();

          expectNoGrowthBlock();
          expect(find.text('Gợi ý do đối tác tổng hợp.'), findsNothing);
          expect(find.textContaining('đối thoại'), findsNothing);
          expect(find.text(GrowthOpportunity.kConfidenceNote), findsNothing);
        },
      );
    }
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

      await tester.tap(find.byKey(const Key('wr_work_info_context_docs_row')));
      await tester.pumpAndSettle();
      expect(find.text('ContextDocs'), findsOneWidget);
    });

    // Changelog 24/08/2026 §6 — lối vào duy nhất của "Viết JD cùng app".
    testWidgets('có lối sang Viết JD cùng app', (tester) async {
      await tester.pumpWidget(_wrap(const WrWorkInfoScreen(), repo: _repo()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nếu chưa có sẵn JD, bạn có thể tự phác thảo nhanh theo 5 bước hướng dẫn',
        ),
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
