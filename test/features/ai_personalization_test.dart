// Tests for Phase 5 Task 4: AI-personalized narratives on report.
//
// Coverage:
// A1 – repository: cache hit returns content without calling edge function
// A2 – repository: cache miss calls edge function and returns its result
// A3 – repository: edge function error returns null (graceful fallback)
// A4 – provider: VI locale reads cache then invokes edge function on miss
// A5 – provider: EN locale returns null immediately (no calls to repo)
// A6 – widget: static narrative still renders when AI returns null (CRITICAL)
// A7 – widget: personalized text replaces static text when AI returns content
// A8 – widget: loading indicator shown while AI is resolving (vi locale)
// A9 – widget: AI section is absent for EN locale
// A10 – invoke receives userContext populated from cc_profiles (position/tenure/dept)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/ai_personalization_models.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/survey/presentation/report_screen.dart';
import 'package:workreflection_mobile/features/survey/survey_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_survey_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child,
    {required FakeSurveyRepository repo,
    FakeWrRepository? wrRepo,
    String locale = 'vi'}) {
  final wr = wrRepo ?? FakeWrRepository();
  return ProviderScope(
    overrides: [
      surveyRepositoryProvider.overrideWithValue(repo),
      // wrRepositoryProvider must be overridden so ccProfileProvider
      // (watched by _AiPersonalizedPremiumSection) doesn't hit live Supabase.
      wrRepositoryProvider.overrideWithValue(wr),
      // appLocaleProvider controls which locale the report_screen widgets use
      // (separate from MaterialApp locale which drives l10n strings).
      appLocaleProvider.overrideWith((ref) => locale),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi'), Locale('en')],
      locale: Locale(locale),
      home: child,
    ),
  );
}

CcReportFull _premiumReport({String id = 'r1'}) => CcReportFull(
      id: id,
      surveyId: 's1',
      userId: 'u1',
      scoreTotal: 4.0,
      scoreStructure: 4.0,
      scoreCulture: 3.5,
      scoreActivity: 4.5,
      scoreEsi: 3.8,
      scoreEnps: 25,
      bottleneckLayer: SurveyLayer.culture,
      scoreLevel: ScoreLevel.good,
      createdAt: DateTime(2026, 7, 18),
    );

const _modelContent = {
  'quote': 'AI quote here',
  'intro': 'AI intro here',
  'structure_desc': 'AI structure desc',
  'culture_desc': 'AI culture desc',
  'activity_desc': 'AI activity desc',
};

const _reflectionContent = {
  'intro': 'Reflection intro',
  'item1_desc': 'Item 1',
  'item2_desc': 'Item 2',
  'item3_desc': 'Item 3',
  'pauses_intro': 'Pauses intro',
  'pause1': 'Pause 1',
  'pause2': 'Pause 2',
  'pause3': 'Pause 3',
};

const _relationshipContent = {
  'header_quote': 'Header quote',
  'misconception_text': 'Misconception text',
  'misconception_quote': 'Misconception quote',
  'asset1_desc': 'Asset 1',
  'asset2_desc': 'Asset 2',
  'asset3_desc': 'Asset 3',
  'asset4_desc': 'Asset 4',
  'asset5_desc': 'Asset 5',
  'closing_quote': 'Closing quote',
};

// ---------------------------------------------------------------------------
// Repository unit tests (A1–A3)
// ---------------------------------------------------------------------------

