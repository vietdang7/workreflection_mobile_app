// "Chứng chỉ, khoá học, kỹ năng đã có" (họp khách 01/10/2026, Task D2).
//
// Người dùng tự khai thứ họ đã có, app không đề xuất lại. Ba chỗ phải nghe
// theo: gợi ý chủ đề (kéo theo phần mềm tự thêm chủ đề), đối chiếu kỹ năng với
// JD, và trợ lý trò chuyện (test Deno riêng).
//
// Mặc định Q5 (khách chưa trả lời): khai tay mở cho MỌI gói; đính kèm tệp
// không chiếm suất tài liệu JD/CV của Free.
//
// Run: flutter test test/features/wr_owned_skills_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_owned_skill_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_owned_skill.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/growth_providers.dart';
import 'package:workreflection_mobile/features/wr/owned_skill_providers.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_owned_skill_sheet.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_work_info_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_owned_skill_repository.dart';
import '../support/practice_themes_fixture.dart';

// ── Dữ liệu: người dùng vướng S1 nhiều nhất ─────────────────────────────────

const _sitS1 = WrSituation(
  code: 'S1-sit-01',
  text: 'Không rõ được giao gì',
  humanNeed: HumanNeed.roRang,
  scaDimension: ScaDimension.s1,
  wave: 1,
);

FakeWrEpisodeRepository _episodesS1(int n) => FakeWrEpisodeRepository()
  ..seed([
    for (var i = 0; i < n; i++)
      ReflectionEpisode(
        id: 'e$i',
        userId: 'u1',
        humanMoment: HumanMoment.confusion,
        state: ExperienceState.integrated,
        situationCode: _sitS1.code,
        openedAt: DateTime(2026, 9, 1).add(Duration(hours: i)),
      ),
  ]);

WrOwnedSkill _owned(
  String id,
  String title, {
  List<String> themeIds = const [],
  OwnedSkillKind kind = OwnedSkillKind.certificate,
  String? issuer,
}) => WrOwnedSkill(
  id: id,
  kind: kind,
  title: title,
  issuer: issuer,
  themeIds: themeIds,
  createdAt: DateTime(2026, 9, 30),
);

