// Đi trọn một vòng đời người dùng, không dừng ở từng màn:
//
//   đăng ký → dựng hồ sơ → Home → check-in → trọn luồng phản tư → khép phiên
//   → cả bốn tab đọc được → đăng nhập lại.
//
// Vì sao cần dù đã có test riêng cho từng màn: mỗi test kia dựng đúng một
// widget với dữ liệu dọn sẵn. Lỗi thật của tuần này (Episode integrated bấm
// lại, ghi trùng Career Memory) chỉ lộ ra khi đi liền mạch nhiều màn với CÙNG
// một kho dữ liệu — đúng thứ file này làm.
//
// Supabase không được đụng tới: mọi repository đều là fake, router dựng riêng
// thay cho appRouterProvider (redirect của nó đọc thẳng Supabase.instance).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/features/auth/data/auth_repository.dart';
import 'package:workreflection_mobile/features/auth/presentation/auth_screen.dart';
import 'package:workreflection_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_commit_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_detail_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_done_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_energy_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_meaning_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_moment_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_step_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_pattern_detail_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_patterns_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_paywall_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';
import '../support/resume_open_episode.dart';

// ---------------------------------------------------------------------------
// Fake AuthRepository — ghi lại lệnh gọi, không chạm mạng.
// ---------------------------------------------------------------------------

class _FakeAuth implements AuthRepository {
  final calls = <String>[];
  String? signUpEmail;
  String? signUpName;
  String? signInEmail;

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn');
    signInEmail = email;
  }

  @override
  Future<void> signUp(String email, String password, String displayName) async {
    calls.add('signUp');
    signUpEmail = email;
    signUpName = displayName;
  }

  @override
  Future<void> signInWithGoogle() async => calls.add('google');

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> resetPassword(String email) async => calls.add('reset');

  @override
  Future<void> changePassword(String newPassword) async => calls.add('change');
}

// ---------------------------------------------------------------------------
// Sân khấu: mọi màn thật, mọi repository fake, một router chung.
// ---------------------------------------------------------------------------

class _Stage {
  _Stage()
      : auth = _FakeAuth(),
        wr = FakeWrRepository(),
        episodes = FakeWrEpisodeRepository(),
        intel = FakeWrIntelligenceRepository(),
        content = FakeWrContentRepository(),
        moodContent = FakeWrMoodContentRepository() {
    content.seedSituations(const [
      WrSituation(
        code: 'C2-sit-01',
        text: 'Không dám lên tiếng trong cuộc họp',
        scaDimension: ScaDimension.c2,
        wave: 1,
        humanNeed: HumanNeed.ketNoi,
      ),
      WrSituation(
        code: 'A3-sit-01',
        text: 'Việc dồn nhiều hơn mình xử lý nổi',
        scaDimension: ScaDimension.a3,
        wave: 1,
        humanNeed: HumanNeed.roRang,
      ),
    ]);
    moodContent.seedChoicePool(const [
      'Ghi nhớ điều này để xem lại sau',
      'Nói chuyện với ai đó về điều này',
      'Chưa biết, cần thêm thời gian',
      'Không cần hành động gì, chỉ cần ghi nhận là đủ',
    ]);
  }

  final _FakeAuth auth;
  final FakeWrRepository wr;
  final FakeWrEpisodeRepository episodes;
  final FakeWrIntelligenceRepository intel;
  final FakeWrContentRepository content;
  final FakeWrMoodContentRepository moodContent;

