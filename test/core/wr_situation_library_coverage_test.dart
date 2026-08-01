// Coverage test — assets/seed/wr_situations.json must match the
// Career Situation Library (Tầng 1): 10 SCA dimensions × 6 situations = 60,
// cộng 10 tình huống tích cực tự soạn P-01 → P-10 (Hai Lớp v1.6 §2.3).
//
// Spec source: /home/duythong/Desktop/FileTam/workreflection/Career Situation Library.docx
// Mapping fields (expected_outcome, sca_perspective) come from
// WorkReflection_DataSpec_v3.docx Tầng 3.
//
// Nhóm tích cực tách riêng khỏi mọi phép đếm SCA: chúng dùng chung trường
// `sca_dimension` nhưng KHÔNG phải chiều SCA (§2.3), nên lẫn vào là hỏng
// điểm số của trụ mà chúng không thuộc về.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

void main() {
  late List<Map<String, dynamic>> raw;
  late List<Map<String, dynamic>> sca;
  late List<Map<String, dynamic>> positive;

  bool isPositiveRow(Map<String, dynamic> s) =>
      ScaDimension.fromDb(s['sca_dimension'] as String).isPositive;

  setUpAll(() {
    final file = File('assets/seed/wr_situations.json');
    raw = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    sca = raw.where((s) => !isPositiveRow(s)).toList();
    positive = raw.where(isPositiveRow).toList();
  });

  group('Career Situation Library coverage', () {
    test('holds exactly 60 SCA situations', () {
      expect(sca.length, 60);
    });

    test('every SCA dimension has exactly 6 situations', () {
      final counts = <String, int>{};
      for (final s in sca) {
        counts.update(s['sca_dimension'] as String, (v) => v + 1,
            ifAbsent: () => 1);
      }
      expect(counts.length, 10);
      for (final dim in ScaDimension.values.where((d) => d.isSca)) {
        expect(
          counts[dim.dbValue],
          6,
          reason: '${dim.dbValue} must have 6 situations',
        );
      }
    });

    test('SCA codes are unique and follow <DIM>-sit-<NN>', () {
      final codes = raw.map((s) => s['code'] as String).toList();
      expect(codes.toSet().length, codes.length, reason: 'duplicate codes');
      final pattern = RegExp(r'^[SCA][1-4]-sit-\d{2}$');
      for (final s in sca) {
        expect(
          pattern.hasMatch(s['code'] as String),
          isTrue,
          reason: 'bad code: ${s['code']}',
        );
      }
    });

    test('no situation is missing narrative fields', () {
      for (final s in raw) {
        final code = s['code'];
        for (final field in const [
          'text',
          'human_need',
          'expected_outcome',
          'sca_perspective',
        ]) {
          final v = s[field];
          expect(v, isA<String>(), reason: '$code.$field must be a String');
          expect(
            (v as String).trim(),
            isNotEmpty,
            reason: '$code.$field must not be empty',
          );
        }
        expect(s['wave'], inInclusiveRange(1, 3), reason: '$code.wave');
      }
    });

    test('every record parses into WrSituation', () {
      for (final s in raw) {
        final sit = WrSituation.fromJson(s);
        expect(sit.code, s['code']);
        expect(sit.humanNeed, isNotNull);
      }
    });

    test('perspectives never leak internal SCA codes to the user', () {
      // DataSpec v3, ghi chú logic tích hợp #4: "Không dùng mã kỹ thuật như S1
      // hay C2 trực tiếp với người dùng."
      final leak = RegExp(r'\b[SCA][1-4]\b');
      for (final s in raw) {
        for (final field in const [
          'text',
          'expected_outcome',
          'sca_perspective',
        ]) {
          expect(
            leak.hasMatch(s[field] as String),
            isFalse,
            reason: '${s['code']}.$field leaks an internal code',
          );
        }
      }
    });

    test('all 60 Career Situation Library entries are present', () {
      // Tầng 1 của Career Situation Library, theo đúng thứ tự tài liệu.
      const library = <String, List<String>>{
        'S1': [
          'Không rõ mình được kỳ vọng điều gì',
          'Không rõ trách nhiệm thuộc về ai',
          'Vai trò chồng chéo với người khác',
          'Công việc thay đổi liên tục, không ổn định',
          'Không biết thế nào là làm tốt',
          'Không biết ưu tiên điều gì trước',
        ],
        'S2': [
          'Khó phối hợp với phòng ban khác',
          'Người khác làm chậm tiến độ của tôi',
          'Không biết tìm ai khi cần hỗ trợ',
          'Công việc phụ thuộc quá nhiều người',
          'Làm việc nhóm không hiệu quả',
          'Thường xuyên phải làm lại vì hiểu sai',
        ],
        'S3': [
          'Không biết tìm thông tin ở đâu',
          'Thông tin đến quá muộn',
          'Thông tin mâu thuẫn nhau',
          'Không được cập nhật khi có thay đổi',
          'Thiếu dữ liệu để ra quyết định',
          'Luôn cảm thấy mình bị động',
        ],
        'C1': [
          'Không tin đồng nghiệp sẽ hoàn thành việc',
          'Không được cấp trên tin tưởng',
          'Bị kiểm soát quá mức',
          'Khó giao việc cho người khác',
          'Thiếu sự hỗ trợ từ đội nhóm',
          'Cảm thấy phải tự làm mọi thứ',
        ],
        'C2': [
          'Không dám lên tiếng',
          'Không được lắng nghe',
          'Ý kiến bị bỏ qua',
          'Sợ phản hồi cấp trên',
          'Sợ mắc lỗi trước tập thể',
          'Tiếng nói của mình không có giá trị',
        ],
        'C3': [
          'Có mâu thuẫn nhưng không thể nói ra',
          'Tránh các cuộc trò chuyện khó',
          'Phản hồi dễ trở thành tranh cãi',
          'Không hiểu nhau dù đã trao đổi',
          'Không biết cách góp ý',
          'Bầu không khí căng thẳng kéo dài',
        ],
        'A1': [
          'Không hiểu mục tiêu chung của tổ chức',
          'Không biết công việc mình đóng góp điều gì',
          'Làm rất nhiều nhưng không thấy ý nghĩa',
          'Không chắc mình đang đi đúng hướng',
          'Mục tiêu thay đổi liên tục mà không giải thích',
          'Muốn chuyển việc vì không còn thấy phù hợp',
        ],
        'A2': [
          'Luôn bận nhưng không hiệu quả',
          'Công việc liên tục bị gián đoạn',
          'Không hoàn thành được việc quan trọng',
          'Quá tải công việc',
          'Luôn trong trạng thái chạy theo deadline',
          'Cảm thấy mất kiểm soát với công việc',
        ],
        'A3': [
          'Không biết mình đang tiến bộ hay thụt lùi',
          'Liên tục lặp lại cùng một vấn đề',
          'Không hiểu nguyên nhân của sự thất vọng',
          'Đưa ra quyết định theo cảm xúc',
          'Không có thời gian nhìn lại',
          'Cảm thấy bị mắc kẹt',
        ],
        'A4': [
          'Mắc lại cùng một sai lầm',
          'Học nhiều nhưng khó áp dụng',
          'Không biến trải nghiệm thành bài học',
          'Không biết bước tiếp theo để phát triển',
          'Muốn thăng tiến nhưng thiếu định hướng',
          'Muốn chuyển nghề nhưng chưa rõ con đường',
        ],
      };

      final present = <String, Set<String>>{};
      for (final s in raw) {
        present
            .putIfAbsent(s['sca_dimension'] as String, () => <String>{})
            .add(s['text'] as String);
      }

      library.forEach((dim, texts) {
        for (final t in texts) {
          expect(
            present[dim],
            contains(t),
            reason: 'missing situation $dim: "$t"',
          );
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // Nhóm tình huống tích cực — Hai Lớp v1.6 §2.3.
  //
  // Vì sao cần nhóm này: Career Situation Library và DataSpec v3 chỉ có tình
  // huống dạng vấn đề. Check-in "khá ổn" / "đang vui" mà vẫn lọc vào chiều S/C/A
  // thì gợi ý ra toàn tình huống vấn đề, người dùng thấy gượng ép.
  // -------------------------------------------------------------------------

  group('Tình huống tích cực (v1.6 §2.3)', () {
    test('có đúng 10 mục, chia đều hai nhóm', () {
      expect(positive.length, 10);

      final achieve = positive
          .where((s) => s['sca_dimension'] == 'P-ACHIEVE')
          .toList();
      final steady =
          positive.where((s) => s['sca_dimension'] == 'P-STEADY').toList();

      // §2.3: P-ACHIEVE = thành tựu (cảm xúc "Đang vui"),
      //       P-STEADY  = ổn định  (cảm xúc "Khá ổn").
      // Lệch số lượng thì một trong hai cảm xúc sẽ không đủ 5 gợi ý và bộ lọc
      // ở §III phải mở rộng ra toàn thư viện, tức là rơi lại vào tình huống
      // vấn đề — đúng cái lỗi nhóm này sinh ra để chữa.
      expect(achieve.length, 5, reason: 'P-ACHIEVE phải có đúng 5 tình huống');
      expect(steady.length, 5, reason: 'P-STEADY phải có đúng 5 tình huống');
    });

    test('mã theo dạng P-NN, đánh số liên tục 01 đến 10', () {
      final codes = positive.map((s) => s['code'] as String).toList()..sort();
      expect(
        codes,
        List.generate(10, (i) => 'P-${(i + 1).toString().padLeft(2, '0')}'),
      );
    });

    test('need luôn là phat_trien', () {
      // §2.3: nhóm tích cực gắn need "Phát triển" theo thuật ngữ DataSpec v3,
      // không dùng Clarity/Connection/Adaptability vì Career Situation Library
      // không có khái niệm tích cực để đối chiếu.
      for (final s in positive) {
        expect(
          s['human_need'],
          'phat_trien',
          reason: '${s['code']} phải có need phat_trien',
        );
      }
    });

    test('thuộc wave 1 để có mặt ngay đợt đầu', () {
      // "Khá ổn" và "Đang vui" là 2 trong 4 lựa chọn check-in ở Home, nên nhóm
      // này không thể chờ đợt 2 hay 3.
      for (final s in positive) {
        expect(s['wave'], 1, reason: '${s['code']} phải ở wave 1');
      }
    });

    test('nhãn chip ở ngôi "tôi" theo §9.2', () {
      // Situation là tiếng nói nội tâm của người dùng, không phải lời nhắc từ
      // ứng dụng. Nhãn chip mở đầu bằng "Bạn" là sai ngôi.
      for (final s in positive) {
        final text = s['text'] as String;
        expect(
          RegExp(r'\bBạn\b').hasMatch(text),
          isFalse,
          reason: '${s['code']}.text dùng ngôi "bạn": "$text"',
        );
      }
    });

    test('mỗi mục đều parse được thành WrSituation và đánh dấu isPositive', () {
      for (final s in positive) {
        final sit = WrSituation.fromJson(s);
        expect(sit.scaDimension.isPositive, isTrue);
        expect(sit.scaDimension.isSca, isFalse);
        expect(sit.humanNeed, HumanNeed.phatTrien);
      }
    });
  });
}
