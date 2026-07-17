import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/development_theme.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/practice.dart';
import 'package:workreflection_mobile/core/models/recurring_situation.dart';
import 'package:workreflection_mobile/core/models/sca_report.dart';
import 'package:workreflection_mobile/core/models/timeline_event.dart';
import 'package:workreflection_mobile/core/models/workshop.dart';
import 'package:workreflection_mobile/features/develop/develop_providers.dart';
import 'package:workreflection_mobile/features/home/home_providers.dart';

import '../support/fake_repository.dart';

// ---------------------------------------------------------------------------
// Delegating repos that fail only on write operations
// ---------------------------------------------------------------------------

/// Wraps a FakeWrRepository but throws on upsertCheckin.
class _FailingCheckinRepo implements WrRepository {
  _FailingCheckinRepo(this._d);
  final FakeWrRepository _d;

  @override Future<Checkin?> getTodayCheckin() => _d.getTodayCheckin();
  @override Future<void> upsertCheckin(Mood mood) async => throw Exception('network error');
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
  @override Future<ScaReport?> getLatestScaReport() => _d.getLatestScaReport();
  @override Future<Workshop?> getUpcomingWorkshop() => _d.getUpcomingWorkshop();
  @override Future<Map<String, dynamic>> getCcProfile() => _d.getCcProfile();
  @override Future<Map<String, dynamic>> exportUserData() => _d.exportUserData();
  @override Future<void> ensureSeeded({String? onboardingSituation}) => _d.ensureSeeded(onboardingSituation: onboardingSituation);
  @override Future<void> saveOnboardingSituation(String s) => _d.saveOnboardingSituation(s);
}

/// Wraps a FakeWrRepository but throws on updatePracticeStatus.
class _FailingPracticeRepo implements WrRepository {
  _FailingPracticeRepo(this._d);
  final FakeWrRepository _d;

  @override Future<Checkin?> getTodayCheckin() => _d.getTodayCheckin();
  @override Future<void> upsertCheckin(Mood mood) => _d.upsertCheckin(mood);
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
  @override Future<ScaReport?> getLatestScaReport() => _d.getLatestScaReport();
  @override Future<Workshop?> getUpcomingWorkshop() => _d.getUpcomingWorkshop();
  @override Future<Map<String, dynamic>> getCcProfile() => _d.getCcProfile();
  @override Future<Map<String, dynamic>> exportUserData() => _d.exportUserData();
  @override Future<void> ensureSeeded({String? onboardingSituation}) => _d.ensureSeeded(onboardingSituation: onboardingSituation);
  @override Future<void> saveOnboardingSituation(String s) => _d.saveOnboardingSituation(s);
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
}
