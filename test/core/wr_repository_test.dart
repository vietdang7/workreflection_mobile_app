import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/practice.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/sca_report.dart';
import 'package:workreflection_mobile/core/models/workshop.dart';
import '../support/fake_repository.dart';

void main() {
  late FakeWrRepository repo;

  setUp(() {
    repo = FakeWrRepository();
  });

  group('FakeWrRepository — checkins', () {
    test('upsertCheckin stores a checkin and getTodayCheckin returns it', () async {
      await repo.upsertCheckin(Mood.happy);
      final checkin = await repo.getTodayCheckin();
      expect(checkin, isNotNull);
      expect(checkin!.mood, Mood.happy);
    });

    test('upsertCheckin with different mood overwrites previous checkin for today', () async {
      await repo.upsertCheckin(Mood.tired);
      await repo.upsertCheckin(Mood.okay);
      final checkin = await repo.getTodayCheckin();
      expect(checkin!.mood, Mood.okay);
    });

    test('getTodayCheckin returns null when no checkin made', () async {
      final checkin = await repo.getTodayCheckin();
      expect(checkin, isNull);
    });

    test('getCheckinDates returns dates for all upserted checkins', () async {
      await repo.upsertCheckin(Mood.happy);
      final dates = await repo.getCheckinDates();
      expect(dates.length, 1);
    });

    test('records upsertCheckin calls', () async {
      await repo.upsertCheckin(Mood.stressed);
      await repo.upsertCheckin(Mood.happy);
      expect(repo.upsertCheckinCalls.map((c) => c.mood), [Mood.stressed, Mood.happy]);
    });
  });

  group('FakeWrRepository — insights', () {
    test('getLatestInsight returns null when empty', () async {
      expect(await repo.getLatestInsight(), isNull);
    });

    test('getLatestInsight returns last added insight', () async {
      repo.seedInsights([
        Insight(
          id: '1',
          userId: 'u',
          content: 'First',
          savedAt: DateTime(2026, 7, 10),
        ),
        Insight(
          id: '2',
          userId: 'u',
          content: 'Latest',
          savedAt: DateTime(2026, 7, 17),
        ),
      ]);
      final ins = await repo.getLatestInsight();
      expect(ins!.content, 'Latest');
    });

    test('getInsights returns all insights', () async {
      repo.seedInsights([
        Insight(id: 'a', userId: 'u', content: 'A', savedAt: DateTime(2026, 7, 1)),
        Insight(id: 'b', userId: 'u', content: 'B', savedAt: DateTime(2026, 7, 2)),
      ]);
      final list = await repo.getInsights();
      expect(list.length, 2);
    });

    test('countInsights returns correct count', () async {
      repo.seedInsights([
        Insight(id: 'x', userId: 'u', content: 'X', savedAt: DateTime(2026, 7, 1)),
      ]);
      expect(await repo.countInsights(), 1);
    });
  });

  group('FakeWrRepository — practices', () {
    test('getTodayPractices returns seeded practices', () async {
      repo.seedPractices([
        Practice(
          id: 'p1',
          userId: 'u',
          title: 'P1',
          status: PracticeStatus.todo,
          practiceDate: DateTime(2026, 7, 17),
          createdAt: DateTime(2026, 7, 17),
        ),
      ]);
      final list = await repo.getTodayPractices();
      expect(list.length, 1);
      expect(list.first.status, PracticeStatus.todo);
    });

    test('updatePracticeStatus changes status and records the call', () async {
      repo.seedPractices([
        Practice(
          id: 'p1',
          userId: 'u',
          title: 'P1',
          status: PracticeStatus.todo,
          practiceDate: DateTime(2026, 7, 17),
          createdAt: DateTime(2026, 7, 17),
        ),
      ]);
      await repo.updatePracticeStatus('p1', PracticeStatus.done);
      final list = await repo.getTodayPractices();
      expect(list.first.status, PracticeStatus.done);
      expect(repo.updatePracticeStatusCalls, [('p1', PracticeStatus.done)]);
    });
  });

  group('FakeWrRepository — profile', () {
    test('getMobileProfile returns null when not seeded', () async {
      expect(await repo.getMobileProfile(), isNull);
    });

    test('getMobileProfile returns seeded profile', () async {
      repo.seedProfile(MobileProfile(
        userId: 'u',
        reminderEnabled: true,
        language: 'vi',
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ));
      final profile = await repo.getMobileProfile();
      expect(profile!.userId, 'u');
      expect(profile.language, 'vi');
    });

    test('updateReminder records call', () async {
      await repo.updateReminder(false);
      expect(repo.updateReminderCalls, [false]);
    });

    test('updateLanguage records call', () async {
      await repo.updateLanguage('en');
      expect(repo.updateLanguageCalls, ['en']);
    });
  });

  group('FakeWrRepository — SCA report', () {
    test('getLatestScaReport returns null when not seeded', () async {
      expect(await repo.getLatestScaReport(), isNull);
    });

    test('getLatestScaReport returns seeded report', () async {
      repo.seedScaReport(ScaReport(
        id: 'r1',
        userId: 'u',
        scoreStructure: 3.5,
        scoreCulture: 4.0,
        scoreActivity: 2.0,
        createdAt: DateTime(2026, 6, 1),
      ));
      final report = await repo.getLatestScaReport();
      expect(report!.scoreStructure, 3.5);
    });
  });

  group('FakeWrRepository — workshop', () {
    test('getUpcomingWorkshop returns null when not seeded', () async {
      expect(await repo.getUpcomingWorkshop(), isNull);
    });

    test('getUpcomingWorkshop returns seeded workshop', () async {
      repo.seedWorkshop(Workshop(
        id: 'w1',
        title: 'Workshop X',
        date: DateTime(2026, 8, 1),
      ));
      final ws = await repo.getUpcomingWorkshop();
      expect(ws!.title, 'Workshop X');
    });
  });

  group('FakeWrRepository — ensureSeeded and saveOnboardingSituation', () {
    test('ensureSeeded records calls', () async {
      await repo.ensureSeeded(onboardingSituation: 'Mệt mỏi');
      expect(repo.ensureSeededCalls, ['Mệt mỏi']);
    });

    test('ensureSeeded creates profile with displayName on first call (insert path)', () async {
      expect(await repo.getMobileProfile(), isNull);
      await repo.ensureSeeded();
      final profile = await repo.getMobileProfile();
      expect(profile, isNotNull);
      expect(profile!.displayName, isNotNull);
    });

    test('ensureSeeded does NOT overwrite displayName when profile already exists', () async {
      repo.seedProfile(MobileProfile(
        userId: 'u1',
        displayName: 'User Edited Name',
        reminderEnabled: true,
        language: 'vi',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 6, 1),
      ));
      // Simulate a second sign-in event (Google OAuth re-triggering ensureSeeded)
      await repo.ensureSeeded();
      final profile = await repo.getMobileProfile();
      // display_name must NOT be overwritten
      expect(profile!.displayName, 'User Edited Name');
    });

    test('ensureSeeded updates onboardingSituation on existing profile without touching displayName', () async {
      repo.seedProfile(MobileProfile(
        userId: 'u1',
        displayName: 'My Name',
        reminderEnabled: true,
        language: 'vi',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 6, 1),
      ));
      await repo.ensureSeeded(onboardingSituation: 'Mệt mỏi');
      final profile = await repo.getMobileProfile();
      expect(profile!.displayName, 'My Name');
      expect(profile.onboardingSituation, 'Mệt mỏi');
    });

    test('saveOnboardingSituation records calls', () async {
      await repo.saveOnboardingSituation('Muốn thay đổi');
      expect(repo.saveOnboardingSituationCalls, ['Muốn thay đổi']);
    });
  });

  group('FakeWrRepository — exportUserData', () {
    test('returns a map with wr_ table keys', () async {
      final data = await repo.exportUserData();
      expect(data, isA<Map<String, dynamic>>());
      expect(data.containsKey('checkins'), isTrue);
      expect(data.containsKey('insights'), isTrue);
    });
  });
}
