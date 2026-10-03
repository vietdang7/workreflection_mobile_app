// Màn chào (đợt E, họp khách 01/10): MỘT màn thay cho ba slide cũ.
//
// Khoá ba điều:
//   1. Chỉ còn một màn: logo, tiêu đề chào mừng, thẻ video, nút "Bắt đầu".
//      Không còn tag Reflect/Understand/Grow, không còn chấm tiến độ.
//   2. "Bắt đầu" ghi cờ `seen_onboarding` như cũ (router dựa vào cờ này).
//   3. Tiêu đề dựng bằng `WrTitleText` và không tràn ở màn hẹp, cả tiếng Anh.
//
// Run: flutter test test/features/onboarding_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/widgets/wr_title_text.dart';
import 'package:workreflection_mobile/features/onboarding/intro_video_providers.dart';
import 'package:workreflection_mobile/features/onboarding/onboarding_state.dart';
import 'package:workreflection_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:workreflection_mobile/features/onboarding/presentation/wr_logo.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('vi')}) {
  return ProviderScope(
    overrides: [
      // Không đọc asset thật: video chạy chế độ không tiếng.
      introTimingSourceProvider.overrideWithValue((_) async => null),
    ],
    child: MaterialApp(
      builder: wrTextScaleBuilder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    wrEnglish = false;
    // Video đã từng bật: các bài ở đây chỉ nói về màn chào, không muốn sheet
    // video tự bật đè lên. Luật bật một lần khoá ở wr_intro_video_test.dart.
    SharedPreferences.setMockInitialValues({'wr_intro_video_shown': true});
  });
  tearDown(() => wrEnglish = false);

  test('OnboardingState không còn bước, tình huống luôn null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(onboardingNotifierProvider).selectedSituation,
      isNull,
    );
  });

  testWidgets(
    'chỉ một màn: có tiêu đề chào mừng, không có Reflect/Understand/Grow, '
    'không có chấm tiến độ',
    (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pump();

      expect(find.byType(WrLogo), findsOneWidget);
      final title = find.byType(WrTitleText);
      expect(title, findsOneWidget);
      expect(
        tester.widget<WrTitleText>(title).text,
        'Chào mừng bạn đến với WorkReflection',
      );
      expect(find.byKey(const Key('intro_video_card')), findsOneWidget);
      expect(find.text('Bắt đầu'), findsOneWidget);

      for (final gone in ['Reflect', 'Understand', 'Grow', 'Tiếp tục']) {
        expect(find.text(gone), findsNothing, reason: '$gone phải biến mất');
      }
      expect(find.byKey(const Key('onboarding_step_dot')), findsNothing);
    },
  );

  testWidgets('Bắt đầu → seen_onboarding = true', (tester) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pump();

    await tester.tap(find.text('Bắt đầu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('seen_onboarding'), isTrue);
  });

  for (final (width, en) in [(320.0, false), (320.0, true), (390.0, false)]) {
    testWidgets(
      'tiêu đề không rớt chữ, không tràn (rộng $width, ${en ? 'EN' : 'VI'})',
      (tester) async {
        wrEnglish = en;
        tester.view.physicalSize = Size(width * 3, 700 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(const OnboardingScreen(), locale: Locale(en ? 'en' : 'vi')),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final w = tester.widget<WrTitleText>(find.byType(WrTitleText));
        expect(
          w.text,
          en
              ? 'Welcome to WorkReflection'
              : 'Chào mừng bạn đến với WorkReflection',
        );
        // Dòng cuối không được là một tiếng ngắn đứng một mình.
        final rendered = tester.widget<Text>(
          find.descendant(
            of: find.byType(WrTitleText),
            matching: find.byType(Text),
          ),
        );
        final painter = TextPainter(
          text: TextSpan(text: rendered.data, style: rendered.style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.of(
            tester.element(find.byType(WrTitleText)),
          ).textScaler,
        )..layout(maxWidth: tester.getSize(find.byType(WrTitleText)).width);
        final lines = painter.computeLineMetrics();
        final last = painter.getLineBoundary(
          painter.getPositionForOffset(
            Offset(1, lines.last.baseline - lines.last.ascent / 2),
          ),
        );
        final lastLine = rendered.data!.substring(last.start, last.end).trim();
        // Font thử của flutter_test (Ahem) rộng hơn font thật nên có thể bẻ
        // giữa một tiếng dài; chỉ bắt lỗi khi dòng cuối là MỘT tiếng ngắn
        // nguyên vẹn của câu, đúng kiểu "rớt chữ".
        final words = rendered.data!.split(RegExp(r'[\s\u00A0]+'));
        final orphan =
            !lastLine.contains(RegExp(r'[\s\u00A0]')) &&
            words.contains(lastLine) &&
            lastLine.length <= 4;
        expect(
          orphan,
          isFalse,
          reason: 'dòng cuối "$lastLine" là một tiếng rớt',
        );
      },
    );
  }
}
