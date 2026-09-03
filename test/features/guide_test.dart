// Màn "Hướng dẫn sử dụng" trong Hồ sơ — yêu cầu §4 họp 26_1.
//
// Ba thứ được khoá ở đây:
//   1. Bộ chữ không được gõ tay các ngưỡng — nó phải đọc từ hằng số app đang
//      chạy, nếu không hướng dẫn sẽ nói khác phần mềm ngay lần đổi ngưỡng đầu.
//   2. Chatbot phải NỔI BẬT: nằm ngoài danh sách gập/mở, luôn thấy, và nút mở
//      thẳng được Chatbot.
//   3. Gập/mở hoạt động, và có lối vào từ màn Hồ sơ.
//
// Run: flutter test test/features/guide_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/logic/wr_career_health.dart';
import 'package:workreflection_mobile/core/logic/wr_practice_theme_grant.dart';
import 'package:workreflection_mobile/core/logic/wr_repeated_situations.dart';
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
      case WrGuideText(:final text):
        buf.write('$text ');
      case WrGuideNote(:final text):
        buf.write('$text ');
      case WrGuideBullets(:final items):
        for (final i in items) {
          buf.write('${i.label} ${i.text} ');
        }
      case WrGuideSteps(:final items):
        for (final i in items) {
          buf.write('${i.title} ${i.text} ');
        }
      case WrGuideTwoColumn(:final rows):
        for (final r in rows) {
          buf.write('${r.left} ${r.right} ');
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
    // Màn cao bất thường: tám mục cộng thẻ Chatbot vượt xa một màn điện thoại,
    // mà `ListView` chỉ dựng phần nằm trong khung nhìn. Khung nhìn thấp thì
    // `find.byKey` trượt vì widget CHƯA TỪNG được dựng — đọc ra như "không có
    // mục đó", trong khi lỗi thật chỉ là chưa cuộn tới.
    view.physicalSize = const Size(420, 6000);
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

    testWidgets('nút trên thẻ Chatbot mở thẳng Chatbot', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('guide_chat_cta')));
      await t.pumpAndSettle();

      expect(find.text('CHATBOT'), findsOneWidget);
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

    // Người đọc hết tám mục mà vẫn chưa thấy câu trả lời là người cần Chatbot
    // nhất, nhưng lúc đó thẻ coral đã trôi khỏi màn từ lâu.
    testWidgets('dòng chốt cuối màn cũng mở được Chatbot', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('guide_chat_footer')));
      await t.pumpAndSettle();

      expect(find.text('CHATBOT'), findsOneWidget);
    });

    testWidgets('mục đầu mở sẵn — vào màn là đã đọc được ngay', (t) async {
      await t.pumpWidget(_wrap());
      await t.pumpAndSettle();

      expect(
        find.text('Đây không phải app ghi chú, cũng không phải app chấm điểm '
            'bạn.'),
        findsOneWidget,
      );
    });
  });
}
