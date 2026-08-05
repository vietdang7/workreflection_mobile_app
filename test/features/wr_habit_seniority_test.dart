// "Thói quen và Ma trận Cấp bậc v1.0" — phần chạm tới màn hình.
//
// Ba việc của tài liệu được kiểm ở đây:
//   A.1/C.2  Một trạng thái tại một thời điểm, và tên gọi mới.
//   A.2/C.5  Câu riêng của chủ đề ở màn ăn mừng.
//   B.3/C.7  Bước Chuyển hoá viết lại theo cấp bậc.
//   C.1      Mảnh ký ức thực hành mang theo theme_id.
//
// Run: flutter test test/features/wr_habit_seniority_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_entitlement.dart';
import 'package:workreflection_mobile/core/logic/wr_seniority.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_jd_match.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_colors.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/widgets/wr_list_card.dart';
import 'package:workreflection_mobile/core/widgets/wr_premium_lock.dart';
import 'package:workreflection_mobile/features/wr/growth_providers.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_skills_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_practice_theme_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_skill_moment.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

Widget _wrap(
  Widget home, {
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
  SeniorityTier? tier,
}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => home),
      GoRoute(
        path: '/wr/growth/theme/:id',
        builder: (_, state) =>
            WrPracticeThemeScreen(themeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('Paywall')),
      ),
      GoRoute(
        path: '/wr/work-info',
        builder: (_, __) => const Scaffold(body: Text('WorkInfo')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider
          .overrideWithValue(intel ?? FakeWrIntelligenceRepository()),
      wrContentRepositoryProvider
          .overrideWithValue(content ?? FakeWrContentRepository()),
      currentUserIdProvider.overrideWithValue('u1'),
      wrSeniorityTierProvider.overrideWithValue(tier),
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

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

/// Chủ đề C1 của bộ 10 — chủ đề duy nhất có mặt trong cả bảng B.2 lẫn B.3.
FakeWrIntelligenceRepository _trustTheme({DateTime? completedAt}) {
  final intel = FakeWrIntelligenceRepository()
    ..seedPracticeThemes([
      const PracticeTheme(
        themeId: 'pt-c1',
        title: 'Tin và được tin',
        scaDimension: ScaDimension.c1,
        description: 'Niềm tin được xây từ việc dám buông.',
        formedLine: 'Bạn tin, và để người khác tự chứng minh mình xứng đáng.',
      ),
    ])
    ..seedPracticeSteps('pt-c1', const [
      PracticeStep(
        stepId: 'pt-c1-1',
        themeId: 'pt-c1',
        stepOrder: 1,
        title: 'Nhận diện',
        content: 'Nội dung gốc bước 1.',
        isPremium: false,
      ),
      PracticeStep(
        stepId: 'pt-c1-2',
        themeId: 'pt-c1',
        stepOrder: 2,
        title: 'Thử nghiệm',
        content: 'Nội dung gốc bước 2.',
        isPremium: false,
      ),
      PracticeStep(
        stepId: 'pt-c1-3',
        themeId: 'pt-c1',
        stepOrder: 3,
        title: 'Chuyển hoá',
        content: 'Nội dung gốc bước 3.',
        isPremium: false,
      ),
    ])
    ..seedEnrollments([
      PracticeEnrollment(
        userId: 'u1',
        themeId: 'pt-c1',
        completedSteps: const ['pt-c1-1', 'pt-c1-2', 'pt-c1-3'],
        completedAt: completedAt,
      ),
    ]);
  return intel;
}

void main() {
  group('B.3 — bước Chuyển hoá theo cấp bậc trên màn chủ đề', () {
    testWidgets('chưa khai vị trí thì giữ nguyên nội dung gốc', (tester) async {
      await _pumpLarge(
        tester,
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-c1'),
          intel: _trustTheme(),
        ),
      );

      expect(find.text('Nội dung gốc bước 3.'), findsOneWidget);
    });

    testWidgets('quản lý nhóm nhỏ thấy bản viết cho người quản lý',
        (tester) async {
      await _pumpLarge(
        tester,
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-c1'),
          intel: _trustTheme(),
          tier: SeniorityTier.leadTeam,
        ),
      );

      expect(find.text('Nội dung gốc bước 3.'), findsNothing);
      expect(
        find.textContaining('giao việc và thật sự buông'),
        findsOneWidget,
      );
      // Hai bước đầu không đổi — B.3 chỉ cho viết lại bước thứ ba.
      expect(find.text('Nội dung gốc bước 1.'), findsOneWidget);
      expect(find.text('Nội dung gốc bước 2.'), findsOneWidget);
    });

    testWidgets('quản lý nhiều nhóm thấy bản phạm vi rộng hơn', (tester) async {
      await _pumpLarge(
        tester,
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-c1'),
          intel: _trustTheme(),
          tier: SeniorityTier.leadOrg,
        ),
      );

      expect(
        find.textContaining('văn hóa tin tưởng áp dụng nhất quán'),
        findsOneWidget,
      );
    });
  });

  group('Yêu cầu 05/08 — màn chủ đề', () {
    testWidgets('mỗi bước là một thẻ RIÊNG, không gộp chung một thẻ',
        (tester) async {
      await _pumpLarge(
        tester,
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-c1'),
          intel: _trustTheme(),
        ),
      );

      expect(find.byType(WrListCard), findsNothing);
      for (final id in ['pt-c1-1', 'pt-c1-2', 'pt-c1-3']) {
        final box = tester
            .widget<Container>(find.byKey(Key('wr_practice_step_$id')))
            .decoration as BoxDecoration;
        expect(box.color, WrColors.white, reason: id);
        expect(box.border, isNotNull, reason: id);
        expect(
          box.borderRadius,
          BorderRadius.circular(kWrCardRadius),
          reason: id,
        );
      }
    });

    testWidgets('đoạn nối là kẻ DỌC mảnh, không phải thanh ngang',
        (tester) async {
      // Màn này dựng bằng ListView, vốn ép con chiếm trọn bề ngang. Thiếu
      // `Align` là `width: 2` bị bỏ qua và đoạn kẻ biến thành một thanh ngang
      // dày chắn giữa hai thẻ — đúng lỗi giao diện báo ngày 05/08.
      await _pumpLarge(
        tester,
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-c1'),
          intel: _trustTheme(),
        ),
      );

      final connectors = find.byKey(const Key('wr_practice_step_connector'));
      // Ba bước thì có hai đoạn nối.
      expect(connectors, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final size = tester.getSize(connectors.at(i));
        expect(size.width, 2, reason: 'đoạn nối $i phải mảnh, đang là $size');
        expect(size.height, greaterThan(size.width), reason: 'phải DỌC');
      }
    });

    testWidgets('bước đã xong thì mờ đi, bước đang chờ thì không',
        (tester) async {
      // Ghi danh của `_trustTheme` đánh dấu cả ba bước đã xong, nên lấy một
      // ghi danh mới chỉ xong bước đầu để so hai trạng thái cạnh nhau.
      final intel = _trustTheme()
        ..seedEnrollments([
          const PracticeEnrollment(
            userId: 'u1',
            themeId: 'pt-c1',
            completedSteps: ['pt-c1-1'],
          ),
        ]);

      await _pumpLarge(
        tester,
        _wrap(const WrPracticeThemeScreen(themeId: 'pt-c1'), intel: intel),
      );

      double opacityOf(String id) => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(Key('wr_practice_step_$id')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;

      expect(opacityOf('pt-c1-1'), lessThan(1.0));
      expect(opacityOf('pt-c1-2'), 1.0);
    });

    testWidgets('bước đã xong KHÔNG bị gạch ngang chữ', (tester) async {
      // Gạch ngang là cách đánh dấu một việc bị huỷ, không phải một việc vừa
      // làm được. Dấu tick đã nói đủ.
      await _pumpLarge(
        tester,
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-c1'),
          intel: _trustTheme(completedAt: DateTime(2026, 8, 1)),
        ),
      );

      final struck = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.decoration == TextDecoration.lineThrough);
      expect(struck, isEmpty);
      // Bước đã xong vẫn còn dấu tick.
      expect(find.byIcon(Icons.check), findsWidgets);
    });
  });

  group('C.1 — mảnh ký ức mang theo theme_id', () {
    testWidgets('ghi nhận duy trì lưu theme_id, không chỉ lưu tên',
        (tester) async {
      final content = FakeWrContentRepository();
      await _pumpLarge(
        tester,
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-c1'),
          intel: _trustTheme(completedAt: DateTime(2026, 8, 1)),
          content: content,
        ),
      );

      await tester.tap(find.byKey(const Key('wr_practice_maintain_pt-c1')));
      await tester.pumpAndSettle();

      final logged = content.insertMemoryEventCalls
          .where((e) => e.behavior == kPracticeMaintainedBehavior)
          .toList();
      expect(logged, hasLength(1));
      expect(logged.single.themeId, 'pt-c1');
    });
  });

  group('A.2/C.5 — câu riêng của chủ đề ở màn ăn mừng', () {
    testWidgets('dùng câu của chủ đề khi có', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSkillFormedCelebration(
                context,
                const SkillFormation(
                  themeId: 'pt-c1',
                  title: 'Tin và được tin',
                  practiceCount: 5,
                  threshold: 5,
                  onboardingDone: true,
                  skillFormedDate: null,
                  formedLine:
                      'Bạn tin, và để người khác tự chứng minh mình xứng đáng.',
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      expect(find.text('MỘT KỸ NĂNG CỦA BẠN'), findsOneWidget);
      expect(
        find.text('Bạn tin, và để người khác tự chứng minh mình xứng đáng.'),
        findsOneWidget,
      );
    });

    testWidgets('chủ đề chưa có câu riêng thì lùi về câu chốt ở A.1',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSkillFormedCelebration(
                context,
                const SkillFormation(
                  themeId: 'pt-voice',
                  title: 'Dám lên tiếng',
                  practiceCount: 5,
                  threshold: 5,
                  onboardingDone: true,
                  skillFormedDate: null,
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      expect(
        find.text('"Dám lên tiếng" giờ là một kỹ năng của bạn.'),
        findsOneWidget,
      );
    });
  });

  group('C.1 — hai chủ đề TRÙNG TÊN không cộng chung bộ đếm (đầu-cuối)', () {
    /// Đúng cảnh tài liệu nêu: `pt-voice` (bản cũ, đã ngưng đề xuất) và
    /// `pt-c2` (bộ chuẩn) cùng tên "Dám lên tiếng". Ai theo cả hai, trước đây
    /// nhìn màn nào cũng thấy tổng của cả hai.
    FakeWrIntelligenceRepository twoVoiceThemes() =>
        FakeWrIntelligenceRepository()
          ..seedPracticeThemes([
            PracticeTheme(
              themeId: 'pt-voice',
              title: 'Dám lên tiếng',
              scaDimension: ScaDimension.c2,
              retiredAt: DateTime(2026, 7, 31),
            ),
            const PracticeTheme(
              themeId: 'pt-c2',
              title: 'Dám lên tiếng',
              scaDimension: ScaDimension.c2,
              formedLine: 'Im lặng không còn là lựa chọn mặc định của bạn nữa.',
            ),
          ])
          ..seedEnrollments([
            PracticeEnrollment(
              userId: 'u1',
              themeId: 'pt-voice',
              completedAt: DateTime(2026, 7, 1),
            ),
            PracticeEnrollment(
              userId: 'u1',
              themeId: 'pt-c2',
              completedAt: DateTime(2026, 8, 1),
            ),
          ]);

    /// Bốn lần cho mỗi chủ đề — cùng chữ, khác theme_id.
    FakeWrContentRepository fourEach() => FakeWrContentRepository()
      ..seedMemoryEvents([
        for (final id in ['pt-voice', 'pt-c2'])
          for (var i = 1; i <= 4; i++)
            CareerMemoryEvent(
              id: '$id-$i',
              userId: 'u1',
              behavior: kPracticeMaintainedBehavior,
              themeId: id,
              reflectionText: 'Dám lên tiếng · Duy trì',
            ),
      ]);

    testWidgets('bộ đếm của mỗi chủ đề là 4/5, không phải 8/5', (tester) async {
      await _pumpLarge(
        tester,
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-c2'),
          intel: twoVoiceThemes(),
          content: fourEach(),
        ),
      );

      expect(find.textContaining('Đã 4/5 lần'), findsOneWidget);
      expect(find.textContaining('8/5'), findsNothing);
      expect(find.textContaining('Còn 1 lần nữa'), findsOneWidget);
    });

    testWidgets('lần thứ 5 mới ăn mừng, và dấu mốc ghi đúng theme_id',
        (tester) async {
      final content = fourEach();
      await _pumpLarge(
        tester,
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-c2'),
          intel: twoVoiceThemes(),
          content: content,
        ),
      );

      await tester.tap(find.byKey(const Key('wr_practice_maintain_pt-c2')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_skill_formed_celebration')),
        findsOneWidget,
      );
      // Câu riêng của chủ đề, không phải câu chung.
      expect(
        find.text('Im lặng không còn là lựa chọn mặc định của bạn nữa.'),
        findsOneWidget,
      );

      final milestones = content.insertMemoryEventCalls
          .where((e) => e.behavior == kSkillFormedBehavior)
          .toList();
      expect(milestones, hasLength(1));
      expect(milestones.single.themeId, 'pt-c2');
    });
  });

  group('Đối chiếu UX/UI 05/08 — ba việc về phần nhìn', () {
    testWidgets('thẻ mở đầu là thẻ trắng có viền, không phải khối màu phẳng',
        (tester) async {
      await _pumpLarge(tester, _wrap(const WrGrowthSkillsScreen()));

      final box = tester
          .widget<Container>(find.byKey(const Key('wr_skills_how_it_works')))
          .decoration as BoxDecoration;
      expect(box.color, WrColors.white);
      expect(box.border, isNotNull);
      expect(
        box.borderRadius,
        BorderRadius.circular(kWrCardRadius),
      );
    });

    testWidgets('mỗi nhóm danh sách nằm trong một khối thẻ chung',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([
          for (var i = 1; i <= 2; i++)
            PracticeTheme(themeId: 't$i', title: 'Chủ đề $i'),
        ])
        ..seedEnrollments([
          for (var i = 1; i <= 2; i++)
            PracticeEnrollment(userId: 'u1', themeId: 't$i'),
        ]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel),
      );

      // Hai dòng "Đang hình thành" phải nằm trong CÙNG một WrListCard, chứ
      // không phải nằm trần trên nền trang.
      expect(find.byType(WrListCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WrListCard),
          matching: find.byKey(const Key('wr_skill_forming_t1')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(WrListCard),
          matching: find.byKey(const Key('wr_skill_forming_t2')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dòng tiến độ dùng dấu phẩy, không dùng dấu chấm giữa',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(
            [const PracticeTheme(themeId: 't1', title: 'Chủ đề 1')])
        ..seedEnrollments([
          PracticeEnrollment(
            userId: 'u1',
            themeId: 't1',
            completedAt: DateTime(2026, 8, 1),
          ),
        ]);

      await _pumpLarge(
        tester,
        _wrap(const WrGrowthSkillsScreen(), intel: intel),
      );

      final line = tester
          .widget<Text>(find.byKey(const Key('wr_skill_progress_t1')))
          .data!;
      expect(line, contains(', còn'));
      expect(line, isNot(contains('·')));
    });

    testWidgets('màu nhãn Premium chỉ còn ở đúng khối khoá Premium',
        (tester) async {
      // `WrColors.amber` là token dành riêng cho nhãn Premium. Dùng nó làm
      // chấm bullet cho khoảng trống JD nói với người dùng một điều sai: rằng
      // khoảng trống đó là hàng trả phí. Ở khối khoá Premium thì nó đúng chỗ,
      // nên test không cấm màu — test cấm nó ĐI RA khỏi chỗ của nó.
      await _pumpLarge(tester, _wrap(const WrGrowthSkillsScreen()));

      final amber = find.byWidgetPredicate(
        (w) => w is Icon && w.color == WrColors.amber,
      );
      final insideLock = find.descendant(
        of: find.byType(WrPremiumLock),
        matching: amber,
      );
      expect(
        tester.widgetList(amber).length,
        tester.widgetList(insideLock).length,
      );
    });
  });

  group('Đối chiếu UX/UI 05/08 — danh sách khoảng trống JD', () {
    /// Dựng thẳng kết quả đối chiếu: cần Premium và một mô tả công việc đọc
    /// được mới tới được khối này, mà cả hai đều nằm ngoài chuyện đang kiểm.
    Widget premiumWithGaps() {
      final gaps = [
        const PracticeTheme(
          themeId: 'pt-a1',
          title: 'Nhìn rõ mình đang đi đâu',
          scaDimension: ScaDimension.a1,
        ),
        const PracticeTheme(
          themeId: 'pt-a3',
          title: 'Thoát khỏi vòng lặp phản ứng',
          scaDimension: ScaDimension.a3,
        ),
      ];
      return ProviderScope(
        overrides: [
          wrIntelligenceRepositoryProvider
              .overrideWithValue(FakeWrIntelligenceRepository()),
          wrContentRepositoryProvider
              .overrideWithValue(FakeWrContentRepository()),
          currentUserIdProvider.overrideWithValue('u1'),
          wrSeniorityTierProvider.overrideWithValue(SeniorityTier.leadOrg),
          wrEntitlementProvider.overrideWith(
            (ref) async => WrEntitlement(plan: WrPlan.premium),
          ),
          wrSkillJdMatchProvider.overrideWith(
            (ref) async => SkillJdMatch(
              matchedPillars: const ['A'],
              matchedDimensions: const ['A1', 'A3'],
              matchedSkills: const [],
              gapThemes: gaps,
              basedOnKeywords: const ['ưu tiên', 'sắp xếp'],
              tier: SeniorityTier.leadOrg,
              gapRelevance: const {
                'pt-a1': SkillRelevance.needed,
                'pt-a3': SkillRelevance.critical,
              },
            ),
          ),
        ],
        child: MaterialApp(
          builder: wrTextScaleBuilder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: const WrGrowthSkillsScreen(),
        ),
      );
    }

    testWidgets('mỗi dòng dẫn đầu bằng pill chữ, không phải chấm tròn',
        (tester) async {
      await _pumpLarge(tester, premiumWithGaps());

      expect(find.text('Cần'), findsOneWidget);
      expect(find.text('Cần, ưu tiên cao'), findsOneWidget);
      // Chấm tròn cũ đã bỏ hẳn.
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    });

    testWidgets('danh sách nằm trong khối thẻ chung', (tester) async {
      await _pumpLarge(tester, premiumWithGaps());

      expect(
        find.descendant(
          of: find.byType(WrListCard),
          matching: find.text('Thoát khỏi vòng lặp phản ứng'),
        ),
        findsOneWidget,
      );
    });
  });

  group('A.1 — tên gọi mới ở màn Kỹ năng', () {
    testWidgets('chưa có kỹ năng nào', (tester) async {
      await _pumpLarge(tester, _wrap(const WrGrowthSkillsScreen()));

      expect(find.text('KỸ NĂNG CỦA BẠN'), findsOneWidget);
      expect(find.text('Chưa có kỹ năng nào'), findsOneWidget);
      expect(
        find.text('Chưa có gì ở đây là bình thường, kỹ năng cần thời gian.'),
        findsOneWidget,
      );
    });
  });
}
