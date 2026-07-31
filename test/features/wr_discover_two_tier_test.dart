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

/// Episode mang mã tình huống, mỗi mã lặp đúng số lần yêu cầu.
///
/// Từ 2026-07-31 mọi khối "đang phản chiếu về điều gì" đọc recentSituationIds —
/// tức chính bảng Episode (Kiến trúc v2.0 §4.3) — nên test phải gieo Episode
/// thật thay vì gieo con số tích luỹ trong `wr_pattern_counts`.
///
/// `openedAt` là mốc sắp xếp: recentSituationIds tính từ lúc CHỌN tình huống.
List<ReflectionEpisode> _episodes(
  Map<String, int> countByCode, {
  DateTime? from,
}) {
  final base = from ?? DateTime(2026, 7, 20);
  final list = <ReflectionEpisode>[];
  var i = 0;
  countByCode.forEach((code, times) {
    for (var k = 0; k < times; k++) {
      i++;
      list.add(ReflectionEpisode(
        id: 'e\${base.month}\${base.day}-\$i',
        userId: 'u1',
        humanMoment: HumanMoment.confusion,
        state: ExperienceState.integrated,
        situationCode: code,
        openedAt: base.add(Duration(hours: i)),
        closedAt: base.add(Duration(hours: i)),
      ));
    }
  });
  return list;
}

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
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
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
      // Gieo EPISODE, không gieo `wr_pattern_counts`: từ 2026-07-31 nhu cầu chủ
      // đạo đọc từ recentSituationIds (Kiến trúc v2.0 §4.3).
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
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
        ..seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        );
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
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
      // Con số này giờ chỉ còn một chỗ hiện: thẻ Career Health. Mục "Hành trình
      // đã đi" ở cuối màn đã bỏ vì nói lại đúng con số đó.
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

      expect(
        find.textContaining('Bạn đã nhìn lại 2/15 lần'),
        findsOneWidget,
      );
    });

    testWidgets('bấm một dòng mở màn chi tiết riêng', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
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

    // Mỗi tình huống phải lặp ≥ kRepeatedSituationsMinCount mới lên bảng (yêu
    // cầu khách 2026-07-31), và cửa sổ chỉ giữ 30 lượt gần nhất — bốn tình
    // huống × 3 lần = 12 lượt, vừa đủ để kiểm tra "chỉ ba dòng ngoài màn".
    testWidgets('bốn tình huống lặp lại thì chỉ hiện ba, kèm lối xem thêm',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts(manyPatterns(6));
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(6));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({
          'sit-00': 4,
          'sit-01': 4,
          'sit-02': 3,
          'sit-03': 3,
        }));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.text('Tình huống số 0'), findsOneWidget);
      expect(find.text('Tình huống số 2'), findsOneWidget);
      expect(find.text('Tình huống số 3'), findsNothing);
      expect(find.text('Xem thêm 1 điều lặp lại'), findsOneWidget);
    });

    testWidgets('dưới ngưỡng lặp thì chưa lên bảng', (tester) async {
      // Yêu cầu khách 2026-07-31: "chỉ hiện từ 3 lần trở lên, cái nào được chọn
      // nhiều thì hiển thị lên". Gặp một hai lần là chuyện vừa xảy ra, chưa
      // phải nếp — để lọt lên thì bảng toàn dòng "1 lần" và điều đang thật sự
      // trở đi trở lại chìm mất.
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(3));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 3, 'sit-01': 2, 'sit-02': 1}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.text('Tình huống số 0'), findsOneWidget);
      expect(find.text('Tình huống số 1'), findsNothing);
      expect(find.text('Tình huống số 2'), findsNothing);
      // Hai dòng bị chặn không được tính vào "Xem thêm" — con số đó hứa cái gì
      // thì màn đầy đủ phải có đúng cái đó.
      expect(find.byKey(const Key('wr_discover_see_more')), findsNothing);
    });

    testWidgets('đã ghi lại nhưng chưa điều nào tới ngưỡng: nói rõ, '
        'không báo rỗng như chưa từng ghi', (tester) async {
      // Hai trạng thái rỗng khác hẳn nhau. Đọc phải câu "sau vài lần nhìn lại"
      // sau khi đã phản tư mấy lần thì người dùng tưởng app nuốt mất dữ liệu.
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(2));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 2, 'sit-01': 2}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.byKey(const Key('wr_discover_patterns_empty')), findsNothing);
      expect(
        find.byKey(const Key('wr_discover_patterns_below_threshold')),
        findsOneWidget,
      );
      expect(find.textContaining('4 lần'), findsOneWidget);
    });

    testWidgets('chỉ đếm trong 30 lần nhìn lại gần nhất', (tester) async {
      // Tình huống cũ lặp 3 lần nhưng đã bị 30 lượt mới hơn đẩy ra khỏi cửa sổ
      // thì biến mất khỏi tấm gương — màn này soi hiện tại, không soi lịch sử.
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(3));
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          ..._episodes({'sit-02': 3}, from: DateTime(2026, 6, 1)),
          ..._episodes({'sit-00': 16, 'sit-01': 14},
              from: DateTime(2026, 8, 1)),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.text('Tình huống số 0'), findsOneWidget);
      expect(find.text('Tình huống số 1'), findsOneWidget);
      expect(find.text('Tình huống số 2'), findsNothing);
    });

    testWidgets('đúng ba tình huống thì không hiện lối xem thêm',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts(manyPatterns(3));
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(3));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 3, 'sit-01': 3, 'sit-02': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.byKey(const Key('wr_discover_see_more')), findsNothing);
    });

    testWidgets('bấm Xem thêm mở màn liệt kê đủ, vẫn không diễn giải',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts(manyPatterns(6));
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(6));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({
          'sit-00': 4,
          'sit-01': 4,
          'sit-02': 3,
          'sit-03': 3,
        }));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      await tester.tap(find.byKey(const Key('wr_discover_see_more')));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        expect(find.text('Tình huống số $i'), findsOneWidget,
            reason: 'thiếu dòng $i ở màn đầy đủ');
      }
      expect(find.textContaining('ĐIỀU ĐỨNG SAU'), findsNothing);

      // Từ đây vẫn mở được chi tiết của từng dòng. Màn chi tiết đọc con số tích
      // luỹ của cả hành trình (`wr_pattern_counts`), không đọc cửa sổ 10 —
      // "đã ghi lại bao nhiêu lần" là câu hỏi về cả chặng đường.
      await tester.tap(find.text('Tình huống số 3'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đã ghi lại điều này 7 lần.'), findsOneWidget);
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
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
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
      // Dòng chân thẻ "Chưa tự đánh giá lần nào / Đã tự đánh giá N lần" đã bỏ:
      // ba nhãn "Chưa đánh giá" ở trên đã nói đúng điều đó rồi.
      expect(find.textContaining('tự đánh giá'), findsNothing);
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
      expect(find.textContaining('tự đánh giá'), findsNothing);
    });

    test('ngưỡng trạng thái trụ giữ đúng như màn Tự đánh giá', () {
      expect(pillarStatusLabel(null), 'Chưa đánh giá');
      expect(pillarStatusLabel(0), 'Chưa đánh giá');
      expect(pillarStatusLabel(1.8), 'Ưu tiên cải thiện');
      expect(pillarStatusLabel(2.5), 'Cần chú ý');
      expect(pillarStatusLabel(3.8), 'Đang phát triển');
    });
  });

  // Hai khối lấy từ mockup Sprint 2 §screenUnderstand: lời mời làm bộ 15 câu và
  // khối Premium "Diễn giải sâu & theo dõi xu hướng".
  group('Hiểu mình — lời mời Self-Check', () {
    testWidgets('chưa làm lần nào thì mời bắt đầu', (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      expect(
        find.byKey(const Key('wr_discover_self_check_invite')),
        findsOneWidget,
      );
      expect(find.text('Tiến độ lần gần nhất: 0/15'), findsOneWidget);
      expect(find.text('Bắt đầu Self-Check'), findsOneWidget);
      expect(find.text('Làm lại Self-Check'), findsNothing);
      expect(
        find.textContaining('15 câu hỏi tình huống ngắn'),
        findsOneWidget,
      );
    });

    testWidgets('đã làm rồi thì đổi thành lời mời làm lại', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: {for (var i = 1; i <= 15; i++) 'q$i': 4},
            structureScore: 4,
            cultureScore: 4,
            activityScore: 4,
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

      expect(find.text('Tiến độ lần gần nhất: 15/15'), findsOneWidget);
      expect(find.text('Làm lại Self-Check'), findsOneWidget);
      expect(find.text('Bắt đầu Self-Check'), findsNothing);
    });

    testWidgets('bấm là mở bộ câu hỏi', (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      await tester.tap(find.text('Bắt đầu Self-Check'));
      await tester.pumpAndSettle();

      expect(find.text('SELFCHECK'), findsOneWidget);
    });

    testWidgets('free thấy khối diễn giải sâu, bấm ra đúng ngữ cảnh paywall',
        (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      expect(
        find.byKey(const Key('wr_discover_sca_deep_lock')),
        findsOneWidget,
      );
      expect(find.text('Diễn giải sâu & theo dõi xu hướng'), findsOneWidget);

      await tester.tap(find.text('Mở khoá'));
      await tester.pumpAndSettle();

      expect(find.text('PAYWALL:sca_deep'), findsOneWidget);
    });

    testWidgets('cả màn chỉ còn ĐÚNG HAI con số', (tester) async {
      // Yêu cầu khách 2026-07-31 (vòng cuối): số lần nhìn lại ở Career Health,
      // và số câu của lần Self-Check gần nhất. Không con số nào khác.
      //
      // Trước đó màn có tới bốn: "Đã tự đánh giá 7 lần", "5/15 Reflection",
      // "Tiến độ lần gần nhất: 12/15", "Bạn đã nhìn lại 16 lần" — hai trong số
      // đó đếm cùng một thứ bằng hai đơn vị.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 5}));
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: {for (var i = 1; i <= 15; i++) 'q$i': 3},
            structureScore: 3,
            cultureScore: 3,
            activityScore: 3,
            takenAt: DateTime(2026, 7, 26),
          ),
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: {for (var i = 1; i <= 15; i++) 'q$i': 3},
            structureScore: 3,
            cultureScore: 3,
            activityScore: 3,
            takenAt: DateTime(2026, 7, 20),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
          episodes: episodes,
        ),
      );

      expect(find.textContaining('Bạn đã nhìn lại 5/15 lần'), findsOneWidget);
      expect(find.text('Tiến độ lần gần nhất: 15/15'), findsOneWidget);

      // Ba con số cũ đã biến mất hẳn.
      expect(find.text('Bạn đã nhìn lại 5 lần.'), findsNothing);
      expect(find.text('HÀNH TRÌNH ĐÃ ĐI'), findsNothing);
      expect(find.textContaining('tự đánh giá'), findsNothing);
    });

    testWidgets('bản ghi thiếu câu thì nói đúng số thật, không làm tròn',
        (tester) async {
      // Di chứng của lỗi nuốt câu (đã vá): bản 30/7 trên DB thật chỉ còn 12/15.
      // Hiện "15/15" ở đây là nói dối về dữ liệu đang có.
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: {for (var i = 1; i <= 12; i++) 'q$i': 3},
            structureScore: 3,
            cultureScore: 3,
            activityScore: 3,
            takenAt: DateTime(2026, 7, 30),
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

      expect(find.text('Tiến độ lần gần nhất: 12/15'), findsOneWidget);
    });

    testWidgets('quá ngưỡng thì hiện đúng số thật, không chặn ở 15',
        (tester) async {
      // Đã nhìn lại 16 lần mà thẻ nói "15/15" là bớt đi công của người dùng.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 16}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
          episodes: episodes,
        ),
      );

      expect(
        find.textContaining('Bạn đã nhìn lại 16/15 lần'),
        findsOneWidget,
      );
    });

    testWidgets('premium không bị mời mua lại thứ đã mua', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        );

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );

      expect(find.byKey(const Key('wr_discover_sca_deep_lock')), findsNothing);
      // Lời mời làm bộ câu hỏi thì vẫn còn — nó không phải thứ phải trả tiền.
      expect(
        find.byKey(const Key('wr_discover_self_check_invite')),
        findsOneWidget,
      );
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
