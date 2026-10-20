// Những gì buổi họp khách 2026-07-29 đổi trên màn hình.
//
// Gom vào một file vì cả năm nhóm dưới đều đến từ cùng một buổi và cùng một
// nguyên tắc: bớt thao tác của người dùng, và chỉ nói ra điều đã có thật.
//
//   1. Home  — "Hệ thống nhận ra" + "Gợi ý" chỉ hiện sau check-in
//   2. Home  — khối "Tiếp tục hôm nay"
//   3. Trà Chiều Nghề Nghiệp — chữ, không ảnh
//   4. Ô hỏi nghề nghiệp + bong bóng trên mọi tab
//   5. Màn đọc — header ghim, và audio nói đúng trạng thái của nó

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_ai_voice.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/data/ausynclab_tts_service.dart';
import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/stt_service.dart';
import 'package:workreflection_mobile/core/logic/wr_tra_chieu.dart';
import 'package:workreflection_mobile/core/data/wr_chat_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_chat.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';
import 'package:workreflection_mobile/core/theme/wr_colors.dart';
import 'package:workreflection_mobile/features/shell/shell_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_ask_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_themes_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_mood_reader_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_tra_chieu_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/ai_consent.dart';
import '../support/fake_repository.dart';
import '../support/fake_workshop_repository.dart';
import '../support/fake_wr_chat_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/widgets/wr_title_text.dart';

// ---------------------------------------------------------------------------
// Hạ tầng test
// ---------------------------------------------------------------------------

/// STT giả — không chạm micro, và luôn báo "không có" để nút mic không chen vào
/// các phép đếm widget của những nhóm test khác.
class _FakeStt implements SttService {
  _FakeStt({this.available = false});

  final bool available;

  @override
  Future<bool> get isAvailable async => available;

  @override
  bool get isListening => false;

  @override
  Future<void> startListening({
    required String localeId,
    required SttResultCallback onResult,
    Duration listenFor = const Duration(seconds: 10),
  }) async {}

  @override
  Future<void> stopListening() async {}
}

class _FakeTts implements TtsService {
  _FakeTts({this.url, this.error});

  final String? url;
  final TtsException? error;
  int calls = 0;

  @override
  Future<String> synthesize({
    required String text,
    required String name,
  }) async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return url!;
  }
}

Checkin _checkin(Mood mood) => Checkin(
  id: 'c1',
  userId: 'u1',
  mood: mood,
  checkinDate: DateTime(2026, 7, 29),
  createdAt: DateTime(2026, 7, 29),
);

WorkshopDetail _traChieu({
  String id = 'tc1',
  String title = 'Bận cả tuần, nhưng mình đang đi về đâu?',
  String? description,
  DateTime? date,
  String? location = 'TP.HCM',
  num price = 99000,
  String? imageUrl = 'https://cdn.test/anh-to.jpg',
}) => WorkshopDetail(
  id: id,
  title: title,
  description: description,
  category: 'Trà chiều nghề nghiệp',
  date: date ?? DateTime.now().add(const Duration(days: 7)),
  location: location,
  price: price,
  currency: 'VND',
  currentParticipants: 0,
  imageUrl: imageUrl,
  status: 'published',
  isActive: true,
);

