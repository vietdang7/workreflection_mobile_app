// Tab Hành trình chỉ hiện vài mảnh Career Memory gần nhất; phần còn lại nằm ở
// màn riêng /wr/career-memory.
//
// Yêu cầu khách 2026-08-01: "mục bảng Career memory nó dài quá, thêm nút ẩn bớt
// lại, cần thì ấn vào chuyển sang trang để hiển thị hết ra".
//
// Run: flutter test test/features/wr_career_memory_preview_test.dart

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
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// [n] mảnh ký ức, mỗi mảnh một ngày khác nhau để tiêu đề dễ phân biệt.
List<CareerMemoryEvent> _events(int n) => [
      for (var i = 1; i <= n; i++)
        CareerMemoryEvent(
          id: 'e$i',
          userId: 'u1',
          behavior: 'insight',
          reflectionText: 'Mảnh ký ức số $i',
          createdAt: DateTime(2026, 7, 1).add(Duration(days: i)),
        ),
    ];

/// Trộn nhiều loại để có gì mà lọc: `insight` → NHẬN RA, `decision` → QUYẾT
/// ĐỊNH. Số lượng lệch nhau để kiểm luôn thứ tự chip (nhiều trước).
List<CareerMemoryEvent> _mixedEvents() => [
      for (var i = 1; i <= 5; i++)
        CareerMemoryEvent(
          id: 'i$i',
          userId: 'u1',
          behavior: 'insight',
          reflectionText: 'Nhận ra $i',
          createdAt: DateTime(2026, 7, 1).add(Duration(days: i)),
        ),
      for (var i = 1; i <= 2; i++)
        CareerMemoryEvent(
          id: 'd$i',
          userId: 'u1',
          behavior: 'decision',
          reflectionText: 'Quyết định $i',
          createdAt: DateTime(2026, 7, 10).add(Duration(days: i)),
        ),
    ];

Widget _wrap({
  required Widget home,
  required List<CareerMemoryEvent> events,
  bool premium = true,
  List<ReflectionEpisode> episodes = const [],
}) {
  final content = FakeWrContentRepository()..seedMemoryEvents(events);
  final episodeRepo = FakeWrEpisodeRepository()..seed(episodes);
  final intel = FakeWrIntelligenceRepository();
  if (premium) {
    intel.seedEntitlement(
      WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
    );
  }

  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => home),
      GoRoute(
        path: '/wr/career-memory',
        builder: (_, __) => const WrCareerMemoryScreen(),
      ),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('PaywallScreen')),
      ),
      GoRoute(
        path: '/wr/journey/narrative',
        builder: (_, __) => const Scaffold(body: Text('Narrative')),
      ),
      GoRoute(
        path: '/wr/discover',
        builder: (_, __) => const Scaffold(body: Text('DiscoverScreen')),
      ),
      GoRoute(
        path: '/wr/ask',
        builder: (_, __) => const Scaffold(body: Text('AskScreen')),
      ),
      GoRoute(
        path: '/wr/work-info',
        builder: (_, __) => const Scaffold(body: Text('WorkInfo')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('Profile')),
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
      builder: wrTextScaleBuilder,routerConfig: router),
  );
}

