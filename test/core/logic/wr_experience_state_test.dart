// Test cho Experience State Machine — WXS v1.0 §4.4 + HXA §3.6.
// Hai luật cần bảo vệ: không nhảy cóc, và Pattern do hệ thống chọn.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_experience_state.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

void main() {
  group('canTransition — transition hợp lệ (WXS §4.4)', () {
    test('chuỗi chuẩn Emerging → Integrated đi qua đủ mọi bước', () {
      const chain = [
        ExperienceState.emerging,
        ExperienceState.captured,
        ExperienceState.exploring,
        ExperienceState.meaningForming,
        ExperienceState.meaningConfirmed,
        ExperienceState.committed,
        ExperienceState.integrated,
      ];
      for (var i = 0; i < chain.length - 1; i++) {
        expect(
          canTransition(chain[i], chain[i + 1]),
          isTrue,
          reason: '${chain[i].dbValue} → ${chain[i + 1].dbValue} phải hợp lệ',
        );
      }
    });

    test('Meaning Forming quay lại Exploring khi ý nghĩa chưa rõ', () {
      expect(
        canTransition(
          ExperienceState.meaningForming,
          ExperienceState.exploring,
        ),
        isTrue,
      );
    });

    test('Meaning Confirmed vào thẳng Integrated khi không cam kết hành động', () {
      expect(
        canTransition(
          ExperienceState.meaningConfirmed,
          ExperienceState.integrated,
        ),
        isTrue,
      );
    });

    test('Dormant → Reactivated → Exploring (Backward Flow, WXS §3.5)', () {
      expect(
        canTransition(ExperienceState.dormant, ExperienceState.reactivated),
        isTrue,
      );
      expect(
        canTransition(ExperienceState.reactivated, ExperienceState.exploring),
        isTrue,
      );
    });

    test('mọi state đang mở đều có thể tạm dừng thành Dormant', () {
      const pausable = [
        ExperienceState.captured,
        ExperienceState.exploring,
        ExperienceState.meaningForming,
        ExperienceState.meaningConfirmed,
      ];
      for (final state in pausable) {
        expect(
          canTransition(state, ExperienceState.dormant),
          isTrue,
          reason: '${state.dbValue} phải tạm dừng được',
        );
      }
    });
  });

  group('canTransition — nhảy cóc bị chặn (WXS §4.4 bảng transition)', () {
    test('Captured → Committed bị chặn (bỏ qua Reflection)', () {
      expect(
        canTransition(ExperienceState.captured, ExperienceState.committed),
        isFalse,
      );
    });

    test('Emerging → Meaning Forming bị chặn (bỏ qua Captured và Exploring)', () {
      expect(
        canTransition(ExperienceState.emerging, ExperienceState.meaningForming),
        isFalse,
      );
    });

    test('Exploring → Integrated bị chặn (bỏ qua Meaning Confirmed)', () {
      expect(
        canTransition(ExperienceState.exploring, ExperienceState.integrated),
        isFalse,
      );
    });

    test('Captured → Meaning Confirmed bị chặn', () {
      expect(
        canTransition(
          ExperienceState.captured,
          ExperienceState.meaningConfirmed,
        ),
        isFalse,
      );
    });

    test('không state nào quay ngược về Emerging', () {
      for (final state in ExperienceState.values) {
        expect(
          canTransition(state, ExperienceState.emerging),
          isFalse,
          reason: '${state.dbValue} không được quay về emerging',
        );
      }
    });

    test('assertTransition ném StateError khi nhảy cóc', () {
      expect(
        () => assertTransition(
          ExperienceState.captured,
          ExperienceState.committed,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('assertTransition không ném khi hợp lệ', () {
      expect(
        () => assertTransition(
          ExperienceState.captured,
          ExperienceState.exploring,
        ),
        returnsNormally,
      );
    });
  });

  group('ExperienceState.isOpen', () {
    test('Integrated và Dormant là đóng, còn lại là mở', () {
      expect(ExperienceState.integrated.isOpen, isFalse);
      expect(ExperienceState.dormant.isOpen, isFalse);
      expect(ExperienceState.captured.isOpen, isTrue);
      expect(ExperienceState.exploring.isOpen, isTrue);
      expect(ExperienceState.meaningForming.isOpen, isTrue);
      expect(ExperienceState.meaningConfirmed.isOpen, isTrue);
      expect(ExperienceState.committed.isOpen, isTrue);
      expect(ExperienceState.reactivated.isOpen, isTrue);
    });
  });

  group('Pattern sequence — HXA §3.6', () {
    test('cả sáu Archetype đều có chuỗi Pattern', () {
      for (final moment in HumanMoment.values) {
        expect(
          patternSequences[moment],
          isNotNull,
          reason: '${moment.dbValue} phải có chuỗi Pattern',
        );
        expect(patternSequences[moment], isNotEmpty);
      }
    });

    test('mọi chuỗi đều bắt đầu bằng Notice', () {
      for (final moment in HumanMoment.values) {
        expect(
          patternSequences[moment]!.first,
          ReflectionPattern.notice,
          reason: '${moment.dbValue} phải bắt đầu bằng Notice',
        );
      }
    });

    test('Recovery bắt đầu Notice → Explore, không bắt đầu Commit (HXA §3.2)', () {
      final recovery = patternSequences[HumanMoment.recovery]!;
      expect(recovery[0], ReflectionPattern.notice);
      expect(recovery[1], ReflectionPattern.explore);
      expect(recovery.contains(ReflectionPattern.commit), isFalse);
    });

    test('Decision đi hết tới Commit', () {
      expect(
        patternSequences[HumanMoment.decision]!.last,
        ReflectionPattern.commit,
      );
    });

    test('không chuỗi nào lặp lại một Pattern', () {
      for (final moment in HumanMoment.values) {
        final seq = patternSequences[moment]!;
        expect(seq.toSet().length, seq.length, reason: moment.dbValue);
      }
    });
  });

  group('nextPattern', () {
    test('chưa làm gì → trả về Pattern đầu tiên', () {
      expect(
        nextPattern(HumanMoment.arrival, const []),
        ReflectionPattern.notice,
      );
    });

    test('đã Notice → trả về Pattern kế tiếp của archetype', () {
      expect(
        nextPattern(HumanMoment.arrival, const [ReflectionPattern.notice]),
        ReflectionPattern.name,
      );
      expect(
        nextPattern(HumanMoment.recovery, const [ReflectionPattern.notice]),
        ReflectionPattern.explore,
      );
    });

    test('đi hết chuỗi → trả về null', () {
      final full = patternSequences[HumanMoment.celebration]!;
      expect(nextPattern(HumanMoment.celebration, full), isNull);
    });

    test('bỏ qua thứ tự vẫn trả về Pattern còn thiếu sớm nhất', () {
      // Người dùng đã Explore trước Name — hệ thống vẫn quay lại đòi Name.
      expect(
        nextPattern(
          HumanMoment.confusion,
          const [ReflectionPattern.notice, ReflectionPattern.explore],
        ),
        ReflectionPattern.name,
      );
    });

    test('patternCount khớp độ dài chuỗi', () {
      for (final moment in HumanMoment.values) {
        expect(patternCount(moment), patternSequences[moment]!.length);
      }
    });
  });

  group('promptFor', () {
    test('mọi cặp (Archetype × Pattern trong chuỗi) đều có câu hỏi riêng', () {
      for (final moment in HumanMoment.values) {
        for (final pattern in patternSequences[moment]!) {
          final prompt = promptFor(moment, pattern);
          expect(prompt, isNotEmpty);
          expect(prompt, isNot('Bạn đang nghĩ gì?'),
              reason: '${moment.dbValue}/${pattern.dbValue} thiếu câu hỏi riêng');
        }
      }
    });

    // Ba luật rút từ mục tiêu của từng Pattern (HXA §3.5). Vi phạm luật nào
    // cũng cho ra câu trả lời cụt — đây là thứ đã làm hỏng nhánh Growth.

    test('Explore không hỏi một mốc thời gian', () {
      // "Lần gần nhất … là khi nào?" chỉ nhận về một cái ngày. Explore cần
      // Surface → Depth.
      for (final moment in HumanMoment.values) {
        if (!patternSequences[moment]!.contains(ReflectionPattern.explore)) {
          continue;
        }
        final prompt = promptFor(moment, ReflectionPattern.explore);
        expect(prompt.contains('khi nào'), isFalse,
            reason: '${moment.dbValue}/explore đang hỏi mốc thời gian');
      }
    });

    test('Preserve không lặp lại câu hỏi của bước Ý nghĩa', () {
      // Bước Ý nghĩa đã hỏi "giữ lại điều gì". Preserve phải giữ một chi tiết
      // cụ thể, không phải bài học.
      for (final moment in HumanMoment.values) {
        if (!patternSequences[moment]!.contains(ReflectionPattern.preserve)) {
          continue;
        }
        final prompt = promptFor(moment, ReflectionPattern.preserve);
        expect(prompt.contains('giữ lại'), isFalse,
            reason: '${moment.dbValue}/preserve trùng bước Ý nghĩa');
      }
    });

    test('mọi bước đều có nửa câu mở đầu gợi ý', () {
      for (final moment in HumanMoment.values) {
        for (final pattern in patternSequences[moment]!) {
          final hint = promptHintFor(moment, pattern);
          expect(hint, isNotEmpty);
          expect(hint, isNot('Viết vài dòng cho riêng bạn…'),
              reason: '${moment.dbValue}/${pattern.dbValue} thiếu gợi ý');
          expect(hint.endsWith('…'), isTrue,
              reason: '$hint phải là nửa câu bỏ lửng');
        }
      }
    });
  });

  group('HumanMoment — HXA §2.5', () {
    test('đúng sáu archetype, không hơn', () {
      expect(HumanMoment.values.length, 6);
    });

    test('mỗi archetype có nhãn và Reflection Tension', () {
      for (final moment in HumanMoment.values) {
        expect(moment.label, isNotEmpty);
        expect(moment.tension, isNotEmpty);
      }
    });

    test('dbValue đi và về không đổi', () {
      for (final moment in HumanMoment.values) {
        expect(HumanMoment.fromDb(moment.dbValue), moment);
      }
    });
  });

  group('ReflectionPattern — HXA §3.5', () {
    test('đúng sáu pattern, không hơn', () {
      expect(ReflectionPattern.values.length, 6);
    });

    test('dbValue đi và về không đổi', () {
      for (final pattern in ReflectionPattern.values) {
        expect(ReflectionPattern.fromDb(pattern.dbValue), pattern);
      }
    });
  });

  group('ExperienceState — WXS §4.2', () {
    test('đúng chín state', () {
      expect(ExperienceState.values.length, 9);
    });

    test('dbValue đi và về không đổi', () {
      for (final state in ExperienceState.values) {
        expect(ExperienceState.fromDb(state.dbValue), state);
      }
    });
  });
}
