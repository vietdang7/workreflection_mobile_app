import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';

// Script Sprint 2 `MOODS`: mỗi nhãn ô check-in đúng HAI dòng
// ("Tôi mệt mỏi<br>cần nghỉ ngơi"). Máy thật 13/10 để cỡ chữ hệ thống 1.15
// và nhãn bị bẻ thành bốn dòng "Tôi / mệt mỏi / cần / nghỉ ngơi".

Widget _app() => ProviderScope(
  overrides: [
    wrContentRepositoryProvider.overrideWithValue(FakeWrContentRepository()),
    wrIntelligenceRepositoryProvider.overrideWithValue(
      FakeWrIntelligenceRepository(),
    ),
    wrMoodContentRepositoryProvider.overrideWithValue(
      FakeWrMoodContentRepository(),
    ),
    wrRepositoryProvider.overrideWithValue(FakeWrRepository()),
    wrEpisodeRepositoryProvider.overrideWithValue(FakeWrEpisodeRepository()),
    currentUserIdProvider.overrideWithValue('u1'),
  ],
  child: MaterialApp.router(
    builder: wrTextScaleBuilder,
    theme: ThemeData(fontFamily: 'BeVietnamPro'),
    routerConfig: GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const WrHomeScreen())],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

void main() {
  setUpAll(() async {
    final bytes = File(
      'test/fixtures/fonts/BeVietnamPro-SemiBold.ttf',
    ).readAsBytesSync();
    final l = FontLoader('BeVietnamPro')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await l.load();
  });

  for (final lang in ['vi', 'en']) {
    for (final scale in [1.0, 1.15, 1.3]) {
      for (final w in [320.0, 360.0, 390.0, 430.0]) {
        testWidgets(
          '[$lang] cỡ chữ $scale, khổ ${w}px: mỗi nhãn ô đúng 2 dòng',
          (tester) async {
            wrSetLocale(lang);
            addTearDown(() => wrSetLocale('vi'));
            tester.view.physicalSize = Size(w, 3000);
            tester.view.devicePixelRatio = 1.0;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await tester.pumpWidget(_app());
            await tester.pumpAndSettle();

            final bad = <String>[];
            double? fontSize;
            for (final o in kCheckinOptions) {
              final tile = find.byKey(Key('wr_home_checkin_${o.id}'));
              final text = find.descendant(
                of: tile,
                matching: find.byType(Text),
              );
              final para = tester.renderObject<RenderParagraph>(
                find.descendant(of: text, matching: find.byType(RichText)),
              );
              final lines = para
                  .getBoxesForSelection(
                    TextSelection(
                      baseOffset: 0,
                      extentOffset: para.text.toPlainText().length,
                    ),
                  )
                  .map((b) => b.top.round())
                  .toSet()
                  .length;
              if (lines != 2) bad.add('${o.id}: $lines dòng');
              // Sáu ô cùng một cỡ chữ.
              final size = tester.widget<Text>(text).style!.fontSize!;
              fontSize ??= size;
              if ((size - fontSize).abs() > 0.001) bad.add('${o.id}: cỡ $size');
            }
            expect(bad, isEmpty);
          },
        );
      }
    }
  }
}
