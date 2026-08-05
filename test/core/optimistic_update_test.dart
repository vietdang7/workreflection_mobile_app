import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_career_profile.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/development_theme.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/practice.dart';
import 'package:workreflection_mobile/core/models/recurring_situation.dart';
import 'package:workreflection_mobile/core/models/sca_report.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/core/models/timeline_event.dart';
import 'package:workreflection_mobile/core/models/workshop.dart';
import 'package:workreflection_mobile/features/develop/develop_providers.dart';
import 'package:workreflection_mobile/features/home/home_providers.dart';
import 'package:workreflection_mobile/features/survey/survey_providers.dart';

import 'package:workreflection_mobile/core/logic/wr_pricing.dart';

import '../support/fake_repository.dart';
import '../support/fake_survey_repository.dart';

// ---------------------------------------------------------------------------
// Delegating repos that fail only on write operations
// ---------------------------------------------------------------------------

/// Wraps a FakeWrRepository but throws on upsertCheckin.
class _FailingCheckinRepo implements WrRepository {
  _FailingCheckinRepo(this._d);
  final FakeWrRepository _d;

  @override Future<Checkin?> getTodayCheckin() => _d.getTodayCheckin();
  @override Future<void> upsertCheckin(Mood mood, {CheckinEnergy? energy, CheckinDirection? direction}) async => throw Exception('network error');
  @override Future<List<DateTime>> getCheckinDates({int limit = 60}) => _d.getCheckinDates(limit: limit);
  @override Future<int> countCheckins() => _d.countCheckins();
  @override Future<Insight?> getLatestInsight() => _d.getLatestInsight();
  @override Future<List<Insight>> getInsights() => _d.getInsights();
  @override Future<int> countInsights() => _d.countInsights();
  @override Future<List<RecurringSituation>> getRecurringSituations() => _d.getRecurringSituations();
  @override Future<DevelopmentTheme?> getActiveTheme() => _d.getActiveTheme();
  @override Future<List<Practice>> getTodayPractices() => _d.getTodayPractices();
  @override Future<void> updatePracticeStatus(String id, PracticeStatus s) => _d.updatePracticeStatus(id, s);
  @override Future<List<TimelineEvent>> getTimelineEvents() => _d.getTimelineEvents();
  @override Future<int> countMilestones() => _d.countMilestones();
  @override Future<MobileProfile?> getMobileProfile() => _d.getMobileProfile();
  @override Future<void> updateReminder(bool e) => _d.updateReminder(e);
  @override Future<void> updateLanguage(String l) => _d.updateLanguage(l);
  @override Future<void> saveCareerSnapshot(CareerSnapshot s) => _d.saveCareerSnapshot(s);
  @override Future<void> saveRecentSituationIds(List<String> c) => _d.saveRecentSituationIds(c);
  @override Future<void> saveRoleText(String? r) => _d.saveRoleText(r);
  @override Future<void> saveMyInfo(Map<String, String?> f) => _d.saveMyInfo(f);
  @override Future<String> uploadContextDocument(List<int> b, String e, String d) => _d.uploadContextDocument(b, e, d);
  @override Future<ScaReport?> getLatestScaReport() => _d.getLatestScaReport();
  @override Future<Workshop?> getUpcomingWorkshop() => _d.getUpcomingWorkshop();
  @override Future<Map<String, dynamic>> getCcProfile() => _d.getCcProfile();
  @override Future<List<WrPremiumPricing>> getPremiumPlans() => _d.getPremiumPlans();
  @override Future<void> updateCcProfile(Map<String, dynamic> fields) => _d.updateCcProfile(fields);
  @override Future<void> updateDisplayName(String displayName) => _d.updateDisplayName(displayName);
  @override Future<Map<String, dynamic>> exportUserData() => _d.exportUserData();
  @override Future<void> ensureSeeded({String? onboardingSituation}) => _d.ensureSeeded(onboardingSituation: onboardingSituation);
  @override Future<void> saveOnboardingSituation(String s) => _d.saveOnboardingSituation(s);
  @override Future<String> uploadAvatar(List<int> bytes, String ext) => _d.uploadAvatar(bytes, ext);
  @override Future<List<Map<String, dynamic>>> getVouchers() => _d.getVouchers();
  @override Future<List<Map<String, dynamic>>> getInvitations() => _d.getInvitations();
  @override Future<String> acceptInvitation(String token) => _d.acceptInvitation(token);
  @override Future<void> declineInvitation(String invitationId) => _d.declineInvitation(invitationId);
}

