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
import 'package:workreflection_mobile/features/wr/presentation/wr_patterns_screen.dart';
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
        path: '/wr/patterns',
        builder: (_, __) => const WrPatternsScreen(),
      ),
      GoRoute(
        path: '/wr/self-check',
        builder: (_, __) => const Scaffold(body: Text('SELFCHECK')),
      ),
      GoRoute(
        path: '/wr/paywall',
        // In ra trigger để test khẳng định paywall được gọi đúng ngữ cảnh.
        builder: (_, s) => Scaffold(
          body: Text('PAYWALL:${s.uri.queryParameters['trigger'] ?? ''}'),
        ),
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
      // Quyết định của khách 2026-07-29: MỌI diễn giải đều là Premium, kể cả
      // tên nhu cầu chủ đạo. Free chỉ thấy khối khoá.
      expect(find.byKey(const Key('wr_discover_need_lock')), findsOneWidget);
      expect(find.byKey(const Key('wr_discover_seeking')), findsNothing);
      expect(find.text('KẾT NỐI · Nhu cầu chủ đạo'), findsNothing);
      // Không có câu diễn giải riêng cho người này ở tầng danh sách.
      expect(find.textContaining('ĐIỀU ĐỨNG SAU'), findsNothing);
    });

    testWidgets('bấm mở phần đọc vị thì paywall nói đúng ngữ cảnh',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);

      await _pump(
        tester,
        _wrap(const WrDiscoverScreen(), intel: intel, content: content),
      );

      await tester.tap(find.text('Mở phần đọc vị'));
      await tester.pumpAndSettle();

      expect(find.text('PAYWALL:need_reading'), findsOneWidget);
    });

    testWidgets('không có tình huống lặp lại thì không mời trả tiền',
        (tester) async {
      // Chưa có gì để đọc vị thì im lặng — không dựng khối khoá rỗng.
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      expect(find.byKey(const Key('wr_discover_need_lock')), findsNothing);
      expect(find.byKey(const Key('wr_discover_need_reading')), findsNothing);
    });

    testWidgets('premium đọc đủ ba lớp, không lộ mã hay chữ SCA',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)])
        ..seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        );
      final content = FakeWrContentRepository()..seedSituations([_sit]);

      await _pump(
        tester,
        _wrap(const WrDiscoverScreen(), intel: intel, content: content),
      );

      expect(find.byKey(const Key('wr_discover_need_lock')), findsNothing);
      expect(find.byKey(const Key('wr_discover_need_reading')), findsOneWidget);
      expect(find.text('MONG ĐỢI KẾT QUẢ'), findsOneWidget);
      expect(find.text('NHU CẦU CỐT LÕI'), findsOneWidget);
      // Trụ được gọi bằng tên đời thường, không phải chữ cái.
      expect(find.text('GÓC NHÌN · MỐI QUAN HỆ'), findsOneWidget);
      expect(
        find.textContaining('chưa chắc nói ra thì có an toàn'),
        findsOneWidget,
      );
      expect(find.textContaining('SCA'), findsNothing);
      expect(find.textContaining('sit-01'), findsNothing);
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

  // Yêu cầu khách 2026-07-29: màn ngoài chỉ ba tình huống lặp nhiều nhất, phần
  // còn lại nằm sau "Xem thêm" hoặc một màn riêng.
  group('Hiểu mình — chỉ ba dòng ngoài màn', () {
    List<PatternCount> manyPatterns(int n) => [
          for (var i = 0; i < n; i++)
            PatternCount(
              id: 'p$i',
              userId: 'u1',
              situationCode: 'sit-0$i',
              scaDimension: ScaDimension.c1,
              occurrenceCount: 10 - i,
              lastSeenAt: DateTime(2026, 7, 26),
            ),
        ];

    List<WrSituation> manySituations(int n) => [
          for (var i = 0; i < n; i++)
            WrSituation(
              code: 'sit-0$i',
              text: 'Tình huống số $i',
              scaDimension: ScaDimension.c1,
              wave: 1,
              humanNeed: HumanNeed.ketNoi,
            ),
        ];

    testWidgets('sáu tình huống thì chỉ hiện ba, kèm lối xem thêm',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts(manyPatterns(6));
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(6));

      await _pump(
        tester,
        _wrap(const WrDiscoverScreen(), intel: intel, content: content),
      );

      expect(find.text('Tình huống số 0'), findsOneWidget);
      expect(find.text('Tình huống số 2'), findsOneWidget);
      expect(find.text('Tình huống số 3'), findsNothing);
      expect(find.text('Xem thêm 3 điều lặp lại'), findsOneWidget);
    });

    testWidgets('đúng ba tình huống thì không hiện lối xem thêm',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts(manyPatterns(3));
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(3));

      await _pump(
        tester,
        _wrap(const WrDiscoverScreen(), intel: intel, content: content),
      );

      expect(find.byKey(const Key('wr_discover_see_more')), findsNothing);
    });

    testWidgets('bấm Xem thêm mở màn liệt kê đủ, vẫn không diễn giải',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts(manyPatterns(6));
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(6));

      await _pump(
        tester,
        _wrap(const WrDiscoverScreen(), intel: intel, content: content),
      );

      await tester.tap(find.byKey(const Key('wr_discover_see_more')));
      await tester.pumpAndSettle();

      for (var i = 0; i < 6; i++) {
        expect(find.text('Tình huống số $i'), findsOneWidget,
            reason: 'thiếu dòng $i ở màn đầy đủ');
      }
      expect(find.textContaining('ĐIỀU ĐỨNG SAU'), findsNothing);

      // Từ đây vẫn mở được chi tiết của từng dòng.
      await tester.tap(find.text('Tình huống số 4'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đã ghi lại điều này 6 lần.'), findsOneWidget);
    });
  });

  // v1.6 §XII.5: mã nội bộ (sit-01, C2-sit-01…) không bao giờ được hiện ra.
  // Đường lộ thật là lúc thư viện tình huống chưa tải xong hoặc mất mạng —
  // trước bản vá này, mỗi dòng hiện đúng cái mã.
  group('Hiểu mình — không phơi mã kỹ thuật', () {
    testWidgets('thiếu thư viện tình huống thì hiện nhãn chung, không hiện mã',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);
      // Thư viện rỗng: đúng cảnh mất mạng.
      final content = FakeWrContentRepository();

      await _pump(
        tester,
        _wrap(const WrDiscoverScreen(), intel: intel, content: content),
      );

      expect(find.textContaining('sit-01'), findsNothing);
      expect(find.text('Tình huống'), findsOneWidget);
      expect(find.text('3 lần'), findsOneWidget);
    });

    testWidgets('màn chi tiết cũng không rơi về mã', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );

      expect(find.textContaining('sit-01'), findsNothing);
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
      // Kể cả từng chữ cái một: ba vòng tròn "S · C · A" cũng là phơi bộ khung.
      for (final letter in ['S', 'C', 'A']) {
        expect(find.text(letter), findsNothing, reason: 'còn lộ chữ $letter');
      }
      // Ba trụ vẫn đọc được bằng tên đời thường.
      expect(find.text('Sự rõ ràng'), findsOneWidget);
      expect(find.text('Mối quan hệ'), findsOneWidget);
      expect(find.text('Cách làm việc'), findsOneWidget);
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