  late final GoRouter router = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(
        path: '/profile/setup',
        builder: (_, __) => const ProfileEditScreen(setupMode: true),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileEditScreen()),
      GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
      GoRoute(path: '/wr/discover', builder: (_, __) => const WrDiscoverScreen()),
      GoRoute(path: '/wr/growth', builder: (_, __) => const WrGrowthScreen()),
      GoRoute(path: '/wr/journey', builder: (_, __) => const WrJourneyScreen()),
      GoRoute(path: '/wr/patterns', builder: (_, __) => const WrPatternsScreen()),
      GoRoute(
        path: '/wr/pattern/:code',
        builder: (_, s) =>
            WrPatternDetailScreen(situationCode: s.pathParameters['code'] ?? ''),
      ),
      GoRoute(path: '/wr/paywall', builder: (_, __) => const WrPaywallScreen()),
      GoRoute(path: '/wr/flow/energy', builder: (_, __) => const WrEnergyScreen()),
      GoRoute(path: '/wr/flow/moment', builder: (_, __) => const WrMomentScreen()),
      GoRoute(path: '/wr/flow/step', builder: (_, __) => const WrStepScreen()),
      GoRoute(path: '/wr/flow/detail', builder: (_, __) => const WrDetailScreen()),
      GoRoute(path: '/wr/flow/meaning', builder: (_, __) => const WrMeaningScreen()),
      GoRoute(path: '/wr/flow/commit', builder: (_, __) => const WrCommitScreen()),
      GoRoute(path: '/wr/flow/done', builder: (_, __) => const WrDoneScreen()),
      GoRoute(
        path: '/wr/self-check',
        builder: (_, __) => const Scaffold(body: Text('SELF-CHECK')),
      ),
    ],
  );

  Widget app() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          wrRepositoryProvider.overrideWithValue(wr),
          wrEpisodeRepositoryProvider.overrideWithValue(episodes),
          wrIntelligenceRepositoryProvider.overrideWithValue(intel),
          wrContentRepositoryProvider.overrideWithValue(content),
          wrMoodContentRepositoryProvider.overrideWithValue(moodContent),
          currentUserIdProvider.overrideWithValue('u1'),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
        ),
      );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// Đi hai bước ghi dữ liệu của luồng §V: chọn tình huống rồi qua bước chi tiết.
