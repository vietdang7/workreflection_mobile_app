import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tiêu đề dạng CÂU (>= 3 tiếng) phải dùng `WrTitleText` để tiếng cuối không
/// rớt xuống dòng một mình, và không được dùng `WrParagraph` (bài học
/// "feeling goo" 11/09: nối cả câu trong ô hẹp thành khối tràn).
String _classBody(String path, String className) {
  final src = File(path).readAsStringSync();
  final start = src.indexOf('class $className');
  expect(start, isNot(-1), reason: 'không tìm thấy $className trong $path');
  final next = src.indexOf('\nclass ', start + 1);
  final body = src.substring(start, next == -1 ? src.length : next);
  return body
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

const _p = 'lib/features/';
const _titles = <(String, String)>[
  ('${_p}wr/presentation/wr_home_screen.dart', '_CheckinQuestionState'),
  ('${_p}wr/presentation/wr_self_check_screen.dart', '_WrSelfCheckScreenState'),
  ('${_p}wr/presentation/wr_payment_screen.dart', '_FreeOrderCard'),
  ('${_p}wr/presentation/wr_payment_screen.dart', '_VoucherListSheetState'),
  ('${_p}wr/presentation/wr_payment_screen.dart', '_ExpiredView'),
  ('${_p}wr/presentation/wr_payment_screen.dart', '_SuccessView'),
  ('${_p}wr/presentation/wr_ask_screen.dart', '_QuestionRow'),
  (
    '${_p}wr/presentation/wr_org_survey_intro_screen.dart',
    'WrOrgSurveyIntroScreen',
  ),
  ('${_p}wr/presentation/wr_org_survey_flow_screen.dart', '_IndustryStep'),
  ('${_p}wr/presentation/wr_org_survey_flow_screen.dart', '_ScaleStep'),
  ('${_p}wr/presentation/wr_org_survey_flow_screen.dart', '_EnpsStep'),
  ('${_p}profile/presentation/profile_screen.dart', '_PremiumCard'),
];

void main() {
  for (final (path, cls) in _titles) {
    test('$cls dựng tiêu đề bằng WrTitleText', () {
      final body = _classBody(path, cls);
      expect(body.contains('WrTitleText('), isTrue);
      // Các lớp khác có thể có đoạn văn thật dùng WrParagraph; chỉ khối câu
      // hỏi Home (toàn tiêu đề) mới cấm hẳn.
      if (cls == '_CheckinQuestionState') {
        expect(body.contains('WrParagraph('), isFalse);
      }
    });
  }
}
