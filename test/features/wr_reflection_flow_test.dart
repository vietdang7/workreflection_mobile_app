// Test luồng phản tư mới — WXS §4 (Experience State Machine) + HXA §2, §3.
//
// Kiểm chứng đúng những yêu cầu của khách:
//   • Home chỉ mời, không xổ nội dung
//   • mỗi màn một hành động: năng lượng → khoảnh khắc → từng câu hỏi
//   • sáu thẻ Human Moment
//   • ghi chú tự viết được lưu thành ký ức
//   • bỏ dở giữa chừng thì quay lại vẫn tiếp tục, không bắt đầu lại

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_flow.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/features/wr/episode_flow_controller.dart';
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

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';
import '../support/resume_open_episode.dart';

class _Harness {
  _Harness()
      : episodes = FakeWrEpisodeRepository(),
        intel = FakeWrIntelligenceRepository(),
        content = FakeWrContentRepository(),
        moodContent = FakeWrMoodContentRepository(),
        wr = FakeWrRepository();

  final FakeWrEpisodeRepository episodes;
  final FakeWrIntelligenceRepository intel;
  final FakeWrContentRepository content;
  final FakeWrMoodContentRepository moodContent;
  final FakeWrRepository wr;

  Widget app({String initialLocation = '/home'}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
        GoRoute(
          path: '/wr/flow/energy',
          builder: (_, __) => const WrEnergyScreen(),
        ),
        GoRoute(
          path: '/wr/flow/moment',
          builder: (_, __) => const WrMomentScreen(),
        ),
        GoRoute(
          path: '/wr/flow/step',
          builder: (_, __) => const WrStepScreen(),
        ),
        GoRoute(
          path: '/wr/flow/detail',
          builder: (_, __) => const WrDetailScreen(),
        ),
        GoRoute(
          path: '/wr/flow/meaning',
          builder: (_, __) => const WrMeaningScreen(),
        ),
        GoRoute(
          path: '/wr/flow/commit',
          builder: (_, __) => const WrCommitScreen(),
        ),
        GoRoute(
          path: '/wr/flow/done',
          builder: (_, __) => const WrDoneScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        wrEpisodeRepositoryProvider.overrideWithValue(episodes),
        wrIntelligenceRepositoryProvider.overrideWithValue(intel),
        wrContentRepositoryProvider.overrideWithValue(content),
        wrMoodContentRepositoryProvider.overrideWithValue(moodContent),
        wrRepositoryProvider.overrideWithValue(wr),
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
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  group('Home — hỏi luôn năng lượng', () {
    testWidgets('hỏi ngay trên Home, không cần bấm Bắt đầu', (tester) async {
      final h = _Harness();
      await _pump(tester, h.app());

      expect(find.text('Ngày hôm nay của bạn như thế nào?'), findsOneWidget);
      for (final o in kCheckinOptions) {
        expect(
          find.byKey(Key('wr_home_checkin_${o.id}')),
          findsOneWidget,
          reason: 'thiếu ô ${o.id}',
        );
      }
      // Không còn nút trung gian.
      expect(find.byKey(const Key('wr_home_start_reflection')), findsNothing);
    });

    // v2.0 §9.1: "Home dẫn thẳng vào luồng 5 bước ngay sau khi người dùng chạm
    // chọn cảm xúc check-in". Màn "Chọn khoảnh khắc" từng chen vào giữa đã bị
    // gỡ khỏi đường này — nó đẩy chip tình huống xuống bước hai và, với hai
    // archetype không có bước đó, làm mất hẳn `situation_code`.
    testWidgets('trả lời cảm xúc là mở thẳng bước chọn tình huống',
        (tester) async {
      final h = _Harness();
      h.content.seedSituations(_someSituations);
      await _pump(tester, h.app());

      await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
      await tester.pumpAndSettle();

      expect(find.byType(WrStepScreen), findsOneWidget);
      expect(find.text(kNoticePrompt), findsOneWidget);
      // Không có màn khoảnh khắc nào chen giữa.
      for (final moment in HumanMoment.values) {
        expect(find.byKey(Key('wr_moment_${moment.dbValue}')), findsNothing);
      }
      // Và không có ô chữ nào ở bước đầu.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('có phiên đang mở thì Home KHÔNG mời tiếp tục, chỉ có đúng các '
        'khối của mockup', (tester) async {
      // Khách 2026-07-30: bỏ thẻ "ĐANG CHỜ BẠN". Mockup Sprint 2 không có nó, và
      // Home phải đúng bằng bản thiết kế.
      //
      // Phiên dở không mất đường quay lại: rời luồng gọi `pause()` nên phiên
      // thành dormant và tab Hành trình mở lại được nó ("Hiểu lại chuyện này").
      final h = _Harness();
      h.seedOpenEpisode();
      await _pump(tester, h.app());

      expect(find.byKey(const Key('wr_home_resume_reflection')), findsNothing);
      expect(find.text(HumanMoment.confusion.tension), findsNothing);
      // Lưới check-in vẫn nguyên chỗ — hỏi thì phải bày sẵn chỗ trả lời.
      expect(find.byKey(const Key('wr_home_checkin_tired')), findsOneWidget);
      expect(
        find.text('Ngày hôm nay của bạn như thế nào?'),
        findsOneWidget,
      );
    });

    // Dormant chỉ đi được sang Reactivated (WXS §4.4). Nạp thẳng vào luồng thì
    // bước lưu kế tiếp đâm vào transition bất hợp lệ và hiện "Không lưu được".
    testWidgets('tiếp tục phiên đang ngủ thì đánh thức trước khi đi tiếp',
        (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        state: ExperienceState.dormant,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'notice': 'cố lên'},
      );
      await _pump(tester, h.app());
      await _resume(tester);

      expect(h.episodes.episodes.single.state, ExperienceState.reactivated);

      // Và bước xác nhận ý nghĩa lưu được, không báo lỗi.
      await tester.enterText(
        find.byKey(const Key('wr_meaning_field')),
        'Tôi cần nói ra sớm hơn.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Không lưu được'), findsNothing);
      expect(
        h.episodes.episodes.single.draftMeaning,
        'Tôi cần nói ra sớm hơn.',
      );
    });
  });

