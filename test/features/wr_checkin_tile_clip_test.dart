// Ô check-in KHÔNG BAO GIỜ được cắt mất dòng cuối, dù nhãn dài hay ngắn.
//
// Dựng MÀN HOME THẬT ở 320 logical px với font Be Vietnam Pro thật (app dùng
// GoogleFonts, bộ test mặc định là Ahem) rồi so chiều cao chữ đã layout với
// lòng ô. Đo bằng TextPainter rời không thấy lỗi này: nguyên nhân nằm ở
// IntrinsicHeight của hàng ô, không nằm ở chữ.
//
// Bề rộng lòng chữ ở 320px, ĐÃ ĐO trên cây thật (tile 111, chữ 88): 320 - 2*22
// lề ListView = 276; - 2*21 (padding thẻ 20 + viền 1) = 234; (234 - 12 khe)/2 =
// 111 mỗi ô; - 2*11.5 (padding 10 + viền 1.5) = 88. Cỡ chữ thật còn bị
// `wrTextScaleBuilder` nới nên KHÔNG đo được bằng TextPainter 13.5px rời.
//
// Run: flutter test test/features/wr_checkin_tile_clip_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
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
    for (final (name, file) in [
      ('BeVietnamPro', 'BeVietnamPro-SemiBold.ttf'),
    ]) {
      final bytes = File('test/fixtures/fonts/$file').readAsBytesSync();
      final l = FontLoader(name)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await l.load();
    }
  });

  for (final lang in ['vi', 'en']) {
    for (var w = 280.0; w <= 430; w += 5) {
      testWidgets('[$lang] không ô check-in nào cắt dòng cuối ở ${w}px', (
        tester,
      ) async {
        wrSetLocale(lang);
        addTearDown(() => wrSetLocale('vi'));
        tester.view.physicalSize = Size(w, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();

        final bad = <String>[];
        for (final o in kCheckinOptions) {
          final tile = find.byKey(Key('wr_home_checkin_${o.id}'));
          expect(tile, findsOneWidget, reason: o.id);
          final container = find.descendant(
            of: tile,
            matching: find.byType(AnimatedContainer),
          );
          final text = find.descendant(of: tile, matching: find.byType(Text));
          // padding dọc 12*2 + viền 1.5*2.
          final inner = tester.getSize(container).height - 24 - 3;
          final textH = tester.getSize(text).height;
          if (textH > inner + 0.5) {
            bad.add('${o.id}: chữ cao $textH > lòng ô $inner');
          }
        }
        expect(bad, isEmpty);
      });
    }
  }
}
