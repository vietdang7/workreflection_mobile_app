// Thẻ nhắc điền hồ sơ trên màn Hôm nay + trạng thái rỗng của "Insight gần nhất"
// — mockup Sprint 2 bản (4), `showProfileNudge`.
//
// Điều đáng canh nhất là NGƯỠNG: thẻ này không được hỏi người mới. Ba điều kiện
// của mockup phải cùng đúng thì mới hiện, và mỗi điều kiện có một test riêng —
// một điều kiện hỏng mà hai điều kiện kia che đi thì không ai thấy.
//
// Run: flutter test test/features/wr_home_profile_nudge_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_colors.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';

/// Insight ĐẾM ĐƯỢC — `wr_insights`, cùng nguồn với con số "Insight lưu" ở màn
/// Hồ sơ. Ngưỡng của thẻ nhắc đọc từ đây, không đọc từ kho intelligence: con số
/// người dùng nhìn thấy và con số quyết định có hỏi hay không phải là một.
List<Insight> _insights(int n) => [
      for (var i = 0; i < n; i++)
        Insight(
          id: 'i$i',
          userId: 'u1',
          content: 'Insight số $i',
          savedAt: DateTime(2026, 6, 20).add(Duration(days: i)),
        ),
    ];

Widget _wrap(FakeWrRepository repo, {FakeWrIntelligenceRepository? intel}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
      GoRoute(
        path: '/profile/my-info',
        builder: (_, __) => const Scaffold(body: Text('THÔNG TIN CỦA BẠN')),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(repo),
      wrIntelligenceRepositoryProvider
          .overrideWithValue(intel ?? FakeWrIntelligenceRepository()),
      wrMoodContentRepositoryProvider
          .overrideWithValue(FakeWrMoodContentRepository()),
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

Future<void> _pump(
  WidgetTester tester,
  FakeWrRepository repo, {
  FakeWrIntelligenceRepository? intel,
}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(repo, intel: intel));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final nudge = find.byKey(const Key('wr_home_profile_nudge'));

  group('thẻ nhắc điền hồ sơ', () {
    testWidgets('người mới KHÔNG bị hỏi — dưới ba Insight thì im', (tester) async {
      final repo = FakeWrRepository()
        ..seedInsights(_insights(2))
        ..seedCcProfile({});
      await _pump(tester, repo);
      expect(nudge, findsNothing);
    });

    testWidgets('đủ ba Insight và chưa khai kinh nghiệm thì hiện',
        (tester) async {
      final repo = FakeWrRepository()
        ..seedInsights(_insights(kProfileNudgeInsightThreshold))
        ..seedCcProfile({});
      await _pump(tester, repo);
      expect(nudge, findsOneWidget);
      expect(
        find.text(
          'Cho mình biết bạn đi làm được bao lâu để những gợi ý sát hơn nhé',
        ),
        findsOneWidget,
      );
    });

    testWidgets('đã khai kinh nghiệm rồi thì không hỏi lại', (tester) async {
      final repo = FakeWrRepository()
        ..seedInsights(_insights(9))
        ..seedCcProfile({'total_work_experience': '5_10'});
      await _pump(tester, repo);
      expect(nudge, findsNothing);
    });

    testWidgets('chuỗi trắng trong cột kinh nghiệm vẫn tính là chưa khai',
        (tester) async {
      final repo = FakeWrRepository()
        ..seedInsights(_insights(5))
        ..seedCcProfile({'total_work_experience': '  '});
      await _pump(tester, repo);
      expect(nudge, findsOneWidget);
    });

    testWidgets('"Điền ngay" mở màn Thông tin của bạn', (tester) async {
      final repo = FakeWrRepository()
        ..seedInsights(_insights(4))
        ..seedCcProfile({});
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('wr_home_profile_nudge_fill')));
      await tester.pumpAndSettle();
      expect(find.text('THÔNG TIN CỦA BẠN'), findsOneWidget);
    });

    testWidgets('"Bỏ qua" ẩn thẻ ngay và nhớ lại ở máy', (tester) async {
      final repo = FakeWrRepository()
        ..seedInsights(_insights(4))
        ..seedCcProfile({});
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('wr_home_profile_nudge_dismiss')));
      await tester.pumpAndSettle();
      expect(nudge, findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('wr_profile_nudge_dismissed'), isTrue);
    });

    testWidgets('đã bỏ qua từ lần mở trước thì không hiện lại', (tester) async {
      SharedPreferences.setMockInitialValues(
        {'wr_profile_nudge_dismissed': true},
      );
      final repo = FakeWrRepository()
        ..seedInsights(_insights(9))
        ..seedCcProfile({});
      await _pump(tester, repo);
      expect(nudge, findsNothing);
    });
  });

  // Mockup bản (4) §screenHome: lưới check-in nằm TRONG một thẻ trắng, và ô
  // đang chọn là VIỀN coral + nền coral nhạt, không tô đặc.
  group('khối check-in', () {
    testWidgets('nằm trong một thẻ trắng viền mảnh', (tester) async {
      final repo = FakeWrRepository()..seedCcProfile({});
      await _pump(tester, repo);

      final cards = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.byKey(const Key('wr_home_checkin_ok')),
              matching: find.byType(Container),
            ),
          )
          .where((c) {
            final d = c.decoration;
            return d is BoxDecoration && d.color == WrColors.white;
          });
      expect(cards, isNotEmpty, reason: 'lưới check-in không nằm trong thẻ');
    });

    testWidgets('ô chưa chọn là nền trắng, không tô coral', (tester) async {
      final repo = FakeWrRepository()..seedCcProfile({});
      await _pump(tester, repo);

      final tile = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(const Key('wr_home_checkin_ok')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final d = tile.decoration! as BoxDecoration;
      expect(d.color, WrColors.white);
      // Coral ĐẶC là màu của CTA chính, spec §01 chỉ cho một chỗ mỗi màn — và
      // đây không phải chỗ đó.
      expect(d.color, isNot(WrColors.coral));
    });
  });

  group('Insight gần nhất', () {
    testWidgets('chưa có Insight nào thì thẻ VẪN đứng đây, đổi thành lời mời',
        (tester) async {
      final repo = FakeWrRepository()..seedCcProfile({});
      await _pump(tester, repo);

      expect(
        find.byKey(const Key('wr_home_latest_insight_empty')),
        findsOneWidget,
      );
      expect(find.text('INSIGHT GẦN NHẤT'), findsOneWidget);
      expect(
        find.textContaining('Chưa có Insight nào'),
        findsOneWidget,
      );
    });

    testWidgets('có Insight thì hiện câu thật, không hiện lời mời',
        (tester) async {
      final repo = FakeWrRepository()..seedCcProfile({});
      final intel = FakeWrIntelligenceRepository()
        ..seedInsights([
          WrInsight(
            userId: 'u1',
            content: 'Tôi thường im lặng vì sợ phán xét.',
            createdAt: DateTime(2026, 6, 20),
          ),
        ]);
      await _pump(tester, repo, intel: intel);

      expect(
        find.byKey(const Key('wr_home_latest_insight_empty')),
        findsNothing,
      );
      expect(find.byKey(const Key('wr_home_latest_insight')), findsOneWidget);
      expect(
        find.text('"Tôi thường im lặng vì sợ phán xét."'),
        findsOneWidget,
      );
    });
  });
}
