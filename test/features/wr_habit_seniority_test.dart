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
import 'package:workreflection_mobile/core/logic/wr_seniority.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
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
