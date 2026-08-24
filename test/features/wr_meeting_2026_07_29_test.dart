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
import 'package:workreflection_mobile/core/widgets/wr_card.dart';
import 'package:workreflection_mobile/features/shell/shell_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_ask_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_themes_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_mood_reader_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_tra_chieu_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_workshop_repository.dart';
import '../support/fake_wr_chat_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';

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
}) =>
    WorkshopDetail(
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
      wrContentRepositoryProvider
          .overrideWithValue(content ?? FakeWrContentRepository()),
      wrIntelligenceRepositoryProvider
          .overrideWithValue(intel ?? FakeWrIntelligenceRepository()),
      wrMoodContentRepositoryProvider
          .overrideWithValue(moodContent ?? FakeWrMoodContentRepository()),
      wrEpisodeRepositoryProvider
          .overrideWithValue(episodes ?? FakeWrEpisodeRepository()),
      workshopRepositoryProvider
          .overrideWithValue(workshops ?? FakeWorkshopRepository()),
      wrChatRepositoryProvider
          .overrideWithValue(chat ?? FakeWrChatRepository()),
      sttServiceProvider
          .overrideWithValue(_FakeStt(available: sttAvailable)),
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
    FakeWrContentRepository contentWithSituation() => FakeWrContentRepository()
      ..seedSituations(const [
        WrSituation(
          code: 's1',
          text: 'Ngại phản biện với đồng nghiệp',
          scaDimension: ScaDimension.c2,
          wave: 1,
        ),
      ]);

    FakeWrEpisodeRepository episodesWithPattern() => FakeWrEpisodeRepository()
      ..seed([
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

    testWidgets('chưa check-in: không có Hệ thống nhận ra, không có Gợi ý',
        (tester) async {
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
      expect(find.text('Ngày hôm nay của bạn như thế nào?'), findsOneWidget);
    });

    testWidgets('đã check-in: cả hai khối hiện ra', (tester) async {
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

      expect(find.byKey(const Key('wr_home_system_notice')), findsOneWidget);
      expect(find.byKey(const Key('wr_home_mood_content')), findsOneWidget);
    });

    testWidgets('thứ tự dọc đúng mockup: check-in → nhận ra → gợi ý → '
        'Insight → Tiếp tục', (tester) async {
      // Thứ tự lấy từ `screenHome()` của mockup Sprint 2. Hai khối "sau
      // check-in" chèn vào GIỮA, không đẩy check-in hay Insight đi đâu cả.
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
        ..seedEnrollments([
          const PracticeEnrollment(userId: 'u1', themeId: 't1'),
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

      final checkin =
          tester.getTopLeft(find.text('Ngày hôm nay của bạn như thế nào?')).dy;
      expect(checkin, lessThan(top('wr_home_system_notice')));
      expect(
        top('wr_home_system_notice'),
        lessThan(top('wr_home_mood_content')),
      );
      expect(
        top('wr_home_mood_content'),
        lessThan(top('wr_home_latest_insight')),
      );
      expect(
        top('wr_home_latest_insight'),
        lessThan(top('wr_home_continue_today')),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Home — Tiếp tục hôm nay', () {
    FakeWrIntelligenceRepository withPractice({
      List<String> completed = const [],
      bool premiumStep = false,
    }) =>
        FakeWrIntelligenceRepository()
          ..seedPracticeThemes([
            const PracticeTheme(themeId: 't1', title: 'Dám lên tiếng'),
          ])
          ..seedPracticeSteps('t1', [
            PracticeStep(
              stepId: 's1',
              themeId: 't1',
              stepOrder: 1,
              title: 'Quan sát lúc muốn im lặng',
              isPremium: premiumStep,
            ),
          ])
          ..seedEnrollments([
            PracticeEnrollment(
              userId: 'u1',
              themeId: 't1',
              completedSteps: completed,
            ),
          ]);

    testWidgets('hiện bước còn dở, kể cả khi chưa check-in', (tester) async {
      await _pump(
        tester,
        _wrap(const WrHomeScreen(), intel: withPractice()),
      );

      expect(find.byKey(const Key('wr_home_continue_today')), findsOneWidget);
      // Khuôn câu của mockup Sprint 2: Home nhắc GIAI ĐOẠN đang dở, tên việc cụ
      // thể để dành cho màn chủ đề.
      expect(
        find.text('"Dám lên tiếng": bước Nhận diện đang chờ'),
        findsOneWidget,
      );
    });

    testWidgets('chạm mở đúng màn chủ đề', (tester) async {
      await _pump(
        tester,
        _wrap(const WrHomeScreen(), intel: withPractice()),
      );

      await tester.tap(find.byKey(const Key('wr_home_continue_today_card')));
      await tester.pumpAndSettle();

      expect(find.text('THEME t1'), findsOneWidget);
    });

    // Khách 2026-07-30: "section Tiếp tục hôm nay đâu sao tôi không thấy".
    //
    // Ba trường hợp dưới đây trước kia làm khối biến mất. Ghi danh chủ đề chỉ
    // xảy ra khi người dùng tự vào tab Phát triển chọn — luồng phản tư không tự
    // ghi danh — nên với người dùng thật khối im lặng vĩnh viễn và Home mất hẳn
    // sợi dây nối sang Phát triển. Giờ khối vẫn đứng đó, đổi lời thành mời chọn
    // chủ đề.
    testWidgets('xong hết bước thì mời chọn chủ đề khác, không biến mất',
        (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrHomeScreen(),
          intel: withPractice(completed: ['s1']),
        ),
      );

      expect(find.byKey(const Key('wr_home_continue_today')), findsOneWidget);
      expect(find.textContaining('Chọn một chủ đề'), findsOneWidget);
    });

    testWidgets('bước bị khoá Premium không được mời tiếp tục', (tester) async {
      // Mời "tiếp tục" một bước không mở được là dẫn thẳng vào paywall từ màn
      // Home, đúng chỗ khách muốn giữ tối giản nhất. Khối vẫn còn, nhưng lời mời
      // là chọn chủ đề chứ không phải bước đang khoá.
      await _pump(
        tester,
        _wrap(
          const WrHomeScreen(),
          intel: withPractice(premiumStep: true),
        ),
      );

      expect(find.byKey(const Key('wr_home_continue_today')), findsOneWidget);
      expect(find.textContaining('Chọn một chủ đề'), findsOneWidget);
      expect(find.textContaining('Dám lên tiếng'), findsNothing);
    });

    testWidgets('chưa ghi danh chủ đề nào thì mời chọn, dẫn sang Phát triển',
        (tester) async {
      await _pump(tester, _wrap(const WrHomeScreen()));

      expect(find.byKey(const Key('wr_home_continue_today')), findsOneWidget);
      expect(find.textContaining('Chọn một chủ đề'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_home_continue_today_card')));
      await tester.pumpAndSettle();

      expect(find.text('THEMES'), findsOneWidget);
    });

    // Lỗi owner báo 2026-07-30, kèm ảnh tab Phát triển với 3 chủ đề đang theo:
    // Home vẫn không hiện "Tiếp tục hôm nay".
    //
    // Gốc: provider chỉ soi ĐÚNG MỘT ghi danh — cái đầu danh sách — rồi bỏ cuộc
    // nếu chủ đề đó hết bước mở được. Hai chủ đề đầu của owner đã xong 2/3 và
    // bước thứ ba là bước Premium (owner đang dùng bản free), nên nó bỏ cuộc
    // ngay, dù chủ đề thứ ba mới 0/3 với bước đầu mở thoải mái.
    testWidgets('chủ đề đầu bí vì bước Premium thì lấy chủ đề khác còn mở được',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([
          const PracticeTheme(themeId: 't1', title: 'Nhịp làm việc ổn định'),
          const PracticeTheme(themeId: 't2', title: 'Dám lên tiếng'),
          const PracticeTheme(themeId: 't3', title: 'Phản hồi hiệu quả'),
        ]);
      for (final id in ['t1', 't2', 't3']) {
        intel.seedPracticeSteps(id, [
          PracticeStep(
            stepId: '$id-s1',
            themeId: id,
            stepOrder: 1,
            title: 'Nhận diện',
            isPremium: false,
          ),
          PracticeStep(
            stepId: '$id-s2',
            themeId: id,
            stepOrder: 2,
            title: 'Thử nghiệm',
            isPremium: false,
          ),
          // Bước Chuyển hoá là bước trả tiền.
          PracticeStep(
            stepId: '$id-s3',
            themeId: id,
            stepOrder: 3,
            title: 'Chuyển hoá',
            isPremium: true,
          ),
        ]);
      }
      intel.seedEnrollments([
        PracticeEnrollment(
          userId: 'u1',
          themeId: 't1',
          startedAt: DateTime(2026, 7, 20),
          completedSteps: const ['t1-s1', 't1-s2'],
        ),
        PracticeEnrollment(
          userId: 'u1',
          themeId: 't2',
          startedAt: DateTime(2026, 7, 22),
          completedSteps: const ['t2-s1', 't2-s2'],
        ),
        PracticeEnrollment(
          userId: 'u1',
          themeId: 't3',
          startedAt: DateTime(2026, 7, 28),
        ),
      ]);

      await _pump(tester, _wrap(const WrHomeScreen(), intel: intel));

      expect(find.byKey(const Key('wr_home_continue_today')), findsOneWidget);
      expect(
        find.text('"Phản hồi hiệu quả": bước Nhận diện đang chờ'),
        findsOneWidget,
      );

      // Và chạm vào mở đúng chủ đề ĐÓ, không phải chủ đề đầu danh sách.
      await tester.tap(find.byKey(const Key('wr_home_continue_today_card')));
      await tester.pumpAndSettle();
      expect(find.text('THEME t3'), findsOneWidget);
    });

    testWidgets('nhiều chủ đề mở được thì lấy chủ đề gần đích nhất',
        (tester) async {
      // "Tiếp tục" phải là tiếp tục việc dở dang nhất, không phải việc mới nhất.
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([
          const PracticeTheme(themeId: 't1', title: 'Mới bắt đầu'),
          const PracticeTheme(themeId: 't2', title: 'Gần xong'),
        ]);
      for (final id in ['t1', 't2']) {
        intel.seedPracticeSteps(id, [
          PracticeStep(
            stepId: '$id-s1',
            themeId: id,
            stepOrder: 1,
            title: 'Nhận diện',
            isPremium: false,
          ),
          PracticeStep(
            stepId: '$id-s2',
            themeId: id,
            stepOrder: 2,
            title: 'Thử nghiệm',
            isPremium: false,
          ),
        ]);
      }
      intel.seedEnrollments([
        PracticeEnrollment(
          userId: 'u1',
          themeId: 't1',
          startedAt: DateTime(2026, 7, 20),
        ),
        PracticeEnrollment(
          userId: 'u1',
          themeId: 't2',
          startedAt: DateTime(2026, 7, 28),
          completedSteps: const ['t2-s1'],
        ),
      ]);

      await _pump(tester, _wrap(const WrHomeScreen(), intel: intel));

      expect(
        find.text('"Gần xong": bước Thử nghiệm đang chờ'),
        findsOneWidget,
      );
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
            description: 'Một buổi cho những người đang thấy mình bận nhưng '
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

    testWidgets('chưa cấu hình link Zalo thì không dựng nút Zalo', (
      tester,
    ) async {
      // `TRA_CHIEU_ZALO_URL` để trống trong test và trong bản build hiện tại.
      final workshops = FakeWorkshopRepository()..seedWorkshops([_traChieu()]);

      await _pump(
        tester,
        _wrap(const WrTraChieuScreen(), workshops: workshops),
      );

      expect(kTraChieuZaloUrl, isEmpty);
      expect(
        find.byKey(const Key('wr_tra_chieu_zalo_button')),
        findsNothing,
      );
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

      expect(find.byType(Image), findsNothing);
      expect(find.byType(NetworkImage), findsNothing);
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

    testWidgets('chưa mở buổi nào thì nói thẳng, không dựng thẻ rỗng', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrTraChieuScreen()));

      expect(find.byKey(const Key('wr_tra_chieu_empty')), findsOneWidget);
      expect(find.byKey(const Key('wr_tra_chieu_next')), findsNothing);
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

      expect(find.byKey(const Key('wr_tra_chieu_empty')), findsOneWidget);
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
      expect(find.byType(Image), findsNothing);
    });

    // Khách 2026-07-30: "để chạm vào là chuyển như vậy dễ chạm nhầm lắm, chỉ
    // vuốt lên thôi mà vô tình chạm cũng bất tiện". Rời khỏi app phải là việc
    // người dùng chủ ý làm, không phải hệ quả của một cú vuốt trượt tay.
    testWidgets('mỗi buổi có nút riêng, chạm vào thẻ thì không đi đâu cả',
        (tester) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([_traChieu(id: 'w1', title: 'Buổi A')]);

      await _pump(
        tester,
        _wrap(const WrTraChieuCalendarScreen(), workshops: workshops),
      );

      expect(
        find.byKey(const Key('wr_tra_chieu_session_button_w1')),
        findsOneWidget,
      );
      // Thẻ là thẻ thuần, không phải một vùng bắt chạm bọc quanh nội dung.
      expect(
        tester.widget(find.byKey(const Key('wr_tra_chieu_session_w1'))),
        isA<WrCardMinimal>(),
      );
    });

    testWidgets('thẻ buổi nói đủ tên, mô tả, giờ, địa điểm và giá',
        (tester) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([
          _traChieu(
            id: 'w1',
            title: 'Buổi A',
            description: 'Một câu hỏi duy nhất cho cả bàn.',
            location: '123 Trường Sơn',
            date: DateTime(2026, 9, 3),
          ),
        ]);

      await _pump(
        tester,
        _wrap(const WrTraChieuCalendarScreen(), workshops: workshops),
      );

      expect(find.text('"Buổi A"'), findsOneWidget);
      expect(find.text('Một câu hỏi duy nhất cho cả bàn.'), findsOneWidget);
      expect(find.text('T5 03/09'), findsOneWidget);
      expect(find.text('123 Trường Sơn'), findsOneWidget);
      expect(find.text('Giữ chỗ 99.000đ'), findsOneWidget);
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

      expect(
        chat.sendCalls.map((c) => c.message),
        ['Tôi vừa im lặng trong một cuộc họp.'],
      );
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
      expect(find.text('Còn 9 lượt trò chuyện miễn phí hôm nay.'), findsOneWidget);
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

    testWidgets('mở màn là vào thẳng cuộc gần nhất, đúng thứ tự', (tester) async {
      // Vào thẳng cuộc đang dở chứ không bắt qua màn chọn: phần lớn lần mở là
      // để nói tiếp chuyện dở dang.
      final chat = FakeWrChatRepository()
        ..seedConversation(
          'cũ',
          const [WrChatMessage(role: WrChatRole.user, content: 'Chuyện tháng trước')],
          lastMessageAt: DateTime(2026, 7, 1),
        )
        ..seedConversation(
          'mới',
          const [
            WrChatMessage(role: WrChatRole.user, content: 'Câu hỏi hôm qua'),
            WrChatMessage(
              role: WrChatRole.assistant,
              content: 'Câu trả lời hôm qua',
            ),
          ],
          lastMessageAt: DateTime(2026, 8, 2),
        );

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
        ..seedConversation(
          'c-cũ',
          const [WrChatMessage(role: WrChatRole.user, content: 'Câu cũ')],
        );

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

    testWidgets('trợ lý mời ghi Reflection thì có nút mở luồng', (tester) async {
      // Mục 5: trợ lý MỜI vào Reflection. Trước 2026-08-03 nó nói được câu mời
      // nhưng không có đường đi tới, nên lời mời rơi vào khoảng không.
      final chat = FakeWrChatRepository()
        ..replyText = 'Muốn ghi lại thành một Reflection không?'
        ..replyAction = WrChatAction.reflect;

      await _pump(tester, _wrap(const WrAskScreen(), chat: chat));
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Mình im lặng');
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
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'Mình mệt quá');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
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
        ..seedConversation(
          'c-xoá',
          const [WrChatMessage(role: WrChatRole.user, content: 'Câu cũ')],
        );

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

      expect(find.text('Câu đã trả lời'), findsOneWidget);
      expect(find.text('Đây là câu trả lời.'), findsOneWidget);
      expect(find.text('Câu chưa trả lời'), findsOneWidget);
      expect(find.text(kAskPendingMessage), findsOneWidget);
    });

    testWidgets('có nút mic khi máy nhận dạng được giọng nói', (tester) async {
      await _pump(
        tester,
        _wrap(const WrAskScreen(), sttAvailable: true),
      );

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
        FakeWrIntelligenceRepository()
          ..seedPracticeThemes([
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
  group('Phát triển — thẻ Trà Chiều thay dòng Thực hành khác', () {
    testWidgets('không còn dòng Thực hành khác', (tester) async {
      await _pump(tester, _wrap(const WrGrowthScreen()));

      expect(find.text('Thực hành khác'), findsNothing);
      expect(
        find.byKey(const Key('wr_growth_other_themes_row')),
        findsNothing,
      );
      // Lối rẽ còn lại không bị đụng tới. "Chặng đường phát triển" đã bỏ khỏi
      // màn này (2026-08-03).
      // Đổi tên theo Ma trận Cấp bậc v1.0 mục A.1: giữ chữ "kỹ năng", bỏ chữ
      // "hình thành" ở tên gọi chính.
      expect(find.text('Kỹ năng của bạn'), findsOneWidget);
      expect(find.text('Chặng đường phát triển'), findsNothing);
    });

    testWidgets('thẻ nói pill, chủ đề buổi, khuôn buổi và Xem chi tiết',
        (tester) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([
          _traChieu(date: DateTime.now().add(const Duration(days: 9))),
        ]);

      await _pump(
        tester,
        _wrap(const WrGrowthScreen(), workshops: workshops),
      );

      final card = find.byKey(const Key('wr_growth_opportunity'));
      expect(card, findsOneWidget);
      expect(find.text('Offline · $kTraChieuLabel'), findsOneWidget);
      expect(
        find.text('"Bận cả tuần, nhưng mình đang đi về đâu?"'),
        findsOneWidget,
      );
      expect(
        find.textContaining(kTraChieuFormatLabel),
        findsOneWidget,
      );
      expect(find.text('Xem chi tiết'), findsOneWidget);
      // Chữ, không ảnh — nguyên tắc của họp 2026-07-29 vẫn giữ.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('chạm thẻ mở màn Trà Chiều', (tester) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([_traChieu()]);

      await _pump(
        tester,
        _wrap(const WrGrowthScreen(), workshops: workshops),
      );
      await tester.tap(find.byKey(const Key('wr_growth_opportunity')));
      await tester.pumpAndSettle();

      expect(find.text('Ba luật của mọi buổi'), findsOneWidget);
    });

    // Khách 2026-07-30: "tôi không còn thấy cái mục giao diện trà chiều đâu
    // cả" — DB của khách chưa có buổi nào mang category Trà Chiều, và bản trước
    // ẩn cả thẻ khi lịch trống. Lịch trống không có nghĩa là không có chương
    // trình: cửa vào phải còn, chỉ đổi lời.
    testWidgets('chưa mở buổi nào thì thẻ vẫn còn, chỉ đổi lời', (tester) async {
      await _pump(tester, _wrap(const WrGrowthScreen()));

      expect(find.byKey(const Key('wr_growth_opportunity')), findsOneWidget);
      expect(find.text('Offline · $kTraChieuLabel'), findsOneWidget);
      expect(find.text('Chưa có buổi nào được mở.'), findsOneWidget);
      expect(find.text(kTraChieuFormatLabel), findsOneWidget);
      expect(find.text('Xem chi tiết'), findsOneWidget);
    });

    testWidgets('lịch trống vẫn chạm được vào màn Trà Chiều', (tester) async {
      await _pump(tester, _wrap(const WrGrowthScreen()));
      await tester.tap(find.byKey(const Key('wr_growth_opportunity')));
      await tester.pumpAndSettle();

      expect(find.text('Ba luật của mọi buổi'), findsOneWidget);
      expect(find.byKey(const Key('wr_tra_chieu_empty')), findsOneWidget);
    });

    testWidgets('buổi đã diễn ra rồi thì không mượn lại làm buổi sắp tới',
        (tester) async {
      final workshops = FakeWorkshopRepository()
        ..seedWorkshops([
          _traChieu(
            title: 'Buổi tháng trước',
            date: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ]);

      await _pump(
        tester,
        _wrap(const WrGrowthScreen(), workshops: workshops),
      );

      expect(find.textContaining('Buổi tháng trước'), findsNothing);
      expect(find.text('Chưa có buổi nào được mở.'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('Màn đọc — header ghim và audio', () {
    FakeWrMoodContentRepository libraryWith(MoodContent item) =>
        FakeWrMoodContentRepository()..seedContent([item]);

    testWidgets('header ghim lại khi cuộn nội dung', (tester) async {
      final moodContent = libraryWith(fakeMoodContent(
        id: 'm1',
        mood: Mood.okay,
        title: 'Khi áp lực đến từ việc muốn kiểm soát mọi thứ',
        body: List.generate(12, (i) => 'Đoạn số $i.').join('\n\n'),
      ));

      await _pump(
        tester,
        _wrap(
          const WrMoodReaderScreen(contentId: 'm1'),
          moodContent: moodContent,
        ),
      );

      expect(find.byKey(const Key('wr_mood_reader_header')), findsOneWidget);
      expect(find.byType(SliverAppBar), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pumpAndSettle();

      // Cuộn xa rồi mà thanh tiêu đề vẫn còn: đúng yêu cầu "chỉ đẩy nội dung
      // lên thôi và giữ lại header".
      expect(find.byKey(const Key('wr_mood_reader_header')), findsOneWidget);
      expect(
        find.text('Khi áp lực đến từ việc muốn kiểm soát mọi thứ'),
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

    testWidgets('audio chưa có bản thu thì mời nghe bằng giọng đọc AI', (
      tester,
    ) async {
      final moodContent = libraryWith(fakeMoodContent(
        id: 'm1',
        mood: Mood.stressed,
        type: MoodContentType.audio,
        kind: 'HEALING AUDIO',
      ));

      await _pump(
        tester,
        _wrap(
          const WrMoodReaderScreen(contentId: 'm1'),
          moodContent: moodContent,
        ),
      );

      expect(find.byKey(const Key('wr_mood_audio_player')), findsOneWidget);
      expect(find.text('Nghe bằng giọng đọc AI'), findsOneWidget);
    });

    testWidgets('đã có bản thu thì không gọi TTS', (tester) async {
      // Gọi lại TTS cho một bài đã dựng là đốt credit của khách cho cùng một
      // đoạn chữ không đổi.
      final tts = _FakeTts(url: 'https://cdn.test/x.wav');
      final moodContent = libraryWith(fakeMoodContent(
        id: 'm1',
        mood: Mood.stressed,
        type: MoodContentType.audio,
        duration: '3 phút',
        audioUrl: 'https://cdn.test/co-san.wav',
      ));

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
      final tts = _FakeTts(
        error: const TtsException(
          'Giọng đọc AI chưa dùng được: A paid plan is required.',
        ),
      );
      final moodContent = libraryWith(fakeMoodContent(
        id: 'm1',
        mood: Mood.stressed,
        type: MoodContentType.audio,
      ));

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
      expect(
        find.textContaining('A paid plan is required'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('công tắc Premium thử nghiệm áp cho cả trợ lý', () {
    // Bản đầu chatbox CỐ Ý bỏ qua công tắc, vì công tắc nằm trên máy nên không
    // được phép mở hạn mức tiêu tiền thật. Đúng về bảo mật, sai về hậu quả: mọi
    // màn khác đổi theo công tắc còn riêng trợ lý thì không, nên bật Premium lên
    // xem thử lại tưởng ranh giới hai gói bị hỏng.
    //
    // Máy chủ tự kiểm tra email của người gọi nên gửi cờ lên là an toàn. Phần
    // dưới khoá đúng phía app: gửi khi được phép, và KHÔNG gửi khi không.

    testWidgets('email được phép: lượt gửi mang theo cờ', (tester) async {
      // Hai key: giá trị và CHỦ công tắc. Thiếu chủ thì công tắc bị bỏ — xem
      // `overrideForAccount`.
      SharedPreferences.setMockInitialValues({
        'wr_dev_premium_override': true,
        'wr_dev_premium_override_owner': 'thedangs7@gmail.com',
      });
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

      expect(chat.sendCalls.single.premiumOverride, isTrue);
    });

    testWidgets('email KHÔNG được phép: cờ bị bỏ qua', (tester) async {
      // Một giá trị sót lại trong SharedPreferences không được phép đổi giọng
      // trợ lý của người dùng thường.
      SharedPreferences.setMockInitialValues({'wr_dev_premium_override': true});
      final chat = FakeWrChatRepository();

      await _pump(
        tester,
        _wrap(const WrAskScreen(), chat: chat, email: 'nguoila@example.com'),
      );
      await tester.enterText(find.byKey(const Key('wr_ask_field')), 'chào');
      // Nút gửi chỉ bật khi ô đã có chữ, nên phải để khung dựng lại trước khi bấm.
      await tester.pump();
      await tester.tap(find.byKey(const Key('wr_ask_send')));
      await tester.pumpAndSettle();

      expect(chat.sendCalls.single.premiumOverride, isNull);
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