///
/// Kết thúc ở màn Insight. [detail] null nghĩa là bỏ trống ô chi tiết — §V cho
/// phép, và đó cũng là đường phần lớn người dùng đi.
Future<void> _walkToMeaning(WidgetTester tester, {String? detail}) async {
  // Bước 0 — CHỌN, không viết. Danh sách trộn ngẫu nhiên nên chạm mã nào đang
  // hiện thì chạm mã đó.
  if (find.byType(WrStepScreen).evaluate().isNotEmpty) {
    for (final code in const ['C2-sit-01', 'A3-sit-01']) {
      final chip = find.byKey(Key('wr_situation_$code'));
      if (chip.evaluate().isEmpty) continue;
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      break;
    }
  }

  // Bước 1 — chi tiết cụ thể, không bắt buộc.
  if (find.byType(WrDetailScreen).evaluate().isNotEmpty) {
    if (detail != null) {
      await tester.enterText(find.byKey(const Key('wr_detail_field')), detail);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('đăng ký → hồ sơ → phản tư trọn vòng → các tab đều đọc được',
      (tester) async {
    final stage = _Stage();
    await _pump(tester, stage.app());

    // ── 1. Đăng ký ───────────────────────────────────────────────────────
    expect(find.byType(AuthScreen), findsOneWidget);
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên của bạn'), 'Duy Thông');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'thong@test.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'), 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(stage.auth.calls, contains('signUp'));
    expect(stage.auth.signUpName, 'Duy Thông');
    // Đăng ký xong đi thẳng sang dựng hồ sơ, không rơi về màn đăng nhập.
    expect(find.byType(ProfileEditScreen), findsOneWidget);
    // Dữ liệu mẫu được gieo ngay sau khi có tài khoản.
    expect(stage.wr.ensureSeededCalls, isNotEmpty);

    // ── 2. Dựng hồ sơ rồi vào Home ───────────────────────────────────────
    await tester.enterText(
        find.byKey(const Key('profile_edit_display_name')), 'Duy Thông');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_edit_save_btn')));
    await tester.pumpAndSettle();

    expect(find.byType(WrHomeScreen), findsOneWidget);

    // ── 3. Check-in mở luồng phản tư ─────────────────────────────────────
    await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
    await tester.pumpAndSettle();
    // v2.0 §9.1: check-in dẫn THẲNG vào bước chọn tình huống, không qua màn
    // khoảnh khắc nào.
    expect(find.byType(WrStepScreen), findsOneWidget);
    expect(find.byType(WrMomentScreen), findsNothing);
    // Check-in ngày ghi ngay, Episode thì chưa — chưa chọn gì thì chưa có phiên.
    expect(stage.wr.upsertCheckinCalls, hasLength(1));
    expect(stage.episodes.episodes, isEmpty);

    // ── 4. Chọn tình huống → chi tiết → màn Ý nghĩa ──────────────────────
    await _walkToMeaning(tester, detail: 'điều tôi viết thêm');
    expect(stage.episodes.episodes, hasLength(1));
    // Mã tình huống PHẢI được ghi — nếu không, "Tình huống lặp lại" và điểm
    // SCA ở tab Hiểu mình sẽ trống mãi (§4.3).
    expect(stage.episodes.episodes.single.situationCode, isNotNull);
    expect(find.byType(WrMeaningScreen), findsOneWidget);
    // Màn Bước phải rời hẳn stack. Còn nằm dưới là nó vẫn dựng lại theo Episode
    // và bắn điều hướng đè mất màn đang xem — xem test riêng bên dưới.
    expect(find.byType(WrStepScreen, skipOffstage: false), findsNothing);

    await tester.enterText(find.byKey(const Key('wr_meaning_field')),
        'Mình lên tiếng được khi thấy an toàn.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();

    // ── 5. Lựa chọn → khép phiên ─────────────────────────────────────────
    expect(find.byType(WrCommitScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('wr_choice_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();

    expect(find.byType(WrDoneScreen), findsOneWidget);
    final saved = stage.episodes.episodes.single;
    expect(saved.state, ExperienceState.integrated);
    expect(saved.draftMeaning, 'Mình lên tiếng được khi thấy an toàn.');
    expect(saved.tinyAction, isNotNull);
    // Đúng một mảnh Career Memory cho một phiên.
    expect(stage.content.insertMemoryEventCalls, hasLength(1));
    expect(stage.intel.insertInsightCalls, hasLength(1));

    // Không màn nào trong cả vòng ném lỗi ra mặt người dùng.
    expect(find.textContaining('Transition bất hợp lệ'), findsNothing);
    expect(find.textContaining('Không lưu được'), findsNothing);

    // ── 6. Về Home, phiên đã khép nên không còn mời tiếp tục ─────────────
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();
    expect(find.byType(WrHomeScreen), findsOneWidget);
    expect(find.byKey(const Key('wr_home_resume_reflection')), findsNothing);

    // ── 7. Bốn tab đều dựng được với dữ liệu vừa tạo ─────────────────────
    stage.router.go('/wr/discover');
    await tester.pumpAndSettle();
    expect(find.byType(WrDiscoverScreen), findsOneWidget);
    expect(find.textContaining('Bạn đã nhìn lại 1/15 lần'), findsOneWidget);
    // Free: mọi diễn giải nằm sau paywall.
    expect(find.byKey(const Key('wr_discover_need_lock')), findsOneWidget);

    stage.router.go('/wr/journey');
    await tester.pumpAndSettle();
    expect(find.byType(WrJourneyScreen), findsOneWidget);
    // Free: Career Memory khoá hoàn toàn, con số tổng vẫn nói ra.
    expect(find.byKey(const Key('wr_journey_memory_lock'), skipOffstage: false),
        findsOneWidget);
    expect(find.textContaining('1 mảnh ký ức', skipOffstage: false),
        findsOneWidget);

    stage.router.go('/wr/growth');
    await tester.pumpAndSettle();
    expect(find.byType(WrGrowthScreen), findsOneWidget);

    stage.router.go('/home');
    await tester.pumpAndSettle();
    expect(find.byType(WrHomeScreen), findsOneWidget);
  });

  // Lỗi owner báo 2026-07-29: "làm tới câu số 4 trở đi cứ lặp lại câu hỏi".
  //
  // Gốc: màn Bước cũ dùng `push` để sang màn Ý nghĩa, nên nó vẫn nằm dưới đáy
  // stack và vẫn theo dõi Episode. Xác nhận Ý nghĩa làm Episode đổi trạng thái
  // → màn Bước dựng lại → nhánh "hết bước" bắn pushReplacement thêm lần nữa →
  // ĐÈ MẤT màn Lựa chọn vừa đẩy lên, ném người dùng về đúng màn Ý nghĩa. Bấm
  // lại thì lại bị ném về, nhìn hệt như app hỏi đi hỏi lại.
  //
  // Chỉ lộ khi đi TỪNG BƯỚC như người thật; test cũ nào cũng seed sẵn Episode
  // đã đi hết chuỗi nên màn Bước bị thay ngay từ đầu và không bao giờ đè ai.
  testWidgets('xác nhận Ý nghĩa xong sang Lựa chọn, không bị ném ngược lại',
      (tester) async {
    final stage = _Stage();
    await _pump(tester, stage.app());
    stage.router.go('/home');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
    await tester.pumpAndSettle();
    await _walkToMeaning(tester);

    await tester.enterText(
        find.byKey(const Key('wr_meaning_field')), 'Điều tôi muốn giữ lại.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();

    // Phải ĐỨNG ở màn Lựa chọn: nó là route trên cùng, không phải một màn Ý
    // nghĩa thứ hai chồng lên. (Màn Ý nghĩa vẫn nằm dưới là đúng — bấm Back
    // phải quay về được nó.)
    expect(find.byType(WrCommitScreen), findsOneWidget);
    final stack = stage.router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList();
    expect(stack.last, '/wr/flow/commit', reason: 'stack: $stack');
    expect(stack.where((l) => l == '/wr/flow/meaning'), hasLength(1),
        reason: 'màn Ý nghĩa bị đẩy chồng lên chính nó: $stack');
    expect(stack, isNot(contains('/wr/flow/step')),
        reason: 'màn Bước còn nằm dưới sẽ đè màn khác: $stack');
    expect(find.textContaining('Transition bất hợp lệ'), findsNothing);
  });

  testWidgets('phiên thứ hai trong ngày vẫn mở được, không đè phiên đã khép',
      (tester) async {
    final stage = _Stage();
    await _pump(tester, stage.app());

    // Bỏ qua đăng ký, vào thẳng Home như người đã có tài khoản.
    stage.router.go('/home');
    await tester.pumpAndSettle();

    // Phiên 1 — bỏ dở giữa chừng bằng nút đóng.
    await tester.tap(find.byKey(const Key('wr_home_checkin_tired')));
    await tester.pumpAndSettle();
    for (final code in const ['C2-sit-01', 'A3-sit-01']) {
      final chip = find.byKey(Key('wr_situation_$code'));
      if (chip.evaluate().isEmpty) continue;
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      break;
    }
    await tester.enterText(
        find.byKey(const Key('wr_detail_field')), 'câu trả lời dở dang');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_flow_close')));
    await tester.pumpAndSettle();

    // Về Home. Từ 2026-07-30 Home KHÔNG còn thẻ mời tiếp tục (khách yêu cầu bỏ
    // theo mockup), nhưng phiên vẫn được giữ chỗ — WXS §4.5.
    expect(find.byType(WrHomeScreen), findsOneWidget);
    expect(find.byKey(const Key('wr_home_resume_reflection')), findsNothing);
    expect(stage.episodes.episodes.single.state, ExperienceState.dormant);

    // Tiếp tục: Episode ngủ phải được đánh thức, không ném lỗi transition.
    await resumeOpenEpisode(tester);

    expect(find.textContaining('Transition bất hợp lệ'), findsNothing);
    expect(find.textContaining('Không lưu được'), findsNothing);
    expect(stage.episodes.episodes.single.state,
        isNot(ExperienceState.dormant));

    // Đi tiếp được tới cuối chuỗi, không bắt trả lời lại từ đầu.
    await _walkToMeaning(tester);
    expect(find.byType(WrMeaningScreen), findsOneWidget);
    expect(
      stage.episodes.episodes.single.notes['explore'],
      'câu trả lời dở dang',
    );
  });

  testWidgets('đăng nhập lại vào thẳng Home', (tester) async {
    final stage = _Stage();
    await _pump(tester, stage.app());

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'thong@test.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'), 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(stage.auth.signInEmail, 'thong@test.com');
    expect(find.byType(WrHomeScreen), findsOneWidget);
  });
}
