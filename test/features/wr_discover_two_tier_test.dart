// Hiểu mình + chi tiết điều lặp lại — ranh giới GHI NHẬN / DIỄN GIẢI.
//
// Yêu cầu khách 2026-07-27:
//   • tích lũy đủ (5 lần) mới đọc ra nguyên nhân sâu
//   • phần đọc ra nguyên nhân là Premium
//   • bản miễn phí chỉ xem thông tin ghi nhận hành trình đã làm

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_pattern_detail_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

const _sit = WrSituation(
  code: 'sit-01',
  text: 'Không được lắng nghe trong họp',
  scaDimension: ScaDimension.c1,
  wave: 1,
  humanNeed: HumanNeed.ketNoi,
);

PatternCount _pattern(int count) => PatternCount(
      id: 'p1',
      userId: 'u1',
      situationCode: 'sit-01',
      scaDimension: ScaDimension.c1,
      occurrenceCount: count,
      lastSeenAt: DateTime(2026, 7, 26),
    );

Widget _wrap(
  Widget child, {
  required FakeWrIntelligenceRepository intel,
  required FakeWrContentRepository content,
  FakeWrEpisodeRepository? episodes,
}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => child),
      GoRoute(
        path: '/wr/pattern/:code',
        builder: (_, s) => WrPatternDetailScreen(
          situationCode: s.pathParameters['code'] ?? '',
        ),
      ),
      GoRoute(
        path: '/wr/self-check',
        builder: (_, __) => const Scaffold(body: Text('SELFCHECK')),
      ),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('PAYWALL')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      wrContentRepositoryProvider.overrideWithValue(content),
      wrEpisodeRepositoryProvider
          .overrideWithValue(episodes ?? FakeWrEpisodeRepository()),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  group('Hiểu mình — chỉ ghi nhận', () {
    testWidgets('liệt kê điều lặp lại kèm số lần, không diễn giải',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);

      await _pump(
        tester,
        _wrap(const WrDiscoverScreen(), intel: intel, content: content),
      );

      expect(find.text('Không được lắng nghe trong họp'), findsOneWidget);
      expect(find.text('3 lần'), findsOneWidget);
      // Nhu cầu chủ đạo là dữ kiện đếm được (nhu cầu nào lặp nhiều nhất), nên
      // ở tầng ghi nhận. Phần "vì sao nó lặp lại" vẫn nằm ở màn chi tiết.
      expect(find.byKey(const Key('wr_discover_seeking')), findsOneWidget);
      expect(find.text('KẾT NỐI · Nhu cầu chủ đạo'), findsOneWidget);
      // Không có câu diễn giải riêng cho người này ở tầng danh sách.
      expect(find.textContaining('ĐIỀU ĐỨNG SAU'), findsNothing);
    });

    testWidgets('đếm số lần đã nhìn lại từ lịch sử Episode', (tester) async {
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          const ReflectionEpisode(
            id: 'e1',
            userId: 'u1',
            humanMoment: HumanMoment.confusion,
            state: ExperienceState.integrated,
          ),
          const ReflectionEpisode(
            id: 'e2',
            userId: 'u1',
            humanMoment: HumanMoment.recovery,
            state: ExperienceState.integrated,
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
          episodes: episodes,
        ),
      );

      expect(find.text('Bạn đã nhìn lại 2 lần.'), findsOneWidget);
    });

    testWidgets('bấm một dòng mở màn chi tiết riêng', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);

      await _pump(
        tester,
        _wrap(const WrDiscoverScreen(), intel: intel, content: content),
      );

      await tester.tap(find.text('Không được lắng nghe trong họp'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn đã ghi lại điều này 3 lần.'), findsOneWidget);
    });
  });

  // Bố cục theo giao-dien-chinh.html §screen-understand — nhưng mọi con số và
  // trạng thái đều đọc từ dữ liệu thật, không có dòng minh hoạ nào cứng.
  group('Hiểu mình — trải nghiệm hiện tại', () {
    testWidgets('chưa tự đánh giá thì cả ba trụ đều nói chưa đánh giá',
        (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      // Hai Lớp v1.6 §XII.5 — chữ "SCA" là thuật ngữ nội bộ, không lộ ra UI.
      expect(find.text('TRẢI NGHIỆM HIỆN TẠI'), findsOneWidget);
      expect(find.textContaining('SCA'), findsNothing);
      expect(find.text('Chưa đánh giá'), findsNWidgets(3));
      expect(find.text('Chưa tự đánh giá lần nào'), findsOneWidget);
    });

    testWidgets('đọc điểm ba trụ từ lần tự đánh giá gần nhất', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2,
            cultureScore: 3.0,
            activityScore: 1.8,
            takenAt: DateTime(2026, 7, 26),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );

      expect(find.text('Đang phát triển'), findsOneWidget); // S = 4.2
      expect(find.text('Cần chú ý'), findsOneWidget); //       C = 3.0
      expect(find.text('Ưu tiên cải thiện'), findsOneWidget); // A = 1.8
      expect(find.text('Đã tự đánh giá 1 lần'), findsOneWidget);
    });

    test('ngưỡng trạng thái trụ giữ đúng như màn Tự đánh giá', () {
      expect(pillarStatusLabel(null), 'Chưa đánh giá');
      expect(pillarStatusLabel(0), 'Chưa đánh giá');
      expect(pillarStatusLabel(1.8), 'Ưu tiên cải thiện');
      expect(pillarStatusLabel(2.5), 'Cần chú ý');
      expect(pillarStatusLabel(3.8), 'Đang phát triển');
    });
  });

  group('Chi tiết điều lặp lại — ngưỡng dữ liệu và Premium', () {
    testWidgets('dưới 5 lần: nói còn thiếu bao nhiêu, chưa mời trả tiền',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: content,
        ),
      );

      expect(
        find.byKey(const Key('wr_pattern_not_enough_data')),
        findsOneWidget,
      );
      expect(find.textContaining('Cần thêm 2 lần nữa'), findsOneWidget);
      expect(find.byKey(const Key('wr_pattern_premium_lock')), findsNothing);
    });

    testWidgets('đủ 5 lần nhưng miễn phí: khoá phần diễn giải',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(5)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: content,
        ),
      );

      expect(find.byKey(const Key('wr_pattern_premium_lock')), findsOneWidget);
      expect(find.byKey(const Key('wr_pattern_narrative')), findsNothing);
    });

    testWidgets('đủ 5 lần và premium: hiện phần diễn giải', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(6)])
        ..seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        )
        ..seedPatternNarratives([
          const PatternNarrative(
            id: 'n1',
            userId: 'u1',
            narrative: 'Điều lặp lại này thường xuất hiện khi bạn ở nhóm mới.',
          ),
        ]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: content,
        ),
      );

      expect(find.byKey(const Key('wr_pattern_narrative')), findsOneWidget);
      expect(find.byKey(const Key('wr_pattern_premium_lock')), findsNothing);
    });

    testWidgets('những lần đã nhìn lại luôn hiện, kể cả bản miễn phí',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(2)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          const ReflectionEpisode(
            id: 'e1',
            userId: 'u1',
            humanMoment: HumanMoment.confusion,
            state: ExperienceState.integrated,
            situationCode: 'sit-01',
            draftMeaning: 'Mình hay im lặng khi chưa chắc chắn',
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      expect(
        find.text('Mình hay im lặng khi chưa chắc chắn'),
        findsOneWidget,
      );
    });
  });
}