Widget _wrap(
  Widget home, {
  FakeWrRepository? repo,
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  FakeWrMoodContentRepository? moodContent,
  FakeWrEpisodeRepository? episodes,
  FakeWorkshopRepository? workshops,
  FakeWrChatRepository? chat,
  TtsService? tts,
  bool sttAvailable = false,
  String? email,
}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => home),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/ask', builder: (_, __) => const WrAskScreen()),
      GoRoute(
        path: '/wr/tra-chieu',
        builder: (_, __) => const WrTraChieuScreen(),
      ),
      GoRoute(path: '/wr/paywall', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/wr/tra-chieu/lich',
        builder: (_, __) => const WrTraChieuCalendarScreen(),
      ),
      // Đường tĩnh đặt TRƯỚC `:id` để không bị nuốt, giống app_router.dart.
      GoRoute(
        path: '/wr/growth/themes',
        builder: (_, __) => const Scaffold(body: Text('THEMES')),
      ),
      GoRoute(
        path: '/wr/growth/theme/:id',
        builder: (_, s) =>
            Scaffold(body: Text('THEME ${s.pathParameters['id']}')),
      ),
      // Đích của nút hành động dưới bong bóng trả lời (mục 5 và mục 8).
      GoRoute(
        path: '/wr/flow/energy',
        builder: (_, __) => const Scaffold(body: Text('LUỒNG REFLECTION')),
      ),
      for (final p in [
        '/wr/pattern/:code',
        '/wr/mood-library',
        '/wr/mood-content/:id',
        '/wr/flow/moment',
      ])
        GoRoute(path: p, builder: (_, __) => const Scaffold()),
    ],
  );

  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(repo ?? FakeWrRepository()),
      wrContentRepositoryProvider.overrideWithValue(
        content ?? FakeWrContentRepository(),
      ),
      wrIntelligenceRepositoryProvider.overrideWithValue(
        intel ?? FakeWrIntelligenceRepository(),
      ),
      wrMoodContentRepositoryProvider.overrideWithValue(
        moodContent ?? FakeWrMoodContentRepository(),
      ),
      wrEpisodeRepositoryProvider.overrideWithValue(
        episodes ?? FakeWrEpisodeRepository(),
      ),
      workshopRepositoryProvider.overrideWithValue(
        workshops ?? FakeWorkshopRepository(),
      ),
      wrChatRepositoryProvider.overrideWithValue(
        chat ?? FakeWrChatRepository(),
      ),
      grantedAiConsent(),
      sttServiceProvider.overrideWithValue(_FakeStt(available: sttAvailable)),
      if (tts != null) ttsServiceProvider.overrideWithValue(tts),
      currentUserIdProvider.overrideWithValue('u1'),
      // Quyết định ai được thấy công tắc Premium thử nghiệm.
      currentUserEmailProvider.overrideWithValue(email),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  group('Home — hai khối chỉ hiện sau check-in', () {
    FakeWrIntelligenceRepository intelWithPattern() =>
        FakeWrIntelligenceRepository();

    /// Năm lượt nhìn lại cùng chọn tình huống `s1`.
    ///
    /// Gieo EPISODE chứ không gieo `wr_pattern_counts`: từ 2026-07-31 thẻ "Hệ
    /// thống nhận ra" đọc recentSituationIds (Kiến trúc v2.0 §4.3).
    /// Tình huống `s1` ở chiều C2 — cùng cụm với cảm xúc "căng thẳng" mà các
    /// test dưới đây gieo (§III: stressed → A3+C2).
    ///
    /// Từ 2026-08-22 thẻ "Hệ thống nhận ra" chỉ xét tình huống thuộc cụm chiều
    /// của cảm xúc vừa check-in — khách nói rõ "nhận diện tình huống vừa
    /// check-in". Không gieo bảng tình huống thì không mã nào tra ra được chiều,
    /// và thẻ im lặng đúng theo luật đó.
    FakeWrContentRepository contentWithSituation() =>
        FakeWrContentRepository()..seedSituations(const [
          WrSituation(
            code: 's1',
            text: 'Ngại phản biện với đồng nghiệp',
            scaDimension: ScaDimension.c2,
            wave: 1,
          ),
        ]);

    FakeWrEpisodeRepository episodesWithPattern() =>
        FakeWrEpisodeRepository()..seed([
          for (var i = 0; i < 5; i++)
            ReflectionEpisode(
              id: 'e\$i',
              userId: 'u1',
              humanMoment: HumanMoment.confusion,
              state: ExperienceState.integrated,
              situationCode: 's1',
              openedAt: DateTime(2026, 7, 20).add(Duration(hours: i)),
            ),
        ]);

    testWidgets('chưa check-in: không có Hệ thống nhận ra, không có Gợi ý', (
      tester,
    ) async {
      final moodContent = FakeWrMoodContentRepository()
        ..seedContent([fakeMoodContent(id: 'm1', mood: Mood.stressed)]);

      await _pump(
        tester,
        _wrap(
          const WrHomeScreen(),
          intel: intelWithPattern(),
          moodContent: moodContent,
        ),
      );

      expect(find.byKey(const Key('wr_home_system_notice')), findsNothing);
      expect(find.byKey(const Key('wr_home_mood_content')), findsNothing);
      // Câu hỏi check-in thì vẫn phải còn — đó là việc duy nhất còn lại.
      expect(
        find.text(wrKeepTitleTail('Ngày hôm nay của bạn như thế nào?')),
        findsOneWidget,
      );
    });

    testWidgets(
      'đã check-in: thẻ Thư viện hiện ra, không còn Hệ thống nhận ra',
      (tester) async {
        final moodContent = FakeWrMoodContentRepository()
          ..seedContent([fakeMoodContent(id: 'm1', mood: Mood.stressed)]);

        await _pump(
          tester,
          _wrap(
            const WrHomeScreen(),
            repo: FakeWrRepository()..seedTodayCheckin(_checkin(Mood.stressed)),
            intel: intelWithPattern(),
            episodes: episodesWithPattern(),
            content: contentWithSituation(),
            moodContent: moodContent,
          ),
        );

        // Mockup Sprint 2 bỏ thẻ navy "Hệ thống nhận ra" khỏi Home.
        expect(find.byKey(const Key('wr_home_system_notice')), findsNothing);
        expect(find.byKey(const Key('wr_home_mood_content')), findsOneWidget);
      },
    );

    testWidgets('thứ tự dọc đúng mockup Sprint 2: cảm xúc hôm nay → Thư viện '
        '→ Tiếp tục', (tester) async {
      // Thứ tự lấy từ `screenHome()` của mockup v47. Sau check-in, Insight
      // gần nhất nhường chỗ cho hai khối nói về chính lần check-in đó.
      // Khoá bằng toạ độ chứ không bằng thứ tự trong code — đây là thứ người
      // dùng thật sự nhìn thấy.
      final intel = intelWithPattern()
        ..seedInsights([
          WrInsight(
            userId: 'u1',
            content: 'Tôi thường im lặng vì sợ phán xét.',
            createdAt: DateTime(2026, 6, 20),
          ),
        ])
        ..seedPracticeThemes([
          const PracticeTheme(themeId: 't1', title: 'Dám lên tiếng'),
        ])
        ..seedPracticeSteps('t1', [
          const PracticeStep(
            stepId: 's1',
            themeId: 't1',
            stepOrder: 1,
            title: 'Quan sát lúc muốn im lặng',
            isPremium: false,
          ),
        ])
        ..seedPracticeSteps('t1', [
          const PracticeStep(
            stepId: 's1',
            themeId: 't1',
            stepOrder: 1,
            title: 'Quan sát lúc muốn im lặng',
            isPremium: false,
          ),
          const PracticeStep(
            stepId: 's2',
            themeId: 't1',
            stepOrder: 2,
            title: 'Nói một câu trong cuộc họp',
            isPremium: false,
          ),
        ])
        ..seedEnrollments([
          const PracticeEnrollment(
            userId: 'u1',
            themeId: 't1',
            completedSteps: ['s1'],
          ),
        ]);
      final moodContent = FakeWrMoodContentRepository()
        ..seedContent([fakeMoodContent(id: 'm1', mood: Mood.stressed)]);

      await _pump(
        tester,
        _wrap(
          const WrHomeScreen(),
          repo: FakeWrRepository()..seedTodayCheckin(_checkin(Mood.stressed)),
          intel: intel,
          episodes: episodesWithPattern(),
          content: contentWithSituation(),
          moodContent: moodContent,
        ),
      );

      double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;

      expect(top('wr_home_mood_row'), lessThan(top('wr_home_mood_content')));
      expect(
        top('wr_home_mood_content'),
        lessThan(top('wr_home_continue_today')),
      );
      expect(find.byKey(const Key('wr_home_system_notice')), findsNothing);
      // Insight đã lưu không phải nguồn của "Lần gần nhất bạn thấy như vậy".
      expect(find.byKey(const Key('wr_home_latest_insight')), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('Home — mockup v47', () {
    testWidgets('hero thành phố thay minh hoạ cũ, avatar nằm trên hero', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrHomeScreen()));

      final hero = find.byKey(const Key('wr_home_hero'));
      expect(hero, findsOneWidget);
      expect(
        find.descendant(
          of: hero,
          matching: find.byKey(const Key('wr_home_profile_button')),
        ),
        findsOneWidget,
      );
      // Họp khách 14/10: ngắt sẵn thành hai dòng, mỗi dòng một Text.
      expect(find.text('Dừng lại một chút.'), findsOneWidget);
      expect(find.text('Hôm nay của bạn đang như thế nào?'), findsOneWidget);
    });

    testWidgets('chưa check-in: chỉ lưới sáu ô', (tester) async {
      await _pump(tester, _wrap(const WrHomeScreen()));

      expect(find.byKey(const Key('wr_home_mood_row')), findsNothing);
      expect(find.byKey(const Key('wr_home_checkin_stress')), findsOneWidget);
      // "Lần gần nhất bạn thấy như vậy" chỉ có nghĩa sau khi chọn cảm xúc.
      expect(find.byKey(const Key('wr_home_latest_insight')), findsNothing);
      expect(
        find.byKey(const Key('wr_home_latest_insight_empty')),
        findsNothing,
      );
    });

    testWidgets('nhãn ô và dòng "Hôm nay bạn …" đúng MOODS của mockup', (
      tester,
    ) async {
      expect(kCheckinOptions.map((o) => o.label).toList(), [
        'Tôi đang\ncăng thẳng',
        'Tôi mệt mỏi\ncần nghỉ ngơi',
        'Tôi thấy\nmơ hồ',
        'Tôi thấy\nmọi thứ lệch nhau',
        'Tôi\nkhá ổn',
        'Tôi\nđang vui',
      ]);
      // `label.replace(/^Tôi (đang )?/, '')`.
      expect(checkinTodayPhrase('happy'), 'vui');
      expect(checkinTodayPhrase('stress'), 'căng thẳng');
      expect(checkinTodayPhrase('outofsync'), 'thấy mọi thứ lệch nhau');
    });

    testWidgets('đã check-in: lưới thu thành "Hôm nay bạn … · Đổi", Đổi mở '
        'lại lưới', (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrHomeScreen(),
          repo: FakeWrRepository()..seedTodayCheckin(_checkin(Mood.tired)),
        ),
      );

      final row = find.byKey(const Key('wr_home_mood_row'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining(
            'mệt mỏi cần nghỉ ngơi',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_home_checkin_stress')), findsNothing);

      await tester.tap(find.byKey(const Key('wr_home_mood_change')));
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(find.byKey(const Key('wr_home_checkin_stress')), findsOneWidget);
    });

    testWidgets('lối vào Thư viện nằm trên đầu thẻ gợi ý', (tester) async {
      final moodContent = FakeWrMoodContentRepository()
        ..seedContent([fakeMoodContent(id: 'm1', mood: Mood.stressed)]);
      await _pump(
        tester,
        _wrap(
          const WrHomeScreen(),
          repo: FakeWrRepository()..seedTodayCheckin(_checkin(Mood.stressed)),
          moodContent: moodContent,
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('wr_home_mood_content_card')),
          matching: find.byKey(const Key('wr_home_mood_library_link')),
        ),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Home — Tiếp tục hôm nay', () {
    // Mockup Sprint 2 `resumeTheme()`: chỉ chủ đề đã xong ít nhất một bước và
    // còn bước chưa xong. Không có thì khối biến mất, không thẻ mời thay thế.
    List<PracticeStep> fourSteps(String id, {bool premiumFrom3 = false}) => [
      for (var i = 1; i <= 4; i++)
        PracticeStep(
          stepId: '$id-s$i',
          themeId: id,
          stepOrder: i,
          title: 'Bước số $i của $id',
          isPremium: premiumFrom3 && i >= 3,
        ),
    ];

    FakeWrIntelligenceRepository withPractice({
      List<String> completed = const ['t1-s1'],
      bool premiumFrom3 = false,
    }) => FakeWrIntelligenceRepository()
      ..seedPracticeThemes([
        const PracticeTheme(themeId: 't1', title: 'Dám lên tiếng'),
      ])
      ..seedPracticeSteps('t1', fourSteps('t1', premiumFrom3: premiumFrom3))
      ..seedEnrollments([
        PracticeEnrollment(
          userId: 'u1',
          themeId: 't1',
          completedSteps: completed,
        ),
      ]);

    testWidgets('chủ đề đang dở: tên, Bước d+1 / 4, câu của bước, kể cả khi '
        'chưa check-in', (tester) async {
      await _pump(tester, _wrap(const WrHomeScreen(), intel: withPractice()));

      expect(find.byKey(const Key('wr_home_continue_today')), findsOneWidget);
      expect(find.text('TIẾP TỤC HÔM NAY'), findsOneWidget);
      expect(find.text('Dám lên tiếng'), findsOneWidget);
      expect(find.text('Bước 2 / 4'), findsOneWidget);
      expect(find.text('Bước số 2 của t1'), findsOneWidget);
    });

    testWidgets('nút "Mở bước này": coral, chữ navy, nhỏ, căn trái', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrHomeScreen(), intel: withPractice()));

      final button = find.byKey(const Key('wr_home_continue_today_card'));
      final style = tester.widget<FilledButton>(button).style!;
      expect(style.backgroundColor!.resolve({}), WrColors.coral);
      expect(style.foregroundColor!.resolve({}), WrColors.navy);
      final card = tester.getRect(
        find.byKey(const Key('wr_home_continue_today')),
      );
      final rect = tester.getRect(button);
      expect(rect.width, lessThan(card.width / 2));
      expect(rect.left - card.left, lessThan(40));
    });

    testWidgets('chạm mở đúng màn chủ đề', (tester) async {
      await _pump(tester, _wrap(const WrHomeScreen(), intel: withPractice()));

      await tester.tap(find.byKey(const Key('wr_home_continue_today_card')));
      await tester.pumpAndSettle();

      expect(find.text('THEME t1'), findsOneWidget);
    });

    testWidgets('chưa xong bước nào thì không phải "tiếp tục": khối ẩn', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(const WrHomeScreen(), intel: withPractice(completed: const [])),
      );

      expect(find.byKey(const Key('wr_home_continue_today')), findsNothing);
    });

    testWidgets('xong hết bước thì khối ẩn', (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrHomeScreen(),
          intel: withPractice(
            completed: const ['t1-s1', 't1-s2', 't1-s3', 't1-s4'],
          ),
        ),
      );

      expect(find.byKey(const Key('wr_home_continue_today')), findsNothing);
    });

    testWidgets('bước kế tiếp bị khoá Premium thì không mời tiếp tục', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          const WrHomeScreen(),
          intel: withPractice(
            completed: const ['t1-s1', 't1-s2'],
            premiumFrom3: true,
          ),
        ),
      );

      expect(find.byKey(const Key('wr_home_continue_today')), findsNothing);
    });

    testWidgets('chưa ghi danh chủ đề nào thì ẩn, không có thẻ mời chọn', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrHomeScreen()));

      expect(find.byKey(const Key('wr_home_continue_today')), findsNothing);
      expect(find.textContaining('Chưa có chủ đề nào đang theo'), findsNothing);
    });

    testWidgets('chủ đề gần đích bí vì bước Premium thì lấy chủ đề đang dở '
        'khác còn mở được', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([
          const PracticeTheme(themeId: 't1', title: 'Nhịp làm việc ổn định'),
          const PracticeTheme(themeId: 't2', title: 'Phản hồi hiệu quả'),
        ])
        ..seedPracticeSteps('t1', fourSteps('t1', premiumFrom3: true))
        ..seedPracticeSteps('t2', fourSteps('t2', premiumFrom3: true))
        ..seedEnrollments([
          PracticeEnrollment(
            userId: 'u1',
            themeId: 't1',
            startedAt: DateTime(2026, 7, 20),
            completedSteps: const ['t1-s1', 't1-s2'],
          ),
          PracticeEnrollment(
            userId: 'u1',
            themeId: 't2',
            startedAt: DateTime(2026, 7, 28),
            completedSteps: const ['t2-s1'],
          ),
        ]);

      await _pump(tester, _wrap(const WrHomeScreen(), intel: intel));

      expect(find.text('Phản hồi hiệu quả'), findsOneWidget);
      expect(find.text('Bước 2 / 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_home_continue_today_card')));
      await tester.pumpAndSettle();
      expect(find.text('THEME t2'), findsOneWidget);
    });

    testWidgets('nhiều chủ đề đang dở thì lấy chủ đề gần đích nhất', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([
          const PracticeTheme(themeId: 't1', title: 'Mới bắt đầu'),
          const PracticeTheme(themeId: 't2', title: 'Gần xong'),
        ])
        ..seedPracticeSteps('t1', fourSteps('t1'))
        ..seedPracticeSteps('t2', fourSteps('t2'))
        ..seedEnrollments([
          PracticeEnrollment(
            userId: 'u1',
            themeId: 't1',
            startedAt: DateTime(2026, 7, 20),
            completedSteps: const ['t1-s1'],
          ),
          PracticeEnrollment(
            userId: 'u1',
            themeId: 't2',
            startedAt: DateTime(2026, 7, 28),
            completedSteps: const ['t2-s1', 't2-s2', 't2-s3'],
          ),
        ]);

      await _pump(tester, _wrap(const WrHomeScreen(), intel: intel));

      expect(find.text('Gần xong'), findsOneWidget);
      expect(find.text('Bước 4 / 4'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('Trà Chiều Nghề Nghiệp', () {
    testWidgets('hiện buổi sắp tới bằng chữ: giờ, địa điểm, giá', (
      tester,
    ) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([_traChieu(location: 'TP.HCM, địa điểm báo sau')]);

      await _pump(
        tester,
        _wrap(const WrTraChieuScreen(), workshops: workshops),
      );

      expect(find.byKey(const Key('wr_tra_chieu_next')), findsOneWidget);
      expect(
        find.text('"Bận cả tuần, nhưng mình đang đi về đâu?"'),
        findsOneWidget,
      );
      expect(find.text('TP.HCM, địa điểm báo sau'), findsOneWidget);
      expect(find.text('Giữ chỗ 99.000đ'), findsOneWidget);
    });

    testWidgets('mô tả ngắn của buổi hiện trên thẻ buổi sắp tới', (
      tester,
    ) async {
      // Khách 2026-07-30 liệt kê đủ năm thứ tab này phải nói bằng chữ: tên,
      // mô tả ngắn, lịch, địa điểm, giá.
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([
          _traChieu(
            description:
                'Một buổi cho những người đang thấy mình bận nhưng '
                'không rõ đang đi đâu.',
          ),
        ]);

      await _pump(
        tester,
        _wrap(const WrTraChieuScreen(), workshops: workshops),
      );

      expect(
        find.byKey(const Key('wr_tra_chieu_next_description')),
        findsOneWidget,
      );
      expect(
        find.textContaining('bận nhưng không rõ đang đi đâu'),
        findsOneWidget,
      );
    });

    testWidgets('buổi không có mô tả thì không chừa khoảng trống', (
      tester,
    ) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([_traChieu(description: '   ')]);

      await _pump(
        tester,
        _wrap(const WrTraChieuScreen(), workshops: workshops),
      );

      expect(
        find.byKey(const Key('wr_tra_chieu_next_description')),
        findsNothing,
      );
    });

    testWidgets('cấu hình link Zalo mặc định 0866883047 dựng nút Zalo', (
      tester,
    ) async {
      final workshops = FakeWorkshopRepository()..seedWorkshops([_traChieu()]);

      await _pump(
        tester,
        _wrap(const WrTraChieuScreen(), workshops: workshops),
      );

      expect(kTraChieuZaloUrl, 'https://zalo.me/0866883047');
      expect(find.byKey(const Key('wr_tra_chieu_zalo_button')), findsOneWidget);
      // Lối đăng ký qua web thì luôn phải còn.
      expect(
        find.byKey(const Key('wr_tra_chieu_detail_button')),
        findsOneWidget,
      );
    });

    testWidgets('TUYỆT ĐỐI không chèn ảnh, dù workshop có image_url', (
      tester,
    ) async {
      // Yêu cầu dứt khoát của khách: "chị không có muốn vô hình… đừng có gắn
      // hình của bên trang kia qua". Ảnh của web co lại trên khung điện thoại
      // thì vỡ bố cục.
      final workshops = FakeWorkshopRepository()..seedWorkshops([_traChieu()]);

      await _pump(
        tester,
        _wrap(const WrTraChieuScreen(), workshops: workshops),
      );

      expect(_contentImages, findsNothing);
      expect(find.byType(NetworkImage), findsNothing);
      // Dải ảnh đầu màn của mockup v55 (10/10) là trang trí của app, không
      // phải ảnh lấy từ web; khách tự đặt nó trong mockup cho màn này.
      expect(find.byKey(const Key('wr_reflect_band_tab_act')), findsOneWidget);
    });

    testWidgets('ba luật và phần vì sao đều có mặt', (tester) async {
      final workshops = FakeWorkshopRepository()..seedWorkshops([_traChieu()]);

      await _pump(
        tester,
        _wrap(const WrTraChieuScreen(), workshops: workshops),
      );

      expect(find.text('Ba luật của mọi buổi'), findsOneWidget);
      for (final rule in kTraChieuRules) {
        expect(find.text(rule), findsOneWidget);
      }
      expect(find.text('Vì sao lại là Trà Chiều'), findsOneWidget);
    });

    testWidgets('chưa mở buổi nào thì hiện buổi mặc định theo script', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrTraChieuScreen()));

      expect(find.byKey(const Key('wr_tra_chieu_next')), findsOneWidget);
      expect(
        find.text('"Bận cả tuần, nhưng mình đang đi về đâu?"'),
        findsOneWidget,
      );
    });

    testWidgets('bỏ qua workshop không phải Trà Chiều', (tester) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([
          WorkshopDetail(
            id: 'w9',
            title: 'Workshop Tư duy hệ thống',
            category: 'Tư duy hệ thống',
            date: DateTime.now().add(const Duration(days: 3)),
            price: 0,
            currency: 'VND',
            currentParticipants: 0,
            status: 'published',
            isActive: true,
          ),
        ]);

      await _pump(
        tester,
        _wrap(const WrTraChieuScreen(), workshops: workshops),
      );

      expect(find.byKey(const Key('wr_tra_chieu_next')), findsOneWidget);
      expect(find.text('Workshop Tư duy hệ thống'), findsNothing);
    });

    testWidgets('lịch các buổi liệt kê đủ, mỗi buổi một dòng chữ', (
      tester,
    ) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([
          _traChieu(
            id: 'a',
            title: 'Buổi A',
            date: DateTime.now().add(const Duration(days: 7)),
          ),
          _traChieu(
            id: 'b',
            title: 'Buổi B',
            date: DateTime.now().add(const Duration(days: 21)),
          ),
        ]);

      await _pump(
        tester,
        _wrap(const WrTraChieuScreen(), workshops: workshops),
      );
      await tester.tap(find.byKey(const Key('wr_tra_chieu_calendar_row')));
      await tester.pumpAndSettle();

      expect(find.text('"Buổi A"'), findsOneWidget);
      expect(find.text('"Buổi B"'), findsOneWidget);
      expect(_contentImages, findsNothing);
    });

    testWidgets('lịch các buổi gom vào một thẻ duy nhất theo script', (
      tester,
    ) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([
          _traChieu(
            id: 'w1',
            title: 'Buổi A',
            description: 'Một câu hỏi duy nhất cho cả bàn.',
            date: DateTime.now().add(const Duration(days: 30)),
          ),
        ]);

      await _pump(
        tester,
        _wrap(const WrTraChieuCalendarScreen(), workshops: workshops),
      );

      expect(find.text('"Buổi A"'), findsOneWidget);
      expect(find.text('Một câu hỏi duy nhất cho cả bàn.'), findsOneWidget);
      expect(_contentImages, findsNothing);
    });

    testWidgets('bấm vào một buổi thì mở bottom sheet chi tiết buổi', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrTraChieuCalendarScreen()));

      // Bấm vào buổi TC1 đầu tiên
      await tester.tap(find.byKey(const Key('wr_tra_chieu_session_TC1')));
      await tester.pumpAndSettle();

      // Hiện bottom sheet với thông tin buổi và nút Zalo giữ chỗ
      expect(
        find.byKey(const Key('wr_tra_chieu_sheet_zalo_button')),
        findsOneWidget,
      );
      expect(
        find.text('10 đến 12 người · 2 tiếng · 1 câu hỏi'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Màn này ĐÃ ĐỔI BẢN CHẤT ngày 2026-08-03: từ ô hỏi một chiều chờ trả lời qua
  // email thành khung chat nhiều lượt do AI trả lời tại chỗ (AI Chatbox System
  // Prompt v1.0). Đó chính là phần khách hoãn ở họp 2026-07-29 ("cái nói chuyện
  // qua nói chuyện lại chị nghĩ cái đó nó sẽ chờ sau").
  //
  // Những câu hỏi gửi theo cách cũ vẫn đọc lại được, xem nhóm test cuối.
  group('Trò chuyện với trợ lý phản chiếu', () {
    testWidgets('gửi xong thì hiện cả câu hỏi lẫn câu trả lời', (tester) async {
      final chat = FakeWrChatRepository()
        ..replyText = 'Nghe quen thuộc đấy. Điều gì khiến bạn chọn im lặng?';

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));

      await tester.enterText(
        find.byKey(const Key('wr_ask_field')),
        'Tôi vừa im lặng trong một cuộc họp.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(chat.sendCalls.map((c) => c.message), [
        'Tôi vừa im lặng trong một cuộc họp.',
      ]);
      expect(find.text('Tôi vừa im lặng trong một cuộc họp.'), findsOneWidget);
      expect(
        find.text('Nghe quen thuộc đấy. Điều gì khiến bạn chọn im lặng?'),
        findsOneWidget,
      );
    });

    testWidgets('ô trống thì không gửi', (tester) async {
      final chat = FakeWrChatRepository();

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(chat.sendCalls, isEmpty);
    });

    testWidgets('gửi hỏng thì báo lỗi và GỠ câu chưa gửi được', (tester) async {
      // Để lại câu đó trên màn hình là dựng một lượt trông như đã gửi mà máy chủ
      // không hề biết — mở lại màn là nó biến mất, không lời giải thích.
      final chat = FakeWrChatRepository();

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      // Gieo lỗi SAU khi màn đã nạp lịch sử: `nextError` chỉ ném một lần, đặt
      // trước thì lần đọc lịch sử nuốt mất nó và lệnh gửi vẫn thành công.
      chat.nextError = const WrChatException('Không kết nối được lúc này.');
      await tester.enterText(
        find.byKey(const Key('wr_ask_field')),
        'Câu hỏi của tôi',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chat_error')), findsOneWidget);
      expect(find.text('Không kết nối được lúc này.'), findsOneWidget);
      expect(find.byKey(const Key('wr_chat_user_bubble')), findsNothing);
    });

    testWidgets('hết lượt thì mời xem gói thay vì mời gửi lại', (tester) async {
      final chat = FakeWrChatRepository();

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      chat.nextError = const WrChatException(
        'Hôm nay bạn đã dùng hết lượt trò chuyện của gói miễn phí.',
        quotaExhausted: true,
      );
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Xin chào');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chat_paywall_link')), findsOneWidget);
    });

    testWidgets('gói miễn phí thấy số lượt còn lại, Premium thì không', (
      tester,
    ) async {
      final chat = FakeWrChatRepository()
        ..limit = 10
        ..isPremium = false;

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Xin chào');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chat_quota_hint')), findsOneWidget);
      expect(
        find.text('Còn 9 lượt trò chuyện miễn phí hôm nay.'),
        findsOneWidget,
      );
    });

    testWidgets('Premium không bị nhắc về hạn mức', (tester) async {
      final chat = FakeWrChatRepository()
        ..isPremium = true
        ..limit = 100;

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Xin chào');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chat_quota_hint')), findsNothing);
    });

    // Chính sách Nội dung do AI tạo của Google Play: báo cáo được câu trả lời
    // AI ngay trong app.
    testWidgets('câu trả lời AI có nút Báo cáo, câu của người dùng thì không', (
      tester,
    ) async {
      final chat = FakeWrChatRepository();

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Xin chào');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chat_ai_bubble')), findsOneWidget);
      expect(find.byKey(const Key('wr_chat_report')), findsOneWidget);
    });

    testWidgets(
      'báo cáo: phải chọn lý do mới gửi được, gửi kèm bản chụp câu trả lời',
      (tester) async {
        final chat = FakeWrChatRepository()
          ..replyText = 'Câu trả lời cần báo cáo';

        await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
        await tester.enterText(
          find.byKey(const Key('wr_ask_field')),
          'Xin chào',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('wr_ask_send')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('wr_chat_report')));
        await tester.pumpAndSettle();
        expect(find.text('Báo cáo câu trả lời này'), findsOneWidget);

        final submit = find.byKey(const Key('wr_chat_report_submit'));
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);

        await tester.tap(find.byKey(const Key('wr_chat_report_offensive')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('wr_chat_report_note')),
          '  thô lỗ  ',
        );
        await tester.pump();
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(chat.reportCalls, hasLength(1));
        final call = chat.reportCalls.single;
        expect(call.content, 'Câu trả lời cần báo cáo');
        expect(call.reason, WrAiReportReason.offensive);
        expect(call.note, '  thô lỗ  ');
        expect(call.conversationId, 'c1');
        expect(find.text('Báo cáo câu trả lời này'), findsNothing);
        expect(
          find.text('Cảm ơn bạn. Báo cáo đã được ghi nhận để đội ngũ xem lại.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('báo cáo lỗi mạng: tấm trượt ở lại và báo lỗi', (tester) async {
      final chat = FakeWrChatRepository();

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Xin chào');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wr_chat_report')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_chat_report_other')));
      await tester.pump();
      chat.nextError = const WrChatException('Chưa gửi được báo cáo.');
      final submit = find.byKey(const Key('wr_chat_report_submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(chat.reportCalls, isEmpty);
      expect(find.text('Báo cáo câu trả lời này'), findsOneWidget);
      expect(find.text('Chưa gửi được báo cáo.'), findsOneWidget);
    });

    testWidgets('mở màn là vào thẳng cuộc gần nhất, đúng thứ tự', (
      tester,
    ) async {
      // Vào thẳng cuộc đang dở chứ không bắt qua màn chọn: phần lớn lần mở là
      // để nói tiếp chuyện dở dang.
      final chat = FakeWrChatRepository()
        ..seedConversation('cũ', const [
          WrChatMessage(role: WrChatRole.user, content: 'Chuyện tháng trước'),
        ], lastMessageAt: DateTime(2026, 7, 1))
        ..seedConversation('mới', const [
          WrChatMessage(role: WrChatRole.user, content: 'Câu hỏi hôm qua'),
          WrChatMessage(
            role: WrChatRole.assistant,
            content: 'Câu trả lời hôm qua',
          ),
        ], lastMessageAt: DateTime(2026, 8, 2));

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));

      expect(find.text('Câu hỏi hôm qua'), findsOneWidget);
      expect(find.text('Câu trả lời hôm qua'), findsOneWidget);
      // Cuộc cũ KHÔNG được trộn vào — đó là cả lý do tách cuộc trò chuyện ra.
      expect(find.text('Chuyện tháng trước'), findsNothing);
      expect(find.byKey(const Key('wr_chat_empty')), findsNothing);
    });

    testWidgets('lượt đầu gửi conversationId null, lượt sau gửi id đã có', (
      tester,
    ) async {
      final chat = FakeWrChatRepository();

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      for (final t in ['Câu một', 'Câu hai']) {
        await tester.enterText(find.byKey(const Key('wr_ask_field')), t);
        await tester.pump();
        await tester.tap(find.byKey(const Key('wr_ask_send')));
        await tester.pumpAndSettle();
      }

      expect(chat.sendCalls.first.conversationId, isNull);
      // Không bám lấy id máy chủ trả về thì mỗi lượt lại đẻ một cuộc mới, và
      // trợ lý mất sạch mạch hội thoại giữa chừng.
      expect(chat.sendCalls.last.conversationId, isNotNull);
    });

    testWidgets('nút cuộc trò chuyện mới dọn màn và bỏ id cũ', (tester) async {
      final chat = FakeWrChatRepository()
        ..seedConversation('c-cũ', const [
          WrChatMessage(role: WrChatRole.user, content: 'Câu cũ'),
        ]);

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      expect(find.text('Câu cũ'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_chat_new')));
      await tester.pumpAndSettle();

      expect(find.text('Câu cũ'), findsNothing);
      expect(find.byKey(const Key('wr_chat_empty')), findsOneWidget);

      // Gửi sau khi bấm nút phải mở cuộc MỚI, không nối vào cuộc cũ.
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Câu mới');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(chat.sendCalls.single.conversationId, isNull);
    });

    testWidgets('mở được cuộc trò chuyện cũ từ màn lịch sử', (tester) async {
      final chat = FakeWrChatRepository()
        ..seedConversation(
          'c-mới',
          const [WrChatMessage(role: WrChatRole.user, content: 'Chuyện mới')],
          title: 'Chuyện mới',
          lastMessageAt: DateTime(2026, 8, 2),
        )
        ..seedConversation(
          'c-cũ',
          const [WrChatMessage(role: WrChatRole.user, content: 'Chuyện cũ')],
          title: 'Chuyện cũ',
          lastMessageAt: DateTime(2026, 7, 1),
        );

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.tap(find.byKey(const Key('wr_chat_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch sử trò chuyện'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_chat_conversation_c-cũ')));
      await tester.pumpAndSettle();

      expect(find.text('Chuyện cũ'), findsOneWidget);
      expect(find.text('Chuyện mới'), findsNothing);
    });

    testWidgets('trợ lý mời ghi Reflection thì có nút mở luồng', (
      tester,
    ) async {
      // Mục 5: trợ lý MỜI vào Reflection. Trước 2026-08-03 nó nói được câu mời
      // nhưng không có đường đi tới, nên lời mời rơi vào khoảng không.
      final chat = FakeWrChatRepository()
        ..replyText = 'Muốn ghi lại thành một Reflection không?'
        ..replyAction = WrChatAction.reflect;

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.enterText(
        find.byKey(const Key('wr_ask_field')),
        'Mình im lặng',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chat_action_reflect')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_chat_action_reflect')));
      await tester.pumpAndSettle();
      expect(find.text('LUỒNG REFLECTION'), findsOneWidget);
    });

    testWidgets('trợ lý đề nghị bài dịu lại thì có nút mở Thư viện', (
      tester,
    ) async {
      // Bước 3 của mục 8. Đây là lượt người dùng đang ở trạng thái tệ nhất, nên
      // "đề nghị giúp rồi không mở được gì" là kiểu hỏng tệ nhất.
      final chat = FakeWrChatRepository()
        ..replyText = 'Mình có một điều nhẹ nhàng có thể giúp bạn dịu lại.'
        ..replyAction = WrChatAction.calm;

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.enterText(
        find.byKey(const Key('wr_ask_field')),
        'Mình mệt quá',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chat_action_calm')), findsOneWidget);
    });

    testWidgets('mở lại cuộc trò chuyện: lời mời ở lượt cuối vẫn có nút', (
      tester,
    ) async {
      // Người dùng gặp 09/09: nút không lưu vào DB, nên mở lại cuộc trò chuyện
      // thì câu "thử một bài đọc ngắn" còn đó mà không có gì để bấm.
      final chat = FakeWrChatRepository()
        ..seedConversation('c1', const [
          WrChatMessage(role: WrChatRole.user, content: 'khá là căng thẳng'),
          WrChatMessage(
            role: WrChatRole.assistant,
            content:
                'Bạn có muốn thử một bài đọc ngắn để thấy nhẹ lòng hơn lúc này không?',
          ),
        ]);

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chat_action_calm')), findsOneWidget);
    });

    testWidgets('lượt không có lời mời thì KHÔNG có nút', (tester) async {
      final chat = FakeWrChatRepository()..replyAction = null;

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Xin chào');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_chat_action_reflect')), findsNothing);
      expect(find.byKey(const Key('wr_chat_action_calm')), findsNothing);
    });

    testWidgets('chưa có gì thì hiện gợi ý mở lời, chạm là điền vào ô', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrAskScreen()));

      expect(find.byKey(const Key('wr_chat_empty')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_chat_starter_0')));
      await tester.pumpAndSettle();

      expect(find.text(kChatStarters.first), findsWidgets);
    });

    testWidgets('lịch sử đọc hỏng thì vẫn trò chuyện được', (tester) async {
      // Máy chủ mới là nơi giữ ngữ cảnh thật. Khoá màn hình lại vì không tải
      // được phần đã cuộn qua là chặn người ta khỏi việc họ vào đây để làm.
      final chat = FakeWrChatRepository()..nextError = StateError('mạng hỏng');

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Xin chào');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(chat.sendCalls.map((c) => c.message), ['Xin chào']);
    });

    testWidgets('xoá cuộc trò chuyện sau khi xác nhận', (tester) async {
      final chat = FakeWrChatRepository()
        ..seedConversation('c-xoá', const [
          WrChatMessage(role: WrChatRole.user, content: 'Câu cũ'),
        ]);

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.tap(find.byKey(const Key('wr_chat_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá cuộc trò chuyện này'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_chat_clear_confirm')));
      await tester.pumpAndSettle();

      expect(chat.deleteCalls, ['c-xoá']);
      expect(find.text('Câu cũ'), findsNothing);
    });

    testWidgets('đọc lại được câu đã hỏi theo cách cũ', (tester) async {
      // Những người đã gửi câu hỏi trước 2026-08-03 được hứa một câu trả lời qua
      // email. Xoá lối vào phần đó đi là nuốt lời hứa.
      final intel = FakeWrIntelligenceRepository()
        ..seedCareerQuestions([
          CareerQuestion(
            id: 'q1',
            userId: 'u1',
            question: 'Câu đã trả lời',
            answer: 'Đây là câu trả lời.',
            createdAt: DateTime(2026, 7, 25),
          ),
          CareerQuestion(
            id: 'q2',
            userId: 'u1',
            question: 'Câu chưa trả lời',
            createdAt: DateTime(2026, 7, 26),
          ),
        ]);

      await _pump(tester, _wrap(const WrAskScreen(), intel: intel));
      await tester.tap(find.byKey(const Key('wr_chat_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Câu hỏi đã gửi trước đây'));
      await tester.pumpAndSettle();

      expect(find.text(wrKeepTitleTail('Câu đã trả lời')), findsOneWidget);
      expect(find.text('Đây là câu trả lời.'), findsOneWidget);
      expect(find.text(wrKeepTitleTail('Câu chưa trả lời')), findsOneWidget);
      expect(find.text(kAskPendingMessage), findsOneWidget);
    });

    testWidgets('có nút mic khi máy nhận dạng được giọng nói', (tester) async {
      await _pump(tester, _wrap(const WrAskScreen(), sttAvailable: true));

      expect(find.byKey(const Key('wr_voice_mic')), findsOneWidget);
    });

    testWidgets('máy không hỗ trợ thì không có nút mic, ô vẫn gõ được', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrAskScreen()));

      expect(find.byKey(const Key('wr_voice_mic')), findsNothing);
      expect(find.byKey(const Key('wr_ask_field')), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('Bong bóng hỏi', () {
    // Khách 2026-07-30 tắt bong bóng trên shell ("chúng ta sẽ làm cái này
    // sau"). Widget và màn hỏi giữ nguyên để bật lại — test dưới dựng thẳng
    // widget nên vẫn khoá được hành vi của nó. Chỗ khoá việc "không còn nổi
    // trên tab nào" nằm ở `shell_test.dart`, nơi dựng shell thật.
    testWidgets('chạm mở màn trò chuyện', (tester) async {
      await _pump(
        tester,
        _wrap(const Scaffold(body: Center(child: WrAskBubble()))),
      );

      expect(find.byKey(const Key('wr_ask_bubble')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_ask_bubble')));
      await tester.pumpAndSettle();

      expect(find.text('Trò chuyện'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('Trà Chiều trong danh sách chủ đề thực hành', () {
    /// Xổ cả thư viện. Màn này dẫn bằng chủ đề được đề xuất (khách 2026-08-04),
    /// danh sách đầy đủ nằm sau một dòng xổ.
    Future<void> showAll(WidgetTester tester) async {
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const Key('wr_growth_themes_show_all')),
              matching: find.byType(Text),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    FakeWrIntelligenceRepository themes(List<String> titles) =>
        FakeWrIntelligenceRepository()..seedPracticeThemes([
          for (var i = 0; i < titles.length; i++)
            PracticeTheme(themeId: 't$i', title: titles[i]),
        ]);

    testWidgets('đứng ngay sau Tư duy hệ thống', (tester) async {
      // Vị trí do khách chỉ định: "nó ở giữa tư duy hệ thống với AI".
      await _pump(
        tester,
        _wrap(
          const WrGrowthThemesScreen(),
          intel: themes([
            'Tư duy hệ thống',
            'AI cho người đi làm',
            'Phong cách hiện diện',
          ]),
        ),
      );

      await showAll(tester);

      final row = find.byKey(const Key('wr_growth_theme_tra_chieu'));
      expect(row, findsOneWidget);

      final traChieuY = tester.getTopLeft(row).dy;
      final tuDuyY = tester.getTopLeft(find.text('Tư duy hệ thống')).dy;
      final aiY = tester.getTopLeft(find.text('AI cho người đi làm')).dy;
      expect(traChieuY, greaterThan(tuDuyY));
      expect(traChieuY, lessThan(aiY));
    });

    testWidgets('không có chủ đề mỏ neo thì để cuối, vẫn hiện', (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrGrowthThemesScreen(),
          intel: themes(['Phong cách hiện diện']),
        ),
      );

      await showAll(tester);

      final row = find.byKey(const Key('wr_growth_theme_tra_chieu'));
      expect(row, findsOneWidget);
      expect(
        tester.getTopLeft(row).dy,
        greaterThan(tester.getTopLeft(find.text('Phong cách hiện diện')).dy),
      );
    });

    testWidgets('vẫn hiện khi đã ghi danh hết chủ đề', (tester) async {
      final intel = themes(['Tư duy hệ thống'])
        ..seedEnrollments([
          const PracticeEnrollment(
            userId: 'u1',
            themeId: 't0',
            completedSteps: [],
          ),
        ]);

      await _pump(tester, _wrap(const WrGrowthThemesScreen(), intel: intel));

      expect(
        find.byKey(const Key('wr_growth_theme_tra_chieu')),
        findsOneWidget,
      );
    });

    testWidgets('chạm mở màn Trà Chiều chứ không ghi danh', (tester) async {
      final intel = themes(['Tư duy hệ thống']);

      await _pump(tester, _wrap(const WrGrowthThemesScreen(), intel: intel));
      await tester.tap(find.byKey(const Key('wr_growth_theme_tra_chieu')));
      await tester.pumpAndSettle();

      expect(find.text('Ba luật của mọi buổi'), findsOneWidget);
      expect(intel.enrollThemeCalls, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Khách 2026-07-30: dòng "Thực hành khác" trên tab Phát triển nhường chỗ cho
  // thẻ mời Trà Chiều, dựng theo mockup Sprint 2 (`screenAct`).
  // Script Sprint 2 (PR #48): Trà Chiều là thẻ thứ hai của phần "Mở rộng"
  // (`upcomingTraChieu() ? … : ''`): ảnh thumb, nhãn "OFFLINE · TRÀ CHIỀU",
  // "Trà chiều nghề nghiệp", "10 đến 12 người · 2 giờ · một câu hỏi". Người
  // dùng 13/10: giữ bản đã duyệt, thẻ luôn hiện kể cả khi chưa có buổi nào.
  group('Phát triển — thẻ Trà Chiều thay dòng Thực hành khác', () {
    final card = find.byKey(const Key('wr_growth_tra_chieu_card'));

    testWidgets('không còn dòng Thực hành khác', (tester) async {
      await _pump(tester, _wrap(const WrGrowthScreen()));

      expect(find.text('Thực hành khác'), findsNothing);
      expect(find.byKey(const Key('wr_growth_other_themes_row')), findsNothing);
      // "Chặng đường phát triển" đã bỏ khỏi màn này (2026-08-03).
      expect(find.text('Chặng đường phát triển'), findsNothing);
    });

    testWidgets('thẻ nói nhãn, tên chương trình và khuôn buổi', (tester) async {
      final buoi = _traChieu(date: DateTime.now().add(const Duration(days: 9)));
      final workshops = FakeWorkshopRepository()..seedWorkshops([buoi]);

      await _pump(tester, _wrap(const WrGrowthScreen(), workshops: workshops));

      expect(card, findsOneWidget);
      Finder inCard(Finder f) => find.descendant(of: card, matching: f);
      expect(inCard(find.text('OFFLINE · TRÀ CHIỀU')), findsOneWidget);
      expect(inCard(find.text('Trà chiều nghề nghiệp')), findsOneWidget);
      expect(inCard(find.textContaining('10 đến 12 người')), findsOneWidget);
      // Ảnh thumb của script là asset cố định; ảnh của workshop (image_url)
      // vẫn KHÔNG được chèn — nguyên tắc họp 2026-07-29.
      expect(
        inCard(
          find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
        ),
        findsNothing,
      );
    });

    testWidgets('chạm thẻ mở màn Trà Chiều', (tester) async {
      final workshops = FakeWorkshopRepository()..seedWorkshops([_traChieu()]);

      await _pump(tester, _wrap(const WrGrowthScreen(), workshops: workshops));
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byType(WrTraChieuScreen), findsOneWidget);
    });

    // Khách 30/07: lịch trống vẫn giữ cửa vào Trà Chiều, thẻ nói thẳng.
    testWidgets('chưa mở buổi nào thì thẻ vẫn hiện', (tester) async {
      await _pump(tester, _wrap(const WrGrowthScreen()));

      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Trà chiều nghề nghiệp')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('buổi đã diễn ra rồi thì không mượn lại làm buổi sắp tới', (
      tester,
    ) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([
          _traChieu(
            title: 'Buổi tháng trước',
            date: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ]);

      await _pump(tester, _wrap(const WrGrowthScreen(), workshops: workshops));

      expect(find.textContaining('Buổi tháng trước'), findsNothing);
      expect(card, findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('Màn đọc — header ghim và audio', () {
    FakeWrMoodContentRepository libraryWith(MoodContent item) =>
        FakeWrMoodContentRepository()..seedContent([item]);

    testWidgets('header ghim lại khi cuộn nội dung', (tester) async {
      final moodContent = libraryWith(
        fakeMoodContent(
          id: 'm1',
          mood: Mood.okay,
          title: 'Khi áp lực đến từ việc muốn kiểm soát mọi thứ',
          body: List.generate(12, (i) => 'Đoạn số $i.').join('\n\n'),
        ),
      );

      await _pump(
        tester,
        _wrap(
          const WrMoodReaderScreen(contentId: 'm1'),
          moodContent: moodContent,
        ),
      );

      final header = find.byKey(const Key('wr_mood_reader_header'));
      expect(header, findsOneWidget);
      final headerTop = tester.getTopLeft(header).dy;

      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();

      // Cuộn xa rồi mà thanh tiêu đề vẫn ở đỉnh, nút lùi vẫn bấm được, và tên
      // bài hiện thu nhỏ trên thanh: đúng yêu cầu "chỉ đẩy nội dung lên thôi
      // và giữ lại header".
      expect(tester.getTopLeft(header).dy, headerTop);
      expect(
        find.byKey(const Key('wr_mood_reader_back')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: header,
          matching: find.text('Khi áp lực đến từ việc muốn kiểm soát mọi thứ'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('bài đọc không dựng khối phát', (tester) async {
      final moodContent = libraryWith(
        fakeMoodContent(id: 'm1', mood: Mood.okay),
      );

      await _pump(
        tester,
        _wrap(
          const WrMoodReaderScreen(contentId: 'm1'),
          moodContent: moodContent,
        ),
      );

      expect(find.byKey(const Key('wr_mood_audio_player')), findsNothing);
    });

    testWidgets('audio chưa có bản thu: giọng AI tắt thì không mời dựng', (
      tester,
    ) async {
      // Mockup v47 (khách 06/10): tắt giọng AI. `kAiVoiceEnabled` mặc định
      // false, nên bài chưa có bản thu chỉ báo đang chuẩn bị, bấm không gọi
      // TTS.
      final tts = _FakeTts(url: 'https://cdn.test/x.wav');
      final moodContent = libraryWith(
        fakeMoodContent(
          id: 'm1',
          mood: Mood.stressed,
          type: MoodContentType.audio,
          kind: 'HEALING AUDIO',
        ),
      );

      await _pump(
        tester,
        _wrap(
          const WrMoodReaderScreen(contentId: 'm1'),
          moodContent: moodContent,
          tts: tts,
        ),
      );

      expect(find.byKey(const Key('wr_mood_audio_player')), findsOneWidget);
      expect(find.text('Nghe bằng giọng đọc AI'), findsNothing);
      expect(find.text('Bản thu đang được chuẩn bị.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_mood_audio_play')));
      await tester.pumpAndSettle();
      expect(tts.calls, 0);
    });

    testWidgets('đã có bản thu thì không gọi TTS', (tester) async {
      // Gọi lại TTS cho một bài đã dựng là đốt credit của khách cho cùng một
      // đoạn chữ không đổi.
      final tts = _FakeTts(url: 'https://cdn.test/x.wav');
      final moodContent = libraryWith(
        fakeMoodContent(
          id: 'm1',
          mood: Mood.stressed,
          type: MoodContentType.audio,
          duration: '3 phút',
          audioUrl: 'https://cdn.test/co-san.wav',
        ),
      );

      await _pump(
        tester,
        _wrap(
          const WrMoodReaderScreen(contentId: 'm1'),
          moodContent: moodContent,
          tts: tts,
        ),
      );

      expect(find.text('3 phút'), findsWidgets);
      expect(tts.calls, 0);
    });

    testWidgets('TTS hỏng thì hiện nguyên văn lý do', (tester) async {
      // Nhánh dựng bản thu tại chỗ chỉ chạy khi bật giọng AI
      // (`--dart-define=WR_AI_VOICE=true`).
      final tts = _FakeTts(
        error: const TtsException(
          'Giọng đọc AI chưa dùng được: A paid plan is required.',
        ),
      );
      final moodContent = libraryWith(
        fakeMoodContent(
          id: 'm1',
          mood: Mood.stressed,
          type: MoodContentType.audio,
        ),
      );

      await _pump(
        tester,
        _wrap(
          const WrMoodReaderScreen(contentId: 'm1'),
          moodContent: moodContent,
          tts: tts,
        ),
      );

      await tester.tap(find.byKey(const Key('wr_mood_audio_play')));
      await tester.pumpAndSettle();

      expect(tts.calls, 1);
      expect(find.textContaining('A paid plan is required'), findsOneWidget);
    }, skip: !kAiVoiceEnabled);
  });

  // -------------------------------------------------------------------------
  group('chat dùng entitlement thật, không dùng override đã lưu', () {
    // Override cũ có thể còn trong SharedPreferences sau khi control bị gỡ.
    // Chat production không được gửi cờ đó; máy chủ phải trả entitlement thật.

    testWidgets('override true không biến gói thật thành Premium', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'wr_dev_premium_override': true,
        'wr_dev_premium_override_owner': 'thedangs7@gmail.com',
      });
      final chat = FakeWrChatRepository()..isPremium = false;

      await _pump(
        tester,
        _wrap(const WrAskScreen(), chat: chat, email: 'thedangs7@gmail.com'),
      );
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'chào');
      // Nút gửi chỉ bật khi ô đã có chữ, nên phải để khung dựng lại trước khi bấm.
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(chat.sendCalls.single.premiumOverride, isNull);
      expect(find.byKey(const Key('wr_chat_quota_hint')), findsOneWidget);
    });

    testWidgets('override false không thu hồi gói Premium thật', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'wr_dev_premium_override': false,
        'wr_dev_premium_override_owner': 'thedangs7@gmail.com',
      });
      final chat = FakeWrChatRepository()..isPremium = true;

      await _pump(
        tester,
        _wrap(const WrAskScreen(), chat: chat, email: 'thedangs7@gmail.com'),
      );
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'chào');
      // Nút gửi chỉ bật khi ô đã có chữ, nên phải để khung dựng lại trước khi bấm.
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(chat.sendCalls.single.premiumOverride, isNull);
      expect(find.byKey(const Key('wr_chat_quota_hint')), findsNothing);
    });

    testWidgets('chưa động vào công tắc thì dùng gói thật', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final chat = FakeWrChatRepository();

      await _pump(
        tester,
        _wrap(const WrAskScreen(), chat: chat, email: 'thedangs7@gmail.com'),
      );
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'chào');
      // Nút gửi chỉ bật khi ô đã có chữ, nên phải để khung dựng lại trước khi bấm.
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(chat.sendCalls.single.premiumOverride, isNull);
    });
  });
}

/// Mọi ảnh trên màn trừ dải ảnh đầu màn (ảnh asset của app). Thứ bị cấm là
/// ảnh nội dung: ảnh workshop của web, ảnh tải qua mạng.
final _contentImages = find.byWidgetPredicate(
  (w) => w is Image && w.image is! AssetImage,
);