/// Wraps a FakeWrRepository but throws on updatePracticeStatus.
class _FailingPracticeRepo implements WrRepository {
  _FailingPracticeRepo(this._d);
  final FakeWrRepository _d;

  @override Future<Checkin?> getTodayCheckin() => _d.getTodayCheckin();
  @override Future<void> upsertCheckin(Mood mood, {CheckinEnergy? energy, CheckinDirection? direction}) => _d.upsertCheckin(mood, energy: energy, direction: direction);
  @override Future<List<DateTime>> getCheckinDates({int limit = 60}) => _d.getCheckinDates(limit: limit);
  @override Future<int> countCheckins() => _d.countCheckins();
  @override Future<Insight?> getLatestInsight() => _d.getLatestInsight();
  @override Future<List<Insight>> getInsights() => _d.getInsights();
  @override Future<int> countInsights() => _d.countInsights();
  @override Future<List<RecurringSituation>> getRecurringSituations() => _d.getRecurringSituations();
  @override Future<DevelopmentTheme?> getActiveTheme() => _d.getActiveTheme();
  @override Future<List<Practice>> getTodayPractices() => _d.getTodayPractices();
  @override Future<void> updatePracticeStatus(String id, PracticeStatus s) async => throw Exception('network error');
  @override Future<List<TimelineEvent>> getTimelineEvents() => _d.getTimelineEvents();
  @override Future<int> countMilestones() => _d.countMilestones();
  @override Future<MobileProfile?> getMobileProfile() => _d.getMobileProfile();
  @override Future<void> updateReminder(bool e) => _d.updateReminder(e);
  @override Future<void> updateLanguage(String l) => _d.updateLanguage(l);
  @override Future<void> saveCareerSnapshot(CareerSnapshot s) => _d.saveCareerSnapshot(s);
  @override Future<void> saveRecentSituationIds(List<String> c) => _d.saveRecentSituationIds(c);
  @override Future<void> saveRoleText(String? r) => _d.saveRoleText(r);
  @override Future<void> saveMyInfo(Map<String, String?> f) => _d.saveMyInfo(f);
  @override Future<String> uploadContextDocument(List<int> b, String e, String d) => _d.uploadContextDocument(b, e, d);
  @override Future<ScaReport?> getLatestScaReport() => _d.getLatestScaReport();
  @override Future<Workshop?> getUpcomingWorkshop() => _d.getUpcomingWorkshop();
  @override Future<Map<String, dynamic>> getCcProfile() => _d.getCcProfile();
  @override Future<List<WrPremiumPricing>> getPremiumPlans() => _d.getPremiumPlans();
  @override Future<void> updateCcProfile(Map<String, dynamic> fields) => _d.updateCcProfile(fields);
  @override Future<void> updateDisplayName(String displayName) => _d.updateDisplayName(displayName);
  @override Future<Map<String, dynamic>> exportUserData() => _d.exportUserData();
  @override Future<void> ensureSeeded({String? onboardingSituation}) => _d.ensureSeeded(onboardingSituation: onboardingSituation);
  @override Future<void> saveOnboardingSituation(String s) => _d.saveOnboardingSituation(s);
  @override Future<String> uploadAvatar(List<int> bytes, String ext) => _d.uploadAvatar(bytes, ext);
  @override Future<List<Map<String, dynamic>>> getVouchers() => _d.getVouchers();
  @override Future<List<Map<String, dynamic>>> getInvitations() => _d.getInvitations();
  @override Future<String> acceptInvitation(String token) => _d.acceptInvitation(token);
  @override Future<void> declineInvitation(String invitationId) => _d.declineInvitation(invitationId);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CheckinNotifier — optimistic update reverts to prior state on failure', () {
    test('reverts to null when prior was null and upsert throws', () async {
      final seed = FakeWrRepository(); // no today checkin → null
      final repo = _FailingCheckinRepo(seed);

      final container = ProviderContainer(
        overrides: [wrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(checkinProvider.future);
      expect(container.read(checkinProvider).valueOrNull, isNull);

      await container.read(checkinProvider.notifier).selectMood(Mood.okay);

      final state = container.read(checkinProvider);
      expect(state.hasError, isFalse,
          reason: 'must revert to prior data, not AsyncError');
      expect(state.valueOrNull, isNull,
          reason: 'reverted to null after failed upsert');
    });

    test('reverts to happy when prior mood was happy and upsert throws', () async {
      final seed = FakeWrRepository();
      await seed.upsertCheckin(Mood.happy);
      final repo = _FailingCheckinRepo(seed);

      final container = ProviderContainer(
        overrides: [wrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(checkinProvider.future);
      expect(container.read(checkinProvider).valueOrNull, Mood.happy);

      await container.read(checkinProvider.notifier).selectMood(Mood.stressed);

      final state = container.read(checkinProvider);
      expect(state.hasError, isFalse,
          reason: 'must revert to prior data, not AsyncError');
      expect(state.valueOrNull, Mood.happy,
          reason: 'reverted to happy after failed upsert');
    });
  });

  group('PracticesNotifier — optimistic update reverts to prior state on failure', () {
    test('reverts to todo when updatePracticeStatus throws', () async {
      final seed = FakeWrRepository();
      seed.seedPractices([
        Practice(
          id: 'p1',
          userId: 'u1',
          title: 'Test Practice',
          status: PracticeStatus.todo,
          practiceDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ]);
      final repo = _FailingPracticeRepo(seed);

      final container = ProviderContainer(
        overrides: [wrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(practicesProvider.future);
      expect(
          container.read(practicesProvider).valueOrNull?.first.status,
          PracticeStatus.todo);

      await container.read(practicesProvider.notifier).advanceStatus('p1');

      final state = container.read(practicesProvider);
      expect(state.hasError, isFalse,
          reason: 'must revert to prior data, not AsyncError');
      expect(state.valueOrNull?.first.status, PracticeStatus.todo,
          reason: 'reverted to todo after failed updatePracticeStatus');
    });
  });

  group('FakeSurveyRepository — blocker contracts', () {
    test('B1+B2: getActionProgress ignores reportId (no param), toggleTask works', () async {
      final fake = FakeSurveyRepository();
      fake.seedActionProgress({'t1': false});
      await fake.toggleTask('t1', true);
      final progress = await fake.getActionProgress();
      expect(progress['t1'], isTrue);
    });

    test('B3: getActionPlan returns all phases ordered by day regardless of type', () async {
      final fake = FakeSurveyRepository();
      fake.seedActionPlan([
        ActionPlanPhase(id: 'p10', day: 10, titleVi: 'Ten', titleEn: 'Ten', surveyType: SurveyType.free, displayOrder: 2),
        ActionPlanPhase(id: 'p1', day: 1, titleVi: 'One', titleEn: 'One', surveyType: SurveyType.free, displayOrder: 1),
        ActionPlanPhase(id: 'p5', day: 5, titleVi: 'Five', titleEn: 'Five', surveyType: SurveyType.free, displayOrder: 3),
      ]);
      final phases = await fake.getActionPlan(SurveyType.premium);
      expect(phases.map((p) => p.day).toList(), [1, 5, 10]);
    });

    test('B4: getQuestions with config preserves order and filters is_active', () async {
      final fake = FakeSurveyRepository();
      final q1 = CcQuestion(id: 'q1', layer: SurveyLayer.structure, scaleType: ScaleType.likert5, questionText: 'Q1', questionOrder: 2, isActive: true);
      final q2 = CcQuestion(id: 'q2', layer: SurveyLayer.culture, scaleType: ScaleType.likert5, questionText: 'Q2', questionOrder: 1, isActive: true);
      fake.seedQuestions([q1, q2]);
      fake.seedConfigQuestionIds(['q2', 'q1'], surveyType: SurveyType.free);
      final qs = await fake.getQuestions(SurveyType.free);
      expect(qs[0].id, 'q2');
      expect(qs[1].id, 'q1');
    });

    test('setToggleFails makes toggleTask throw', () async {
      final fake = FakeSurveyRepository();
      fake.seedActionProgress({'t1': false});
      fake.setToggleFails(true);
      expect(() async => await fake.toggleTask('t1', true), throwsException);
    });
  });

  group('FakeSurveyRepository — idempotent cc_reports (Fix 3)', () {
    test('calling submitSurvey twice with same existingSurveyId returns same report, no duplicate', () async {
      final fake = FakeSurveyRepository();

      // First call: no existingSurveyId → creates survey + report
      final report1 = await fake.submitSurvey(
        type: SurveyType.free,
        answers: {'q1': 3},
        questions: [],
        existingSurveyId: null,
        onSurveyCreated: (_) {},
      );

      // Second call: same surveyId (simulates provider re-run) → must return same report
      final report2 = await fake.submitSurvey(
        type: SurveyType.free,
        answers: {'q1': 3},
        questions: [],
        existingSurveyId: 'fake-survey-id',
        onSurveyCreated: (_) {},
      );

      expect(report2.id, equals(report1.id),
          reason: 'second call with same surveyId must return existing report id');
      expect(fake.submitSurveyCalls, hasLength(2),
          reason: 'both calls were recorded');
    });

    test('different surveyIds produce separate reports', () async {
      final fake = FakeSurveyRepository();

      // First survey
      final report1 = await fake.submitSurvey(
        type: SurveyType.free,
        answers: {'q1': 3},
        questions: [],
        existingSurveyId: null,
      );

      // Seed a different latestReport so second call returns a distinct report
      final secondReport = CcReportFull(
        id: 'report-2',
        surveyId: 'survey-2',
        userId: 'u2',
        scoreTotal: 4.0,
        scoreStructure: 4.0,
        scoreCulture: 4.0,
        scoreActivity: 4.0,
        bottleneckLayer: SurveyLayer.structure,
        scoreLevel: ScoreLevel.good,
        createdAt: DateTime.now(),
      );
      fake.seedLatestReport(secondReport);

      final report2 = await fake.submitSurvey(
        type: SurveyType.free,
        answers: {'q1': 5},
        questions: [],
        existingSurveyId: 'survey-2',
      );

      expect(report2.id, equals('report-2'));
      expect(report1.id, isNot(equals(report2.id)),
          reason: 'distinct surveyIds must produce distinct reports');
    });
  });

  group('ActionProgressNotifier — rollback', () {
    test('N18: optimistic toggle rolls back to prior value on failure', () async {
      final fake = FakeSurveyRepository();
      fake.seedActionProgress({'t1': false});

      final container = ProviderContainer(overrides: [
        surveyRepositoryProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(actionProgressNotifierProvider('r1').notifier);
      notifier.init({'t1': false});
      expect(container.read(actionProgressNotifierProvider('r1'))['t1'], isFalse);

      fake.setToggleFails(true);
      await notifier.toggle('t1', true);

      expect(container.read(actionProgressNotifierProvider('r1'))['t1'], isFalse);
    });
  });
}
