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

class _Harness {
  _Harness()
      : episodes = FakeWrEpisodeRepository(),
        intel = FakeWrIntelligenceRepository(),
        content = FakeWrContentRepository(),
        wr = FakeWrRepository();

  final FakeWrEpisodeRepository episodes;
  final FakeWrIntelligenceRepository intel;
  final FakeWrContentRepository content;
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

      // Celebration không có bước Commit → sang thẳng màn khép.
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
      ),
    ]);
  }
}

/// Bấm "Tiếp tục" trên Home để vào đúng màn của trạng thái hiện tại.
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
