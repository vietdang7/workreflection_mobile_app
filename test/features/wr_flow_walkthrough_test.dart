// Đi trọn luồng phản tư của CẢ SÁU khoảnh khắc, đúng đường người dùng đi:
// Home → cảm xúc → khoảnh khắc → từng bước (chạm thẻ tình huống ở bước Name)
// → màn Ý nghĩa. Bắt lỗi lặp câu hỏi và bắt bước bị nuốt.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_experience_state.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_commit_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_done_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_energy_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_flow_scaffold.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_meaning_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_moment_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_step_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';
import '../support/fake_repository.dart';

void main() {
  for (final moment in HumanMoment.values) {
    testWidgets('walk ${moment.name}', (tester) async {
      final episodes = FakeWrEpisodeRepository();
      final moodContent = FakeWrMoodContentRepository()
        ..seedChoicePool(const ['Ghi nhớ điều này để xem lại sau']);
      // Bước Name hiện thẻ tình huống — đây mới là đường người dùng hay đi.
      final content = FakeWrContentRepository()
        ..seedSituations(const [
          WrSituation(
              code: 'A3-sit-01',
              text: 'Việc dồn nhiều hơn mình xử lý nổi',
              scaDimension: ScaDimension.a3,
              wave: 1),
          WrSituation(
              code: 'C2-sit-01',
              text: 'Không dám lên tiếng trong cuộc họp',
              scaDimension: ScaDimension.c2,
              wave: 1),
          WrSituation(
              code: 'A1-sit-01',
              text: 'Không biết mình đang đi về đâu',
              scaDimension: ScaDimension.a1,
              wave: 1),
        ]);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
          GoRoute(
              path: '/wr/flow/energy',
              builder: (_, __) => const WrEnergyScreen()),
          GoRoute(
              path: '/wr/flow/moment',
              builder: (_, __) => const WrMomentScreen()),
          GoRoute(
              path: '/wr/flow/step', builder: (_, __) => const WrStepScreen()),
          GoRoute(
              path: '/wr/flow/meaning',
              builder: (_, __) => const WrMeaningScreen()),
          GoRoute(
              path: '/wr/flow/commit',
              builder: (_, __) => const WrCommitScreen()),
          GoRoute(
              path: '/wr/flow/done', builder: (_, __) => const WrDoneScreen()),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          wrEpisodeRepositoryProvider.overrideWithValue(episodes),
          wrIntelligenceRepositoryProvider
              .overrideWithValue(FakeWrIntelligenceRepository()),
          wrContentRepositoryProvider.overrideWithValue(content),
          wrMoodContentRepositoryProvider.overrideWithValue(moodContent),
          wrRepositoryProvider.overrideWithValue(FakeWrRepository()),
          currentUserIdProvider.overrideWithValue('u1'),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ));
      await tester.pumpAndSettle();

      // Home → chọn cảm xúc → màn khoảnh khắc.
      await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('wr_moment_${moment.name}')));
      await tester.pumpAndSettle();

      // Đi từng bước cho tới khi rời màn bước, ghi lại nhãn + câu hỏi.
      final seen = <String>[];
      for (var i = 1; i <= 8; i++) {
        final stepScreen = find.byType(WrStepScreen);
        if (stepScreen.evaluate().isEmpty) break;
        final scaffold =
            tester.widget<WrFlowScaffold>(find.byType(WrFlowScaffold));
        seen.add('${scaffold.eyebrow} · ${scaffold.title}');

        final field = find.byKey(const Key('wr_step_note'));
        if (field.evaluate().isEmpty) {
          // Bước Name: chạm thẻ tình huống đầu tiên thay vì tự viết.
          final tile = find.byKey(const Key('wr_situation_A3-sit-01'));
          final target = tile.evaluate().isNotEmpty
              ? tile
              : find.byKey(const Key('wr_situation_C2-sit-01'));
          await tester.tap(
              target.evaluate().isNotEmpty
                  ? target
                  : find.byKey(const Key('wr_situation_A1-sit-01')),
              warnIfMissed: false);
          await tester.pumpAndSettle();
        } else {
          await tester.enterText(
              find.byKey(const Key('wr_step_note')), 'câu trả lời $i');
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('wr_flow_primary')));
        await tester.pumpAndSettle();
      }

      // Đi hết đúng số bước của archetype, không thừa không thiếu.
      expect(seen, hasLength(patternCount(moment)),
          reason: '${moment.name}: đi $seen');
      // Không bước nào hỏi lại đúng câu của bước trước.
      expect(seen.toSet(), hasLength(seen.length),
          reason: '${moment.name} lặp câu hỏi: $seen');
      // Kết thúc ở màn Ý nghĩa, và mỗi bước để lại đúng một ghi chú.
      expect(find.byType(WrMeaningScreen), findsOneWidget);
      expect(
        episodes.episodes.single.notes.keys.toSet(),
        patternSequences[moment]!.map((p) => p.dbValue).toSet(),
        reason: '${moment.name}: thiếu ghi chú của bước nào đó',
      );
    });
  }
}
