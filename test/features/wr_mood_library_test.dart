// Thư viện Nội dung Cảm xúc — màn danh sách + màn đọc/nghe.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §VIII, §8.1, §8.2, §8.3.
// Run: flutter test test/features/wr_mood_library_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_mood_library_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_mood_reader_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_mood_content_repository.dart';

Widget _wrap({
  required FakeWrMoodContentRepository moodContent,
  String initial = '/wr/mood-library',
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/wr/mood-library',
        builder: (_, __) => const WrMoodLibraryScreen(),
      ),
      GoRoute(
        path: '/wr/mood-content/:id',
        builder: (_, s) =>
            WrMoodReaderScreen(contentId: s.pathParameters['id']!),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      wrMoodContentRepositoryProvider.overrideWithValue(moodContent),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  group('Màn Thư viện', () {
    testWidgets('nhóm đủ bốn cảm xúc, đúng thứ tự lưới check-in',
        (tester) async {
      final repo = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(id: 'a', mood: Mood.happy, title: 'Của vui'),
          fakeMoodContent(id: 'b', mood: Mood.stressed, title: 'Của căng'),
          fakeMoodContent(id: 'c', mood: Mood.okay, title: 'Của ổn'),
          fakeMoodContent(id: 'd', mood: Mood.tired, title: 'Của mệt'),
        ]);

      await _pump(tester, _wrap(moodContent: repo));

      for (final label in ['Căng thẳng', 'Mệt mỏi', 'Khá ổn', 'Đang vui']) {
        expect(find.text(label), findsOneWidget);
      }

      // Thứ tự phải khớp lưới check-in ở Home, nếu không người dùng phải quét
      // mắt tìm nhóm của mình.
      final positions = ['Căng thẳng', 'Mệt mỏi', 'Khá ổn', 'Đang vui']
          .map((l) => tester.getTopLeft(find.text(l)).dy)
          .toList();
      final sorted = [...positions]..sort();
      expect(positions, sorted);
    });

    testWidgets('các mục trong một nhóm xếp theo sort_order', (tester) async {
      final repo = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(
              id: 'x', mood: Mood.okay, sortOrder: 3, title: 'Bài ba'),
          fakeMoodContent(
              id: 'y', mood: Mood.okay, sortOrder: 1, title: 'Bài một'),
          fakeMoodContent(
              id: 'z', mood: Mood.okay, sortOrder: 2, title: 'Bài hai'),
        ]);

      await _pump(tester, _wrap(moodContent: repo));

      final one = tester.getTopLeft(find.text('Bài một')).dy;
      final two = tester.getTopLeft(find.text('Bài hai')).dy;
      final three = tester.getTopLeft(find.text('Bài ba')).dy;
      expect(one, lessThan(two));
      expect(two, lessThan(three));
    });

    testWidgets('nội dung nháp có nhãn, nội dung thật thì không',
        (tester) async {
      final repo = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(
              id: 'draft', mood: Mood.okay, sortOrder: 1, placeholder: true),
          fakeMoodContent(
              id: 'real', mood: Mood.okay, sortOrder: 2, placeholder: false),
        ]);

      await _pump(tester, _wrap(moodContent: repo));

      expect(find.text('Nháp'), findsOneWidget);
    });

    testWidgets('thư viện rỗng thì nói thẳng, không hiện khung trống',
        (tester) async {
      await _pump(tester, _wrap(moodContent: FakeWrMoodContentRepository()));
      expect(find.textContaining('Chưa có nội dung'), findsOneWidget);
    });

    testWidgets('lỗi đọc cũng không làm vỡ màn', (tester) async {
      final repo = FakeWrMoodContentRepository()..nextError = Exception('mất mạng');
      await _pump(tester, _wrap(moodContent: repo));
      expect(find.textContaining('Chưa có nội dung'), findsOneWidget);
    });

    testWidgets('chạm một dòng mở đúng màn đọc', (tester) async {
      final repo = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(
            id: 'abc',
            mood: Mood.tired,
            title: 'Kiệt sức không phải là yếu đuối',
          ),
        ]);

      await _pump(tester, _wrap(moodContent: repo));
      await tester.tap(find.byKey(const Key('wr_mood_row_abc')));
      await tester.pumpAndSettle();

      expect(find.text('Kiệt sức không phải là yếu đuối'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('Màn đọc / nghe', () {
    testWidgets('BÀI ĐỌC hiện từng đoạn, không có khối trình phát',
        (tester) async {
      final repo = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(
            id: 'r1',
            mood: Mood.stressed,
            title: 'Khi áp lực đến từ việc muốn kiểm soát',
            body: 'Đoạn mở đầu.\n\nĐoạn thứ hai.\n\nĐoạn kết.',
          ),
        ]);

      await _pump(
        tester,
        _wrap(moodContent: repo, initial: '/wr/mood-content/r1'),
      );

      expect(find.text('Đoạn mở đầu.'), findsOneWidget);
      expect(find.text('Đoạn thứ hai.'), findsOneWidget);
      expect(find.text('Đoạn kết.'), findsOneWidget);
      expect(find.byKey(const Key('wr_mood_audio_player')), findsNothing);
    });

    testWidgets('HEALING AUDIO có khối trình phát', (tester) async {
      // §8.1: type quyết định giao diện — audio có thêm khối trình phát.
      final repo = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(
            id: 'a1',
            mood: Mood.stressed,
            type: MoodContentType.audio,
            kind: 'HEALING AUDIO',
            duration: '3 phút',
            body: 'Một bài hướng dẫn hít thở ngắn.',
          ),
        ]);

      await _pump(
        tester,
        _wrap(moodContent: repo, initial: '/wr/mood-content/a1'),
      );

      expect(find.byKey(const Key('wr_mood_audio_player')), findsOneWidget);
      expect(find.text('HEALING AUDIO · 3 PHÚT'), findsOneWidget);
    });

    testWidgets('nội dung nháp báo rõ chưa thu âm/biên tập', (tester) async {
      final repo = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(id: 'd1', mood: Mood.okay, placeholder: true),
        ]);

      await _pump(
        tester,
        _wrap(moodContent: repo, initial: '/wr/mood-content/d1'),
      );

      expect(find.byKey(const Key('wr_mood_draft_notice')), findsOneWidget);
    });

    testWidgets('màn đọc KHÔNG bao giờ hiện kịch bản lồng tiếng',
        (tester) async {
      // §XII.3: script chỉ dùng nội bộ cho đội sản xuất audio, không render ra
      // API trả về cho app. Ràng buộc thật nằm ở view `wr_mood_content_public`
      // (không có cột script) và ở model MoodContent (không có trường script).
      // Test này khoá lại ý định: nếu ai đó thêm trường script vào model và
      // đem hiển thị, mấy dòng dưới sẽ bắt được.
      final repo = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(
            id: 'a1',
            mood: Mood.stressed,
            type: MoodContentType.audio,
            kind: 'HEALING AUDIO',
            body: 'Mô tả ngắn hiển thị dưới khối trình phát.',
          ),
        ]);

      await _pump(
        tester,
        _wrap(moodContent: repo, initial: '/wr/mood-content/a1'),
      );

      expect(find.textContaining('dừng'), findsNothing);
      expect(find.textContaining('Kịch bản'), findsNothing);
      expect(find.textContaining('kịch bản'), findsNothing);
    });

    testWidgets('id không tồn tại thì báo lỗi nhẹ, không văng', (tester) async {
      final repo = FakeWrMoodContentRepository()
        ..seedContent([fakeMoodContent(id: 'có-thật', mood: Mood.okay)]);

      await _pump(
        tester,
        _wrap(moodContent: repo, initial: '/wr/mood-content/không-có'),
      );

      expect(find.textContaining('Không mở được'), findsOneWidget);
    });
  });
}