Future<void> _pumpTall(WidgetTester tester, Widget widget) async {
  // Màn cao để mọi thứ nằm trong cây widget — bài test này đếm số dòng, không
  // kiểm cuộn.
  tester.view.physicalSize = const Size(1080, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

/// Đếm số mốc đang hiện trên dòng thời gian.
///
/// Đếm theo MŨI TÊN thu gọn, không theo tiêu đề mốc. Từ 2026-08-03 mỗi mốc thu
/// gọn sẵn nên tiêu đề không hiện cho tới khi người dùng chạm vào, còn mũi tên
/// thì mỗi mốc đúng một cái — nó mới là thứ tương ứng một-một với "có bao nhiêu
/// mảnh đang bày ra", chính là điều các bài kiểm này muốn nói.
int _visibleEntries(WidgetTester tester, int total) =>
    find.byIcon(Icons.keyboard_arrow_down_rounded).evaluate().length;

/// Mở hết mọi mốc đang hiện, để kiểm được NỘI DUNG bên trong.
///
/// Chạm từ mốc cuối ngược lên đầu: mở một mốc làm trang dài ra và đẩy mọi mốc
/// phía dưới xuống, nên đi xuôi thì từ mốc thứ hai trở đi toạ độ đã lệch.
Future<void> _expandAll(WidgetTester tester) async {
  final arrows = find.byIcon(Icons.keyboard_arrow_down_rounded);
  for (var i = arrows.evaluate().length - 1; i >= 0; i--) {
    await tester.tap(arrows.at(i), warnIfMissed: false);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  // ---------------------------------------------------------------------------
  // "Dữ liệu trong app chưa được kết nối với nhau" — câu mở đầu phản hồi của
  // khách 2026-08-24.
  //
  // Dựng lại ĐÚNG dữ liệu của chị trên DB hôm đó: 15 Episode, trong đó 13 đã
  // khép, cộng 8 dấu mốc thực hành. Tab Hiểu mình nói "15 lần nhìn lại"; tab
  // này nói "21 mảnh ký ức". Cả hai đều đúng, nhưng không nơi nào nói ra vì sao
  // chúng khác nhau, nên người dùng chỉ còn cách kết luận là app đếm sai.
  // ---------------------------------------------------------------------------
  group('Mảnh ký ức tự giải thích con số của mình', () {
    List<ReflectionEpisode> episodesFor({required int total, required int closed}) => [
          for (var i = 1; i <= total; i++)
            ReflectionEpisode(
              id: 'ep$i',
              userId: 'u1',
              humanMoment: HumanMoment.confusion,
              state: i <= closed
                  ? ExperienceState.integrated
                  : ExperienceState.exploring,
              situationCode: 'C1-sit-01',
              openedAt: DateTime(2026, 8, 1).add(Duration(hours: i)),
              closedAt: DateTime(2026, 8, 1).add(Duration(hours: i)),
            ),
        ];

    testWidgets('tách con số thành các phần hợp thành nó', (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          home: const WrJourneyScreen(),
          events: _events(8),
          episodes: episodesFor(total: 15, closed: 13),
        ),
      );

      // 13 Episode đã khép + 8 dấu mốc = 21, đúng con số trên ảnh khách gửi.
      expect(
        find.text('Bạn đã để lại 21 mảnh ký ức nghề nghiệp.'),
        findsOneWidget,
        reason: 'phép cộng phải khớp dữ liệu thật của khách',
      );
      expect(
        find.textContaining('Gồm 13 lần nhìn lại đã khép và 8 dấu mốc'),
        findsOneWidget,
      );
      // Và phải nói thẳng vì sao tab Hiểu mình hiện một con số khác.
      expect(find.textContaining('tab Hiểu mình'), findsOneWidget);
    });

    testWidgets('chưa có dấu mốc nào thì không bịa vế thứ hai', (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          home: const WrJourneyScreen(),
          events: const [],
          episodes: episodesFor(total: 6, closed: 6),
        ),
      );

      expect(find.textContaining('Gồm 6 lần nhìn lại đã khép.'), findsOneWidget);
      expect(find.textContaining('dấu mốc thực hành'), findsNothing);
    });

    testWidgets('chưa có gì thì không hiện dòng giải thích', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrJourneyScreen(), events: const []),
      );

      expect(
        find.byKey(const Key('wr_journey_memory_breakdown')),
        findsNothing,
      );
    });
  });

  group('Tab Hành trình — Career Memory rút gọn', () {
    testWidgets('nhiều hơn ngưỡng thì chỉ hiện $kJourneyPreviewCount mảnh',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrJourneyScreen(), events: _events(38)),
      );

      expect(_visibleEntries(tester, 38), kJourneyPreviewCount);
    });

    testWidgets('hiện nút xem tất cả kèm tổng số và số còn lại', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrJourneyScreen(), events: _events(38)),
      );

      expect(find.byKey(const Key('wr_journey_memory_see_all')), findsOneWidget);
      expect(find.text('Xem tất cả 38 mảnh ký ức'), findsOneWidget);
      expect(find.text('Còn 33 mảnh nữa'), findsOneWidget);
    });

    testWidgets('vừa đúng ngưỡng thì không có nút — không giấu gì cả',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          home: const WrJourneyScreen(),
          events: _events(kJourneyPreviewCount),
        ),
      );

      expect(_visibleEntries(tester, kJourneyPreviewCount), kJourneyPreviewCount);
      expect(find.byKey(const Key('wr_journey_memory_see_all')), findsNothing);
    });

    testWidgets('bản miễn phí vẫn bị khoá, không lòi nút xem tất cả',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          home: const WrJourneyScreen(),
          events: _events(38),
          premium: false,
        ),
      );

      expect(find.byKey(const Key('wr_journey_memory_lock')), findsOneWidget);
      expect(find.byKey(const Key('wr_journey_memory_see_all')), findsNothing);
      expect(_visibleEntries(tester, 38), 0);
    });

    testWidgets('bấm nút thì sang màn Career Memory đầy đủ', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrJourneyScreen(), events: _events(38)),
      );

      await tester.tap(find.byKey(const Key('wr_journey_memory_see_all')));
      await tester.pumpAndSettle();

      expect(find.text('Tất cả 38 mảnh ký ức'), findsOneWidget);
    });
  });

  group('WrCareerMemoryScreen', () {
    testWidgets('liệt kê đủ mọi mảnh, không cắt bớt', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: _events(38)),
      );

      expect(_visibleEntries(tester, 38), 38);
    });

    // Khách 2026-08-01: "nên phân theo ngày trong tuần, tuần trong tháng".
    testWidgets('dựng đủ ba tầng tháng · tuần · ngày', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: _events(10)),
      );

      // Tháng — sự kiện rơi vào 02/07 đến 11/07/2026.
      expect(find.text('THÁNG 7, 2026'), findsOneWidget);
      // Tuần — có số thứ tự và khoảng ngày, cắt theo biên tháng.
      expect(find.textContaining('TUẦN 1 · '), findsOneWidget);
      expect(find.textContaining('TUẦN 2 · '), findsOneWidget);
      // Ngày — mang tên thứ, không phải "02/07" trơ trọi.
      expect(find.text('Thứ Năm, 02/07'), findsOneWidget);
      expect(find.text('Thứ Bảy, 11/07'), findsOneWidget);
    });

    testWidgets('ngày không bị in lại trên từng dòng dưới tiêu đề ngày',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: _events(1)),
      );

      expect(find.text('Thứ Năm, 02/07'), findsOneWidget);
      // Dòng bên dưới trước đây in thêm "02/07" — giờ ngày chỉ nói một lần.
      expect(find.text('02/07'), findsNothing);
    });

    // Bộ lọc theo loại — yêu cầu khách 2026-08-01.
    testWidgets('hàng chip dựng từ loại thật có trong dữ liệu, nhiều trước',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: _mixedEvents()),
      );

      expect(find.byKey(const Key('wr_career_memory_filter_bar')),
          findsOneWidget);
      expect(find.text('Tất cả 7'), findsOneWidget);
      expect(find.text('NHẬN RA 5'), findsOneWidget);
      expect(find.text('QUYẾT ĐỊNH 2'), findsOneWidget);
      // Loại không có mặt thì không có chip — chip 0 mục là lời hứa suông.
      expect(find.textContaining('KỸ NĂNG'), findsNothing);
    });

    testWidgets('chọn một loại thì chỉ còn mục thuộc loại đó', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: _mixedEvents()),
      );

      await tester
          .tap(find.byKey(const Key('wr_career_memory_filter_QUYẾT ĐỊNH')));
      await tester.pumpAndSettle();
      await _expandAll(tester);

      expect(find.text('Quyết định 1'), findsOneWidget);
      expect(find.text('Nhận ra 1'), findsNothing);
      // Tiêu đề nói đúng số đang xem, không giữ nguyên tổng.
      expect(find.text('2 mảnh · quyết định'), findsOneWidget);
    });

    testWidgets('mọi chip vẫn còn sau khi lọc — luôn có đường quay lại',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: _mixedEvents()),
      );

      await tester
          .tap(find.byKey(const Key('wr_career_memory_filter_QUYẾT ĐỊNH')));
      await tester.pumpAndSettle();

      expect(find.text('NHẬN RA 5'), findsOneWidget);
      expect(find.text('Tất cả 7'), findsOneWidget);
    });

    testWidgets('bấm lại chip đang chọn thì bỏ lọc', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: _mixedEvents()),
      );

      final chip = find.byKey(const Key('wr_career_memory_filter_QUYẾT ĐỊNH'));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('Tất cả 7 mảnh ký ức'), findsOneWidget);
      await _expandAll(tester);
      expect(find.text('Nhận ra 1'), findsOneWidget);
    });

    testWidgets('chỉ một loại thì không dựng hàng chip', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: _events(6)),
      );

      expect(find.byKey(const Key('wr_career_memory_filter_bar')), findsNothing);
    });

    testWidgets('bản miễn phí bị khoá — mở thẳng đường dẫn không đi vòng được',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          home: const WrCareerMemoryScreen(),
          events: _events(38),
          premium: false,
        ),
      );

      expect(find.byKey(const Key('wr_career_memory_lock')), findsOneWidget);
      expect(_visibleEntries(tester, 38), 0);
    });

    testWidgets('chưa có mảnh nào thì nói rõ, không để trang trắng',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: const []),
      );

      expect(find.byKey(const Key('wr_career_memory_empty')), findsOneWidget);
    });
  });
}
