// Test luồng phản tư mới — WXS §4 (Experience State Machine) + HXA §2, §3.
//
// Kiểm chứng đúng những yêu cầu của khách:
//   • Home chỉ mời, không xổ nội dung
//   • mỗi màn một hành động: năng lượng → khoảnh khắc → từng câu hỏi
//   • sáu thẻ Human Moment
//   • ghi chú tự viết được lưu thành ký ức
//   • bỏ dở giữa chừng thì quay lại vẫn tiếp tục, không bắt đầu lại
//
// Từ mockup v47 (06/10) luồng còn BỐN bước: chọn chuyện (chọn rồi bấm Tiếp
// tục) → kể lại (bắt buộc) → Insight hiện ngay (đồng ý / nói lại) → mang theo
// một phép thử nhỏ (chọn thẻ hoặc tự viết, rồi Lưu).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_v47.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/widgets/wr_card.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';
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
import 'package:workreflection_mobile/core/widgets/wr_title_text.dart';

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

      expect(
        find.text(wrKeepTitleTail('Ngày hôm nay của bạn như thế nào?')),
        findsOneWidget,
      );
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

    // v2.0 §9.1: "Home dẫn thẳng vào luồng ngay sau khi người dùng chạm chọn
    // cảm xúc check-in". Màn "Chọn khoảnh khắc" từng chen vào giữa đã bị gỡ
    // khỏi đường này — nó đẩy chip tình huống xuống bước hai và, với hai
    // archetype không có bước đó, làm mất hẳn `situation_code`.
    testWidgets('trả lời cảm xúc là mở thẳng bước chọn tình huống', (
      tester,
    ) async {
      final h = _Harness();
      h.content.seedSituations(_someSituations);
      await _pump(tester, h.app());

      await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
      await tester.pumpAndSettle();

      expect(find.byType(WrStepScreen), findsOneWidget);
      // Mockup v47: tiêu đề bước 1/4 là "Điều gì giống ngày hôm nay của bạn
      // nhất?", không còn câu hỏi Notice cũ.
      expect(_para(kPickStoryTitle), findsOneWidget);
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
        find.text(wrKeepTitleTail('Ngày hôm nay của bạn như thế nào?')),
        findsOneWidget,
      );
    });

    // Dormant chỉ đi được sang Reactivated (WXS §4.4). Nạp thẳng vào luồng thì
    // bước lưu kế tiếp đâm vào transition bất hợp lệ và hiện "Không lưu được".
    testWidgets('tiếp tục phiên đang ngủ thì đánh thức trước khi đi tiếp', (
      tester,
    ) async {
      const detail = 'Cuộc họp sáng nay kéo dài';
      final h = _Harness();
      h.seedOpenEpisode(
        state: ExperienceState.dormant,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'notice': 'cố lên', 'explore': detail},
      );
      await _pump(tester, h.app());
      // Dừng ở bước kể: bấm "Tôi đã kể xong" là ghi bước explore, và chính
      // bước ghi đó đưa phiên từ reactivated sang exploring.
      await _resume(tester, stopAtDetail: true);

      expect(h.episodes.episodes.single.state, ExperienceState.reactivated);

      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      // Và bước giữ Insight lưu được, không báo lỗi. v47: Insight hiện ngay,
      // một chạm "Ừ, tôi cũng thấy vậy" là `draft_meaning` nhận đúng câu đó.
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Không lưu được'), findsNothing);
      expect(
        h.episodes.episodes.single.draftMeaning,
        reflectionAhaFor(title: 'cố lên', detail: detail),
      );
    });
  });

  group('Màn năng lượng đứng riêng', () {
    testWidgets('chọn xong mở màn sáu khoảnh khắc, không cần nút xác nhận', (
      tester,
    ) async {
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

  group('Bước 1/4 — chọn tình huống (§V)', () {
    testWidgets('chọn một tình huống rồi bấm Tiếp tục mới mở Episode và ghi '
        'situation_code', (tester) async {
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
      // Chưa chọn gì thì "Tiếp tục" khoá.
      expect(_primary(tester).onPressed, isNull);

      final shown = _firstVisibleSituationCode();
      await tester.tap(find.byKey(Key('wr_situation_$shown')));
      await tester.pumpAndSettle();

      // Mockup v47: chạm một dòng chỉ là CHỌN. Chạm nhầm thì vẫn đổi được,
      // nên chưa được mở phiên nào và vẫn đứng ở bước này.
      expect(find.byType(WrStepScreen), findsOneWidget);
      expect(h.episodes.openEpisodeCalls, isEmpty);
      expect(_primary(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(find.byType(WrDetailScreen), findsOneWidget);
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

    testWidgets('check-in lần hai luôn mở phiên mới, kể cả khi còn phiên dở', (
      tester,
    ) async {
      // Khách báo 2026-08-24: "các check in lặp lại 2 lần không được count".
      //
      // Đường đi sinh ra lỗi: chọn tình huống xong rồi rời luồng bằng thanh tab
      // (không phải nút Xong, nên `leave()` không chạy) — phiên vẫn nằm trong
      // `episodeFlowProvider`. Lần chạm ô cảm xúc kế tiếp bị `wr_step_screen`
      // kéo thẳng về bước dở của phiên cũ, không Episode nào được mở, và bộ đếm
      // Career Health đứng yên trong khi người dùng đã check-in hai lần.
      final h = _Harness();
      h.content.seedSituations(_someSituations);
      await _pump(tester, h.app());

      await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
      await tester.pumpAndSettle();
      await _pickSituation(tester, _firstVisibleSituationCode());
      expect(h.episodes.openEpisodeCalls, hasLength(1));

      // Rời luồng bằng thanh tab: không đóng phiên, không gọi `leave()`.
      GoRouter.of(tester.element(find.byType(WrDetailScreen))).go('/home');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
      await tester.pumpAndSettle();

      // Phải hỏi lại tình huống, không nhảy thẳng vào bước dở của phiên cũ.
      expect(
        find.byType(WrStepScreen),
        findsOneWidget,
        reason: 'check-in mới phải bắt đầu từ bước chọn tình huống',
      );

      await _pickSituation(tester, _firstVisibleSituationCode());

      expect(
        h.episodes.openEpisodeCalls,
        hasLength(2),
        reason: 'hai lần check-in phải thành hai lần nhìn lại được đếm',
      );
      // Phiên cũ không bị xoá — nó vẫn nằm đó để thẻ "Còn dở" mời quay lại.
      expect(h.episodes.episodes, hasLength(2));
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

  group('Bước 2/4 — một khoảnh khắc cụ thể', () {
    // Bản trước §V ghi ô này "không bắt buộc". Khách 06/10 (mockup v47) đảo
    // lại: Insight ở bước 3 được dựng từ chính câu kể (`reflectionAhaFor` đọc
    // từ khoá trong đó), nên "Tôi đã kể xong" khoá cho tới khi có chữ.
    testWidgets('ô kể BẮT BUỘC — trống thì khoá nút, gõ chữ mới mở', (
      tester,
    ) async {
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.recovery,
        state: ExperienceState.exploring,
        patternsDone: const [ReflectionPattern.notice],
      );
      await _pump(tester, h.app());
      await _resume(tester, stopAtDetail: true);

      expect(find.byType(WrDetailScreen), findsOneWidget);
      expect(
        _primary(tester).onPressed,
        isNull,
        reason: 'v47: chưa kể thì chưa có nguyên liệu cho Insight',
      );

      // Chỉ toàn khoảng trắng cũng chưa tính là đã kể.
      await tester.enterText(find.byKey(const Key('wr_detail_field')), '   ');
      await tester.pumpAndSettle();
      expect(_primary(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('wr_detail_field')),
        'Sếp hỏi lại kết quả trước cả phòng',
      );
      await tester.pumpAndSettle();
      expect(_primary(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      expect(find.byType(WrMeaningScreen), findsOneWidget);
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
      await tester.pumpAndSettle();
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

      testWidgets('phiên đã có mã thì không hỏi lại, thẻ "Bạn chọn" nhắc đúng '
          'tình huống', (tester) async {
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
        // v47 bỏ khối đọc Story; thay bằng thẻ "Bạn chọn" nhắc lại điều vừa
        // chọn ở bước 1, để người dùng kể đúng về nó.
        expect(
          find.descendant(
            of: find.byKey(const Key('wr_detail_chosen')),
            matching: _para(_someSituations.first.text),
          ),
          findsOneWidget,
        );
      });

      testWidgets('chọn một chip thì phiên được vá mã và vào lịch sử', (
        tester,
      ) async {
        final h = customHarness();
        await _pump(tester, h.app());
        await _resume(tester, stopAtDetail: true);

        expect(find.text('GẦN NHẤT VỚI ĐIỀU NÀO?'), findsOneWidget);

        final chip = find.byKey(const Key('wr_detail_link_A3-sit-01'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();

        // Ô kể vẫn bắt buộc ở nhánh này.
        await tester.enterText(
          find.byKey(const Key('wr_detail_field')),
          'Việc dồn tới cuối tuần',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('wr_flow_primary')));
        await tester.pumpAndSettle();

        final saved = h.episodes.episodes.single;
        expect(saved.situationCode, 'A3-sit-01');
        expect(h.wr.saveRecentSituationIdsCalls.last.first, 'A3-sit-01');
      });

      testWidgets('bỏ qua chip vẫn đi tiếp được, phiên giữ nguyên không mã', (
        tester,
      ) async {
        final h = customHarness();
        await _pump(tester, h.app());
        await _resume(tester, stopAtDetail: true);

        // Chip là câu hỏi phụ — chỉ ô kể là điều kiện để đi tiếp.
        await tester.enterText(
          find.byKey(const Key('wr_detail_field')),
          'Một chuyện không có trong danh sách',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('wr_flow_primary')));
        await tester.pumpAndSettle();

        expect(find.byType(WrMeaningScreen), findsOneWidget);
        expect(h.episodes.episodes.single.situationCode, isNull);
      });
    });
  });

  group('Bước 3/4 — Insight và ký ức', () {
    // Họp 26_1 BỎ khối "BẠN VỪA VIẾT" đọc lại cặp hỏi–đáp của bước trước.
    // v47 (khách 06/10) bỏ thêm lớp ô trống "Với tôi, điều này…": bấm "Tôi đã
    // kể xong" là thấy Insight NGAY.
    testWidgets('Insight hiện ngay, không còn lớp ô trống phía trước', (
      tester,
    ) async {
      const told = 'Mình đã dám trình bày trước cả phòng';
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': told},
      );
      await _pump(tester, h.app());
      await _resume(tester);

      expect(find.byType(WrMeaningScreen), findsOneWidget);
      expect(find.byKey(const Key('wr_meaning_recap')), findsNothing);
      // Câu kể không bị đọc lại nguyên văn.
      expect(find.text(told), findsNothing);
      expect(_para(told), findsNothing);

      // Không còn ô chữ nào trước Insight.
      expect(find.byKey(const Key('wr_meaning_field')), findsNothing);
      expect(find.byKey(const Key('wr_meaning_stem_card')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('wr_meaning_aha')),
          matching: _para('“${reflectionAhaFor(detail: told)}”'),
        ),
        findsOneWidget,
      );
      expect(_para(kInsightTitle), findsOneWidget);
    });

    // Mục 4.3 + 4.4 (khách 09/09) bỏ hẳn thẻ `selfReflection` và khối "CHƯA
    // BIẾT VIẾT GÌ?". v47 giữ nguyên điều đó: bước này chỉ có thẻ Insight và
    // hai lối trả lời, không có thẻ gợi ý nào chen vào.
    testWidgets('bước 3 chỉ có thẻ Insight và hai nút, không còn thẻ gợi ý', (
      tester,
    ) async {
      final h = await _atInsight(tester);

      expect(find.byKey(const Key('wr_meaning_aha')), findsOneWidget);
      expect(find.text(kInsightAgree), findsOneWidget);
      expect(find.text(kInsightRetell), findsOneWidget);
      // Nút "Tiếp tục" cũ không còn ở bước này.
      expect(find.text('Tiếp tục'), findsNothing);

      expect(find.byKey(const Key('wr_meaning_suggestions')), findsNothing);
      expect(find.byKey(const Key('wr_meaning_suggestion_0')), findsNothing);
      expect(find.byKey(const Key('wr_meaning_self_reflection')), findsNothing);
      expect(h.intel.insertInsightCalls, isEmpty);
    });

    testWidgets('chỉ người dùng xác nhận mới sinh Insight', (tester) async {
      final h = await _atInsight(tester);

      // Đứng ở thẻ Insight chưa phải là xác nhận: hệ thống chỉ đề xuất
      // (WIA Invariant 2).
      expect(h.intel.insertInsightCalls, isEmpty);
      expect(h.episodes.confirmMeaningCalls, isEmpty);

      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      final proposed = _proposedFor(h);
      expect(h.episodes.confirmMeaningCalls, hasLength(1));
      expect(h.intel.insertInsightCalls, hasLength(1));
      expect(h.intel.insertInsightCalls.first.content, proposed);
      // v47: draft_meaning là ĐÚNG câu vừa đồng ý, không còn ghép hai vế.
      expect(h.episodes.episodes.single.draftMeaning, proposed);
      expect(find.byType(WrCommitScreen), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // §10 changelog Career Snapshot (khách 10/09) — đồng ý / không đồng ý.
    // v47 đổi nhánh không đồng ý thành "Chưa đúng, để tôi nói lại".
    // -----------------------------------------------------------------------

    testWidgets('Chưa đúng thì mở màn nói lại, không lặng lẽ đi tiếp', (
      tester,
    ) async {
      // §10.2: "Không nên im lặng chuyển sang bước sau như thể không có gì xảy
      // ra." v47 dừng lại bằng một màn hỏi tiếp "Vậy điều gì gần với bạn
      // hơn?" — chưa ghi gì cho tới khi người dùng tự giữ cách hiểu của mình.
      final h = await _atInsight(tester);

      await tester.tap(find.byKey(const Key('wr_flow_secondary')));
      await tester.pumpAndSettle();

      expect(find.byType(WrMeaningScreen), findsOneWidget);
      expect(find.byType(WrCommitScreen), findsNothing);
      expect(_para(kCorrectionTitle), findsOneWidget);
      expect(find.byKey(const Key('wr_meaning_field')), findsOneWidget);
      expect(find.text(kCorrectionKeep), findsOneWidget);
      // Chưa viết gì thì chưa giữ được — và chưa ghi một dòng nào.
      expect(_primary(tester).onPressed, isNull);
      expect(h.intel.insertInsightFeedbackCalls, isEmpty);
      expect(h.intel.insertInsightCalls, isEmpty);
      expect(h.episodes.confirmMeaningCalls, isEmpty);

      // Lùi lại là về thẻ Insight, không rời bước.
      await tester.tap(find.byKey(const Key('wr_flow_back')));
      await tester.pumpAndSettle();
      expect(find.byType(WrMeaningScreen), findsOneWidget);
      expect(find.byKey(const Key('wr_meaning_aha')), findsOneWidget);
    });

    testWidgets('Nói lại: Insight là CÂU NGƯỜI DÙNG và Episode vẫn chốt', (
      tester,
    ) async {
      // Bản trước: "Không đồng ý" thì KHÔNG ghi Insight nào. Khách 06/10 muốn
      // cách hiểu người dùng tự viết lại mới là thứ được giữ, nên nó đi vào
      // `wr_reflection_insights` như mọi Insight. §10.1 vẫn giữ: lần
      // Reflection đó không bị bỏ.
      final h = await _atInsight(tester);
      final proposed = _proposedFor(h);

      await _retell(tester, 'mình chưa nói ra điều đó');

      expect(h.intel.insertInsightCalls, hasLength(1));
      expect(
        h.intel.insertInsightCalls.single.content,
        'mình chưa nói ra điều đó',
      );
      expect(h.episodes.confirmMeaningCalls, hasLength(1));
      final saved = h.episodes.episodes.single;
      expect(saved.state, ExperienceState.meaningConfirmed);
      // Câu lưu lại là câu của họ, không kèm câu hệ thống vừa đề xuất.
      expect(saved.draftMeaning, 'mình chưa nói ra điều đó');
      expect(saved.draftMeaning, isNot(contains(proposed)));
      expect(find.byType(WrCommitScreen), findsOneWidget);
    });

    testWidgets('rời màn nói lại thì chữ đang viết nằm ở notes reframe, phiên '
        'ngủ', (tester) async {
      // Rời giữa chừng chưa phải đã xác lập ý nghĩa: KHÔNG ghi draft_meaning
      // (Home sẽ hiện "Insight gần nhất" cho một phiên chưa xong), nhưng chữ
      // người dùng đang viết thì không được mất.
      final h = await _atInsight(tester);

      await tester.tap(find.byKey(const Key('wr_flow_secondary')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('wr_meaning_field')),
        'chữ của chính tôi',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_close')));
      await tester.pumpAndSettle();

      final saved = h.episodes.episodes.single;
      expect(
        saved.notes[ReflectionPattern.reframe.dbValue],
        'chữ của chính tôi',
      );
      expect(saved.draftMeaning, isNull);
      expect(saved.state, ExperienceState.dormant);
      expect(h.intel.insertInsightCalls, isEmpty);
      expect(find.byType(WrHomeScreen), findsOneWidget);
    });

    testWidgets('mở lại phiên đang nói lại dở thì về đúng ô đang viết', (
      tester,
    ) async {
      final h = await _atInsight(tester);
      await tester.tap(find.byKey(const Key('wr_flow_secondary')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('wr_meaning_field')),
        'chữ của chính tôi',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_close')));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container
          .read(episodeFlowProvider.notifier)
          .resume(h.episodes.episodes.single);
      GoRouter.of(
        tester.element(find.byType(WrHomeScreen)),
      ).push('/wr/flow/meaning');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_meaning_aha')), findsNothing);
      final field = tester.widget<TextField>(
        find.byKey(const Key('wr_meaning_field')),
      );
      expect(field.controller!.text, 'chữ của chính tôi');
      expect(_primary(tester).onPressed, isNotNull);
    });

    testWidgets('quay lại bấm đồng ý lần nữa không ghi thêm phản hồi', (
      tester,
    ) async {
      final h = await _atInsight(tester);
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      expect(find.byType(WrCommitScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_flow_back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(h.intel.insertInsightFeedbackCalls, hasLength(1));
      expect(h.intel.insertInsightCalls, hasLength(1));
    });

    testWidgets('cả hai vế đều được ghi log theo tình huống', (tester) async {
      // §10.3 — tỷ lệ từ chối là tín hiệu chất lượng nội dung. Chỉ ghi vế từ
      // chối thì không có mẫu số: "3 lần bị từ chối" không nói lên gì khi không
      // biết tình huống đó xuất hiện bao nhiêu lần.
      final agreed = await _atInsight(tester);
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      expect(agreed.intel.insertInsightFeedbackCalls, hasLength(1));
      expect(agreed.intel.insertInsightFeedbackCalls.single.agreed, isTrue);
      expect(
        agreed.intel.insertInsightFeedbackCalls.single.situationCode,
        'S1-01',
      );

      final refused = await _atInsight(tester);
      await _retell(tester, 'mình chưa nói ra');
      expect(refused.intel.insertInsightFeedbackCalls, hasLength(1));
      expect(refused.intel.insertInsightFeedbackCalls.single.agreed, isFalse);
      expect(
        refused.intel.insertInsightFeedbackCalls.single.situationCode,
        'S1-01',
      );
    });

    testWidgets('D6 — phép đếm tần suất KHÔNG loại lần bị từ chối', (
      tester,
    ) async {
      // Tài liệu §10.1 gọi thẳng đây là chỗ dễ làm sai nhất: "nếu dev lọc bỏ
      // luôn các lần Reflection bị từ chối đúc kết khỏi phép đếm tần suất, cột
      // 'Xuất hiện' sẽ bị thiếu hụt và mọi kết luận về khoảng lệch đều sai
      // theo."
      //
      // Cách khoá: Episode là nguồn duy nhất của phép đếm, nên chỉ cần Episode
      // của lần bị từ chối vẫn còn nguyên mã tình huống là phép đếm không thể
      // bỏ sót nó. Tần suất đo việc người dùng GẶP tình huống, không đo việc họ
      // ĐỒNG Ý với cách diễn giải.
      final h = await _atInsight(tester);

      await _retell(tester, 'mình chưa nói ra điều đó');

      final ep = h.episodes.episodes.single;
      expect(ep.situationCode, 'S1-01');
      expect(ep.state, ExperienceState.meaningConfirmed);
    });

    // Owner gặp trên bản debug 2026-07-28: màn Lựa chọn mở bằng push, bấm Back
    // là về đúng màn Ý nghĩa với Episode đã meaning_confirmed. Bấm nút lần nữa
    // thì code chạy lại chuỗi forming → confirmed và ném
    // "Transition bất hợp lệ: meaning_confirmed → meaning_forming".
    /// Đi trọn đường như người dùng: giữ Insight (sang màn Mang theo bằng
    /// push) rồi bấm Back để quay lại đúng màn Insight — lúc này Episode đã ở
    /// meaning_confirmed. Seed thẳng state đó KHÔNG tái hiện được, vì resume từ
    /// Home sẽ nhảy luôn qua các bước.
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

    testWidgets('quay lại bấm xác nhận lần nữa không ném lỗi trạng thái', (
      tester,
    ) async {
      final h = await backToMeaningAfterConfirm(tester);
      expect(
        h.episodes.episodes.single.state,
        ExperienceState.meaningConfirmed,
      );
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
    testWidgets('khép phiên rồi lùi về màn Ý nghĩa cũng không ném lỗi', (
      tester,
    ) async {
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

      // Chọn một phép thử rồi lưu → sang màn Xong, Episode được integrate.
      await _tapCard(tester, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      expect(h.episodes.episodes.single.state, ExperienceState.integrated);

      // Back của trình duyệt: Xong → Mang theo → Insight.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // Phiên đã có ý nghĩa chốt nên màn hiện đúng câu đã giữ — không bắt viết
      // lại một câu đã được trả lời.
      expect(find.byKey(const Key('wr_meaning_aha')), findsOneWidget);
      expect(find.byKey(const Key('wr_meaning_field')), findsNothing);

      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Transition bất hợp lệ'), findsNothing);
      expect(find.textContaining('Không lưu được'), findsNothing);
      // Phiên đã vào Career Memory — tuyệt đối không sửa lặng lẽ.
      expect(h.episodes.reviseMeaningCalls, isEmpty);
      expect(h.episodes.episodes.single.state, ExperienceState.integrated);
    });

    testWidgets(
      'sửa lại câu đã xác nhận thì cập nhật, vẫn không đổi trạng thái',
      (tester) async {
        final h = await backToMeaningAfterConfirm(tester);

        // Màn mở lại ở thẻ Insight với câu đã giữ; "Chưa đúng, để tôi nói lại"
        // là đường sửa lại chữ của mình.
        await tester.tap(find.byKey(const Key('wr_flow_secondary')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('wr_meaning_field')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('wr_meaning_field')),
          'nghĩ lại thì lý do khác',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('wr_flow_primary')));
        await tester.pumpAndSettle();

        expect(h.episodes.reviseMeaningCalls, hasLength(1));
        final saved = h.episodes.episodes.single;
        expect(saved.draftMeaning, 'nghĩ lại thì lý do khác');
        expect(saved.state, ExperienceState.meaningConfirmed);
        expect(find.textContaining('Transition bất hợp lệ'), findsNothing);
      },
    );

    testWidgets('khép phiên mới ghi Career Memory (WDA Inv.6)', (tester) async {
      const told = 'Mình đã dám trình bày';
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': told},
      );
      await _pump(tester, h.app());
      await _resume(tester);

      // Trước khi xác nhận: chưa có ký ức nào.
      expect(h.content.insertMemoryEventCalls, isEmpty);

      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      // Mọi khoảnh khắc đều đi qua bước Mang theo, kể cả Celebration. Giữ
      // Insight xong CHƯA khép phiên.
      expect(find.byType(WrCommitScreen), findsOneWidget);
      expect(h.episodes.integrateCalls, isEmpty);
      expect(h.content.insertMemoryEventCalls, isEmpty);

      // Đóng ở bước cuối vẫn giữ lần nhìn lại — HXA §3.8: Reflection kết thúc
      // khi đủ ý nghĩa, không phải khi đủ bước.
      await tester.tap(find.byKey(const Key('wr_flow_close')));
      await tester.pumpAndSettle();

      expect(find.byType(WrDoneScreen), findsOneWidget);
      expect(h.episodes.integrateCalls, hasLength(1));

      // STORY đứng đầu, đúng một mảnh cho một lượt. Các mảnh sau nó là lớp
      // diễn giải sinh thêm (changelog 24/08 §8.2) — lượt đầu tiên của một
      // người luôn kèm ít nhất một Cột mốc.
      final stories = h.content.insertMemoryEventCalls
          .where((e) => e.behavior == 'reflection_episode')
          .toList();
      expect(stories, hasLength(1));
      expect(stories.single.reflectionText, reflectionAhaFor(detail: told));
      expect(
        h.content.insertMemoryEventCalls.first.behavior,
        'reflection_episode',
      );
      expect(h.episodes.episodes.single.state, ExperienceState.integrated);
    });

    testWidgets('màn Xong nhắc lại điều được giữ, lần đầu là một cột mốc', (
      tester,
    ) async {
      const told = 'Mình đã dám trình bày';
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': told},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await _confirmMeaning(tester);
      await _tapCard(tester, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      // Lần nhìn lại đầu tiên của một người luôn là một "lần đầu" theo luật
      // Cột mốc của Career Memory, nên tiêu đề đổi theo.
      expect(find.text(kDoneMilestoneTitle), findsOneWidget);
      expect(find.byKey(const Key('wr_done_milestone')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('wr_done_kept')),
          matching: _para('“${reflectionAhaFor(detail: told)}”'),
        ),
        findsOneWidget,
      );

      // "Về màn hình chính" khép luồng. Hai thẻ ghi nhận đẩy nút xuống dưới
      // khung máy test nên phải cuộn tới.
      await tester.ensureVisible(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      expect(find.byType(WrHomeScreen), findsOneWidget);
    });

    // Owner gặp trên bản web 2026-07-29: "Transition bất hợp lệ: integrated →
    // committed". Cùng một cái bẫy như bước Ý nghĩa, chỉ lùi thêm một màn —
    // màn Xong cũng mở bằng push nên Back là về đúng màn Mang theo.
    /// Đi trọn đường: giữ Insight → chọn một phép thử → lưu (sang màn Xong,
    /// Episode được integrate) → Back về đúng màn Mang theo.
    Future<_Harness> backToChoiceAfterCommit(WidgetTester tester) async {
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

      await _tapCard(tester, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      // Back của trình duyệt: Xong → Mang theo.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('khép phiên rồi lùi về màn Lựa chọn, bấm lưu lần nữa không ném '
        'lỗi', (tester) async {
      final h = await backToChoiceAfterCommit(tester);
      expect(h.episodes.episodes.single.state, ExperienceState.integrated);
      expect(find.byKey(const Key('wr_choice_0')), findsOneWidget);
      final choiceBefore = h.episodes.episodes.single.reflectChoice;
      expect(choiceBefore, 'Quan sát thêm một lần');

      await _tapCard(tester, 1);
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

    testWidgets('lùi về màn Đóng lần nữa không ghi trùng Career Memory', (
      tester,
    ) async {
      final h = await backToChoiceAfterCommit(tester);
      // Cả STORY lẫn các mảnh sinh thêm đều phải đứng yên ở lần hai — chốt số
      // đếm ở đây thay vì chốt riêng STORY, để một mảnh Cột mốc bị ghi trùng
      // cũng bị bắt.
      final eventsAfterFirst = h.content.insertMemoryEventCalls.length;
      final stepsAfterFirst = h.intel.insertReflectionStepCalls.length;

      // Tới lại màn Xong: initState gọi integrate() lần hai.
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(find.byType(WrDoneScreen), findsOneWidget);
      expect(h.episodes.integrateCalls, hasLength(1));
      expect(h.content.insertMemoryEventCalls, hasLength(eventsAfterFirst));
      expect(h.intel.insertReflectionStepCalls, hasLength(stepsAfterFirst));
    });

    // Ở mức controller chứ không qua UI: màn Mang theo luôn đẩy sang màn Xong,
    // mà màn Xong khép phiên ngay sau khung hình đầu — nên state `committed`
    // chỉ tồn tại khi bước khép chưa chạy xong (đóng app, mất mạng, integrate
    // lỗi). Đúng lúc đó người dùng vẫn phải đổi được lựa chọn.
    test(
      'đổi lựa chọn khi phiên còn mở thì cập nhật, không đổi trạng thái',
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
        final container = ProviderContainer(
          overrides: [
            wrEpisodeRepositoryProvider.overrideWithValue(episodes),
            currentUserIdProvider.overrideWithValue('u1'),
          ],
        );
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
      },
    );
  });

  // -------------------------------------------------------------------------
  // Mockup v47 — bước 4/4 "Mang theo"
  //
  // Bản trước lấy bốn câu từ bể `wr_choice_pool` (Hai Lớp v1.6 §VI), có nhãn
  // "Gợi ý" cho Practice và ô tự viết làm đường lùi khi bể trống/tải muộn. v47
  // thay bằng ba thẻ cố định theo luật (`reflectionNextOptions`) + "Tự viết",
  // nên các test về bể trả về muộn và nhãn "Gợi ý" đã bỏ: không còn bể để chờ,
  // không còn nhãn để khoá.
  // -------------------------------------------------------------------------

  group('v47 · bước Mang theo', () {
    testWidgets('Practice của tình huống thành mô tả của thẻ "Thử một bước '
        'nhỏ"', (tester) async {
      const practice =
          'Tuần này ghi lại một lần tôi muốn lên tiếng nhưng đã chọn im lặng.';
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
            // Keep the legacy situation id meaningful: v2 story resolution is
            // exact, so this fixture's story key follows its seeded episode.
            storyId: 'C2-sit-01',
            title: 'Ý tưởng của tôi biến mất trong cuộc họp',
            scaDimension: ScaDimension.c2,
            storyContent: 'Tôi đã chuẩn bị khá kỹ.',
            emotionTags: [],
            behaviorTags: [],
            careerStages: [],
            ahaMessage:
                'Đôi khi điều khiến tôi im lặng không phải vì thiếu ý '
                'tưởng.',
            practiceAction: practice,
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

      expect(find.byType(WrCommitScreen), findsOneWidget);
      // Ba thẻ phép thử + lối "Tự viết", không hơn.
      expect(find.byKey(const Key('wr_choice_0')), findsOneWidget);
      expect(find.byKey(const Key('wr_choice_2')), findsOneWidget);
      expect(find.byKey(const Key('wr_choice_3')), findsNothing);
      expect(find.byKey(const Key('wr_commit_write_own')), findsOneWidget);

      // Practice không đứng riêng nữa — nó là mô tả của thẻ giữa.
      final small = find.byKey(const Key('wr_choice_1'));
      expect(
        find.descendant(of: small, matching: _para('Thử một bước nhỏ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: small, matching: _para(practice)),
        findsOneWidget,
      );
      expect(find.text('Gợi ý'), findsNothing);

      // Thẻ coral nhắc lại Insight vừa giữ, để phép thử bám đúng điều đó.
      final seen = h.episodes.episodes.single.draftMeaning!;
      expect(
        find.descendant(
          of: find.byKey(const Key('wr_commit_seen')),
          matching: _para('“$seen”'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('không có tình huống thì vẫn đủ ba thẻ chung, không hiện màn '
        'trống', (tester) async {
      // Thay cho test cũ "không đọc được bể thì lùi về ô tự viết": v47 không
      // đọc bể nào, nên điều cần khoá là nhánh "Điều khác" (không mã, không
      // Story) vẫn có đủ lựa chọn để chạm.
      final h = _Harness();
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

      for (final (i, title) in const [
        'Quan sát thêm một lần',
        'Thử một bước nhỏ',
        'Nói ra điều mình cần',
      ].indexed) {
        expect(
          find.descendant(
            of: find.byKey(Key('wr_choice_$i')),
            matching: _para(title),
          ),
          findsOneWidget,
          reason: 'thẻ $i phải là "$title"',
        );
      }
      // Ô tự viết chỉ mở khi người dùng chọn "Tự viết".
      expect(find.byKey(const Key('wr_commit_field')), findsNothing);
    });

    testWidgets('chạm thẻ chỉ là chọn, bấm Lưu mới ghi', (tester) async {
      // Khách 06/10: "chọn hoặc tự gõ, rồi Lưu". Mockup chạm là lưu luôn; app
      // để người dùng còn đổi ý hoặc chuyển sang tự viết.
      final h = await _toChoiceStep(tester);

      expect(_primary(tester).onPressed, isNull);

      await _tapCard(tester, 2);
      await tester.pumpAndSettle();
      expect(find.byType(WrCommitScreen), findsOneWidget);
      expect(h.episodes.commitActionCalls, isEmpty);
      expect(
        tester
            .widget<WrMentorCard>(find.byKey(const Key('wr_choice_2')))
            .selected,
        isTrue,
      );

      // Đổi ý sang thẻ khác: chỉ một thẻ sáng.
      await _tapCard(tester, 0);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WrMentorCard>(find.byKey(const Key('wr_choice_2')))
            .selected,
        isFalse,
      );

      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      expect(h.episodes.commitActionCalls, hasLength(1));
      expect(h.episodes.episodes.single.tinyAction, 'Quan sát thêm một lần');
      expect(find.byType(WrDoneScreen), findsOneWidget);
    });

    testWidgets('mở lại phiên đã lưu thì thẻ cũ vẫn được chọn', (tester) async {
      const saved = 'Nói ra điều mình cần';
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.committed,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        notes: const {'explore': 'Mình đã dám trình bày'},
        draftMeaning: 'Điều mình nhận ra',
        reflectChoice: saved,
        tinyAction: saved,
      );

      await _pump(tester, h.app());
      await _resume(tester);

      // Hiểu lại một phiên cũ đi qua các bước trước đó rồi mới mở lại màn
      // Mang theo. Đẩy trực tiếp màn cuối ở đây để cô lập đúng invariant đang
      // kiểm: câu đã lưu phải được hydrate và nút Lưu phải sẵn sàng.
      final element = tester.element(find.byType(WrMeaningScreen));
      GoRouter.of(element).push('/wr/flow/commit');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_commit_field')), findsNothing);
      expect(
        tester
            .widget<WrMentorCard>(find.byKey(const Key('wr_choice_2')))
            .selected,
        isTrue,
      );
      expect(_primary(tester).onPressed, isNotNull);
    });

    testWidgets('mở lại phiên tự viết thì câu cũ nằm trong ô Tự viết', (
      tester,
    ) async {
      const saved = 'Mình sẽ nói trước khi cuộc họp kết thúc';
      final h = _Harness();
      h.seedOpenEpisode(
        state: ExperienceState.committed,
        draftMeaning: 'Điều mình nhận ra',
        tinyAction: saved,
      );

      await _pump(tester, h.app(initialLocation: '/wr/flow/commit'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container
          .read(episodeFlowProvider.notifier)
          .resume(h.episodes.episodes.single);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('wr_commit_field')),
      );
      expect(field.controller!.text, saved);
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<WrMentorCard>(find.byKey(Key('wr_choice_$i'))).selected,
          isFalse,
        );
      }
      expect(_primary(tester).onPressed, isNotNull);
    });

    testWidgets('đổi episode trong cùng màn: phiên tự viết không mang thẻ của '
        'phiên trước', (tester) async {
      const firstAction = 'Quan sát thêm một lần';
      const secondAction = 'Bước đã lưu của phiên sau';
      final first = const ReflectionEpisode(
        id: 'ep-first',
        userId: 'u1',
        humanMoment: HumanMoment.celebration,
        state: ExperienceState.integrated,
        reflectChoice: firstAction,
        tinyAction: firstAction,
      );
      final second = const ReflectionEpisode(
        id: 'ep-second',
        userId: 'u1',
        humanMoment: HumanMoment.recovery,
        state: ExperienceState.integrated,
        // This episode is a saved free-write. It must not inherit the first
        // episode's selected preset while the same route stays mounted.
        tinyAction: secondAction,
      );
      final h = _Harness();
      h.episodes.seed([first]);

      await _pump(tester, h.app(initialLocation: '/wr/flow/commit'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container.read(episodeFlowProvider.notifier).resume(first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WrMentorCard>(find.byKey(const Key('wr_choice_0')))
            .selected,
        isTrue,
      );

      // The same mounted route now observes another episode id.
      await container.read(episodeFlowProvider.notifier).resume(second);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('wr_commit_field')),
      );
      expect(field.controller!.text, secondAction);
      expect(
        tester
            .widget<WrMentorCard>(find.byKey(const Key('wr_choice_0')))
            .selected,
        isFalse,
      );
    });

    testWidgets('đổi episode trong cùng màn: phiên chọn thẻ không mang chữ tự '
        'viết của phiên trước', (tester) async {
      // Chiều ngược của test trên: trước đây `_restore` không xoá lựa chọn
      // cũ, nên bấm Lưu sẽ ghi chữ của phiên trước vào phiên sau.
      final first = const ReflectionEpisode(
        id: 'ep-first',
        userId: 'u1',
        humanMoment: HumanMoment.recovery,
        state: ExperienceState.integrated,
        tinyAction: 'Chữ tự viết của phiên trước',
      );
      final second = const ReflectionEpisode(
        id: 'ep-second',
        userId: 'u1',
        humanMoment: HumanMoment.celebration,
        state: ExperienceState.integrated,
      );
      final h = _Harness();
      h.episodes.seed([first]);

      await _pump(tester, h.app(initialLocation: '/wr/flow/commit'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container.read(episodeFlowProvider.notifier).resume(first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_commit_field')), findsOneWidget);

      await container.read(episodeFlowProvider.notifier).resume(second);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_commit_field')), findsNothing);
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<WrMentorCard>(find.byKey(Key('wr_choice_$i'))).selected,
          isFalse,
        );
      }
      expect(_primary(tester).onPressed, isNull);
    });
  });

  // WDA Invariant 9 + v1.6 §V: Choice là MỘT bước của Reflection Cycle, không
  // phải một phần của Action. Trước đây câu người dùng chạm bị lưu thẳng vào
  // tiny_action, nên wr_reflection_steps chưa bao giờ có dòng 'choice'.
  group('v1.6 · Choice là bước riêng (§V · WDA Inv.9)', () {
    testWidgets('chạm một thẻ thì ghi cả bước choice lẫn bước action', (
      tester,
    ) async {
      final h = await _toChoiceStep(tester);

      // Đọc thẳng tiêu đề thẻ đang hiện để biết mình vừa chạm vào cái gì.
      final tile = find.byKey(const Key('wr_choice_0'));
      final shown = tester
          .widget<WrParagraph>(
            find.descendant(of: tile, matching: find.byType(WrParagraph)).first,
          )
          .text;

      await _tapCard(tester, 0);
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      final picked = h.episodes.episodes.single.reflectChoice;
      expect(picked, shown, reason: 'phải lưu đúng câu người dùng đã chạm');
      expect(picked, 'Quan sát thêm một lần');

      final steps = h.intel.insertReflectionStepCalls;
      final choiceSteps = steps
          .where((s) => s.step == ReflectionStepType.choice)
          .toList();
      final actionSteps = steps
          .where((s) => s.step == ReflectionStepType.action)
          .toList();

      expect(choiceSteps, hasLength(1));
      expect(choiceSteps.single.content, picked);
      // Action vẫn còn: câu đó vừa là lựa chọn, vừa là điều đã cam kết.
      expect(actionSteps, hasLength(1));
      expect(actionSteps.single.content, picked);
    });

    testWidgets('tự viết thì có bước action nhưng KHÔNG có bước choice', (
      tester,
    ) async {
      // Người dùng bỏ qua ba thẻ để tự viết — ghi một dòng 'choice' lúc này là
      // bịa ra một lựa chọn họ không hề chạm.
      final h = await _toChoiceStep(tester);

      final writeOwn = find.byKey(const Key('wr_commit_write_own'));
      await tester.ensureVisible(writeOwn);
      await tester.tap(writeOwn);
      await tester.pumpAndSettle();
      // Mở ô rồi mà chưa gõ thì chưa lưu được.
      expect(_primary(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('wr_commit_field')),
        'Tuần này tôi sẽ nói ra sớm hơn.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();

      expect(h.episodes.episodes.single.reflectChoice, isNull);
      expect(
        h.episodes.episodes.single.tinyAction,
        'Tuần này tôi sẽ nói ra sớm hơn.',
      );

      final steps = h.intel.insertReflectionStepCalls;
      expect(steps.where((s) => s.step == ReflectionStepType.choice), isEmpty);
      expect(
        steps.where((s) => s.step == ReflectionStepType.action).single.content,
        'Tuần này tôi sẽ nói ra sớm hơn.',
      );
    });
  });

  // Nhóm này từng tên là "§1.2 · Aha chuyển sang Lớp 2" và khoá việc câu Aha
  // KHÔNG lộ ở Lớp 1. v47 bỏ hẳn Lớp 1, nên điều cần khoá giờ là: câu Insight
  // dựng đúng từ tình huống người dùng chọn + câu aha trong thư viện, và thẻ
  // Self Reflection vẫn không quay lại (mục 4.3, khách 09/09).
  group('v47 · Insight dựng từ tình huống', () {
    testWidgets('Insight ghép tên tình huống với câu aha của thư viện', (
      tester,
    ) async {
      const told = 'mình sợ nói ra thì bị đánh giá';
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
            storyId: 'C2-sit-01',
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
        notes: const {'explore': told},
      );

      await _pump(tester, h.app());
      await _resume(tester);

      // Mục 4.3 — thẻ Self Reflection không còn được hiện, dù thư viện vẫn có
      // dữ liệu cho nó (story ở trên có `selfReflection`).
      expect(find.byKey(const Key('wr_meaning_self_reflection')), findsNothing);
      expect(
        find.text('Điều gì thường khiến tôi ngần ngại lên tiếng?'),
        findsNothing,
      );

      final expected = reflectionAhaFor(
        code: 'C2-sit-01',
        title: 'Không dám lên tiếng',
        detail: told,
        situationAha: 'Nhiều tổ chức không thiếu ý tưởng.',
      );
      expect(expected, contains('Không dám lên tiếng'));
      expect(expected, contains('Nhiều tổ chức không thiếu ý tưởng.'));
      expect(
        find.descendant(
          of: find.byKey(const Key('wr_meaning_aha')),
          matching: _para('“$expected”'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('mở lại phiên đã giữ ý nghĩa thì hiện đúng câu đã giữ', (
      tester,
    ) async {
      // WIA Inv.2: hệ thống chỉ đề xuất. Phiên đã có câu người dùng giữ thì
      // không được dựng lại một câu đề xuất mới đè lên.
      final h = _Harness();
      h.content.seedSituations([
        const WrSituation(
          code: 'C2-sit-01',
          text: 'Không dám lên tiếng',
          scaDimension: ScaDimension.c2,
          wave: 1,
        ),
      ]);
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.meaningConfirmed,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.explore,
        ],
        situationCode: 'C2-sit-01',
        notes: const {'explore': 'Mình đã dám trình bày'},
        draftMeaning: 'chữ của chính tôi',
      );

      await _pump(tester, h.app());
      await _resume(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('wr_meaning_aha')),
          matching: _para('“chữ của chính tôi”'),
        ),
        findsOneWidget,
      );
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
    String? reflectChoice,
    String? tinyAction,
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
        reflectChoice: reflectChoice,
        tinyAction: tinyAction,
      ),
    ]);
  }
}

/// Đoạn chữ dựng bằng [WrParagraph] có đúng nội dung [text].
///
/// Không dùng `find.text`: WrParagraph nối tiếng cuối câu bằng U+00A0 nên chuỗi
/// hiển thị khác chuỗi gốc.
Finder _para(String text) =>
    find.byWidgetPredicate((w) => w is WrParagraph && w.text == text);

/// Nút chính của khung luồng (`FilledButton` từ mockup v47).
FilledButton _primary(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('wr_flow_primary')));

/// Chọn tình huống [code] rồi bấm "Tiếp tục" — hai chạm của bước 1/4 (v47).
Future<void> _pickSituation(WidgetTester tester, String code) async {
  final row = find.byKey(Key('wr_situation_$code'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('wr_flow_primary')));
  await tester.pumpAndSettle();
}

/// Đưa màn tới thẻ Insight của bước 3/4, với phiên mang mã `S1-01` (mã không
/// có luật riêng trong `reflectionAhaFor`, thư viện để trống).
Future<_Harness> _atInsight(WidgetTester tester) async {
  final h = _Harness();
  h.seedOpenEpisode(
    moment: HumanMoment.celebration,
    situationCode: 'S1-01',
    state: ExperienceState.exploring,
    patternsDone: const [ReflectionPattern.notice, ReflectionPattern.explore],
    notes: const {'explore': 'Mình đã dám trình bày'},
  );
  await _pump(tester, h.app());
  await _resume(tester);
  expect(find.byKey(const Key('wr_meaning_aha')), findsOneWidget);
  return h;
}

/// Câu Insight hệ thống đề xuất cho phiên của [_atInsight].
String _proposedFor(_Harness h) => reflectionAhaFor(
  code: 'S1-01',
  detail: h.episodes.episodes.single.notes['explore'],
);

/// "Chưa đúng, để tôi nói lại" → viết [text] → "Giữ lại cách hiểu của tôi".
Future<void> _retell(WidgetTester tester, String text) async {
  await tester.tap(find.byKey(const Key('wr_flow_secondary')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('wr_meaning_field')), text);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('wr_flow_primary')));
  await tester.pumpAndSettle();
}

/// Đưa Episode tới bước Mang theo (không mã tình huống → ba thẻ chung).
Future<_Harness> _toChoiceStep(WidgetTester tester) async {
  final h = _Harness();
  h.seedOpenEpisode(
    moment: HumanMoment.celebration,
    state: ExperienceState.exploring,
    patternsDone: const [ReflectionPattern.notice, ReflectionPattern.explore],
  );
  await _pump(tester, h.app());
  await _resume(tester);
  await _confirmMeaning(tester);
  expect(find.byType(WrCommitScreen), findsOneWidget);
  return h;
}

/// Đi hết bước 3/4 để sang bước Mang theo.
///
/// v47 bỏ hai lớp của changelog 24/08: Insight hiện ngay, một chạm "Ừ, tôi
/// cũng thấy vậy" là giữ câu đó và sang bước kế.
Future<void> _confirmMeaning(WidgetTester tester) async {
  expect(find.byKey(const Key('wr_meaning_aha')), findsOneWidget);
  await tester.tap(find.byKey(const Key('wr_flow_primary')));
  await tester.pumpAndSettle();
}

Future<void> _resume(WidgetTester tester, {bool stopAtDetail = false}) =>
    resumeOpenEpisode(tester, stopAtDetail: stopAtDetail);

/// Vài tình huống đủ để bước chọn chuyện có dòng mà chạm.
const _someSituations = [
  WrSituation(
    code: 'A3-sit-01',
    text: 'Việc dồn nhiều hơn mình xử lý nổi',
    scaDimension: ScaDimension.a3,
    pillarCode: 'A',
    subgroup: 'A3',
    mood: 'tired',
    valence: WrValence.thachThuc,
    wave: 1,
  ),
  WrSituation(
    code: 'A1-sit-01',
    text: 'Không biết mình đang đi về đâu',
    scaDimension: ScaDimension.a1,
    pillarCode: 'A',
    subgroup: 'A1',
    mood: 'tired',
    valence: WrValence.thachThuc,
    wave: 1,
  ),
];

/// Mã của dòng đang hiện đầu tiên. Danh sách được trộn ngẫu nhiên (§4.1) nên
/// không đoán trước được mã nào ở vị trí nào.
String _firstVisibleSituationCode() {
  for (final s in _someSituations) {
    if (find.byKey(Key('wr_situation_${s.code}')).evaluate().isNotEmpty) {
      return s.code;
    }
  }
  throw StateError('không có chip tình huống nào đang hiện');
}

/// Chạm thẻ phép thử thứ [index] ở bước Mang theo.
///
/// Cuộn tới trước: thẻ Insight và câu tiêu đề dài đẩy ba thẻ xuống dưới khung
/// 800px của máy test.
Future<void> _tapCard(WidgetTester tester, int index) async {
  final card = find.byKey(Key('wr_choice_$index'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}