FakeWrRepository _wrRepo() => FakeWrRepository()
  ..seedProfile(
    MobileProfile(
      userId: 'u1',
      reminderEnabled: false,
      language: 'vi',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

List<Override> _overrides({
  required FakeWrOwnedSkillRepository owned,
  FakeWrIntelligenceRepository? intel,
  FakeWrEpisodeRepository? episodes,
  FakeWrRepository? wr,
  OwnedSkillFilePicker? picker,
}) {
  final content = FakeWrContentRepository()..seedSituations([_sitS1]);
  return [
    wrRepositoryProvider.overrideWithValue(wr ?? _wrRepo()),
    wrContentRepositoryProvider.overrideWithValue(content),
    wrIntelligenceRepositoryProvider.overrideWithValue(
      intel ??
          (FakeWrIntelligenceRepository()..seedPracticeThemes(kTestThemes)),
    ),
    wrEpisodeRepositoryProvider.overrideWithValue(
      episodes ?? FakeWrEpisodeRepository(),
    ),
    wrOwnedSkillRepositoryProvider.overrideWithValue(owned),
    if (picker != null) ownedSkillFilePickerProvider.overrideWithValue(picker),
    currentUserIdProvider.overrideWithValue('u1'),
  ];
}

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp.router(
    builder: wrTextScaleBuilder,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    routerConfig: GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(path: '/test', builder: (_, __) => home),
        GoRoute(
          path: '/wr/paywall',
          builder: (_, __) => const Scaffold(body: Text('Paywall')),
        ),
        GoRoute(
          path: '/wr/self-check',
          builder: (_, __) => const Scaffold(body: Text('SelfCheck')),
        ),
        GoRoute(
          path: '/wr/context-docs',
          builder: (_, __) => const Scaffold(body: Text('ContextDocs')),
        ),
        GoRoute(
          path: '/wr/jd-builder',
          builder: (_, __) => const Scaffold(body: Text('JdBuilder')),
        ),
      ],
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

Future<void> _openAddSheet(WidgetTester tester) async {
  final row = find.byKey(const Key('wr_work_info_owned_skill_add'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  group('gợi ý chủ đề bỏ qua thứ người dùng đã có', () {
    test(
      'đã khai chủ đề pt-s1 → wrPracticeSuggestionProvider không bao giờ đề xuất pt-s1',
      () async {
        Future<String?> suggestionWith(List<WrOwnedSkill> owned) async {
          final c = ProviderContainer(
            overrides: _overrides(
              owned: FakeWrOwnedSkillRepository()..seed(owned),
              episodes: _episodesS1(15),
            ),
          );
          addTearDown(c.dispose);
          // Đọc đủ mọi nguồn trước khi hỏi gợi ý, như màn hình làm.
          c.listen(wrPracticeSuggestionProvider, (_, __) {});
          await c.read(practiceThemesProvider.future);
          await c.read(practiceEnrollmentsProvider.future);
          await c.read(wrEpisodeHistoryProvider.future);
          await c.read(wrSituationsProvider.future);
          await c.read(wrSelfCheckHistoryProvider.future);
          await c.read(wrOwnedSkillsProvider.future);
          await c.read(wrSkillJdMatchProvider.future);
          return c.read(wrPracticeSuggestionProvider)?.theme.themeId;
        }

        // Không khai gì: tình huống S1 lặp lại → đúng chủ đề S1.
        expect(await suggestionWith(const []), 'pt-s1');

        // Đã khai một chứng chỉ gắn pt-s1 → không bao giờ là pt-s1 nữa.
        final s = await suggestionWith([
          _owned('os1', 'Khoá làm rõ yêu cầu', themeIds: const ['pt-s1']),
        ]);
        expect(s, isNot('pt-s1'));
      },
    );

    testWidgets('auto-enroll bỏ qua pt-s1 khi người dùng đã khai có pt-s1', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(kTestThemes)
        ..seedEnrollments([]);
      await _pump(
        tester,
        _app(
          const WrGrowthScreen(),
          _overrides(
            owned: FakeWrOwnedSkillRepository()
              ..seed([
                _owned('os1', 'Khoá làm rõ yêu cầu', themeIds: const ['pt-s1']),
              ]),
            intel: intel,
            episodes: _episodesS1(15),
          ),
        ),
      );

      expect(intel.enrollThemeCalls, hasLength(1));
      expect(intel.enrollThemeCalls.single.themeId, isNot('pt-s1'));
    });

    testWidgets('chưa khai gì thì auto-enroll vẫn chọn pt-s1 như cũ', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(kTestThemes)
        ..seedEnrollments([]);
      await _pump(
        tester,
        _app(
          const WrGrowthScreen(),
          _overrides(
            owned: FakeWrOwnedSkillRepository(),
            intel: intel,
            episodes: _episodesS1(15),
          ),
        ),
      );

      expect(intel.enrollThemeCalls.single.themeId, 'pt-s1');
    });
  });

  // Họp khách 14/10: bỏ form nhiều ô, chỉ còn nút tải file trong thẻ Tài liệu.
  group('màn Bối cảnh công việc — tải chứng chỉ', () {
    OwnedSkillFilePicker pick(String name) =>
        () async => (name: name, ext: 'pdf', bytes: const [1, 2, 3]);

    testWidgets('tải file → thành Chứng chỉ, tên lấy từ tên file, máy tự '
        'khớp chủ đề', (tester) async {
      final owned = FakeWrOwnedSkillRepository();
      await _pump(
        tester,
        _app(
          const WrWorkInfoScreen(),
          _overrides(owned: owned, picker: pick('Chung_chi-Quan ly du an.pdf')),
        ),
      );

      // Nằm chung thẻ Tài liệu với JD, không còn khối riêng.
      expect(
        find.descendant(
          of: find.byKey(const Key('wr_work_info_documents_card')),
          matching: find.text('CHỨNG CHỈ, KHOÁ HỌC ĐÃ CÓ'),
        ),
        findsOneWidget,
      );
      await _openAddSheet(tester);

      // Không mở form nào.
      expect(find.byKey(const Key('wr_owned_skill_title')), findsNothing);
      final saved = owned.addCalls.single;
      expect(saved.kind, OwnedSkillKind.certificate);
      expect(saved.title, 'Chung chi Quan ly du an');
      expect(saved.filePath, owned.uploadedPaths.single);
      expect(owned.uploadedPaths.single, startsWith('u1/cert-'));
      expect(
        find.byKey(Key('wr_work_info_owned_skill_${owned.rows.single.id}')),
        findsOneWidget,
      );
    });

    testWidgets('tên khớp chủ đề thì gắn chủ đề đó để không gợi ý lại', (
      tester,
    ) async {
      final owned = FakeWrOwnedSkillRepository();
      await _pump(
        tester,
        _app(
          const WrWorkInfoScreen(),
          _overrides(
            owned: owned,
            picker: pick('Chứng chỉ Quản lý dự án PMP.pdf'),
          ),
        ),
      );
      await _openAddSheet(tester);
      expect(owned.addCalls.single.title, 'Chứng chỉ Quản lý dự án PMP');
      expect(owned.addCalls.single.themeIds, ['pt-s2']);
    });

    testWidgets('tên không khớp gì → không tự gắn chủ đề nào', (tester) async {
      final owned = FakeWrOwnedSkillRepository();
      await _pump(
        tester,
        _app(
          const WrWorkInfoScreen(),
          _overrides(owned: owned, picker: pick('Bằng lái xe B2.pdf')),
        ),
      );
      await _openAddSheet(tester);
      expect(owned.addCalls.single.themeIds, isEmpty);
    });

    testWidgets('huỷ chọn file thì không lưu gì', (tester) async {
      final owned = FakeWrOwnedSkillRepository();
      await _pump(
        tester,
        _app(
          const WrWorkInfoScreen(),
          _overrides(owned: owned, picker: () async => null),
        ),
      );
      await _openAddSheet(tester);
      expect(owned.addCalls, isEmpty);
      expect(owned.uploadedPaths, isEmpty);
    });

    testWidgets(
      'Free tải chứng chỉ không chiếm suất tài liệu (canUploadContextDocument không đổi)',
      (tester) async {
        final owned = FakeWrOwnedSkillRepository();
        final intel = FakeWrIntelligenceRepository()
          ..seedPracticeThemes(kTestThemes)
          ..seedContextDocuments([]);
        await _pump(
          tester,
          _app(
            const WrWorkInfoScreen(),
            _overrides(
              owned: owned,
              intel: intel,
              wr: _wrRepo(),
              picker: pick('pmp.pdf'),
            ),
          ),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(WrWorkInfoScreen)),
        );
        final entitlement = await container.read(wrEntitlementProvider.future);
        expect(entitlement.plan, WrPlan.free);
        final docsBefore = await container.read(
          wrContextDocumentsProvider.future,
        );

        await _openAddSheet(tester);

        expect(owned.addCalls, hasLength(1));
        expect(intel.insertContextDocumentCalls, isEmpty);
        container.invalidate(wrContextDocumentsProvider);
        final docsAfter = await container.read(
          wrContextDocumentsProvider.future,
        );
        expect(docsAfter.length, docsBefore.length);
        expect(entitlement.canUploadContextDocument(docsAfter.length), isTrue);
      },
    );

    testWidgets('mục đã có (kể cả khai tay trước đây) xoá phải hỏi lại', (
      tester,
    ) async {
      final owned = FakeWrOwnedSkillRepository()
        ..seed([
          _owned(
            'os1',
            'Khoá kỹ năng thuyết trình',
            kind: OwnedSkillKind.course,
            issuer: 'Trung tâm A',
            themeIds: const ['pt-c2'],
          ),
        ]);
      await _pump(
        tester,
        _app(const WrWorkInfoScreen(), _overrides(owned: owned)),
      );

      final item = find.byKey(const Key('wr_work_info_owned_skill_os1'));
      expect(item, findsOneWidget);
      expect(
        find.descendant(
          of: item,
          matching: find.text('Khoá kỹ năng thuyết trình'),
        ),
        findsOneWidget,
      );

      final del = find.byKey(const Key('wr_owned_skill_delete_os1'));
      await tester.ensureVisible(del);
      await tester.tap(del);
      await tester.pumpAndSettle();
      expect(owned.deleteCalls, isEmpty);
      await tester.tap(find.byKey(const Key('wr_owned_skill_delete_confirm')));
      await tester.pumpAndSettle();
      expect(owned.deleteCalls, ['os1']);
      expect(
        find.byKey(const Key('wr_work_info_owned_skill_os1')),
        findsNothing,
      );
    });
  });
}
