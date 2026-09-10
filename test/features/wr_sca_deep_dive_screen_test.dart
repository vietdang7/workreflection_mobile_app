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

  // §8 đảo lại cấu trúc màn: bản trước in 3 trụ × 3 lớp = 9 khối văn bản, và
  // tài liệu gọi thẳng đó là một bản báo cáo người dùng sẽ lướt qua. Nay ba trụ
  // ở dạng RÚT GỌN — luôn thấy tên và mức, ba lớp chữ chỉ hiện khi bấm mở.
  //
  // Việc cần khoá không còn là "ba lớp luôn hiện" mà là "ba lớp vẫn TỚI ĐƯỢC".
  testWidgets('Premium: ba trụ rút gọn, bấm mở là đủ ba lớp', (tester) async {
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
      expect(find.byKey(Key('wr_sca_deep_dive_status_$p')), findsOneWidget);

      // Chưa bấm thì hàng chỉ có tên và mức.
      if (find.byKey(Key('wr_sca_deep_dive_trend_$p')).evaluate().isEmpty) {
        await tester.tap(find.byKey(Key('wr_deep_pillar_toggle_$p')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(Key('wr_sca_deep_dive_trend_$p')), findsOneWidget);
      expect(find.byKey(Key('wr_sca_deep_dive_pattern_$p')), findsOneWidget);
    }
    expect(find.byKey(const Key('wr_sca_deep_dive_footnote')), findsOneWidget);
  });

  testWidgets('Premium: trụ nói ở đoạn dẫn dắt được mở sẵn', (tester) async {
    // Người vừa đọc xong một đoạn về trụ đó mà còn phải tự tìm rồi bấm mở lần
    // nữa để xem chi tiết là bắt họ làm việc thừa.
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

    expect(find.byKey(const Key('wr_deep_lead')), findsOneWidget);
    // C là trụ nổi trội → mở sẵn; hai trụ kia vẫn rút gọn.
    expect(find.byKey(const Key('wr_sca_deep_dive_pattern_c')), findsOneWidget);
    expect(find.byKey(const Key('wr_sca_deep_dive_pattern_s')), findsNothing);
    expect(find.byKey(const Key('wr_sca_deep_dive_pattern_a')), findsNothing);
  });

  testWidgets('Premium: trụ nổi bật trong Reflection được chỉ ra',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(
      premium: true,
      // C tự chấm cao nhất, nhưng lại là nhóm quay lại nhiều nhất — đúng thứ
      // §7 gọi là "lệch pha tự nhận thức".
      history: [_check(at: now.subtract(const Duration(days: 1)), c: 4.5)],
      episodes: [
        for (var i = 0; i < 3; i++)
          _ep('C2-01', now.subtract(Duration(days: i))),
      ],
    ));
    await tester.pumpAndSettle();

    final pattern = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('wr_sca_deep_dive_pattern_c')),
        matching: find.byType(Text),
      ),
    );
    expect(pattern.data, contains('quay lại nhiều nhất'));
    expect(pattern.data, contains('3 lần'));
  });

  testWidgets('Premium: lần Self-Check đầu tiên thì nói rõ chưa có gì để so',
      (tester) async {
    await tester.pumpWidget(_wrap(
      premium: true,
      history: [_check(at: DateTime.now())],
    ));
    await tester.pumpAndSettle();

    // Chưa nhìn lại lần nào nên không trụ nào nổi trội, cả ba đều rút gọn.
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

  testWidgets('Premium, đã nhìn lại đều mà chưa Self-Check: vẫn có xu hướng',
      (tester) async {
    // §4 — tầng 2 KHÔNG cần Self-Check. Người vừa trả tiền mà gặp màn hình rỗng
    // trong khi họ đã nhìn lại đều đặn hai tháng là đúng cái §6 gọi là phần dễ
    // làm hỏng trải nghiệm nhất.
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
    expect(find.byKey(const Key('wr_deep_trend')), findsOneWidget);
    // Không có mức nào để bày thì phần "TỪNG TRỤ MỘT" vắng mặt, thay bằng lời
    // mời làm 15 câu.
    expect(find.byKey(const Key('wr_sca_deep_dive_pillar_s')), findsNothing);
    expect(find.byKey(const Key('wr_deep_no_self_check_yet')), findsOneWidget);
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
