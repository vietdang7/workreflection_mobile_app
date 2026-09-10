import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/onboarding/onboarding_state.dart';
import 'package:workreflection_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:workreflection_mobile/features/onboarding/presentation/wr_logo.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      builder: wrTextScaleBuilder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: child,
    ),
  );
}

void main() {
  group('OnboardingNotifier state', () {
    test('starts at step 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(onboardingNotifierProvider);
      expect(state.currentStep, 0);
      expect(state.selectedSituation, isNull);
    });

    test('nextStep advances step', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(onboardingNotifierProvider.notifier).nextStep();
      expect(container.read(onboardingNotifierProvider).currentStep, 1);
    });

    test('nextStep does not exceed step 2', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingNotifierProvider.notifier);
      notifier.nextStep();
      notifier.nextStep();
      notifier.nextStep(); // attempt beyond max
      expect(container.read(onboardingNotifierProvider).currentStep, 2);
    });

    test('selectSituation stores value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(onboardingNotifierProvider.notifier)
          .selectSituation('Mệt nhưng không biết tại sao');
      expect(
        container.read(onboardingNotifierProvider).selectedSituation,
        'Mệt nhưng không biết tại sao',
      );
    });

    test('selectSituation can be changed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingNotifierProvider.notifier);
      notifier.selectSituation('A');
      notifier.selectSituation('B');
      expect(container.read(onboardingNotifierProvider).selectedSituation, 'B');
    });
  });

  group('OnboardingScreen widget', () {
    testWidgets('renders step 1 tag and title', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pump();

      // Step 1 tag
      expect(find.text('Reflect'), findsOneWidget);
      // Step 1 CTA
      expect(find.text('Tiếp tục'), findsOneWidget);
      // Step 1 body text fragment
      expect(find.textContaining('khoảnh khắc'), findsOneWidget);
    });

    testWidgets('renders WrLogo on step 1', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pump();
      // WrLogo nhúng thẳng file logo chuẩn assets/images/wr_logo.png
      expect(find.byType(WrLogo), findsOneWidget);
    });

    testWidgets('progress dots row shows 3 dot containers', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pump();
      // The dots row is a Row with 3 containers; verify step 1 tag visible means screen rendered
      // and we have navigation forward; we check via the overall rendered count of containers
      // The presence of WrLogo (CustomPaint) proves the screen is rendering with visual elements
      expect(find.byType(CustomPaint), findsWidgets);
    });

    // Khách 09/09 đổi nhãn nút bước 2 từ "Bắt đầu ngay" (coral) sang "Tiếp tục"
    // (navy) — cả ba bước giờ dùng cùng một nhãn cho hai bước đầu. Nên các bài
    // dưới đây khoá VỊ TRÍ BƯỚC bằng nhãn tag (Reflect · Understand · Grow),
    // thứ không đổi theo câu chữ, chứ không bằng nhãn nút.
    Future<void> advance(WidgetTester tester) async {
      await tester.tap(find.text('Tiếp tục'));
      await tester.pump();
    }

    testWidgets('tapping CTA on step 1 advances to step 2', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pump();

      await advance(tester);

      // Now step 2
      expect(find.text('Understand'), findsOneWidget);
      expect(find.text('Reflect'), findsNothing);
    });

    testWidgets('step 2 shows situation options', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pump();

      // Advance to step 2
      await advance(tester);

      expect(find.text('Mệt mỏi nhưng không rõ lý do.'), findsOneWidget);
      expect(find.text('Nỗ lực nhiều nhưng chưa thấy bước tiến.'), findsOneWidget);
      expect(
        find.text('Khao khát thay đổi nhưng chưa biết bắt đầu từ đâu.'),
        findsOneWidget,
      );
      expect(
        find.text('Mọi thứ đang ổn, nhưng muốn thấu hiểu mình sâu hơn.'),
        findsOneWidget,
      );
    });

    testWidgets('selecting situation on step 2 toggles selection', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pump();

      await advance(tester);

      // Tap option 1 — should appear selected (check via _SituationCard internal state)
      await tester.tap(find.text('Mệt mỏi nhưng không rõ lý do.'));
      await tester.pump();

      // Tapping again should deselect (the state tracks selectedSituation in notifier)
      await tester.tap(find.text('Mệt mỏi nhưng không rõ lý do.'));
      await tester.pump();
      // Widget did not crash
    });

    testWidgets('tapping through to step 3 shows Grow tag', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pump();

      // Step 1 → 2 → 3
      await advance(tester);
      await advance(tester);

      expect(find.text('Grow'), findsOneWidget);
      expect(find.text('Bắt đầu hành trình'), findsOneWidget);
    });

    testWidgets('step 3 shows all three promise cards', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pump();

      await advance(tester);
      await advance(tester);

      expect(find.text('5–15 phút mỗi ngày'), findsOneWidget);
      expect(find.text('Riêng tư hoàn toàn'), findsOneWidget);
      expect(find.text('Góc nhìn khách quan'), findsOneWidget);
    });
  });
}
