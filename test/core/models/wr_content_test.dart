// Tests for WrSituation, WrStory, CareerMemoryEvent models + HumanNeed/ScaDimension enums.
// TDD: these tests are written BEFORE production code.
// Run: flutter test test/core/models/wr_content_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

void main() {
  // ---------------------------------------------------------------------------
  // HumanNeed enum
  // ---------------------------------------------------------------------------

  group('HumanNeed', () {
    test('dbValue returns snake_case string', () {
      expect(HumanNeed.roRang.dbValue, 'ro_rang');
      expect(HumanNeed.ketNoi.dbValue, 'ket_noi');
      expect(HumanNeed.thichNghi.dbValue, 'thich_nghi');
      expect(HumanNeed.phatTrien.dbValue, 'phat_trien');
    });

    test('fromDb parses all valid values', () {
      expect(HumanNeed.fromDb('ro_rang'), HumanNeed.roRang);
      expect(HumanNeed.fromDb('ket_noi'), HumanNeed.ketNoi);
      expect(HumanNeed.fromDb('thich_nghi'), HumanNeed.thichNghi);
      expect(HumanNeed.fromDb('phat_trien'), HumanNeed.phatTrien);
    });

    test('fromDb throws ArgumentError for unknown value', () {
      expect(
        () => HumanNeed.fromDb('unknown_value'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('roundtrip: fromDb(dbValue) returns original enum', () {
      for (final need in HumanNeed.values) {
        expect(HumanNeed.fromDb(need.dbValue), need);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ScaDimension enum
  // ---------------------------------------------------------------------------

  group('ScaDimension', () {
    test('dbValue returns uppercase string like S1, C2, A4', () {
      expect(ScaDimension.s1.dbValue, 'S1');
      expect(ScaDimension.s2.dbValue, 'S2');
      expect(ScaDimension.s3.dbValue, 'S3');
      expect(ScaDimension.c1.dbValue, 'C1');
      expect(ScaDimension.c2.dbValue, 'C2');
      expect(ScaDimension.c3.dbValue, 'C3');
      expect(ScaDimension.a1.dbValue, 'A1');
      expect(ScaDimension.a2.dbValue, 'A2');
      expect(ScaDimension.a3.dbValue, 'A3');
      expect(ScaDimension.a4.dbValue, 'A4');
    });

    test('has 10 SCA dimensions plus 2 positive groups', () {
      // v1.6 §2.2: trường `dim` nhận cả chiều SCA lẫn hai nhóm tình huống tích
      // cực. §2.3: hai nhóm đó KHÔNG phải chiều SCA, nên mọi thống kê SCA phải
      // lọc qua isSca trước.
      expect(ScaDimension.values.length, 12);
      expect(ScaDimension.values.where((d) => d.isSca).length, 10);
      expect(ScaDimension.values.where((d) => d.isPositive).length, 2);
    });

    test('isPositive chỉ đúng với P-ACHIEVE và P-STEADY', () {
      expect(ScaDimension.pAchieve.isPositive, isTrue);
      expect(ScaDimension.pSteady.isPositive, isTrue);
      expect(ScaDimension.c2.isPositive, isFalse);
      expect(ScaDimension.a3.isPositive, isFalse);
    });

    test('dbValue của hai nhóm tích cực khớp check constraint', () {
      expect(ScaDimension.pAchieve.dbValue, 'P-ACHIEVE');
      expect(ScaDimension.pSteady.dbValue, 'P-STEADY');
    });

    test('fromDb parses all valid values', () {
      expect(ScaDimension.fromDb('P-ACHIEVE'), ScaDimension.pAchieve);
      expect(ScaDimension.fromDb('P-STEADY'), ScaDimension.pSteady);
      expect(ScaDimension.fromDb('S1'), ScaDimension.s1);
      expect(ScaDimension.fromDb('S2'), ScaDimension.s2);
      expect(ScaDimension.fromDb('S3'), ScaDimension.s3);
      expect(ScaDimension.fromDb('C1'), ScaDimension.c1);
      expect(ScaDimension.fromDb('C2'), ScaDimension.c2);
      expect(ScaDimension.fromDb('C3'), ScaDimension.c3);
      expect(ScaDimension.fromDb('A1'), ScaDimension.a1);
      expect(ScaDimension.fromDb('A2'), ScaDimension.a2);
      expect(ScaDimension.fromDb('A3'), ScaDimension.a3);
      expect(ScaDimension.fromDb('A4'), ScaDimension.a4);
    });

    test('fromDb throws ArgumentError for unknown value', () {
      expect(
        () => ScaDimension.fromDb('B1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('roundtrip: fromDb(dbValue) returns original enum', () {
      for (final dim in ScaDimension.values) {
        expect(ScaDimension.fromDb(dim.dbValue), dim);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // WrSituation.fromJson
  // ---------------------------------------------------------------------------

  group('WrSituation.fromJson', () {
    // Full record from assets/seed/wr_situations.json (S1-sit-01)
    final fullJson = {
      'code': 'S1-sit-01',
      'text': 'Không rõ mình được kỳ vọng điều gì',
      'sca_dimension': 'S1',
      'human_need': 'ro_rang',
      'expected_outcome':
          'Tôi muốn biết rõ mình cần đạt được điều gì để được coi là làm tốt',
      'sca_perspective':
          'Khi không biết tiêu chí hoàn thành của công việc là gì, người làm giỏi đến đâu cũng khó yên tâm.',
      'wave': 2,
      'created_at': '2026-07-21T00:00:00.000Z',
    };

    test('parses full record correctly', () {
      final sit = WrSituation.fromJson(fullJson);
      expect(sit.code, 'S1-sit-01');
      expect(sit.text, 'Không rõ mình được kỳ vọng điều gì');
      expect(sit.scaDimension, ScaDimension.s1);
      expect(sit.humanNeed, HumanNeed.roRang);
      expect(sit.expectedOutcome, isNotNull);
      expect(sit.scaPerspective, isNotNull);
      expect(sit.wave, 2);
    });

    test('parses record with null nullable fields', () {
      final sparseJson = {
        'code': 'S2-sit-01',
        'text': 'Khó phối hợp với phòng ban khác',
        'sca_dimension': 'S2',
        'human_need': null,
        'expected_outcome': null,
        'sca_perspective': null,
        'wave': 3,
        'created_at': '2026-07-21T00:00:00.000Z',
      };
      final sit = WrSituation.fromJson(sparseJson);
      expect(sit.humanNeed, isNull);
      expect(sit.expectedOutcome, isNull);
      expect(sit.scaPerspective, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // WrStory.fromJson
  // ---------------------------------------------------------------------------

  group('WrStory.fromJson', () {
    // Full record from assets/seed/wr_stories.json (A1-01)
    final fullJson = {
      'story_id': 'A1-01',
      'title': 'Tôi đang đi rất nhanh, nhưng đi đâu?',
      'sca_dimension': 'A1',
      'human_need': 'thich_nghi',
      'situation': 'Không biết mình đang đi đúng hướng không',
      'emotion_tags': ['hoang mang', 'nghi ngờ', 'mất phương hướng'],
      'behavior_tags': ['tìm kiếm định hướng', 'đổi mục tiêu'],
      'career_stages': <String>[],
      'difficulty_level': null,
      'story_content':
          'Bạn vẫn hoàn thành công việc.\nBạn vẫn đạt KPI.\nBạn vẫn được đánh giá tốt.',
      'reflection_question': 'Bạn có đang bận rộn hơn là có định hướng không?',
      'self_reflection': 'Điều gì khiến bạn tin rằng mình đang đi đúng hướng?',
      'aha_message': 'Mất phương hướng không phải là đứng yên.',
      'practice_action': 'Viết ra 3 điều bạn muốn có trong sự nghiệp 3 năm tới.',
      'created_at': '2026-07-21T00:00:00.000Z',
    };

    test('parses full story correctly', () {
      final story = WrStory.fromJson(fullJson);
      expect(story.storyId, 'A1-01');
      expect(story.title, 'Tôi đang đi rất nhanh, nhưng đi đâu?');
      expect(story.scaDimension, ScaDimension.a1);
      expect(story.humanNeed, HumanNeed.thichNghi);
      expect(story.situation, 'Không biết mình đang đi đúng hướng không');
      expect(story.emotionTags, containsAll(['hoang mang', 'nghi ngờ', 'mất phương hướng']));
      expect(story.behaviorTags, containsAll(['tìm kiếm định hướng', 'đổi mục tiêu']));
      expect(story.careerStages, isEmpty);
      expect(story.difficultyLevel, isNull);
      expect(story.storyContent, contains('Bạn vẫn hoàn thành công việc'));
      expect(story.reflectionQuestion, isNotNull);
      expect(story.selfReflection, isNotNull);
      expect(story.ahaMessage, isNotNull);
      expect(story.practiceAction, isNotNull);
    });

    test('parses story with null nullable fields', () {
      final sparseJson = {
        'story_id': 'A2-01',
        'title': 'Tôi biết phải làm gì nhưng vẫn chưa làm',
        'sca_dimension': 'A2',
        'human_need': null,
        'situation': null,
        'emotion_tags': <String>[],
        'behavior_tags': <String>[],
        'career_stages': <String>[],
        'difficulty_level': null,
        'story_content': 'Bạn đã suy nghĩ về việc này nhiều lần.',
        'reflection_question': null,
        'self_reflection': null,
        'aha_message': null,
        'practice_action': null,
        'created_at': '2026-07-21T00:00:00.000Z',
      };
      final story = WrStory.fromJson(sparseJson);
      expect(story.humanNeed, isNull);
      expect(story.situation, isNull);
      expect(story.difficultyLevel, isNull);
      expect(story.reflectionQuestion, isNull);
      expect(story.selfReflection, isNull);
      expect(story.ahaMessage, isNull);
      expect(story.practiceAction, isNull);
      expect(story.emotionTags, isEmpty);
    });

    test('emotion_tags and behavior_tags are List<String>', () {
      final story = WrStory.fromJson(fullJson);
      expect(story.emotionTags, isA<List<String>>());
      expect(story.behaviorTags, isA<List<String>>());
    });
  });

  // ---------------------------------------------------------------------------
  // CareerMemoryEvent.fromJson + toInsert
  // ---------------------------------------------------------------------------

  group('CareerMemoryEvent', () {
    final fullJson = {
      'id': 'abc-123',
      'user_id': 'user-456',
      'story_id': 'A1-01',
      'situation_code': 'A1-sit-01',
      'human_need': 'phat_trien',
      'sca_dimension': 'A1',
      'emotion': 'lo lắng',
      'behavior': 'tìm kiếm định hướng',
      'intensity': 3,
      'reflection_text': 'Tôi cần suy nghĩ lại về mục tiêu của mình.',
      'career_stage': 'mid',
      'created_at': '2026-07-21T00:00:00.000Z',
    };

    test('fromJson parses full record', () {
      final event = CareerMemoryEvent.fromJson(fullJson);
      expect(event.id, 'abc-123');
      expect(event.userId, 'user-456');
      expect(event.storyId, 'A1-01');
      expect(event.situationCode, 'A1-sit-01');
      expect(event.humanNeed, HumanNeed.phatTrien);
      expect(event.scaDimension, ScaDimension.a1);
      expect(event.emotion, 'lo lắng');
      expect(event.behavior, 'tìm kiếm định hướng');
      expect(event.intensity, 3);
      expect(event.reflectionText, 'Tôi cần suy nghĩ lại về mục tiêu của mình.');
      expect(event.careerStage, 'mid');
    });

    test('fromJson handles null optional fields', () {
      final sparseJson = {
        'id': 'def-456',
        'user_id': 'user-789',
        'story_id': null,
        'situation_code': null,
        'human_need': null,
        'sca_dimension': null,
        'emotion': null,
        'behavior': null,
        'intensity': null,
        'reflection_text': null,
        'career_stage': null,
        'created_at': '2026-07-21T00:00:00.000Z',
      };
      final event = CareerMemoryEvent.fromJson(sparseJson);
      expect(event.storyId, isNull);
      expect(event.situationCode, isNull);
      expect(event.humanNeed, isNull);
      expect(event.scaDimension, isNull);
      expect(event.emotion, isNull);
      expect(event.intensity, isNull);
      expect(event.reflectionText, isNull);
    });

    test('toInsert contains required user-writable fields', () {
      final event = CareerMemoryEvent.fromJson(fullJson);
      final insert = event.toInsert();

      expect(insert.containsKey('user_id'), isTrue);
      expect(insert['user_id'], 'user-456');
      expect(insert['story_id'], 'A1-01');
      expect(insert['situation_code'], 'A1-sit-01');
      expect(insert['human_need'], 'phat_trien');
      expect(insert['sca_dimension'], 'A1');
      expect(insert['emotion'], 'lo lắng');
      expect(insert['behavior'], 'tìm kiếm định hướng');
      expect(insert['intensity'], 3);
      expect(insert['reflection_text'], 'Tôi cần suy nghĩ lại về mục tiêu của mình.');
      expect(insert['career_stage'], 'mid');
    });

    test('toInsert does NOT contain id or created_at', () {
      final event = CareerMemoryEvent.fromJson(fullJson);
      final insert = event.toInsert();

      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('created_at'), isFalse);
    });

    test('toInsert with null fields omits or passes null correctly', () {
      final sparseJson = {
        'id': 'xyz',
        'user_id': 'user-1',
        'story_id': null,
        'situation_code': null,
        'human_need': null,
        'sca_dimension': null,
        'emotion': null,
        'behavior': null,
        'intensity': null,
        'reflection_text': null,
        'career_stage': null,
        'created_at': '2026-07-21T00:00:00.000Z',
      };
      final event = CareerMemoryEvent.fromJson(sparseJson);
      final insert = event.toInsert();

      // user_id must always be present
      expect(insert.containsKey('user_id'), isTrue);
      // null fields: either absent or null value (either is acceptable for Supabase)
      // but id and created_at must never appear
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('created_at'), isFalse);
    });
  });
}
