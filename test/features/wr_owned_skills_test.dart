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

Future<void> _typeTitle(WidgetTester tester, String title) async {
  await tester.enterText(find.byKey(const Key('wr_owned_skill_title')), title);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final save = find.byKey(const Key('wr_owned_skill_save'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

bool? _checked(WidgetTester tester, String themeId) => tester
    .widget<CheckboxListTile>(find.byKey(Key('wr_owned_skill_theme_$themeId')))
    .value;

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

  group('màn Thông tin công việc', () {
    testWidgets(
      'màn Thông tin công việc: thêm Chứng chỉ → sheet hiện gợi ý chủ đề có ô tích, bỏ tích thì lưu theme_ids rỗng',
      (tester) async {
        final owned = FakeWrOwnedSkillRepository();
        await _pump(
          tester,
          _app(const WrWorkInfoScreen(), _overrides(owned: owned)),
        );

        expect(find.text('CHỨNG CHỈ, KHOÁ HỌC, KỸ NĂNG ĐÃ CÓ'), findsOneWidget);
        await _openAddSheet(tester);

        await tester.tap(
          find.byKey(const Key('wr_owned_skill_kind_certificate')),
        );
        await tester.pumpAndSettle();
        await _typeTitle(tester, 'Chứng chỉ Quản lý dự án PMP');

        // Gợi ý hiện ra, đã tích sẵn để người dùng xác nhận.
        expect(_checked(tester, 'pt-s2'), isTrue);

        await tester.tap(find.byKey(const Key('wr_owned_skill_theme_pt-s2')));
        await tester.pumpAndSettle();
        expect(_checked(tester, 'pt-s2'), isFalse);

        await _save(tester);

        final saved = owned.addCalls.single;
        expect(saved.kind, OwnedSkillKind.certificate);
        expect(saved.title, 'Chứng chỉ Quản lý dự án PMP');
        expect(saved.themeIds, isEmpty);
        // Sheet đóng, mục mới hiện trong danh sách.
        expect(find.byKey(const Key('wr_owned_skill_save')), findsNothing);
        expect(
          find.byKey(Key('wr_work_info_owned_skill_${owned.rows.single.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets('giữ ô tích thì lưu đúng chủ đề đã xác nhận', (tester) async {
      final owned = FakeWrOwnedSkillRepository();
      await _pump(
        tester,
        _app(const WrWorkInfoScreen(), _overrides(owned: owned)),
      );

      await _openAddSheet(tester);
      await _typeTitle(tester, 'Chứng chỉ Quản lý dự án PMP');
      await tester.enterText(
        find.byKey(const Key('wr_owned_skill_issuer')),
        'PMI',
      );
      await tester.pumpAndSettle();
      await _save(tester);

      final saved = owned.addCalls.single;
      expect(saved.themeIds, ['pt-s2']);
      expect(saved.issuer, 'PMI');
    });

    testWidgets('tên không khớp gì → không gợi ý, không tự gắn chủ đề nào', (
      tester,
    ) async {
      final owned = FakeWrOwnedSkillRepository();
      await _pump(
        tester,
        _app(const WrWorkInfoScreen(), _overrides(owned: owned)),
      );

      await _openAddSheet(tester);
      await _typeTitle(tester, 'Bằng lái xe B2');
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        find.byKey(const Key('wr_owned_skill_no_suggestion')),
        findsOneWidget,
      );

      await _save(tester);
      expect(owned.addCalls.single.themeIds, isEmpty);
    });

    testWidgets('tên trống → nút Lưu tắt', (tester) async {
      final owned = FakeWrOwnedSkillRepository();
      await _pump(
        tester,
        _app(const WrWorkInfoScreen(), _overrides(owned: owned)),
      );

      await _openAddSheet(tester);
      await _typeTitle(tester, '   ');
      final save = tester.widget<ElevatedButton>(
        find.byKey(const Key('wr_owned_skill_save')),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets(
      'Free thêm chứng chỉ không chiếm suất tài liệu (canUploadContextDocument không đổi)',
      (tester) async {
        final owned = FakeWrOwnedSkillRepository();
        final intel = FakeWrIntelligenceRepository()
          ..seedPracticeThemes(kTestThemes)
          ..seedContextDocuments([]);
        final wr = _wrRepo();
        await _pump(
          tester,
          _app(
            const WrWorkInfoScreen(),
            _overrides(
              owned: owned,
              intel: intel,
              wr: wr,
              picker: () async =>
                  (name: 'pmp.pdf', ext: 'pdf', bytes: const [1, 2, 3]),
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
        expect(entitlement.canUploadContextDocument(docsBefore.length), isTrue);

        await _openAddSheet(tester);
        await _typeTitle(tester, 'Chứng chỉ Quản lý dự án PMP');
        final attach = find.byKey(const Key('wr_owned_skill_attach'));
        await tester.ensureVisible(attach);
        await tester.tap(attach);
        await tester.pumpAndSettle();
        expect(find.text('pmp.pdf'), findsOneWidget);
        await _save(tester);

        // Tệp đi vào thư mục của người dùng, tiền tố cert-.
        expect(owned.uploadedPaths.single, startsWith('u1/cert-'));
        expect(owned.addCalls.single.filePath, owned.uploadedPaths.single);
        // Không thành một tài liệu JD/CV, suất tài liệu giữ nguyên.
        expect(intel.insertContextDocumentCalls, isEmpty);
        container.invalidate(wrContextDocumentsProvider);
        final docsAfter = await container.read(
          wrContextDocumentsProvider.future,
        );
        expect(docsAfter.length, docsBefore.length);
        expect(entitlement.canUploadContextDocument(docsAfter.length), isTrue);
      },
    );

    testWidgets('bấm một mục đã khai → sửa được, xoá phải hỏi lại', (
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
        find.descendant(of: item, matching: find.textContaining('Trung tâm A')),
        findsOneWidget,
      );

      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
      // Mở lại đúng lựa chọn người dùng đã xác nhận.
      expect(_checked(tester, 'pt-c2'), isTrue);

      final del = find.byKey(const Key('wr_owned_skill_delete'));
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