  group('Màn năng lượng đứng riêng', () {
    testWidgets('chọn xong mở màn sáu khoảnh khắc, không cần nút xác nhận',
        (tester) async {
      final h = _Harness();
      await _pump(tester, h.app(initialLocation: '/wr/flow/energy'));

      expect(find.byKey(const Key('wr_flow_primary')), findsNothing);

      await tester.tap(find.byKey(const Key('wr_energy_low')));
      await tester.pumpAndSettle();

      for (final moment in HumanMoment.values) {
        expect(
          find.byKey(Key('wr_moment_${moment.dbValue}')),
          findsOneWidget,
          reason: 'thiếu thẻ ${moment.dbValue}',
        );
      }
    });
  });

  group('Màn khoảnh khắc — chỉ còn là lối vào phụ', () {
    // Không còn nằm trên đường Home → Reflect (§9.1), nhưng vẫn giữ cho lối vào
    // qua màn năng lượng: ở đó không có cảm xúc nào để suy ra archetype.
    testWidgets('vẫn đủ sáu thẻ khi vào từ màn năng lượng', (tester) async {
      final h = _Harness();
      await _pump(tester, h.app(initialLocation: '/wr/flow/energy'));
      await tester.tap(find.byKey(const Key('wr_energy_low')));
      await tester.pumpAndSettle();

      expect(find.text(HumanMoment.arrival.label), findsOneWidget);
      expect(find.text(HumanMoment.celebration.label), findsOneWidget);
    });
  });

