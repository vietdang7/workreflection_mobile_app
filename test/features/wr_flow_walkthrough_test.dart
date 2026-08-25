// Đi trọn luồng Reflect của CẢ BỐN cảm xúc check-in, đúng đường người dùng đi:
// Home → chạm ô cảm xúc → CHỌN tình huống → chi tiết (tuỳ chọn) → Ý nghĩa.
// Kiến trúc Dữ liệu v2.0 §V.
//
// ---------------------------------------------------------------------------
// Lỗi mà tệp này canh (2026-07-31)
// ---------------------------------------------------------------------------
//
// Trước bản này, luồng chèn thêm màn "Chọn khoảnh khắc" rồi chạy chuỗi Pattern
// của archetype, mà bước ĐẦU của chuỗi là một ô chữ trống. Chip tình huống nằm
// ở Pattern `name`, và `name` chỉ có trong 4 trên 6 archetype — `growth` và
// `recovery` KHÔNG có. Ai check-in "mệt mỏi" thì đi hết phiên mà không được đưa
// ra lựa chọn nào, và Episode khép lại với `situation_code = NULL`.
//
// Mất `situation_code` là mất recentSituationIds, tức mất luôn "Tình huống lặp
// lại", "Nhu cầu chủ đạo" và gợi ý Practice Theme (§4.3).
//
// Nên hai khẳng định quan trọng nhất ở đây là:
//   1. màn đầu tiên KHÔNG có ô chữ nào,
//   2. cả bốn cảm xúc đều ghi được `situationCode` xuống Episode.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_flow.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_commit_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_detail_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_done_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_energy_screen.dart';
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

/// Một tình huống cho mỗi cụm chiều của §III, để cảm xúc nào cũng có chip.
const _situations = [
  WrSituation(
    code: 'A3-sit-01',
    text: 'Việc dồn nhiều hơn mình xử lý nổi',
    scaDimension: ScaDimension.a3,
    wave: 1,
  ),
  WrSituation(
    code: 'C2-sit-01',
    text: 'Không dám lên tiếng trong cuộc họp',
    scaDimension: ScaDimension.c2,
    wave: 1,
  ),
  WrSituation(
    code: 'A1-sit-01',
    text: 'Không biết mình đang đi về đâu',
    scaDimension: ScaDimension.a1,
    wave: 1,
  ),
  WrSituation(
    code: 'P-01',
    text: 'Tôi vừa hoàn thành một việc khó hơn mong đợi',
    scaDimension: ScaDimension.pAchieve,
    wave: 1,
  ),
  WrSituation(
    code: 'P-06',
    text: 'Công việc hôm nay diễn ra đúng như tôi mong đợi',
    scaDimension: ScaDimension.pSteady,
    wave: 1,
  ),
];

