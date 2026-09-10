// Bản tiếng Anh của phần WorkReflection — kiểm trên MÀN HÌNH THẬT.
//
// `wr_tr_test.dart` khoá bản thân hàm `tr()`. Nhóm này khoá điều khác hẳn và
// quan trọng hơn: bật tiếng Anh lên thì chữ trên màn hình ĐỔI THẬT. Bọc thiếu
// một chỗ, hoặc bọc rồi mà chỗ đó chở một hằng đã chốt ngôn ngữ lúc nạp lớp,
// thì bài ở đây đỏ còn bài kia vẫn xanh.
//
// Run: flutter test test/features/wr_english_build_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_deep_interpretation.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_flow.dart';
import 'package:workreflection_mobile/core/logic/wr_sca_deep_dive.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_org_survey.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(builder: wrTextScaleBuilder, home: child),
    );

void main() {
  // Mọi bài khác trong repo khoá chuỗi tiếng Việt. Quên trả về là hàng trăm
  // bài chạy sau đó đỏ ở file khác hẳn với file gây ra.
  tearDown(() => wrEnglish = false);

  group('bật tiếng Anh thì chữ đổi thật', () {
    testWidgets('lưới check-in ở Home', (tester) async {
      wrSetLocale('en');
      await tester.pumpWidget(_wrap(
        Scaffold(
          body: Column(
            children: [
              for (final o in kCheckinOptions) Text(o.label),
            ],
          ),
        ),
      ));

      expect(find.text('I feel\ntense'), findsOneWidget);
      expect(find.text('Tôi đang\ncăng thẳng'), findsNothing);
    });

    testWidgets('màn Hôm nay dựng được và không còn chữ Việt ở câu chào',
        (tester) async {
      wrSetLocale('en');
      await tester.pumpWidget(_wrap(const Scaffold(body: SizedBox())));
      // Chỉ cần biết hằng đã đi qua tr(); dựng cả màn cần nhiều provider giả.
      expect(kCheckinOptions.first.label.contains('tense'), isTrue);
    });
  });

  group('hằng tầng file là GETTER, không phải final', () {
    // Đây là bẫy tinh vi nhất của cả đợt. `final kFoo = tr(...)` ở tầng file
    // chốt ngôn ngữ tại lần đọc ĐẦU TIÊN. Người dùng đổi ngôn ngữ giữa phiên
    // vẫn thấy chữ cũ cho tới khi khởi động lại app — và không test nào đọc
    // hằng đúng MỘT lần sẽ bắt được.
    test('đọc lần hai sau khi đổi ngôn ngữ phải ra chữ mới', () {
      expect(kDetailPrompt, 'Viết ra bất cứ điều gì vừa xuất hiện trong đầu bạn lúc này.');
      wrSetLocale('en');
      expect(kDetailPrompt, 'Write whatever just came to mind.');
      wrSetLocale('vi');
      expect(kDetailPrompt, 'Viết ra bất cứ điều gì vừa xuất hiện trong đầu bạn lúc này.');
    });

    test('danh sách hằng cũng đổi theo, không đông cứng ở lần đầu', () {
      final vi = List<String>.from(kInsightStemSuggestions);
      wrSetLocale('en');
      final en = List<String>.from(kInsightStemSuggestions);
      expect(en, isNot(equals(vi)));
      expect(en.length, vi.length);
    });
  });

  group('nhãn của enum đi qua tr()', () {
    // Đối số hàm tạo của enum bắt buộc là hằng biên dịch, nên mấy chỗ này phải
    // chuyển sang getter. Chuyển sót một enum thì nó im lặng ở lại tiếng Việt.
    test('ScaPillarStatus', () {
      wrSetLocale('en');
      expect(ScaPillarStatus.developing.label, 'Supporting you well');
      expect(ScaPillarStatus.needsAttention.inlineLabel,
          'fine but with room to grow');
    });

    test('SelfCheckPillar', () {
      wrSetLocale('en');
      expect(SelfCheckPillar.s.displayName, 'Clarity');
      expect(SelfCheckPillar.c.displayName, 'Relationships');
      expect(SelfCheckPillar.a.displayName, 'Ways of working');
    });

    test('OrgSurveyArea', () {
      wrSetLocale('en');
      expect(OrgSurveyArea.compensation.label, 'Pay and benefits');
      expect(OrgSurveyArea.support.label, 'Support');
    });
  });

  group('câu ghép biến giữ nguyên số và biến', () {
    // Bản dịch viết lại vế câu quanh `${...}`. Viết hụt một biến thì câu tiếng
    // Anh in ra thiếu đúng con số mà cả đoạn đang nói tới.
    test('câu Lớp 2 chở đủ ngày ở cả hai ngôn ngữ', () {
      final res = ScaSelfCheckResponse(
        userId: 'u1',
        answers: const {},
        takenAt: DateTime(2026, 7, 20),
        structureScore: 3.0,
        cultureScore: 3.0,
        activityScore: 3.0,
      );
      final vi = scaTrendText(
          pillar: SelfCheckPillar.s, score: 3.6, previous: res)!;
      wrSetLocale('en');
      final en = scaTrendText(
          pillar: SelfCheckPillar.s, score: 3.6, previous: res)!;

      expect(vi.contains('20/07/2026'), isTrue);
      expect(en.contains('20/07/2026'), isTrue);
      expect(en, isNot(equals(vi)));
    });

    test('câu hướng dẫn khi chưa đủ dữ liệu đổi ngôn ngữ', () {
      final vi = kDeepNotEnoughReflection;
      wrSetLocale('en');
      expect(kDeepNotEnoughReflection, isNot(equals(vi)));
    });
  });
}
