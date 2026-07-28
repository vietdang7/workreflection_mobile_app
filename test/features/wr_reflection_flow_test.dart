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
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/logic/wr_experience_state.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_commit_screen.dart';
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

      expect(find.text('Bạn đang trải qua điều gì?'), findsOneWidget);
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

    testWidgets('trả lời năng lượng là mở thẳng màn khoảnh khắc',
        (tester) async {
      final h = _Harness();
      await _pump(tester, h.app());

      await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
      await tester.pumpAndSettle();

      for (final moment in HumanMoment.values) {
        expect(
          find.byKey(Key('wr_moment_${moment.dbValue}')),
          findsOneWidget,
          reason: 'thiếu thẻ ${moment.dbValue}',
        );
      }
    });

    testWidgets('có phiên đang mở thì mời tiếp tục, không hỏi lại năng lượng',
        (tester) async {
      final h = _Harness();
      h.seedOpenEpisode();
      await _pump(tester, h.app());

      expect(find.byKey(const Key('wr_home_resume_reflection')), findsOneWidget);
      expect(find.text(HumanMoment.confusion.tension), findsOneWidget);
      expect(find.byKey(const Key('wr_home_checkin_tired')), findsNothing);
    });

    // Bỏ dở giữa chừng là Episode ngủ. Nếu Home không mời lại thì người dùng
    // mất đường quay về — trái WPA Inv.4.
    testWidgets('phiên đang ngủ vẫn được mời tiếp tục', (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        state: ExperienceState.dormant,
        patternsDone: const [ReflectionPattern.notice],
        notes: const {'notice': 'cố lên'},
      );
      await _pump(tester, h.app());

      expect(find.byKey(const Key('wr_home_resume_reflection')), findsOneWidget);
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
          ReflectionPattern.name,
          ReflectionPattern.explore,
          ReflectionPattern.preserve,
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

  group('Màn khoảnh khắc', () {
    testWidgets('đúng sáu thẻ, không hơn', (tester) async {
      final h = _Harness();
      await _pump(tester, h.app());
      await tester.tap(find.byKey(const Key('wr_home_checkin_ok')));
      await tester.pumpAndSettle();

      expect(find.text(HumanMoment.arrival.label), findsOneWidget);
      expect(find.text(HumanMoment.celebration.label), findsOneWidget);
    });

    testWidgets('chọn khoảnh khắc mở Episode ở state captured', (tester) async {
      final h = _Harness();
      await _pump(tester, h.app());
      await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wr_moment_recovery')));
      await tester.pumpAndSettle();

      expect(h.episodes.openEpisodeCalls, hasLength(1));
      final opened = h.episodes.openEpisodeCalls.first;
      expect(opened.humanMoment, HumanMoment.recovery);
      expect(opened.energy, CheckinEnergy.low);
      expect(opened.state, ExperienceState.captured);
      // Check-in ngày vẫn được ghi, mood suy ra từ năng lượng.
      expect(h.wr.upsertCheckinCalls, hasLength(1));
      expect(h.wr.upsertCheckinCalls.first.energy, CheckinEnergy.low);
      expect(h.wr.upsertCheckinCalls.first.mood, Mood.tired);
      // Không còn ghi "hướng đi".
      expect(h.wr.upsertCheckinCalls.first.direction, isNull);
    });
  });

  group('Các bước phản tư', () {
    testWidgets('hiện đúng một câu hỏi mỗi lần và đi theo chuỗi của archetype',
        (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(moment: HumanMoment.recovery);
      await _pump(tester, h.app());
      await _resume(tester);

      // Recovery: Notice → Explore → Preserve
      expect(find.text('BƯỚC 1/3'), findsOneWidget);
      expect(find.text('Điều gì đang làm bạn mất năng lượng?'), findsOneWidget);

      await _writeStep(tester, 'Cuộc họp sáng nay');
      expect(find.text('BƯỚC 2/3'), findsOneWidget);
      expect(
        find.text(promptFor(HumanMoment.recovery, ReflectionPattern.explore)),
        findsOneWidget,
      );
    });

    testWidgets('chưa viết gì thì chưa đi tiếp được', (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(moment: HumanMoment.recovery);
      await _pump(tester, h.app());
      await _resume(tester);

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('wr_flow_primary')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('đi hết chuỗi thì sang màn Ý nghĩa', (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(moment: HumanMoment.recovery);
      await _pump(tester, h.app());
      await _resume(tester);

      await _writeStep(tester, 'Cuộc họp sáng nay');
      await _writeStep(tester, 'Cảm giác không được nghe');
      await _writeStep(tester, 'Mình cần nói sớm hơn');
      await tester.pumpAndSettle();

      expect(
        find.text('Nếu giữ lại một điều từ lần nhìn lại này, đó là gì?'),
        findsOneWidget,
      );
    });

    testWidgets('thoát giữa chừng thì phiên ngủ, không mất', (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(moment: HumanMoment.recovery);
      await _pump(tester, h.app());
      await _resume(tester);

      await _writeStep(tester, 'Cuộc họp sáng nay');
      await tester.tap(find.byKey(const Key('wr_flow_close')));
      await tester.pumpAndSettle();

      expect(h.episodes.dormantCalls, hasLength(1));
      final saved = h.episodes.episodes.single;
      expect(saved.state, ExperienceState.dormant);
      // Ghi chú đã viết vẫn còn nguyên.
      expect(saved.notes['notice'], 'Cuộc họp sáng nay');
    });
  });

  group('Ý nghĩa và ký ức', () {
    // Câu trả lời tách khỏi câu hỏi thì vô nghĩa. Bước Ý nghĩa phải đọc lại
    // đủ cặp hỏi–đáp, và ô nhập để trống — điều muốn giữ là chữ mới của người
    // dùng, không phải đáp án của một câu hỏi khác bê sang.
    testWidgets('đọc lại đủ câu hỏi lẫn câu trả lời, ô nhập để trống',
        (tester) async {
      final h = _Harness();
      h.seedOpenEpisode(
        moment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        patternsDone: const [
          ReflectionPattern.notice,
          ReflectionPattern.name,
          ReflectionPattern.preserve,
        ],
        notes: const {'name': 'Mình đã dám trình bày trước cả phòng'},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_meaning_recap')), findsOneWidget);
      expect(
        find.text(
          promptFor(HumanMoment.celebration, ReflectionPattern.name),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Mình đã dám trình bày trước cả phòng'),
        findsOneWidget,
      );

      final field = tester.widget<TextField>(
        find.byKey(const Key('wr_meaning_field')),
      );
      expect(field.controller!.text, '');
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
        ],
        notes: const {'name': 'hôm nay'},
      );
      await _pump(tester, h.app());
      await _resume(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_meaning_recap_name')), findsOneWidget);
      final answer = find.text('hôm nay');
      await tester.ensureVisible(answer);
      await tester.pumpAndSettle();
      await tester.tap(answer);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('wr_meaning_recap_field_name')),
        'Mình đã dám trình bày trước cả phòng',
      );
      await tester.tap(find.byKey(const Key('wr_meaning_recap_save_name')));
      await tester.pumpAndSettle();

      expect(
        h.episodes.episodes.single.notes['name'],
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
        ],
        notes: const {'name': 'Mình đã dám trình bày'},
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
        ],
        notes: const {'name': 'Mình đã dám trình bày'},
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
        ],
        notes: const {'name': 'Mình đã dám trình bày'},
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
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
          ReflectionPattern.name,
          ReflectionPattern.preserve,
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

Future<void> _resume(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('wr_home_resume_reflection')));
  await tester.pumpAndSettle();
}

/// Viết một bước phản tư rồi bấm Tiếp.
Future<void> _writeStep(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('wr_step_note')), text);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('wr_flow_primary')));
  await tester.pumpAndSettle();
}
