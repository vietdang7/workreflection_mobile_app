// Màn "Diễn giải sâu & xu hướng" — changelog 24/08/2026 §7.
//
// §7 mở đầu bằng lỗi cần chữa: nút "Mở khoá" của tính năng này không có màn
// đích. Nhóm test đầu tiên khoá đúng chỗ đó — cả hai lối vào phải tới được màn.
//
// Run: flutter test test/features/wr_sca_deep_dive_screen_test.dart

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
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_sca_deep_dive_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

const _situations = <WrSituation>[
  WrSituation(
    code: 'S1-01',
    text: 'Vai trò chưa rõ',
    scaDimension: ScaDimension.s1,
    wave: 1,
  ),
  WrSituation(
    code: 'C2-01',
    text: 'Không dám nói',
    scaDimension: ScaDimension.c2,
    wave: 1,
  ),
];

ScaSelfCheckResponse _check({
  required DateTime at,
  double s = 3.0,
  double c = 3.0,
  double a = 3.0,
}) =>
    ScaSelfCheckResponse(
      userId: 'u1',
      answers: const {},
      takenAt: at,
      structureScore: s,
      cultureScore: c,
      activityScore: a,
    );

ReflectionEpisode _ep(String code, DateTime at) => ReflectionEpisode(
      userId: 'u1',
      humanMoment: HumanMoment.confusion,
      situationCode: code,
      openedAt: at,
    );

