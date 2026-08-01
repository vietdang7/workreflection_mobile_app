// Tests for WR Intelligence models + enums (Task 5).
// TDD: model round-trip fromJson/toInsert + enum error handling.
// Run: flutter test test/core/models/wr_intelligence_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

import '../../support/fake_wr_intelligence_repository.dart';

void main() {
  // ---------------------------------------------------------------------------
  // WrPlan enum
  // ---------------------------------------------------------------------------
  group('WrPlan', () {
    test('dbValue returns correct strings', () {
      expect(WrPlan.free.dbValue, 'free');
      expect(WrPlan.premium.dbValue, 'premium');
    });

    test('fromDb parses all valid values', () {
      expect(WrPlan.fromDb('free'), WrPlan.free);
      expect(WrPlan.fromDb('premium'), WrPlan.premium);
    });

    test('fromDb throws ArgumentError for unknown value', () {
      expect(() => WrPlan.fromDb('gold'), throwsA(isA<ArgumentError>()));
    });

    test('roundtrip fromDb(dbValue)', () {
      for (final plan in WrPlan.values) {
        expect(WrPlan.fromDb(plan.dbValue), plan);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ReflectionStepType enum
  // ---------------------------------------------------------------------------
  group('ReflectionStepType', () {
    test('dbValue returns correct strings', () {
      expect(ReflectionStepType.notice.dbValue, 'notice');
      expect(ReflectionStepType.meaning.dbValue, 'meaning');
      expect(ReflectionStepType.insight.dbValue, 'insight');
      expect(ReflectionStepType.choice.dbValue, 'choice');
      expect(ReflectionStepType.action.dbValue, 'action');
    });

    test('has exactly 5 values', () {
      expect(ReflectionStepType.values.length, 5);
    });

    test('fromDb parses all valid values', () {
      expect(ReflectionStepType.fromDb('notice'), ReflectionStepType.notice);
      expect(ReflectionStepType.fromDb('meaning'), ReflectionStepType.meaning);
      expect(ReflectionStepType.fromDb('insight'), ReflectionStepType.insight);
      expect(ReflectionStepType.fromDb('choice'), ReflectionStepType.choice);
      expect(ReflectionStepType.fromDb('action'), ReflectionStepType.action);
    });

    test('fromDb throws ArgumentError for unknown value', () {
      expect(
        () => ReflectionStepType.fromDb('reflect'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('roundtrip fromDb(dbValue)', () {
      for (final step in ReflectionStepType.values) {
        expect(ReflectionStepType.fromDb(step.dbValue), step);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // WrEntitlementRecord
  // ---------------------------------------------------------------------------
  group('WrEntitlementRecord', () {
    test('fromJson parses free plan', () {
      final json = {
        'user_id': 'user-1',
        'plan': 'free',
        'valid_until': null,
        'source': null,
        'updated_at': '2026-07-22T00:00:00.000Z',
      };
      final r = WrEntitlementRecord.fromJson(json);
      expect(r.userId, 'user-1');
      expect(r.plan, WrPlan.free);
      expect(r.validUntil, isNull);
      expect(r.isActivePremium, isFalse);
    });

    test('fromJson parses premium plan with future validUntil', () {
      final future = DateTime.now().add(const Duration(days: 30));
      final json = {
        'user_id': 'user-2',
        'plan': 'premium',
        'valid_until': future.toIso8601String(),
        'source': 'stripe',
        'updated_at': '2026-07-22T00:00:00.000Z',
      };
      final r = WrEntitlementRecord.fromJson(json);
      expect(r.plan, WrPlan.premium);
      expect(r.validUntil, isNotNull);
      expect(r.isActivePremium, isTrue);
    });

    test('isActivePremium false when validUntil in past', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final json = {
        'user_id': 'user-3',
        'plan': 'premium',
        'valid_until': past.toIso8601String(),
        'source': 'stripe',
        'updated_at': '2026-07-22T00:00:00.000Z',
      };
      final r = WrEntitlementRecord.fromJson(json);
      expect(r.isActivePremium, isFalse);
    });

    test('isActivePremium true when premium with null validUntil (perpetual)', () {
      final json = {
        'user_id': 'user-4',
        'plan': 'premium',
        'valid_until': null,
        'source': 'manual',
        'updated_at': '2026-07-22T00:00:00.000Z',
      };
      final r = WrEntitlementRecord.fromJson(json);
      expect(r.isActivePremium, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // ReflectionStep
  // ---------------------------------------------------------------------------
  group('ReflectionStep', () {
    final fullJson = {
      'id': 'step-1',
      'user_id': 'user-1',
      'memory_event_id': 'event-1',
      'step': 'notice',
      'content': 'Tôi nhận ra rằng...',
      'created_at': '2026-07-22T00:00:00.000Z',
    };

    test('fromJson parses correctly', () {
      final s = ReflectionStep.fromJson(fullJson);
      expect(s.id, 'step-1');
      expect(s.userId, 'user-1');
      expect(s.memoryEventId, 'event-1');
      expect(s.step, ReflectionStepType.notice);
      expect(s.content, 'Tôi nhận ra rằng...');
    });

    test('toInsert contains required fields and omits id/created_at', () {
      final s = ReflectionStep.fromJson(fullJson);
      final insert = s.toInsert();
      expect(insert['user_id'], 'user-1');
      expect(insert['step'], 'notice');
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('created_at'), isFalse);
    });

    test('fromJson handles null optional fields', () {
      final sparse = {
        'id': 'step-2',
        'user_id': 'user-1',
        'memory_event_id': null,
        'step': 'action',
        'content': null,
        'created_at': null,
      };
      final s = ReflectionStep.fromJson(sparse);
      expect(s.memoryEventId, isNull);
      expect(s.content, isNull);
      expect(s.createdAt, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // WrInsight
  // ---------------------------------------------------------------------------
  group('WrInsight', () {
    final fullJson = {
      'id': 'ins-1',
      'user_id': 'user-1',
      'source': 'story',
      'sca_dimension': 'A1',
      'human_need': 'phat_trien',
      'content': 'Insight content here',
      'created_at': '2026-07-22T00:00:00.000Z',
    };

    test('fromJson parses correctly', () {
      final i = WrInsight.fromJson(fullJson);
      expect(i.userId, 'user-1');
      expect(i.source, 'story');
      expect(i.scaDimension, ScaDimension.a1);
      expect(i.humanNeed, HumanNeed.phatTrien);
      expect(i.content, 'Insight content here');
    });

    test('toInsert omits id and created_at', () {
      final i = WrInsight.fromJson(fullJson);
      final insert = i.toInsert();
      expect(insert['user_id'], 'user-1');
      expect(insert['content'], 'Insight content here');
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('created_at'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // ScaSelfCheckResponse
  // ---------------------------------------------------------------------------
  group('ScaSelfCheckResponse', () {
    final fullJson = {
      'id': 'scr-1',
      'user_id': 'user-1',
      'answers': {'q1': 3, 'q2': 4, 'q3': 5},
      'structure_score': 4.5,
      'culture_score': 3.2,
      'activity_score': 2.8,
      'taken_at': '2026-07-22T00:00:00.000Z',
    };

    test('fromJson parses correctly', () {
      final r = ScaSelfCheckResponse.fromJson(fullJson);
      expect(r.userId, 'user-1');
      expect(r.answers['q1'], 3);
      expect(r.structureScore, closeTo(4.5, 0.001));
      expect(r.cultureScore, closeTo(3.2, 0.001));
      expect(r.activityScore, closeTo(2.8, 0.001));
    });

    test('toInsert omits id and taken_at', () {
      final r = ScaSelfCheckResponse.fromJson(fullJson);
      final insert = r.toInsert();
      expect(insert['user_id'], 'user-1');
      expect(insert['answers'], isA<Map>());
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('taken_at'), isFalse);
    });

    test('fromJson handles null scores', () {
      final sparse = {
        'id': 'scr-2',
        'user_id': 'user-1',
        'answers': <String, dynamic>{},
        'structure_score': null,
        'culture_score': null,
        'activity_score': null,
        'taken_at': '2026-07-22T00:00:00.000Z',
      };
      final r = ScaSelfCheckResponse.fromJson(sparse);
      expect(r.structureScore, isNull);
      expect(r.cultureScore, isNull);
      expect(r.activityScore, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // PracticeStep
  // ---------------------------------------------------------------------------
  group('PracticeStep', () {
    test('fromJson parses isPremium correctly', () {
      final json = {
        'step_id': 'st-1',
        'theme_id': 'theme-1',
        'step_order': 1,
        'title': 'Step 1',
        'content': 'Content here',
        'is_premium': false,
        'created_at': '2026-07-22T00:00:00.000Z',
      };
      final step = PracticeStep.fromJson(json);
      expect(step.isPremium, isFalse);
      expect(step.stepOrder, 1);
    });

    test('fromJson parses premium step', () {
      final json = {
        'step_id': 'st-2',
        'theme_id': 'theme-1',
        'step_order': 3,
        'title': 'Premium Step',
        'content': 'Deep dive',
        'is_premium': true,
        'created_at': null,
      };
      final step = PracticeStep.fromJson(json);
      expect(step.isPremium, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // PracticeEnrollment toInsert
  // ---------------------------------------------------------------------------
  group('PracticeEnrollment', () {
    test('toInsert contains only user_id and theme_id', () {
      const e = PracticeEnrollment(
        id: 'enroll-1',
        userId: 'user-1',
        themeId: 'theme-1',
        startedAt: null,
        completedAt: null,
      );
      final insert = e.toInsert();
      expect(insert['user_id'], 'user-1');
      expect(insert['theme_id'], 'theme-1');
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('started_at'), isFalse);
      expect(insert.containsKey('completed_at'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // WrContextDocument toInsert
  // ---------------------------------------------------------------------------
  group('WrContextDocument', () {
    test('toInsert omits id and uploaded_at', () {
      const d = WrContextDocument(
        id: 'doc-1',
        userId: 'user-1',
        docType: 'cv',
        filePath: '/uploads/cv.pdf',
        uploadedAt: null,
      );
      final insert = d.toInsert();
      expect(insert['user_id'], 'user-1');
      expect(insert['file_path'], '/uploads/cv.pdf');
      expect(insert['doc_type'], 'cv');
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('uploaded_at'), isFalse);
    });
  });

  // Bắt được khi chạy thật 2026-07-28: migration 20260728000000 nới check
  // constraint sca_dimension cho bốn bảng nhưng sót wr_reflection_insights, nên
  // phản tư trên tình huống tích cực bị Supabase trả 400. Không test nào thấy
  // vì fake repository nhận mọi giá trị.
  group('Hợp đồng với check constraint của DB', () {
    test('mọi ScaDimension đều nằm trong miền giá trị DB chấp nhận', () {
      for (final dim in ScaDimension.values) {
        expect(
          kAllowedScaDimensions,
          contains(dim.dbValue),
          reason: '${dim.dbValue} có trong enum nhưng chưa được thêm vào check '
              'constraint — thêm chiều mới thì phải nới constraint kèm theo, '
              'nếu không mọi lần ghi chiều đó sẽ bị DB từ chối.',
        );
      }
    });

    test('hai nhóm tích cực của v1.6 §2.2 nằm trong miền giá trị', () {
      expect(kAllowedScaDimensions, containsAll(['P-ACHIEVE', 'P-STEADY']));
    });

    test('luồng Episode ghi source mà DB chấp nhận', () {
      // Giá trị này là thứ EpisodeFlowController.confirmMeaning gửi đi.
      expect(kAllowedInsightSources, contains('episode'));
    });

    // Đọc thẳng file SQL chứ không chép tay danh sách bảng vào test: chép tay
    // thì test chỉ xác nhận chính nó, đúng loại test đã KHÔNG bắt được hai lỗi
    // 400 hôm nay.
    test('mọi bảng app có ghi sca_dimension đều đã nới cho nhóm tích cực', () {
      // Bảng app thực sự INSERT/UPDATE sca_dimension xuống.
      // wr_practice_themes và wr_situations/wr_stories không có ở đây vì app
      // chỉ đọc chúng — nội dung do migration seed.
      const written = [
        'wr_reflection_episodes',
        'wr_reflection_insights',
        'wr_career_memory_events',
        'wr_pattern_counts',
      ];

      final files = Directory('supabase/migrations').listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      final sql = [
        for (final f in files)
          if (f.path.endsWith('.sql')) File(f.path).readAsStringSync(),
      ].join('\n');

      for (final table in written) {
        final scoped = _lastScaConstraintFor(sql, table);
        expect(
          scoped,
          isNotNull,
          reason: 'không tìm thấy constraint sca_dimension nào cho $table',
        );
        for (final dim in ScaDimension.values.where((d) => d.isPositive)) {
          expect(
            scoped,
            contains("'${dim.dbValue}'"),
            reason: '$table chưa nhận ${dim.dbValue} — phản tư trên tình huống '
                'tích cực sẽ bị Supabase trả 400.',
          );
        }
      }
    });
  });
}

/// Miền giá trị `sca_dimension` đang có hiệu lực cho [table].
///
/// Một bảng có thể được khai báo ở migration này rồi nới constraint ở migration
/// khác, nên cái có hiệu lực là lần khai báo CUỐI CÙNG theo thứ tự file. Trả về
/// null khi không tìm thấy khai báo nào.
String? _lastScaConstraintFor(String sql, String table) {
  String? found;

  // 1. Khai báo trong CREATE TABLE.
  final created = RegExp(
    'create table if not exists public\\.$table\\s*\\((.*?)\\n\\);',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(sql);
  if (created != null) {
    final inline = RegExp(r'sca_dimension[^,]*?check \(sca_dimension in \(([^)]*)\)')
        .firstMatch(created.group(1)!);
    if (inline != null) found = inline.group(1);
  }

  // 2. Mọi ALTER … ADD CONSTRAINT sau đó — cái sau đè cái trước.
  final altered = RegExp(
    'alter table public\\.$table\\s+add constraint \\w+\\s+'
    r'check \(sca_dimension in \(([^)]*)\)',
    dotAll: true,
    caseSensitive: false,
  ).allMatches(sql);
  for (final m in altered) {
    found = m.group(1);
  }

  return found;
}
