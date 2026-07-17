import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/recurring_situation.dart';
import 'package:workreflection_mobile/core/models/development_theme.dart';
import 'package:workreflection_mobile/core/models/practice.dart';
import 'package:workreflection_mobile/core/models/timeline_event.dart';
import 'package:workreflection_mobile/core/models/sca_report.dart';
import 'package:workreflection_mobile/core/models/workshop.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';

void main() {
  group('Mood enum', () {
    test('dbValues match migration check constraint', () {
      expect(Mood.stressed.dbValue, 'stressed');
      expect(Mood.tired.dbValue, 'tired');
      expect(Mood.okay.dbValue, 'okay');
      expect(Mood.happy.dbValue, 'happy');
    });

    test('Mood.fromDb parses all valid values', () {
      expect(Mood.fromDb('stressed'), Mood.stressed);
      expect(Mood.fromDb('tired'), Mood.tired);
      expect(Mood.fromDb('okay'), Mood.okay);
      expect(Mood.fromDb('happy'), Mood.happy);
    });

    test('Mood.fromDb throws on unknown value', () {
      expect(() => Mood.fromDb('unknown'), throwsArgumentError);
    });
  });

  group('PracticeStatus enum', () {
    test('dbValues match migration check constraint', () {
      expect(PracticeStatus.todo.dbValue, 'todo');
      expect(PracticeStatus.doing.dbValue, 'doing');
      expect(PracticeStatus.done.dbValue, 'done');
    });

    test('PracticeStatus.fromDb parses all valid values', () {
      expect(PracticeStatus.fromDb('todo'), PracticeStatus.todo);
      expect(PracticeStatus.fromDb('doing'), PracticeStatus.doing);
      expect(PracticeStatus.fromDb('done'), PracticeStatus.done);
    });
  });

  group('TimelineEventType enum', () {
    test('values match migration check constraint', () {
      expect(TimelineEventType.milestone.dbValue, 'MILESTONE');
      expect(TimelineEventType.story.dbValue, 'STORY');
      expect(TimelineEventType.theme.dbValue, 'THEME');
    });

    test('TimelineEventType.fromDb parses all valid values', () {
      expect(TimelineEventType.fromDb('MILESTONE'), TimelineEventType.milestone);
      expect(TimelineEventType.fromDb('STORY'), TimelineEventType.story);
      expect(TimelineEventType.fromDb('THEME'), TimelineEventType.theme);
    });
  });

  group('Checkin.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'abc-123',
        'user_id': 'user-456',
        'mood': 'happy',
        'checkin_date': '2026-07-17',
        'created_at': '2026-07-17T10:00:00.000Z',
      };
      final checkin = Checkin.fromJson(json);
      expect(checkin.id, 'abc-123');
      expect(checkin.userId, 'user-456');
      expect(checkin.mood, Mood.happy);
      expect(checkin.checkinDate, DateTime(2026, 7, 17));
      expect(checkin.createdAt, isNotNull);
    });
  });

  group('Insight.fromJson', () {
    test('parses required fields', () {
      final json = {
        'id': 'ins-1',
        'user_id': 'user-1',
        'content': 'Some insight',
        'source': 'VOICE',
        'saved_at': '2026-07-10T08:00:00.000Z',
      };
      final insight = Insight.fromJson(json);
      expect(insight.id, 'ins-1');
      expect(insight.content, 'Some insight');
      expect(insight.source, 'VOICE');
      expect(insight.savedAt, isA<DateTime>());
    });

    test('source is nullable', () {
      final json = {
        'id': 'ins-2',
        'user_id': 'user-1',
        'content': 'Another insight',
        'source': null,
        'saved_at': '2026-07-10T08:00:00.000Z',
      };
      final insight = Insight.fromJson(json);
      expect(insight.source, isNull);
    });
  });

  group('RecurringSituation.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'rs-1',
        'user_id': 'user-1',
        'label': 'Ngại phản biện',
        'occurrence_count': 5,
        'updated_at': '2026-07-15T00:00:00.000Z',
      };
      final rs = RecurringSituation.fromJson(json);
      expect(rs.id, 'rs-1');
      expect(rs.label, 'Ngại phản biện');
      expect(rs.occurrenceCount, 5);
      expect(rs.updatedAt, isA<DateTime>());
    });
  });

  group('DevelopmentTheme.fromJson', () {
    test('parses all fields including nullable subtitle', () {
      final json = {
        'id': 'dt-1',
        'user_id': 'user-1',
        'code': 'VOICE',
        'title': 'Khả năng lên tiếng',
        'subtitle': 'Phát triển kỹ năng',
        'stage': 2,
        'total_stages': 4,
        'progress': 0.55,
        'is_active': true,
        'created_at': '2026-07-01T00:00:00.000Z',
      };
      final dt = DevelopmentTheme.fromJson(json);
      expect(dt.code, 'VOICE');
      expect(dt.stage, 2);
      expect(dt.totalStages, 4);
      expect(dt.progress, 0.55);
      expect(dt.isActive, true);
      expect(dt.subtitle, 'Phát triển kỹ năng');
    });

    test('subtitle is nullable', () {
      final json = {
        'id': 'dt-2',
        'user_id': 'user-1',
        'code': 'FOCUS',
        'title': 'Focus theme',
        'subtitle': null,
        'stage': 1,
        'total_stages': 3,
        'progress': 0.0,
        'is_active': false,
        'created_at': '2026-07-01T00:00:00.000Z',
      };
      final dt = DevelopmentTheme.fromJson(json);
      expect(dt.subtitle, isNull);
      expect(dt.isActive, false);
    });

    test('progress handles int from JSON (Supabase numeric may return int)', () {
      final json = {
        'id': 'dt-3',
        'user_id': 'user-1',
        'code': 'X',
        'title': 'T',
        'subtitle': null,
        'stage': 1,
        'total_stages': 4,
        'progress': 1, // int not double
        'is_active': true,
        'created_at': '2026-07-01T00:00:00.000Z',
      };
      final dt = DevelopmentTheme.fromJson(json);
      expect(dt.progress, 1.0);
    });
  });

  group('Practice.fromJson', () {
    test('parses status enum and nullable completed_at', () {
      final json = {
        'id': 'pr-1',
        'user_id': 'user-1',
        'theme_id': 'dt-1',
        'title': 'Quan sát',
        'status': 'done',
        'practice_date': '2026-07-17',
        'completed_at': '2026-07-17T09:00:00.000Z',
        'created_at': '2026-07-17T08:00:00.000Z',
      };
      final p = Practice.fromJson(json);
      expect(p.status, PracticeStatus.done);
      expect(p.completedAt, isNotNull);
      expect(p.themeId, 'dt-1');
    });

    test('completed_at is nullable', () {
      final json = {
        'id': 'pr-2',
        'user_id': 'user-1',
        'theme_id': null,
        'title': 'Todo practice',
        'status': 'todo',
        'practice_date': '2026-07-17',
        'completed_at': null,
        'created_at': '2026-07-17T08:00:00.000Z',
      };
      final p = Practice.fromJson(json);
      expect(p.status, PracticeStatus.todo);
      expect(p.completedAt, isNull);
      expect(p.themeId, isNull);
    });
  });

  group('TimelineEvent.fromJson', () {
    test('parses event_type enum and nullable description', () {
      final json = {
        'id': 'te-1',
        'user_id': 'user-1',
        'event_type': 'MILESTONE',
        'title': 'Insight đầu tiên',
        'description': 'Some description',
        'occurred_at': '2026-07-03',
        'created_at': '2026-07-03T00:00:00.000Z',
      };
      final te = TimelineEvent.fromJson(json);
      expect(te.eventType, TimelineEventType.milestone);
      expect(te.description, 'Some description');
      expect(te.occurredAt, DateTime(2026, 7, 3));
    });

    test('description is nullable', () {
      final json = {
        'id': 'te-2',
        'user_id': 'user-1',
        'event_type': 'STORY',
        'title': 'Story title',
        'description': null,
        'occurred_at': '2026-07-05',
        'created_at': '2026-07-05T00:00:00.000Z',
      };
      final te = TimelineEvent.fromJson(json);
      expect(te.eventType, TimelineEventType.story);
      expect(te.description, isNull);
    });
  });

  group('ScaReport.fromJson', () {
    test('maps cc_reports columns (score_structure, score_culture, score_activity)', () {
      final json = {
        'id': 'sca-1',
        'user_id': 'user-1',
        'score_structure': 3.5,
        'score_culture': 4.0,
        'score_activity': 2.0,
        'created_at': '2026-06-01T00:00:00.000Z',
      };
      final report = ScaReport.fromJson(json);
      expect(report.scoreStructure, 3.5);
      expect(report.scoreCulture, 4.0);
      expect(report.scoreActivity, 2.0);
      expect(report.createdAt, isA<DateTime>());
    });

    test('handles int scores (numeric may return int from Supabase)', () {
      final json = {
        'id': 'sca-2',
        'user_id': 'user-1',
        'score_structure': 4,
        'score_culture': 3,
        'score_activity': 2,
        'created_at': '2026-06-01T00:00:00.000Z',
      };
      final report = ScaReport.fromJson(json);
      expect(report.scoreStructure, 4.0);
      expect(report.scoreCulture, 3.0);
      expect(report.scoreActivity, 2.0);
    });
  });

  group('Workshop.fromJson', () {
    test('maps cc_workshops columns', () {
      final json = {
        'id': 'ws-1',
        'title': 'Workshop Title',
        'category': 'Leadership',
        'date': '2026-08-01',
        'starts_at': '2026-08-01T09:00:00.000Z',
      };
      final ws = Workshop.fromJson(json);
      expect(ws.id, 'ws-1');
      expect(ws.title, 'Workshop Title');
      expect(ws.category, 'Leadership');
      expect(ws.date, DateTime(2026, 8, 1));
      expect(ws.startsAt, isNotNull);
    });

    test('category and starts_at are nullable', () {
      final json = {
        'id': 'ws-2',
        'title': 'Basic Workshop',
        'category': null,
        'date': '2026-09-01',
        'starts_at': null,
      };
      final ws = Workshop.fromJson(json);
      expect(ws.category, isNull);
      expect(ws.startsAt, isNull);
    });
  });

  group('MobileProfile.fromJson', () {
    test('maps wr_mobile_profiles columns', () {
      final json = {
        'user_id': 'user-1',
        'display_name': 'Duy Thong',
        'onboarding_situation': 'Mệt nhưng không biết tại sao',
        'reminder_enabled': true,
        'language': 'vi',
        'created_at': '2026-07-01T00:00:00.000Z',
        'updated_at': '2026-07-17T00:00:00.000Z',
      };
      final profile = MobileProfile.fromJson(json);
      expect(profile.userId, 'user-1');
      expect(profile.displayName, 'Duy Thong');
      expect(profile.onboardingSituation, 'Mệt nhưng không biết tại sao');
      expect(profile.reminderEnabled, true);
      expect(profile.language, 'vi');
    });

    test('nullable fields', () {
      final json = {
        'user_id': 'user-2',
        'display_name': null,
        'onboarding_situation': null,
        'reminder_enabled': false,
        'language': 'en',
        'created_at': '2026-07-01T00:00:00.000Z',
        'updated_at': '2026-07-01T00:00:00.000Z',
      };
      final profile = MobileProfile.fromJson(json);
      expect(profile.displayName, isNull);
      expect(profile.onboardingSituation, isNull);
      expect(profile.reminderEnabled, false);
    });
  });
}
