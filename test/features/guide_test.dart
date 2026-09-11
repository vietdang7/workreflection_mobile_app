// Màn "Hướng dẫn sử dụng" trong Hồ sơ — yêu cầu §4 họp 26_1.
//
// Ba thứ được khoá ở đây:
//   1. Bộ chữ không được gõ tay các ngưỡng — nó phải đọc từ hằng số app đang
//      chạy, nếu không hướng dẫn sẽ nói khác phần mềm ngay lần đổi ngưỡng đầu.
//   2. Trợ lý AI phải NỔI BẬT: nằm ngoài danh sách gập/mở, luôn thấy, và nút
//      mở thẳng được trợ lý.
//   3. Gập/mở hoạt động, và có lối vào từ màn Hồ sơ.
//   4. Mỗi cụm mục in nhãn ĐÚNG MỘT LẦN — bản v4 chia mười một mục thành bốn
//      cụm, in lại nhãn ở từng mục là hỏng hẳn ý chia cụm.
//
// Run: flutter test test/features/guide_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/logic/wr_career_health.dart';
import 'package:workreflection_mobile/core/logic/wr_practice_theme_grant.dart';
import 'package:workreflection_mobile/core/logic/wr_repeated_situations.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/logic/wr_user_guide.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/profile/presentation/guide_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

Widget _wrap({String initial = '/profile/guide'}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/profile/guide',
        builder: (_, __) => const GuideScreen(),
      ),
      GoRoute(
        path: '/wr/ask',
        builder: (_, __) => const Scaffold(body: Text('CHATBOT')),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      routerConfig: router,
    ),
  );
}