  group('Bước 0 — chọn tình huống (§V)', () {
    testWidgets('chạm một tình huống mở Episode và ghi ngay situation_code',
        (tester) async {
      final h = _Harness();
      h.content.seedSituations(_someSituations);
      await _pump(tester, h.app());
      await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
      await tester.pumpAndSettle();

      // Check-in được ghi ngay khi chạm ô cảm xúc, TRƯỚC khi có Episode nào.
      expect(h.wr.upsertCheckinCalls, hasLength(1));
      expect(h.wr.upsertCheckinCalls.first.energy, CheckinEnergy.low);
      expect(h.wr.upsertCheckinCalls.first.mood, Mood.tired);
      expect(h.wr.upsertCheckinCalls.first.direction, isNull);
      // Chưa chọn tình huống thì chưa có phiên rỗng nào trong DB.
      expect(h.episodes.openEpisodeCalls, isEmpty);

      final shown = _firstVisibleSituationCode();
      await tester.tap(find.byKey(Key('wr_situation_$shown')));
      await tester.pumpAndSettle();

      expect(h.episodes.openEpisodeCalls, hasLength(1));
      final opened = h.episodes.openEpisodeCalls.first;
      // Archetype suy từ cảm xúc: "mệt mỏi" → Recovery (HXA §2.5).
      expect(opened.humanMoment, HumanMoment.recovery);
      expect(opened.energy, CheckinEnergy.low);
      expect(opened.state, ExperienceState.captured);

      final saved = h.episodes.episodes.single;
      expect(saved.situationCode, shown);
      expect(saved.patternsDone, contains(ReflectionPattern.notice));
      // §4.1: mã vừa chọn được đẩy lên đầu lịch sử chống lặp.
      expect(h.wr.saveRecentSituationIdsCalls.last.first, shown);
    });

    testWidgets('thoát giữa chừng thì phiên ngủ, không mất', (tester) async {
      final h = _Harness();
      h.content.seedSituations(_someSituations);
      h.seedOpenEpisode(
        moment: HumanMoment.recovery,
        state: ExperienceState.exploring,
        patternsDone: const [ReflectionPattern.notice],
        situationCode: 'A3-sit-01',
      );
      await _pump(tester, h.app());
      await _resume(tester, stopAtDetail: true);

      await tester.enterText(
        find.byKey(const Key('wr_detail_field')),
        'Cuộc họp sáng nay',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_close')));
      await tester.pumpAndSettle();

      expect(h.episodes.dormantCalls, hasLength(1));
      final saved = h.episodes.episodes.single;
      expect(saved.state, ExperienceState.dormant);
      // Chữ đã viết vẫn còn nguyên.
      expect(saved.notes['explore'], 'Cuộc họp sáng nay');
    });
  });

  group('Bước 1 — chi tiết cụ thể (§V)', () {
    testWidgets('bỏ trống vẫn đi tiếp được — bước này KHÔNG bắt buộc',
        (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.recovery,
        state: ExperienceState.exploring,
        patternsDone: const [ReflectionPattern.notice],
      );
      await _pump(tester, h.app());
      await _resume(tester, stopAtDetail: true);

      expect(find.byType(WrDetailScreen), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('wr_flow_primary')),
      );
      expect(button.onPressed, isNotNull,
          reason: '§V ghi rõ "không bắt buộc" — khoá nút khi ô trống là biến '
              'một bước tuỳ chọn thành bắt buộc');

      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      expect(find.byType(WrMeaningScreen), findsOneWidget);
      // Không viết gì thì không ghi bước nào.
      expect(h.episodes.episodes.single.notes['explore'], isNull);
    });

    testWidgets('viết rồi thì lưu vào bước explore', (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.recovery,
        state: ExperienceState.exploring,
        patternsDone: const [ReflectionPattern.notice],
      );
      await _pump(tester, h.app());
      await _resume(tester, stopAtDetail: true);

      await tester.enterText(
        find.byKey(const Key('wr_detail_field')),
        'Cảm giác không được nghe',
      );
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(find.byType(WrMeaningScreen), findsOneWidget);
      expect(
        h.episodes.episodes.single.notes['explore'],
        'Cảm giác không được nghe',
      );
    });