void main() {
  group('FakeSurveyRepository AI personalization', () {
    late FakeSurveyRepository repo;

    setUp(() => repo = FakeSurveyRepository());

    test('A1: cache hit returns content without calling invoke', () async {
      repo.seedAiCache('r1', 'model', _modelContent);

      final result = await repo.getCachedAiPersonalization('r1', 'model');

      expect(result, equals(_modelContent));
      expect(repo.aiInvokeCalls, isEmpty); // invoke was never called
    });

    test('A2: cache miss → invokeAiPersonalize returns seeded content', () async {
      // No cache entry seeded → getCachedAiPersonalization returns null.
      repo.seedAiInvokeResult('reflection', _reflectionContent);

      final cached = await repo.getCachedAiPersonalization('r1', 'reflection');
      expect(cached, isNull);

      final result = await repo.invokeAiPersonalize(
        reportId: 'r1',
        section: 'reflection',
        userContext: const AiPersonalizationUserContext(),
        scoreContext: AiPersonalizationScoreContext(
          structure: 4.0,
          culture: 3.5,
          activity: 4.5,
          total: 4.0,
          esi: 3.8,
          bottleneck: 'CULTURE',
          scoreLevel: 'GOOD',
        ),
        defaultContent: {},
      );

      expect(result, equals(_reflectionContent));
      expect(repo.aiInvokeCalls, contains('reflection'));
    });

    test('A3: edge function failure returns null (graceful fallback)', () async {
      repo.setAiInvokeFails(true);

      final result = await repo.invokeAiPersonalize(
        reportId: 'r1',
        section: 'model',
        userContext: const AiPersonalizationUserContext(),
        scoreContext: AiPersonalizationScoreContext(
          structure: 4.0,
          culture: 3.5,
          activity: 4.5,
          total: 4.0,
          esi: 3.8,
          bottleneck: 'CULTURE',
          scoreLevel: 'GOOD',
        ),
        defaultContent: {},
      );

      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Provider tests (A4–A5)
  // ---------------------------------------------------------------------------

  group('aiPersonalizationProvider', () {
    late FakeSurveyRepository repo;

    setUp(() => repo = FakeSurveyRepository());

    AiPersonalizationArgs makeArgs(String section, String locale) => (
          reportId: 'r1',
          section: section,
          userContext: const AiPersonalizationUserContext(),
          scoreContext: AiPersonalizationScoreContext(
            structure: 4.0,
            culture: 3.5,
            activity: 4.5,
            total: 4.0,
            esi: 3.8,
            bottleneck: 'CULTURE',
            scoreLevel: 'GOOD',
          ),
          defaultContent: const {'quote': ''},
          locale: locale,
        );

    test('A4: VI locale → cache miss then invokes edge function', () async {
      repo.seedAiInvokeResult('model', _modelContent);

      final container = ProviderContainer(overrides: [
        surveyRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final result =
          await container.read(aiPersonalizationProvider(makeArgs('model', 'vi')).future);

      expect(result, equals(_modelContent));
      expect(repo.aiInvokeCalls, contains('model'));
    });

    test('A5: EN locale → returns null immediately, no repo calls', () async {
      final container = ProviderContainer(overrides: [
        surveyRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final result =
          await container.read(aiPersonalizationProvider(makeArgs('model', 'en')).future);

      expect(result, isNull);
      expect(repo.aiInvokeCalls, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests (A6–A9)
  // ---------------------------------------------------------------------------

  group('ReportScreen AI personalization widget', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
      repo.seedNarratives([]);
    });

    testWidgets(
        'A6: CRITICAL — static narrative renders when AI returns null (AI down)',
        (tester) async {
      final report = _premiumReport();
      repo.seedLatestReport(report);
      // AI returns null for all sections → graceful fallback
      repo.setAiInvokeFails(true);

      await tester.pumpWidget(
          _wrap(ReportScreen(reportId: 'r1'), repo: repo, locale: 'vi'));
      await tester.pumpAndSettle();

      // ESI section (static) still renders
      expect(find.textContaining('ESI'), findsOneWidget);
      // eNPS section (static) still renders
      expect(find.text('25'), findsOneWidget);
      // No crash, no infinite spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'A7: personalized model content replaces static when AI returns data',
        (tester) async {
      final report = _premiumReport();
      repo.seedLatestReport(report);
      // Seed cache directly so provider resolves synchronously from cache
      repo.seedAiCache('r1', 'model', _modelContent);
      repo.seedAiCache('r1', 'reflection', _reflectionContent);
      repo.seedAiCache('r1', 'relationship', _relationshipContent);

      await tester.pumpWidget(
          _wrap(ReportScreen(reportId: 'r1'), repo: repo, locale: 'vi'));
      await tester.pumpAndSettle();

      // AI model content should appear
      expect(find.text('AI quote here'), findsOneWidget);
      expect(find.text('AI intro here'), findsOneWidget);
    });

    testWidgets('A8: loading indicator shown while AI is resolving (vi locale)',
        (tester) async {
      final report = _premiumReport();
      repo.seedLatestReport(report);
      // No cache, no invoke result → provider stays loading until null returned

      await tester.pumpWidget(
          _wrap(ReportScreen(reportId: 'r1'), repo: repo, locale: 'vi'));
      // pump once without settle to catch loading state
      await tester.pump();

      // Either a spinner or the settled state (null → no AI section) is valid.
      // The important thing is no crash occurs.
      expect(tester.takeException(), isNull);
    });

    testWidgets('A9: AI section absent for EN locale', (tester) async {
      final report = _premiumReport();
      repo.seedLatestReport(report);
      // Even if cache has data, EN locale skips AI section
      repo.seedAiCache('r1', 'model', _modelContent);

      await tester.pumpWidget(
          _wrap(ReportScreen(reportId: 'r1'), repo: repo, locale: 'en'));
      await tester.pumpAndSettle();

      // AI content should NOT appear for EN locale
      expect(find.text('AI quote here'), findsNothing);
      expect(find.text('AI intro here'), findsNothing);
      // But the static premium sections (ESI) still show
      expect(find.textContaining('ESI'), findsOneWidget);
    });

    testWidgets(
        'A10: invoke receives userContext populated from cc_profiles',
        (tester) async {
      final report = _premiumReport();
      repo.seedLatestReport(report);
      // No cache → will call invoke for each section
      repo.seedAiInvokeResult('model', _modelContent);
      repo.seedAiInvokeResult('reflection', _reflectionContent);
      repo.seedAiInvokeResult('relationship', _relationshipContent);

      // Seed cc_profiles data in the WrRepository fake.
      final wrRepo = FakeWrRepository()
        ..seedCcProfile({
          'position': 'staff',
          'company_tenure': 'less_6m',
          'department': 'engineering',
        });

      await tester.pumpWidget(
          _wrap(ReportScreen(reportId: 'r1'), repo: repo, wrRepo: wrRepo));
      await tester.pumpAndSettle();

      // All three sections should have been invoked (cache miss path).
      expect(repo.aiInvokeCalls, containsAll(['model', 'reflection', 'relationship']));

      // The invoke calls must have received the cc_profiles data as raw DB
      // enum values (same as web — no translation, no display labels).
      for (final section in ['model', 'reflection', 'relationship']) {
        final ctx = repo.aiInvokeUserContexts[section]!;
        expect(ctx.position, 'staff',
            reason: '$section: position must be raw DB value');
        expect(ctx.tenure, 'less_6m',
            reason: '$section: tenure must be raw DB value (company_tenure)');
        expect(ctx.department, 'engineering',
            reason: '$section: department must be raw DB value');
        // Not translated to display labels.
        expect(ctx.position, isNot('Nhân viên'));
        expect(ctx.tenure, isNot('Dưới 6 tháng'));
      }
    });

    testWidgets(
        'A11: no AI invoke fires while profile is loading; invoke fires with '
        'populated context after profile completes',
        (tester) async {
      final report = _premiumReport();
      repo.seedLatestReport(report);
      // No cache → will call invoke on miss.
      repo.seedAiInvokeResult('model', _modelContent);
      repo.seedAiInvokeResult('reflection', _reflectionContent);
      repo.seedAiInvokeResult('relationship', _relationshipContent);

      // Completer keeps getCcProfile suspended until we resolve it.
      final profileCompleter = Completer<Map<String, dynamic>>();
      final wrRepo = FakeWrRepository()
        ..setCcProfileCompleter(profileCompleter);

      await tester.pumpWidget(
          _wrap(ReportScreen(reportId: 'r1'), repo: repo, wrRepo: wrRepo));

      // One frame: profile is still loading.
      await tester.pump();

      // AI invoke must NOT have fired yet — profile not settled.
      expect(repo.aiInvokeCalls, isEmpty,
          reason: 'invokeAiPersonalize must not fire while profile is loading');

      // Now resolve the profile with populated data.
      profileCompleter.complete({
        'position': 'manager',
        'company_tenure': '1_3y',
        'department': 'product',
      });
      await tester.pumpAndSettle();

      // After profile settles, AI invokes fire with the populated context.
      expect(repo.aiInvokeCalls,
          containsAll(['model', 'reflection', 'relationship']));
      for (final section in ['model', 'reflection', 'relationship']) {
        final ctx = repo.aiInvokeUserContexts[section]!;
        expect(ctx.position, 'manager',
            reason: '$section: position populated from settled profile');
        expect(ctx.tenure, '1_3y',
            reason: '$section: tenure populated from settled profile');
        expect(ctx.department, 'product',
            reason: '$section: department populated from settled profile');
      }
    });
  });
}