/// Gom toàn bộ chữ của một mục lại để soát nội dung mà không phải bới cây khối.
String _flatten(WrGuideSection s) {
  final buf = StringBuffer('${s.title} ${s.summary} ');
  for (final b in s.blocks) {
    switch (b) {
      case WrGuideHeading(:final text):
        buf.write('$text ');
      case WrGuideText(:final text):
        buf.write('$text ');
      case WrGuideNote(:final text):
        buf.write('$text ');
      case WrGuideChecks(:final items, :final footnote):
        for (final i in items) {
          buf.write('$i ');
        }
        if (footnote != null) buf.write('$footnote ');
      case WrGuideBullets(:final items):
        for (final i in items) {
          buf.write('${i.label} ${i.text} ');
        }
      case WrGuideSteps(:final items):
        for (final i in items) {
          buf.write('${i.title} ${i.text} ');
        }
      case WrGuideQa(:final items):
        for (final i in items) {
          buf.write('${i.question} ${i.answer} ');
        }
    }
  }
  return buf.toString();
}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    // Màn cao bất thường: mười một mục cộng thẻ trợ lý vượt xa một màn điện
    // thoại, mà `ListView` chỉ dựng phần nằm trong khung nhìn. Khung nhìn thấp
    // thì `find.byKey` trượt vì widget CHƯA TỪNG được dựng — đọc ra như "không
    // có mục đó", trong khi lỗi thật chỉ là chưa cuộn tới.
    view.physicalSize = const Size(420, 9000);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  // -------------------------------------------------------------------------
  // Bộ chữ
  // -------------------------------------------------------------------------

  group('bộ chữ hướng dẫn', () {
    test('mã mục là duy nhất — Key widget và mỏ neo test dựa vào nó', () {
      final ids = wrGuideSections().map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    // Bản v4 cho mỗi mục một biểu tượng riêng. Dùng lại một glyph cho hai mục
    // là mất đúng thứ biểu tượng dùng để làm: phân biệt mục này với mục kia
    // khi lướt qua danh sách đã gập.
    test('mỗi mục một biểu tượng, không trùng nhau', () {
      final icons = wrGuideSections().map((s) => s.icon).toList();
      expect(icons.toSet().length, icons.length);
    });

    test('mọi mục đều có tóm tắt và ít nhất một khối', () {
      for (final s in wrGuideSections()) {
        expect(s.title.trim(), isNotEmpty, reason: s.id);
        expect(s.summary.trim(), isNotEmpty, reason: s.id);
        expect(s.blocks, isNotEmpty, reason: s.id);
      }
    });

    test('đúng một mục mở sẵn — mở hết thì bằng với không gập', () {
      expect(wrGuideSections().where((s) => s.openByDefault).length, 1);
      expect(wrGuideSections().first.openByDefault, isTrue);
    });

    // Đây là test đáng giá nhất của nhóm: nó bắt đúng lỗi "tài liệu nói một
    // đằng, app chạy một nẻo". Đổi ngưỡng ở file logic mà chữ không đổi theo
    // thì test này đỏ.
    test('ngưỡng trong chữ đọc từ hằng số của app', () {
      final byId = {for (final s in wrGuideSections()) s.id: _flatten(s)};

      expect(
        byId['understand'],
        contains('$kRepeatedSituationsMinCount lần'),
      );
      expect(
        byId['understand'],
        contains('$kRepeatedSituationsTop dòng'),
      );
      expect(
        byId['understand'],
        contains('$kCareerHealthThreshold lần'),
      );
      expect(
        byId['growth'],
        contains('$kReflectionsPerPracticeTheme lần'),
      );
      expect(byId['growth'], contains('$kSkillThreshold lần'));
      expect(
        byId['understand'],
        contains('${kSelfCheckQuestions.length} câu hỏi'),
      );
    });

    // Bốn cụm của bản v4, đúng thứ tự. Mục nào rơi sai cụm là nhãn in ra hai
    // lần trên màn — chính thứ test dưới đây bắt.
    test('các mục cùng cụm nằm liền nhau', () {
      final seen = <String>[];
      String? previous;
      for (final s in wrGuideSections()) {
        if (s.group != previous) {
          expect(seen, isNot(contains(s.group)),
              reason: 'cụm "${s.group}" bị ngắt quãng ở mục ${s.id}');
          seen.add(s.group);
          previous = s.group;
        }
      }
      expect(seen.length, 4);
    });
  });

  // -------------------------------------------------------------------------
  // Màn hình
  // -------------------------------------------------------------------------

  group('màn Hướng dẫn sử dụng', () {
    testWidgets('mở ra là thấy tiêu đề, thẻ Chatbot và mọi mục', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      expect(find.text('Hướng dẫn sử dụng'), findsOneWidget);
      expect(find.byKey(const Key('guide_chat_card')), findsOneWidget);

      for (final s in wrGuideSections()) {
        expect(
          find.byKey(Key('guide_section_${s.id}')),
          findsOneWidget,
          reason: s.id,
        );
      }
    });

    testWidgets('thẻ Chatbot nêu ví dụ câu hỏi thật', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      for (final q in kGuideChatExamples) {
        expect(find.text('“$q”'), findsOneWidget, reason: q);
      }
    });

    testWidgets('nút trên thẻ Trợ lý AI mở thẳng trợ lý', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('guide_chat_cta')));
      await t.pumpAndSettle();

      expect(find.text('CHATBOT'), findsOneWidget);
    });

    testWidgets('thẻ chốt màn cũng mở được trợ lý', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('guide_closing_cta')));
      await t.pumpAndSettle();

      expect(find.text('CHATBOT'), findsOneWidget);
    });

    testWidgets('mỗi nhãn cụm chỉ in một lần', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      for (final group in wrGuideSections().map((s) => s.group).toSet()) {
        expect(find.text(group.toUpperCase()), findsOneWidget, reason: group);
      }
    });

    testWidgets('mục đóng hiện tóm tắt; chạm thì mở ra, chạm nữa thì đóng',
        (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      final faq = wrGuideSections().firstWhere((s) => s.id == 'faq');
      final firstQa =
          faq.blocks.whereType<WrGuideQa>().single.items.first.question;

      // Đóng: thấy tóm tắt, chưa thấy nội dung.
      expect(find.text(faq.summary), findsOneWidget);
      expect(find.text(firstQa), findsNothing);

      await t.tap(find.byKey(const Key('guide_section_faq')));
      await t.pumpAndSettle();
      expect(find.text(firstQa), findsOneWidget);
      expect(find.text(faq.summary), findsNothing);

      await t.tap(find.byKey(const Key('guide_section_faq')));
      await t.pumpAndSettle();
      expect(find.text(firstQa), findsNothing);
      expect(find.text(faq.summary), findsOneWidget);
    });

    testWidgets('mở được nhiều mục cùng lúc để đối chiếu', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('guide_section_understand')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('guide_section_growth')));
      await t.pumpAndSettle();

      final understand =
          wrGuideSections().firstWhere((s) => s.id == 'understand');
      final growth = wrGuideSections().firstWhere((s) => s.id == 'growth');

      // Cả hai đang mở → không mục nào còn hiện dòng tóm tắt.
      expect(find.text(understand.summary), findsNothing);
      expect(find.text(growth.summary), findsNothing);
    });

    // Nhãn nhóm là thứ giữ tám thẻ trắng khỏi đọc thành một danh sách không có
    // hình dạng. Khoá hai điều: nhãn có ra màn hình, và các mục CÙNG NHÓM đứng
    // liền nhau — màn hình chỉ in nhãn khi nhóm đổi, nên nhóm bị xen kẽ sẽ in
    // một nhãn hai lần và `findsOneWidget` bắt được.
    testWidgets('mỗi nhóm in nhãn đúng một lần, ở mục đầu nhóm', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      final groups = <String>[];
      for (final s in wrGuideSections()) {
        if (groups.isEmpty || groups.last != s.group) groups.add(s.group);
      }

      expect(groups.toSet().length, groups.length,
          reason: 'các mục cùng nhóm phải đứng liền nhau');

      for (final g in groups) {
        expect(find.text(g.toUpperCase()), findsOneWidget, reason: g);
      }
    });

    // Người đọc hết các mục mà vẫn chưa thấy câu trả lời là người cần Chatbot
    // nhất, nhưng lúc đó thẻ coral đã trôi khỏi màn từ lâu.
    //
    // Khoá đổi từ `guide_chat_footer` sang `guide_closing_cta` khi màn này
    // được dựng lại theo mockup InApp v4. Chỉ TÊN đổi — dòng chốt cuối màn vẫn
    // còn và vẫn mở thẳng Chatbot, nên điều bài này canh không suy suyển.
    testWidgets('dòng chốt cuối màn cũng mở được Chatbot', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('guide_closing_cta')));
      await t.pumpAndSettle();

      expect(find.text('CHATBOT'), findsOneWidget);
    });

    testWidgets('mục đầu mở sẵn — vào màn là đã đọc được ngay', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      expect(
        find.text('WorkReflection không đơn thuần là một ứng dụng ghi chú.'),
        findsOneWidget,
      );
    });
  });
}
