// Script Sprint 2 — "Đang duy trì" ở tab Phát triển và màn Tâm thế & duy trì,
// thẻ Mở rộng (YouTube, Trà Chiều) lấy dữ liệu thật.
//
// Run: flutter test test/features/wr_growth_keep_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_learning_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_career_memory_rules.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_learning_resource.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_stance_keep_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_tra_chieu_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_workshop_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

class _FakeLearning implements WrLearningRepository {
  _FakeLearning(this.items);

  final List<LearningResource> items;

  @override
  Future<List<LearningResource>> fetchActive() async => items;
}

Widget _wrap(
  Widget home, {
  required FakeWrIntelligenceRepository intel,
  FakeWrContentRepository? content,
  FakeWorkshopRepository? workshops,
  List<LearningResource> videos = const [],
}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => home),
      for (final p in [
        '/wr/growth/stance-keep',
        '/wr/tra-chieu',
        '/wr/learning-library',
        '/wr/learning-library/:id',
        '/wr/growth/theme/:id',
        '/wr/paywall',
        '/profile',
      ])
        GoRoute(
          path: p,
          builder: (_, s) => Scaffold(body: Text('ROUTE ${s.uri.path}')),
        ),
    ],
  );
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      wrContentRepositoryProvider.overrideWithValue(
        content ?? FakeWrContentRepository(),
      ),
      wrEpisodeRepositoryProvider.overrideWithValue(FakeWrEpisodeRepository()),
      workshopRepositoryProvider.overrideWithValue(
        workshops ?? FakeWorkshopRepository(),
      ),
      wrLearningRepositoryProvider.overrideWithValue(_FakeLearning(videos)),
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

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