    // Nhánh "Điều khác" để `situation_code` trống, nên phiên đó biến mất khỏi
    // mọi thống kê theo tình huống (14/59 Episode trên DB thật, 2026-08-22).
    // Màn này hỏi thêm một chạm để phiên tự mô tả vẫn có chỗ đứng.
    group('nhánh Điều khác — hỏi lại điều gần nhất', () {
      _Harness customHarness() {
        final h = _Harness();
        h.content.seedSituations(_someSituations);
        h.seedOpenEpisode(
          moment: HumanMoment.recovery,
          state: ExperienceState.exploring,
          patternsDone: const [ReflectionPattern.notice],
          // Đúng dấu vết của nhánh "Điều khác".
          situationCode: null,
        );
        return h;
      }

      testWidgets('phiên đã có mã thì không hỏi lại', (tester) async {
        final h = _Harness();
        h.content.seedSituations(_someSituations);
        h.seedOpenEpisode(
          moment: HumanMoment.recovery,
          state: ExperienceState.exploring,
          patternsDone: const [ReflectionPattern.notice],
          situationCode: 'A3-sit-01',
        );
        await _pump(tester, h.app());
        await _resume(tester, stopAtDetail: true);

        expect(find.text('GẦN NHẤT VỚI ĐIỀU NÀO?'), findsNothing);
      });

      testWidgets('chọn một chip thì phiên được vá mã và vào lịch sử',
          (tester) async {
        final h = customHarness();
        await _pump(tester, h.app());
        await _resume(tester, stopAtDetail: true);

        expect(find.text('GẦN NHẤT VỚI ĐIỀU NÀO?'), findsOneWidget);

        final chip = find.byKey(const Key('wr_detail_link_A3-sit-01'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('wr_flow_primary')));
        await tester.pumpAndSettle();

        final saved = h.episodes.episodes.single;
        expect(saved.situationCode, 'A3-sit-01');
        expect(h.wr.saveRecentSituationIdsCalls.last.first, 'A3-sit-01');
      });

      testWidgets('bỏ qua vẫn đi tiếp được, phiên giữ nguyên không mã',
          (tester) async {
        final h = customHarness();
        await _pump(tester, h.app());
        await _resume(tester, stopAtDetail: true);

        await tester.tap(find.byKey(const Key('wr_flow_primary')));
        await tester.pumpAndSettle();

        expect(find.byType(WrMeaningScreen), findsOneWidget);
        expect(h.episodes.episodes.single.situationCode, isNull);
      });
    });
  });

  group('Ý nghĩa và ký ức', () {
    // Câu trả lời tách khỏi câu hỏi thì vô nghĩa. Bước Insight phải đọc lại đủ
    // cặp hỏi–đáp. Ô nhập thì mở sẵn bằng câu Aha (§V) — không có tình huống
    // thì dùng câu mặc định, không bao giờ để trống.
    testWidgets('đọc lại đủ câu hỏi lẫn câu trả lời, ô nhập mở sẵn câu Aha',
        (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': 'Mình đã dám trình bày trước cả phòng'},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_meaning_recap')), findsOneWidget);
      expect(find.text(kCustomDetailPrompt), findsOneWidget);
      expect(
        find.text('Mình đã dám trình bày trước cả phòng'),
        findsOneWidget,
      );

      final field = tester.widget<TextField>(
        find.byKey(const Key('wr_meaning_field')),
      );
      expect(field.controller!.text, kDefaultAha);
    });

    // Đọc lại mà không sửa được thì vô ích: người dùng nhìn lại mới thấy mình
    // vừa trả lời cụt, lúc đó phải viết lại được ngay (WPA Inv.4).
    testWidgets('sửa lại được câu trả lời ngay trên màn Ý nghĩa',
        (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': 'hôm nay'},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_meaning_recap_explore')), findsOneWidget);
      final answer = find.text('hôm nay');
      await tester.ensureVisible(answer);
      await tester.pumpAndSettle();
      await tester.tap(answer);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('wr_meaning_recap_field_explore')),
        'Mình đã dám trình bày trước cả phòng',
      );
      await tester.tap(find.byKey(const Key('wr_meaning_recap_save_explore')));
      await tester.pumpAndSettle();

      expect(
        h.episodes.episodes.single.notes['explore'],
        'Mình đã dám trình bày trước cả phòng',
      );
      // Sửa xong quay về dạng đọc, chữ mới hiện ngay.
      expect(
        find.text('Mình đã dám trình bày trước cả phòng'),
        findsOneWidget,
      );
      expect(find.text('hôm nay'), findsNothing);
    });

    testWidgets('chỉ người dùng xác nhận mới sinh Insight', (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'name': 'Mình đã dám trình bày trước cả phòng'},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await tester.pumpAndSettle();

      // Chưa viết gì thì chưa xác nhận được.
      expect(h.intel.insertInsightCalls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('wr_meaning_field')),
        'Tôi lên tiếng được khi thấy an toàn.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(h.episodes.confirmMeaningCalls, hasLength(1));
      expect(h.intel.insertInsightCalls, hasLength(1));
      expect(
        h.intel.insertInsightCalls.first.content,
        'Tôi lên tiếng được khi thấy an toàn.',
      );
    });

    // Owner gặp trên bản debug 2026-07-28: màn Lựa chọn mở bằng push, bấm Back
    // là về đúng màn Ý nghĩa với Episode đã meaning_confirmed. Bấm nút lần nữa
    // thì code chạy lại chuỗi forming → confirmed và ném
    // "Transition bất hợp lệ: meaning_confirmed → meaning_forming".
    /// Đi trọn đường như người dùng: xác nhận Ý nghĩa (sang màn Lựa chọn bằng
    /// push) rồi bấm Back để quay lại đúng màn Ý nghĩa — lúc này Episode đã ở
    /// meaning_confirmed. Seed thẳng state đó KHÔNG tái hiện được, vì resume từ
    /// Home sẽ nhảy luôn sang màn Lựa chọn.
    Future<_Harness> backToMeaningAfterConfirm(WidgetTester tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': 'Mình đã dám trình bày'},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await _confirmMeaning(tester);
      // Nút Back riêng của WrFlowScaffold, không phải AppBar chuẩn.
      await tester.tap(find.byKey(const Key('wr_flow_back')));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('quay lại bấm xác nhận lần nữa không ném lỗi trạng thái',
        (tester) async {
      final h = await backToMeaningAfterConfirm(tester);
      expect(h.episodes.episodes.single.state,
          ExperienceState.meaningConfirmed);
      final insightsAfterFirst = h.intel.insertInsightCalls.length;

      // Không sửa gì, bấm lại đúng nút đó.
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Transition bất hợp lệ'), findsNothing);
      expect(find.textContaining('Không lưu được'), findsNothing);
      // Câu không đổi thì không ghi gì, và không sinh Insight trùng.
      expect(h.episodes.reviseMeaningCalls, isEmpty);
      expect(h.intel.insertInsightCalls, hasLength(insightsAfterFirst));
    });

    // Owner gặp tiếp trên bản web 2026-07-28: "Transition bất hợp lệ:
    // integrated → meaning_forming". Màn Đóng KHÔNG có nút Back trong app, nên
    // đường về là nút Back của trình duyệt — thứ đi vòng qua mọi nút của app.
    // Bản vá đầu chỉ chặn meaning_confirmed nên vẫn dính ở integrated.
    testWidgets('khép phiên rồi lùi về màn Ý nghĩa cũng không ném lỗi',
        (tester) async {
      final h = _Harness();
      h.moodContent.seedChoicePool(const ['Ghi nhớ điều này để xem lại sau']);
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': 'Mình đã dám trình bày'},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await _confirmMeaning(tester);

      // Chọn một lựa chọn rồi lưu → sang màn Đóng, Episode được integrate.
      await tester.tap(find.byKey(const Key('wr_choice_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      expect(h.episodes.episodes.single.state, ExperienceState.integrated);

      // Back của trình duyệt: Đóng → Lựa chọn → Ý nghĩa.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_meaning_field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Transition bất hợp lệ'), findsNothing);
      expect(find.textContaining('Không lưu được'), findsNothing);
      // Phiên đã vào Career Memory — tuyệt đối không sửa lặng lẽ.
      expect(h.episodes.reviseMeaningCalls, isEmpty);
      expect(h.episodes.episodes.single.state, ExperienceState.integrated);
    });

    testWidgets('sửa lại câu đã xác nhận thì cập nhật, vẫn không đổi trạng thái',
        (tester) async {
      final h = await backToMeaningAfterConfirm(tester);

      await tester.enterText(
        find.byKey(const Key('wr_meaning_field')),
        'Câu mới sau khi nghĩ lại.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(h.episodes.reviseMeaningCalls, hasLength(1));
      final saved = h.episodes.episodes.single;
      expect(saved.draftMeaning, 'Câu mới sau khi nghĩ lại.');
      expect(saved.state, ExperienceState.meaningConfirmed);
      expect(find.textContaining('Transition bất hợp lệ'), findsNothing);
    });

    testWidgets('khép phiên mới ghi Career Memory (WDA Inv.6)', (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': 'Mình đã dám trình bày'},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await tester.pumpAndSettle();

      // Trước khi xác nhận: chưa có ký ức nào.
      expect(h.content.insertMemoryEventCalls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('wr_meaning_field')),
        'Mình đã dám trình bày',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      // Hai Lớp v1.6 §V: mọi khoảnh khắc đều đi qua bước Lựa chọn, kể cả
      // Celebration. Xác nhận ý nghĩa xong CHƯA khép phiên.
      expect(h.episodes.integrateCalls, isEmpty);
      expect(h.content.insertMemoryEventCalls, isEmpty);

      // Bỏ qua lựa chọn — HXA §3.8: Reflection kết thúc khi đủ ý nghĩa, không
      // phải khi đủ bước.
      await tester.tap(find.byKey(const Key('wr_flow_secondary')));
      await tester.pumpAndSettle();

      expect(h.episodes.integrateCalls, hasLength(1));
      expect(h.content.insertMemoryEventCalls, hasLength(1));
      expect(
        h.content.insertMemoryEventCalls.first.reflectionText,
        'Mình đã dám trình bày',
      );
      expect(
        h.content.insertMemoryEventCalls.first.behavior,
        'reflection_episode',
      );
      expect(h.episodes.episodes.single.state, ExperienceState.integrated);
    });

    // Owner gặp trên bản web 2026-07-29: "Transition bất hợp lệ: integrated →
    // committed". Cùng một cái bẫy như bước Ý nghĩa, chỉ lùi thêm một màn —
    // màn Đóng cũng mở bằng push nên Back là về đúng màn Lựa chọn.
    /// Đi trọn đường: xác nhận Ý nghĩa → chọn một câu → lưu (sang màn Đóng,
    /// Episode được integrate) → Back về đúng màn Lựa chọn.
    Future<_Harness> backToChoiceAfterCommit(WidgetTester tester) async {
      final h = _Harness();
      h.moodContent.seedChoicePool(const [
        'Ghi nhớ điều này để xem lại sau',
        'Nói chuyện với ai đó về điều này',
        'Chưa biết, cần thêm thời gian',
        'Không cần hành động gì, chỉ cần ghi nhận là đủ',
      ]);
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': 'Mình đã dám trình bày'},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await _confirmMeaning(tester);

      await tester.tap(find.byKey(const Key('wr_choice_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      // Back của trình duyệt: Đóng → Lựa chọn.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('khép phiên rồi lùi về màn Lựa chọn, bấm lưu lần nữa không ném '
        'lỗi', (tester) async {
      final h = await backToChoiceAfterCommit(tester);
      expect(h.episodes.episodes.single.state, ExperienceState.integrated);
      expect(find.byKey(const Key('wr_choice_0')), findsOneWidget);
      // Bể lựa chọn được trộn mỗi lần vào, nên giữ lại câu đã ghi để so.
      final choiceBefore = h.episodes.episodes.single.reflectChoice;

      await tester.tap(find.byKey(const Key('wr_choice_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Transition bất hợp lệ'), findsNothing);
      expect(find.textContaining('Không lưu được'), findsNothing);
      // Phiên đã vào Career Memory — không sửa lặng lẽ lựa chọn đã ghi.
      expect(h.episodes.reviseActionCalls, isEmpty);
      final saved = h.episodes.episodes.single;
      expect(saved.state, ExperienceState.integrated);
      expect(saved.reflectChoice, choiceBefore);
    });

    testWidgets('lùi về màn Đóng lần nữa không ghi trùng Career Memory',
        (tester) async {
      final h = await backToChoiceAfterCommit(tester);
      expect(h.content.insertMemoryEventCalls, hasLength(1));
      final stepsAfterFirst = h.intel.insertReflectionStepCalls.length;

      // Tới lại màn Đóng: initState gọi integrate() lần hai.
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(h.episodes.integrateCalls, hasLength(1));
      expect(h.content.insertMemoryEventCalls, hasLength(1));
      expect(h.intel.insertReflectionStepCalls, hasLength(stepsAfterFirst));
    });

    // Ở mức controller chứ không qua UI: màn Lựa chọn luôn đẩy sang màn Đóng,
    // mà màn Đóng khép phiên ngay trong initState — nên state `committed` chỉ
    // tồn tại khi bước khép chưa chạy xong (đóng app, mất mạng, integrate lỗi).
    // Đúng lúc đó người dùng vẫn phải đổi được lựa chọn.
    test('đổi lựa chọn khi phiên còn mở thì cập nhật, không đổi trạng thái',
        () async {
      final episodes = FakeWrEpisodeRepository();
      episodes.seed([
        const ReflectionEpisode(
          id: 'ep-seed',
          userId: 'u1',
          humanMoment: HumanMoment.celebration,
          state: ExperienceState.committed,
          tinyAction: 'Ghi nhớ điều này để xem lại sau',
          reflectChoice: 'Ghi nhớ điều này để xem lại sau',
        ),
      ]);
      final container = ProviderContainer(overrides: [
        wrEpisodeRepositoryProvider.overrideWithValue(episodes),
        currentUserIdProvider.overrideWithValue('u1'),
      ]);
      addTearDown(container.dispose);

      final flow = container.read(episodeFlowProvider.notifier);
      await flow.resume(episodes.episodes.single);

      // Bấm lại đúng câu cũ: không ghi gì cả.
      await flow.commit(
        'Ghi nhớ điều này để xem lại sau',
        choice: 'Ghi nhớ điều này để xem lại sau',
      );
      expect(episodes.reviseActionCalls, isEmpty);

      // Đổi sang câu khác: cập nhật thuần, trạng thái giữ nguyên.
      await flow.commit(
        'Nói chuyện với ai đó về điều này',
        choice: 'Nói chuyện với ai đó về điều này',
      );
      expect(episodes.commitActionCalls, isEmpty);
      expect(episodes.reviseActionCalls, hasLength(1));
      final saved = episodes.episodes.single;
      expect(saved.state, ExperienceState.committed);
      expect(saved.tinyAction, 'Nói chuyện với ai đó về điều này');
      expect(saved.reflectChoice, 'Nói chuyện với ai đó về điều này');

      // Chuyển sang tự viết thì lựa chọn cũ phải biến mất, không giữ lại.
      await flow.commit('Mình sẽ tự nhắc mình mỗi sáng');
      expect(episodes.episodes.single.reflectChoice, isNull);
    });
  });
  // -------------------------------------------------------------------------
  // Hai Lớp v1.6 — chip lọc theo cảm xúc, Aha gợi sẵn, bể Lựa chọn
  // -------------------------------------------------------------------------

  group('v1.6 · bước Lựa chọn (§VI)', () {
    testWidgets('Practice của tình huống đứng đầu và mang nhãn Gợi ý',
        (tester) async {
      final h = _Harness();
      h.moodContent.seedChoicePool(const [
        'Thử một cách tiếp cận khác vào lần tới',
        'Giữ nguyên cách làm hiện tại, quan sát thêm',
        'Chưa biết, cần thêm thời gian',
        'Nói chuyện với ai đó về điều này',
        'Ghi nhớ điều này để xem lại sau',
        'Đặt lời nhắc để quay lại tình huống này sau một tuần',
        'Chia sẻ điều này với người liên quan trực tiếp',
        'Không cần hành động gì, chỉ cần ghi nhận là đủ',
      ]);
      h.content
        ..seedSituations([
          const WrSituation(
            code: 'C2-sit-01',
            text: 'Không dám lên tiếng',
            scaDimension: ScaDimension.c2,
            wave: 1,
          ),
        ])
        ..seedStories([
          const WrStory(
            storyId: 'C2-01',
            title: 'Ý tưởng của tôi biến mất trong cuộc họp',
            scaDimension: ScaDimension.c2,
            storyContent: 'Tôi đã chuẩn bị khá kỹ.',
            emotionTags: [],
            behaviorTags: [],
            careerStages: [],
            selfReflection: 'Lần gần nhất tôi thấy tiếng nói mình không được '
                'nhìn thấy là khi nào?',
            ahaMessage: 'Đôi khi điều khiến tôi im lặng không phải vì thiếu ý '
                'tưởng.',
            practiceAction: 'Tuần này ghi lại một lần tôi muốn lên tiếng '
                'nhưng đã chọn im lặng.',
          ),
        ]);

      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        situationCode: 'C2-sit-01',
      );

      await _pump(tester, h.app());
      await _resume(tester);
      await _confirmMeaning(tester);

      // §VI: bốn lựa chọn — Practice riêng + 3 câu chung.
      expect(find.byKey(const Key('wr_choice_0')), findsOneWidget);
      expect(find.byKey(const Key('wr_choice_3')), findsOneWidget);
      expect(find.byKey(const Key('wr_choice_4')), findsNothing);

      // Practice đứng đầu và là mục DUY NHẤT mang nhãn "Gợi ý".
      expect(
        find.textContaining('tôi muốn lên tiếng nhưng đã chọn im lặng'),
        findsOneWidget,
      );
      expect(find.text('Gợi ý'), findsOneWidget);
    });

    testWidgets('không đọc được bể thì lùi về ô tự viết, không hiện màn trống',
        (tester) async {
      final h = _Harness(); // bể để rỗng
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
      );

      await _pump(tester, h.app());
      await _resume(tester);
      await _confirmMeaning(tester);

      expect(find.byKey(const Key('wr_commit_field')), findsOneWidget);
      expect(find.byKey(const Key('wr_choice_0')), findsNothing);
    });
  });

  // WDA Invariant 9 + v1.6 §V: Choice là MỘT bước của Reflection Cycle, không
  // phải một phần của Action. Trước đây câu người dùng chạm bị lưu thẳng vào
  // tiny_action, nên wr_reflection_steps chưa bao giờ có dòng 'choice'.
  group('v1.6 · Choice là bước riêng (§V · WDA Inv.9)', () {
    /// Đưa Episode tới màn Lựa chọn với bể [pool].
    Future<_Harness> toChoiceStep(
      WidgetTester tester, {
      required List<String> pool,
    }) async {
      final h = _Harness();
      if (pool.isNotEmpty) h.moodContent.seedChoicePool(pool);
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await _confirmMeaning(tester);
      return h;
    }

    testWidgets('chạm một lựa chọn thì ghi cả bước choice lẫn bước action',
        (tester) async {
      const pool = [
        'Thử một cách tiếp cận khác vào lần tới',
        'Giữ nguyên cách làm hiện tại, quan sát thêm',
        'Chưa biết, cần thêm thời gian',
        'Nói chuyện với ai đó về điều này',
      ];
      final h = await toChoiceStep(tester, pool: pool);

      // Bể xáo ngẫu nhiên nên không biết trước câu nào ở vị trí 0 — đọc thẳng
      // nhãn đang hiện để biết mình vừa chạm vào cái gì.
      final tile = find.byKey(const Key('wr_choice_0'));
      final shown = tester
          .widget<Text>(
            find.descendant(of: tile, matching: find.byType(Text)).first,
          )
          .data;

      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      final picked = h.episodes.episodes.single.reflectChoice;
      expect(picked, shown, reason: 'phải lưu đúng câu người dùng đã chạm');
      expect(pool, contains(picked));

      final steps = h.intel.insertReflectionStepCalls;
      final choiceSteps =
          steps.where((s) => s.step == ReflectionStepType.choice).toList();
      final actionSteps =
          steps.where((s) => s.step == ReflectionStepType.action).toList();

      expect(choiceSteps, hasLength(1));
      expect(choiceSteps.single.content, picked);
      // Action vẫn còn: câu đó vừa là lựa chọn, vừa là điều đã cam kết.
      expect(actionSteps, hasLength(1));
      expect(actionSteps.single.content, picked);
    });

    testWidgets('tự viết thì có bước action nhưng KHÔNG có bước choice',
        (tester) async {
      // Bể rỗng → màn lùi về ô tự viết. Không có lựa chọn nào được đưa ra,
      // nên ghi một dòng 'choice' sẽ là bịa ra việc chưa từng xảy ra.
      final h = await toChoiceStep(tester, pool: const []);

      await tester.enterText(
        find.byKey(const Key('wr_commit_field')),
        'Tuần này tôi sẽ nói ra sớm hơn.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(h.episodes.episodes.single.reflectChoice, isNull);

      final steps = h.intel.insertReflectionStepCalls;
      expect(
        steps.where((s) => s.step == ReflectionStepType.choice),
        isEmpty,
      );
      expect(
        steps
            .where((s) => s.step == ReflectionStepType.action)
            .single
            .content,
        'Tuần này tôi sẽ nói ra sớm hơn.',
      );
    });
  });

  group('v1.6 · Aha gợi sẵn ở bước Ý nghĩa (§V)', () {
    testWidgets('ô nhập điền sẵn câu Aha, kèm câu Self Reflection',
        (tester) async {
      final h = _Harness();
      h.content
        ..seedSituations([
          const WrSituation(
            code: 'C2-sit-01',
            text: 'Không dám lên tiếng',
            scaDimension: ScaDimension.c2,
            wave: 1,
          ),
        ])
        ..seedStories([
          const WrStory(
            storyId: 'C2-01',
            title: 'Ý tưởng của tôi biến mất',
            scaDimension: ScaDimension.c2,
            storyContent: 'Nội dung.',
            emotionTags: [],
            behaviorTags: [],
            careerStages: [],
            selfReflection: 'Điều gì thường khiến tôi ngần ngại lên tiếng?',
            ahaMessage: 'Nhiều tổ chức không thiếu ý tưởng.',
            practiceAction: 'Viết ra một điều tôi đang giữ lại.',
          ),
        ]);

      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        situationCode: 'C2-sit-01',
      );

      await _pump(tester, h.app());
      await _resume(tester);

      expect(
        find.byKey(const Key('wr_meaning_self_reflection')),
        findsOneWidget,
      );
      expect(
        find.text('Điều gì thường khiến tôi ngần ngại lên tiếng?'),
        findsOneWidget,
      );

      final field = tester.widget<TextField>(
        find.byKey(const Key('wr_meaning_field')),
      );
      expect(field.controller!.text, 'Nhiều tổ chức không thiếu ý tưởng.');
    });

    testWidgets('bản nháp của người dùng thắng câu Aha', (tester) async {
      // WIA Inv.2: hệ thống chỉ đề xuất. Đè lên chữ người dùng đã viết là
      // vượt quyền.
      final h = _Harness();
      h.content
        ..seedSituations([
          const WrSituation(
            code: 'C2-sit-01',
            text: 'Không dám lên tiếng',
            scaDimension: ScaDimension.c2,
            wave: 1,
          ),
        ])
        ..seedStories([
          const WrStory(
            storyId: 'C2-01',
            title: 'T',
            scaDimension: ScaDimension.c2,
            storyContent: 'N',
            emotionTags: [],
            behaviorTags: [],
            careerStages: [],
            ahaMessage: 'Câu Aha có sẵn.',
          ),
        ]);

      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        situationCode: 'C2-sit-01',
        draftMeaning: 'Chữ của chính tôi.',
      );

      await _pump(tester, h.app());
      await _resume(tester);

      final field = tester.widget<TextField>(
        find.byKey(const Key('wr_meaning_field')),
      );
      expect(field.controller!.text, 'Chữ của chính tôi.');
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

extension on _Harness {
  void seedOpenEpisode({
    HumanMoment moment = HumanMoment.confusion,
    ExperienceState state = ExperienceState.captured,
    List<ReflectionPattern> patternsDone = const [],
    Map<String, String> notes = const {},
    String? situationCode,
    String? draftMeaning,
  }) {
    episodes.seed([
      ReflectionEpisode(
        id: 'ep-seed',
        userId: 'u1',
        humanMoment: moment,
        state: state,
        energy: CheckinEnergy.low,
        patternsDone: patternsDone,
        notes: notes,
        situationCode: situationCode,
        draftMeaning: draftMeaning,
      ),
    ]);
  }
}

/// Bấm "Tiếp tục" trên Home để vào đúng màn của trạng thái hiện tại.
/// Xác nhận ý nghĩa để sang bước Lựa chọn.
Future<void> _confirmMeaning(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('wr_meaning_field')),
    'Điều tôi muốn giữ lại.',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('wr_flow_primary')));
  await tester.pumpAndSettle();
}

Future<void> _resume(WidgetTester tester, {bool stopAtDetail = false}) =>
    resumeOpenEpisode(tester, stopAtDetail: stopAtDetail);

/// Vài tình huống đủ để bước Notice có chip mà chạm.
const _someSituations = [
  WrSituation(
    code: 'A3-sit-01',
    text: 'Việc dồn nhiều hơn mình xử lý nổi',
    scaDimension: ScaDimension.a3,
    wave: 1,
  ),
  WrSituation(
    code: 'A1-sit-01',
    text: 'Không biết mình đang đi về đâu',
    scaDimension: ScaDimension.a1,
    wave: 1,
  ),
];

/// Mã của chip đang hiện đầu tiên. Danh sách được trộn ngẫu nhiên (§4.1) nên
/// không đoán trước được mã nào ở vị trí nào.
String _firstVisibleSituationCode() {
  for (final s in _someSituations) {
    if (find.byKey(Key('wr_situation_${s.code}')).evaluate().isNotEmpty) {
      return s.code;
    }
  }
  throw StateError('không có chip tình huống nào đang hiện');
}