void main() {
  for (final option in kCheckinOptions) {
    testWidgets('walk ${option.id}', (tester) async {
      final episodes = FakeWrEpisodeRepository();
      final moodContent = FakeWrMoodContentRepository()
        ..seedChoicePool(const ['Ghi nhớ điều này để xem lại sau']);
      final content = FakeWrContentRepository()..seedSituations(_situations);

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
              path: '/wr/flow/detail',
              builder: (_, __) => const WrDetailScreen()),
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
      builder: wrTextScaleBuilder,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ));
      await tester.pumpAndSettle();

      // Home → chạm ô cảm xúc → THẲNG vào bước chọn tình huống.
      //
      // Cuộn tới trước khi chạm: từ changelog 24/08 §3 lưới có SÁU ô xếp ba
      // hàng, và §5 thêm hình minh hoạ mở đầu phía trên — hai hàng dưới nằm
      // ngoài khung 600px mặc định của flutter_test.
      final cell = find.byKey(Key('wr_home_checkin_${option.id}'));
      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();

      expect(find.byType(WrStepScreen), findsOneWidget,
          reason: '${option.id}: check-in phải vào thẳng bước chọn tình huống, '
              'không qua màn khoảnh khắc nào');
      expect(find.byType(TextField), findsNothing,
          reason: '${option.id}: bước đầu KHÔNG được có ô chữ nào — §V bảo '
              'chọn chip, và ô chữ ở đây là đúng lỗi đã làm mất situation_code');
      expect(find.text(kNoticePrompt), findsOneWidget);
      // "Điều khác" luôn có mặt, không thuộc cơ chế lọc (§III). Nó nằm dưới
      // năm chip nên phải cuộn tới mới nhìn thấy.
      await tester.scrollUntilVisible(
        find.byKey(const Key('wr_situation_other')),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_situation_other')), findsOneWidget);

      // Chạm chip đầu tiên đang hiện. Danh sách được lọc theo cảm xúc nên mã cụ
      // thể khác nhau tuỳ ô check-in — tìm mã nào có mặt thì chạm mã đó.
      final shown = _situations.firstWhere(
        (s) => find
            .byKey(Key('wr_situation_${s.code}'))
            .evaluate()
            .isNotEmpty,
        orElse: () => throw StateError('${option.id}: không có chip nào hiện'),
      );
      // Danh sách chip được trộn ngẫu nhiên (§4.1) nên chip cần chạm có thể
      // đang nằm ngoài khung sau cú cuộn ở trên — kéo nó vào tầm nhìn đã.
      await tester.ensureVisible(find.byKey(Key('wr_situation_${shown.code}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('wr_situation_${shown.code}')));
      await tester.pumpAndSettle();

      // Chọn xong là Episode đã ghi mã tình huống — điều mà bản cũ đánh rơi ở
      // hai archetype.
      final episode = episodes.episodes.single;
      expect(episode.situationCode, shown.code,
          reason: '${option.id}: chọn tình huống mà không ghi được mã');
      expect(episode.humanMoment, momentForMood(option.mood));
      expect(episode.patternsDone, contains(ReflectionPattern.notice));

      // Bước 1 — chi tiết cụ thể, KHÔNG bắt buộc: bỏ trống vẫn đi tiếp được.
      expect(find.byType(WrDetailScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      // Bước 2 — Ý nghĩa. Từ changelog 24/08 §1.2 bước này có HAI LỚP, và
      // Lớp 1 mở bằng ô chữ TRỐNG nối tiếp câu mở dở.
      //
      // Kỳ vọng cũ ở đây là ngược lại ("phải mở bằng câu Aha có sẵn, không bao
      // giờ bằng ô trống") — đó chính là cơ chế §1.2 thay: câu trả lời có mặt
      // trước khi câu hỏi kịp đọng lại.
      expect(find.byType(WrMeaningScreen), findsOneWidget);
      expect(find.text(kInsightStemPrompt), findsOneWidget,
          reason: '${option.id}: Lớp 1 phải hiện câu mở dở');
      final field = tester.widget<TextField>(
        find.byKey(const Key('wr_meaning_field')),
      );
      expect(field.controller!.text, isEmpty,
          reason: '${option.id}: Lớp 1 mở bằng ô trống, câu Aha để dành Lớp 2');
      expect(find.byKey(const Key('wr_meaning_aha')), findsNothing,
          reason: '${option.id}: chưa viết gì mà đã thấy câu Aha là hỏng đúng '
              'cái §1.2 chữa');

      // Bỏ qua vẫn sang được Lớp 2 — lối thoát của §1.2.
      await tester.tap(find.byKey(const Key('wr_flow_secondary')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_meaning_aha')), findsOneWidget,
          reason: '${option.id}: Lớp 2 phải hiện câu Aha');
      expect(find.byKey(const Key('wr_meaning_your_words')), findsNothing,
          reason: '${option.id}: bỏ qua thì không có "điều bạn vừa viết"');
    });
  }

  testWidgets('nhánh "Điều khác" vẫn đi được, và không ghi mã tình huống nào',
      (tester) async {
    final episodes = FakeWrEpisodeRepository();
    final content = FakeWrContentRepository()..seedSituations(_situations);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
        GoRoute(
            path: '/wr/flow/step', builder: (_, __) => const WrStepScreen()),
        GoRoute(
            path: '/wr/flow/detail',
            builder: (_, __) => const WrDetailScreen()),
        GoRoute(
            path: '/wr/flow/meaning',
            builder: (_, __) => const WrMeaningScreen()),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        wrEpisodeRepositoryProvider.overrideWithValue(episodes),
        wrIntelligenceRepositoryProvider
            .overrideWithValue(FakeWrIntelligenceRepository()),
        wrContentRepositoryProvider.overrideWithValue(content),
        wrMoodContentRepositoryProvider
            .overrideWithValue(FakeWrMoodContentRepository()),
        wrRepositoryProvider.overrideWithValue(FakeWrRepository()),
        currentUserIdProvider.overrideWithValue('u1'),
      ],
      child: MaterialApp.router(
      builder: wrTextScaleBuilder,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wr_home_checkin_stress')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('wr_situation_other')),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_situation_other')));
    await tester.pumpAndSettle();

    // §V: nhánh này bỏ qua Story/Reflection, hỏi thẳng "Chuyện gì cụ thể đã
    // xảy ra?" — và mã tình huống vẫn để trống, vì "khác" không trả lời được
    // câu hỏi "người này đang phản chiếu nhiều về điều gì" (§4.3).
    expect(find.byType(WrDetailScreen), findsOneWidget);
    expect(find.text(kCustomDetailPrompt), findsOneWidget);
    expect(find.byKey(const Key('wr_detail_story')), findsNothing);
    expect(episodes.episodes.single.situationCode, isNull);

    await tester.enterText(
      find.byKey(const Key('wr_detail_field')),
      'chuyện xảy ra trong cuộc họp sáng nay',
    );
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();

    expect(find.byType(WrMeaningScreen), findsOneWidget);
    expect(
      episodes.episodes.single.notes[ReflectionPattern.explore.dbValue],
      'chuyện xảy ra trong cuộc họp sáng nay',
    );
    // Lớp 1 mở bằng ô trống, kể cả nhánh "Điều khác".
    final field = tester.widget<TextField>(
      find.byKey(const Key('wr_meaning_field')),
    );
    expect(field.controller!.text, isEmpty);

    // Viết một câu rồi sang Lớp 2: chữ vừa viết phải hiện lại nguyên vẹn dưới
    // nhãn "Điều bạn vừa viết", và §V vẫn giữ — không có tình huống thì Aha
    // dùng câu mặc định cố định.
    await tester.enterText(
      find.byKey(const Key('wr_meaning_field')),
      'mình chưa từng nói ra',
    );
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();

    expect(
      find.text('$kInsightStemPrefix mình chưa từng nói ra'),
      findsOneWidget,
    );
    expect(find.text(kDefaultAha), findsOneWidget);
    expect(
      episodes.episodes.single.notes[ReflectionPattern.reframe.dbValue],
      '$kInsightStemPrefix mình chưa từng nói ra',
      reason: 'chữ ở Lớp 1 phải ghi ngay, không đợi tới lúc xác nhận',
    );
  });

  testWidgets('sáu cảm xúc check-in ánh xạ đúng bốn archetype', (tester) async {
    final moments = {
      for (final o in kCheckinOptions) o.mood: momentForMood(o.mood),
    };
    // Bốn chứ không phải sáu: hai cảm xúc thêm 24/08 cùng rơi vào Confusion —
    // "có điều gì đó không ổn, chưa gọi tên được" (HXA §2.5). Phần phân biệt
    // giữa chúng nằm ở cụm chiều S1/S2, không ở nhãn archetype.
    expect(moments.values.toSet(), hasLength(4));
    expect(moments[Mood.stressed], HumanMoment.confusion);
    expect(moments[Mood.tired], HumanMoment.recovery);
    expect(moments[Mood.foggy], HumanMoment.confusion);
    expect(moments[Mood.outofsync], HumanMoment.confusion);
    expect(moments[Mood.okay], HumanMoment.arrival);
    expect(moments[Mood.happy], HumanMoment.celebration);
  });
}