Widget _wrap({
  required bool premium,
  List<ScaSelfCheckResponse> history = const [],
  List<ReflectionEpisode> episodes = const [],
}) {
  final intel = FakeWrIntelligenceRepository()
    ..seedSelfCheckHistory(history)
    ..seedEntitlement(
      WrEntitlementRecord(
        userId: 'u1',
        plan: premium ? WrPlan.premium : WrPlan.free,
      ),
    );
  final content = FakeWrContentRepository()..seedSituations(_situations);
  final eps = FakeWrEpisodeRepository()..seed(episodes);

  final router = GoRouter(
    initialLocation: '/wr/sca-deep-dive',
    routes: [
      GoRoute(
        path: '/wr/sca-deep-dive',
        builder: (_, __) => const WrScaDeepDiveScreen(),
      ),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('PAYWALL')),
      ),
      GoRoute(
        path: '/wr/self-check',
        builder: (_, __) => const Scaffold(body: Text('SELF-CHECK')),
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

void main() {
  setUp(() {
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

  // `DienGiaiSau v2 §7` đổi khối "Từng trụ một" thành "Xem chi tiết theo nhóm",
  // đóng mặc định, và ĐỔI HẲN NỘI DUNG bên trong. §1.3: khối cũ hiện nhãn mức
  // đánh giá cộng số lần xuất hiện — cả hai đã có nguyên ở Career Snapshot bản
  // miễn phí — cộng một câu gần như giống hệt nhau ba lần.
  testWidgets('Premium: ba nhóm đóng sẵn, bấm mở ra tình huống cụ thể',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(
      premium: true,
      history: [
        _check(at: now.subtract(const Duration(days: 40)), s: 2.0),
        _check(at: now.subtract(const Duration(days: 2)), s: 4.2),
      ],
      episodes: [
        for (var i = 0; i < 4; i++)
          _ep('C2-01', now.subtract(Duration(days: i))),
      ],
    ));
    await tester.pumpAndSettle();

    for (final p in ['s', 'c', 'a']) {
      expect(find.byKey(Key('wr_sca_deep_dive_pillar_$p')), findsOneWidget);
      // Nhãn mức đánh giá đã bỏ — nó trùng nguyên cột "Bạn đánh giá" của
      // Career Snapshot (nghiệm thu §9 việc 5).
      expect(find.byKey(Key('wr_sca_deep_dive_status_$p')), findsNothing);
      // Đóng mặc định, cả ba.
      expect(find.byKey(Key('wr_sca_deep_dive_trend_$p')), findsNothing);
    }

    await tester.tap(find.byKey(const Key('wr_deep_pillar_toggle_c')));
    await tester.pumpAndSettle();

    // Mở ra: câu so với lần Self-Check trước, cộng tình huống cụ thể của nhóm.
    expect(find.byKey(const Key('wr_sca_deep_dive_trend_c')), findsOneWidget);
    expect(find.byKey(const Key('wr_deep_pillar_sit_C2-01')), findsOneWidget);
    // Và KHÔNG còn câu đối chiếu pattern theo trụ.
    expect(find.byKey(const Key('wr_sca_deep_dive_pattern_c')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('wr_sca_deep_dive_footnote')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('wr_sca_deep_dive_footnote')), findsOneWidget);
  });

  // Phép thử cuối của §9.1, dựng lại đúng hình dạng tài khoản khách báo lỗi.
  testWidgets('Premium: khối chính gọi tên một tình huống kèm số lần',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(
      premium: true,
      history: [_check(at: now.subtract(const Duration(days: 1)), c: 4.5)],
      episodes: [
        for (var i = 0; i < 20; i++)
          _ep('C2-01', now.subtract(Duration(days: i % 25))),
      ],
    ));
    await tester.pumpAndSettle();

    final lead = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('wr_deep_lead')),
        matching: find.byType(Text),
      ),
    );
    expect(lead.data, contains('Không dám nói'));
    expect(lead.data, contains('20'));
  });

  testWidgets('Premium: những vòng lặp quen thuộc bày ngay dưới khối chính',
      (tester) async {
    // §7 khối phụ. Nó là chính lớp dữ liệu khối chính vừa đọc, nên bày ra để
    // người dùng kiểm chứng được thay vì phải tin.
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(
      premium: true,
      episodes: [
        for (var i = 0; i < 12; i++)
          _ep('C2-01', now.subtract(Duration(days: i))),
        for (var i = 0; i < 4; i++)
          _ep('S1-01', now.subtract(Duration(days: 12 + i))),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wr_deep_loop_C2-01')), findsOneWidget);
    expect(find.byKey(const Key('wr_deep_loop_S1-01')), findsOneWidget);
  });

  testWidgets('Premium: lần Self-Check đầu tiên thì nói rõ chưa có gì để so',
      (tester) async {
    await tester.pumpWidget(_wrap(
      premium: true,
      history: [_check(at: DateTime.now())],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wr_deep_pillar_toggle_s')));
    await tester.pumpAndSettle();

    final trend = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('wr_sca_deep_dive_trend_s')),
        matching: find.byType(Text),
      ),
    );
    expect(trend.data, contains('lần tự soi đầu tiên'));
    expect(
      find.textContaining('Self-Check trước đó: chưa có'),
      findsOneWidget,
    );
  });

  testWidgets('Premium, đã nhìn lại đều mà chưa Self-Check: vẫn có khối chính',
      (tester) async {
    // §4 — bốn trong năm bậc không cần Self-Check. Người vừa trả tiền mà gặp
    // màn hình rỗng trong khi họ đã nhìn lại đều đặn hai tháng là đúng cái §6
    // gọi là phần dễ làm hỏng trải nghiệm nhất.
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(
      premium: true,
      episodes: [
        for (var i = 0; i < 12; i++)
          _ep('C2-01', now.subtract(Duration(days: i))),
        for (var i = 0; i < 12; i++)
          _ep('S1-01', now.subtract(Duration(days: 31 + i))),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wr_sca_deep_dive_empty')), findsNothing);
    expect(find.byKey(const Key('wr_deep_lead')), findsOneWidget);
    expect(find.byKey(const Key('wr_deep_trend')), findsOneWidget);
    // Không có mức nào để bày thì khối "Xem chi tiết theo nhóm" vắng mặt, thay
    // bằng một lời mời NGẮN ở cuối — Self-Check giờ mở thêm một lớp, không còn
    // là cửa vào.
    expect(find.byKey(const Key('wr_sca_deep_dive_pillar_s')), findsNothing);
    expect(find.byKey(const Key('wr_deep_no_self_check_yet')), findsOneWidget);
  });

  testWidgets('Premium: hai đoạn chờ rút thành một dòng ở cuối', (tester) async {
    // §6 điều chỉnh 2: "hai đoạn giải thích dài về việc chờ thêm đang chiếm
    // nhiều diện tích hơn cả phần nội dung thật."
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(
      premium: true,
      history: [_check(at: now.subtract(const Duration(days: 1)))],
      episodes: [
        for (var i = 0; i < 16; i++)
          _ep('C2-01', now.subtract(Duration(days: i))),
      ],
    ));
    await tester.pumpAndSettle();

    // Cả khối XU HƯỚNG vắng mặt, không còn hai đoạn dài giữa màn.
    expect(find.byKey(const Key('wr_deep_trend')), findsNothing);
    expect(find.byKey(const Key('wr_deep_self_check_trend')), findsNothing);
    // Thay bằng ĐÚNG MỘT dòng.
    expect(find.byKey(const Key('wr_deep_waiting_line')), findsOneWidget);
  });

  testWidgets('Premium, chưa có gì cả: mời đi làm 15 câu', (tester) async {
    await tester.pumpWidget(_wrap(premium: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wr_sca_deep_dive_empty')), findsOneWidget);
    await tester
        .tap(find.byKey(const Key('wr_sca_deep_dive_start_self_check')));
    await tester.pumpAndSettle();
    expect(find.text('SELF-CHECK'), findsOneWidget);
  });

  // Vào thẳng route mà chưa mua — deep link, hoặc quyền hết hạn giữa chừng.
  testWidgets('Free: không thấy nội dung, chỉ thấy lối mua', (tester) async {
    await tester.pumpWidget(_wrap(
      premium: false,
      history: [_check(at: DateTime.now())],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wr_sca_deep_dive_locked')), findsOneWidget);
    expect(find.byKey(const Key('wr_sca_deep_dive_pillar_s')), findsNothing);

    await tester.tap(find.text('Mở diễn giải sâu'));
    await tester.pumpAndSettle();
    expect(find.text('PAYWALL'), findsOneWidget);
  });
}