FakeWrIntelligenceRepository _kept({
  List<String> themeIds = const ['pt-c2'],
  bool keptAll = true,
}) {
  final intel = FakeWrIntelligenceRepository()
    ..seedPracticeThemes(const [
      PracticeTheme(themeId: 'pt-c2', title: 'Dám lên tiếng'),
      PracticeTheme(themeId: 'pt-c1', title: 'Tin và được tin'),
      PracticeTheme(themeId: 'pt-s1', title: 'Rõ ràng về điều được kỳ vọng'),
      PracticeTheme(themeId: 'pt-s2', title: 'Ưu tiên đúng việc của mình'),
    ]);
  intel.seedEnrollments([
    for (var i = 0; i < themeIds.length; i++)
      PracticeEnrollment(
        userId: 'u1',
        themeId: themeIds[i],
        completedSteps: const [],
        completedAt: keptAll
            ? DateTime.now().subtract(Duration(days: 3 + i))
            : null,
      ),
  ]);
  return intel;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Tab Phát triển — Đang duy trì', () {
    // Máy thật 13/10: chủ đề xong đủ bốn bước nhưng chưa bấm "Đưa vào phần
    // duy trì" vẫn ghi "Bước 4 / 4", người dùng tưởng app không chuyển.
    testWidgets('xong đủ bước, chưa đưa vào duy trì: dòng mời "Hết một vòng"', (
      tester,
    ) async {
      PracticeStep step(int n) => PracticeStep(
        stepId: 'pt-s3-$n',
        themeId: 'pt-s3',
        stepOrder: n,
        title: 'Bước $n',
        isPremium: false,
      );
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(const [
          PracticeTheme(
            themeId: 'pt-s3',
            title: 'Vững vàng khi mọi thứ thay đổi',
          ),
          PracticeTheme(themeId: 'pt-s2', title: 'Ưu tiên đúng việc của mình'),
        ])
        ..seedPracticeSteps('pt-s3', [for (var n = 1; n <= 4; n++) step(n)])
        ..seedPracticeSteps('pt-s2', [
          for (var n = 1; n <= 4; n++)
            PracticeStep(
              stepId: 'pt-s2-$n',
              themeId: 'pt-s2',
              stepOrder: n,
              title: 'Bước $n',
              isPremium: false,
            ),
        ])
        ..seedEnrollments(const [
          PracticeEnrollment(
            userId: 'u1',
            themeId: 'pt-s3',
            completedSteps: ['pt-s3-1', 'pt-s3-2', 'pt-s3-3', 'pt-s3-4'],
          ),
          PracticeEnrollment(
            userId: 'u1',
            themeId: 'pt-s2',
            completedSteps: ['pt-s2-1'],
          ),
        ]);

      await _pump(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(
        find.byKey(const Key('wr_growth_theme_round_done_pt-s3')),
        findsOneWidget,
      );
      expect(
        find.text('Hết một vòng · Đưa vào phần duy trì ›'),
        findsOneWidget,
      );
      // Chủ đề đang dở vẫn ghi bước đang làm.
      expect(
        find.byKey(const Key('wr_growth_theme_round_done_pt-s2')),
        findsNothing,
      );
      expect(find.text('Bước 2 / 4'), findsOneWidget);
      // Chưa bấm thì chưa nằm ở "Đang duy trì".
      expect(find.byKey(const Key('wr_keep_row_pt-s3')), findsNothing);

      await tester.tap(find.byKey(const Key('wr_growth_theme_row_pt-s3')));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /wr/growth/theme/pt-s3'), findsOneWidget);
    });

    testWidgets('chưa có chủ đề nào được đưa vào duy trì thì ẩn cả khối', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(const WrGrowthScreen(), intel: _kept(keptAll: false)),
      );

      expect(find.byKey(const Key('wr_growth_keeping')), findsNothing);
      // Không còn dữ liệu mẫu của script.
      expect(find.text('Thoát khỏi vòng lặp phản ứng'), findsNothing);
      expect(find.text('Giữ năng lượng đường dài'), findsNothing);
      expect(find.textContaining('12 lần'), findsNothing);
    });

    testWidgets('chỉ chủ đề thật đã đưa vào duy trì, số lần và ngày thật', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrGrowthScreen(), intel: _kept()));

      final row = find.byKey(const Key('wr_keep_row_pt-c2'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(
          of: row,
          matching: find.text('1 lần · gần nhất 3 ngày trước'),
        ),
        findsOneWidget,
      );
      expect(find.text('Rõ ràng về điều được kỳ vọng'), findsNothing);
    });

    testWidgets('Ghi nhận: một lần một ngày, không huỷ, ghi Career Memory', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      await _pump(
        tester,
        _wrap(const WrGrowthScreen(), intel: _kept(), content: content),
      );

      final mark = find.byKey(const Key('wr_keep_mark_pt-c2'));
      expect(
        find.descendant(of: mark, matching: find.text('Ghi nhận')),
        findsOneWidget,
      );
      await tester.tap(mark);
      await tester.pumpAndSettle();

      final logged = content.insertMemoryEventCalls
          .where((e) => e.behavior == kPracticeMaintainedBehavior)
          .toList();
      expect(logged, hasLength(1));
      expect(logged.single.themeId, 'pt-c2');
      expect(logged.single.reflectionText, 'Duy trì: Dám lên tiếng');
      expect(
        find.descendant(of: mark, matching: find.text('✓ Đã ghi')),
        findsOneWidget,
      );
      expect(find.text('2 lần · gần nhất hôm nay'), findsOneWidget);

      // Bấm lại trong ngày: không huỷ, không cộng thêm.
      await tester.tap(mark);
      await tester.pumpAndSettle();
      expect(
        content.insertMemoryEventCalls.where(
          (e) => e.behavior == kPracticeMaintainedBehavior,
        ),
        hasLength(1),
      );
      expect(
        find.descendant(of: mark, matching: find.text('✓ Đã ghi')),
        findsOneWidget,
      );
    });

    testWidgets('quá ba chủ đề thì "Còn n chủ đề khác" dẫn sang màn đầy đủ', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          const WrGrowthScreen(),
          intel: _kept(themeIds: const ['pt-c2', 'pt-c1', 'pt-s1', 'pt-s2']),
        ),
      );

      expect(find.text('Còn 1 chủ đề khác'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_growth_keep_all')));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /wr/growth/stance-keep'), findsOneWidget);
    });
  });

  group('Tab Phát triển — Mở rộng', () {
    // Người dùng 13/10: Mở rộng giữ đúng bản đã duyệt — hai thẻ cố định
    // "Chuỗi Series Tâm thế người đi làm" và "Trà chiều nghề nghiệp", luôn
    // hiện kể cả khi chưa có video hay buổi nào (khách 30/07).
    testWidgets('hai thẻ cố định, hiện cả khi chưa có dữ liệu', (tester) async {
      await _pump(tester, _wrap(const WrGrowthScreen(), intel: _kept()));

      final series = find.byKey(const Key('wr_growth_youtube_card'));
      final tea = find.byKey(const Key('wr_growth_tra_chieu_card'));
      await tester.scrollUntilVisible(tea, 200);
      for (final t in [
        'YOUTUBE',
        'SERIES CHIA SẺ',
        'Chuỗi Series Tâm thế người đi làm',
      ]) {
        expect(
          find.descendant(of: series, matching: find.text(t)),
          findsOneWidget,
          reason: t,
        );
      }
      for (final t in [
        'OFFLINE · TRÀ CHIỀU',
        'Trà chiều nghề nghiệp',
        '10 đến 12 người · 2 giờ · một câu hỏi',
      ]) {
        expect(
          find.descendant(of: tea, matching: find.text(t)),
          findsOneWidget,
          reason: t,
        );
      }
      expect(find.textContaining('Tập 7'), findsNothing);
    });

    testWidgets('chạm thẻ Series mở Thư viện học tập', (tester) async {
      await _pump(tester, _wrap(const WrGrowthScreen(), intel: _kept()));

      final series = find.byKey(const Key('wr_growth_youtube_card'));
      await tester.scrollUntilVisible(series, 200);
      await tester.tap(series);
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /wr/learning-library'), findsOneWidget);
    });
  });

  group('Màn Tâm thế & duy trì', () {
    testWidgets('còn ít dữ liệu thì không có câu mẫu, nói rõ là còn trống', (
      tester,
    ) async {
      await _pump(tester, _wrap(const WrStanceKeepScreen(), intel: _kept()));

      expect(find.byKey(const Key('wr_stance_low_data')), findsOneWidget);
      expect(find.textContaining('chuyện chờ'), findsNothing);
      expect(find.byKey(const Key('wr_stance_yes')), findsNothing);
    });

    FakeWrContentRepository enoughData() =>
        FakeWrContentRepository()..seedMemoryEvents([
          for (final (i, id) in const ['pt-c2', 'pt-c2', 'pt-c1'].indexed)
            CareerMemoryEvent(
              id: 'e$i',
              userId: 'u1',
              behavior: kPracticeStepBehavior,
              themeId: id,
              createdAt: DateTime(2026, 10, 1 + i),
            ),
        ]);

    FakeWrIntelligenceRepository withNotes() {
      final intel = _kept();
      intel.upsertPracticeStepNote(
        PracticeStepNote(
          userId: 'u1',
          stepId: 'pt-c2-1',
          note: 'Mình gần như không nói gì.',
          createdAt: DateTime(2026, 10, 1),
        ),
      );
      intel.upsertPracticeStepNote(
        PracticeStepNote(
          userId: 'u1',
          stepId: 'pt-c1-1',
          note: 'Hôm nay mình hỏi lại một câu.',
          createdAt: DateTime(2026, 10, 3),
        ),
      );
      return intel;
    }

    testWidgets('Đúng với tôi ghi một Cột mốc vào Career Memory', (
      tester,
    ) async {
      final content = enoughData();
      await _pump(
        tester,
        _wrap(const WrStanceKeepScreen(), intel: withNotes(), content: content),
      );

      expect(find.byKey(const Key('wr_stance_observation')), findsOneWidget);
      expect(
        find.textContaining('“Hôm nay mình hỏi lại một câu”'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('wr_stance_yes')));
      await tester.pumpAndSettle();

      final milestone = content.insertMemoryEventCalls.single;
      expect(milestone.behavior, kMilestoneBehavior);
      expect(
        milestone.reflectionText,
        'Bạn xác nhận một tâm thế đang hình thành',
      );
      expect(find.text('✓ Bạn thấy điều này đúng'), findsOneWidget);
    });

    testWidgets('tự gọi tên: Ghi lại ghi Cột mốc; Chưa gọi tên được thì dừng', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      await _pump(
        tester,
        _wrap(const WrStanceKeepScreen(), intel: _kept(), content: content),
      );

      // Chưa gọi tên được → trạng thái "Đang đọc lại".
      await tester.tap(find.byKey(const Key('wr_stance_name_now')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_stance_own_skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_stance_paused')), findsOneWidget);
      expect(content.insertMemoryEventCalls, isEmpty);

      await tester.tap(find.byKey(const Key('wr_stance_name_now')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('wr_stance_own_field')),
        'Mình bớt ngại khi chưa biết hết.',
      );
      await tester.tap(find.byKey(const Key('wr_stance_own_save')));
      await tester.pumpAndSettle();

      final milestone = content.insertMemoryEventCalls.single;
      expect(milestone.behavior, kMilestoneBehavior);
      expect(
        milestone.reflectionText,
        'Bạn tự gọi tên điều đang hình thành: “Mình bớt ngại khi chưa biết hết.”',
      );
      expect(find.byKey(const Key('wr_stance_own')), findsOneWidget);
    });

    testWidgets('danh sách duy trì: Xem thêm mỗi lần năm chủ đề', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          const WrStanceKeepScreen(),
          intel: _kept(themeIds: const ['pt-c2', 'pt-c1']),
        ),
      );

      expect(find.byKey(const Key('wr_keep_row_pt-c2')), findsOneWidget);
      expect(find.byKey(const Key('wr_keep_row_pt-c1')), findsOneWidget);
      expect(find.byKey(const Key('wr_stance_keep_more')), findsNothing);
      expect(find.text('Ghi nhận'), findsNWidgets(2));
    });
  });

  group('Màn Trà Chiều — chữ theo script', () {
    WorkshopDetail session() {
      final d = DateTime.now().add(const Duration(days: 4));
      return WorkshopDetail(
        id: 'tc1',
        title: 'Bận cả tuần',
        category: 'Trà chiều nghề nghiệp',
        date: d,
        price: 199000,
        currency: 'VND',
        currentParticipants: 0,
        status: 'published',
        isActive: true,
      );
    }

    testWidgets('dòng khuôn, Vì sao lại là Trà Chiều, địa điểm chưa có', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          const WrTraChieuScreen(),
          intel: _kept(),
          workshops: FakeWorkshopRepository()..seedWorkshops([session()]),
        ),
      );

      expect(
        find.text('10 đến 12 người · 2 tiếng · 1 câu hỏi.'),
        findsOneWidget,
      );
      expect(find.text('Vì sao lại là Trà Chiều'), findsOneWidget);
      expect(
        find.textContaining('Không phải hội thảo, không có sân khấu.'),
        findsOneWidget,
      );
      expect(find.text('Ba luật của mọi buổi'), findsOneWidget);
      expect(find.text('TP.HCM, địa điểm sẽ thông báo sau'), findsOneWidget);
    });

    testWidgets('lịch: câu chân trang Có thể dày hơn nếu…', (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrTraChieuCalendarScreen(),
          intel: _kept(),
          workshops: FakeWorkshopRepository()..seedWorkshops([session()]),
        ),
      );

      expect(
        find.text(
          'Định kỳ 2 tuần một lần, chiều thứ Bảy. Có thể dày hơn nếu lượng '
          'đăng ký trước đủ đông.',
        ),
        findsOneWidget,
      );
      expect(find.text('TP.HCM, địa điểm sẽ thông báo sau'), findsOneWidget);
    });
  });
}
