// Thư viện học tập — video, tài liệu của web xem ngay trong app (khách 10/10).
// Run: flutter test test/features/wr_learning_library_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_learning_repository.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/models/wr_learning_resource.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_learning_library_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

/// Ảnh tải từ mạng — ảnh đầu trang (asset) của màn thì được phép.
final _networkImages = find.byWidgetPredicate(
  (w) => w is Image && w.image is NetworkImage,
  skipOffstage: false,
);

class _FakeLearningRepo implements WrLearningRepository {
  _FakeLearningRepo(this.items, {this.fail = false});

  final List<LearningResource> items;
  final bool fail;

  @override
  Future<List<LearningResource>> fetchActive() async {
    if (fail) throw Exception('offline');
    return items;
  }
}

/// Đúng dòng thật trong `cc_workshop_resources` ngày 10/10.
final _series = LearningResource.fromJson({
  'id': 'f0d7658d',
  'title':
      'Chuỗi series "Tâm thế người đi làm" || Chủ đề "Tôi không dám hỏi lại"',
  'description':
      'Chuỗi series "Tâm thế người đi làm" được phát triển trong '
      'hệ sinh của WorkReflection.',
  'category': 'Communication',
  'resource_type': 'video',
  'file_url': null,
  'external_url': 'https://youtu.be/iKs4vZjT7rs',
  'thumbnail_url': null,
  'duration_minutes': 9,
  'created_at': '2026-09-24T02:50:45.317597+00:00',
});

final _pdf = LearningResource.fromJson({
  'id': 'doc1',
  'title': 'Sổ tay giao tiếp',
  'resource_type': 'document',
  'file_url': 'https://cdn.example/so-tay.pdf',
  'duration_minutes': null,
});

Widget _wrap(Widget home, WrLearningRepository repo) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => home),
      GoRoute(
        path: '/wr/learning-library',
        builder: (_, _) => const Scaffold(body: Text('LibraryScreen')),
      ),
      GoRoute(
        path: '/wr/learning-library/:id',
        builder: (_, s) =>
            Scaffold(body: Text('VideoScreen ${s.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      wrLearningRepositoryProvider.overrideWithValue(repo),
      wrContentRepositoryProvider.overrideWithValue(FakeWrContentRepository()),
      wrIntelligenceRepositoryProvider.overrideWithValue(
        FakeWrIntelligenceRepository(),
      ),
      wrEpisodeRepositoryProvider.overrideWithValue(FakeWrEpisodeRepository()),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
    ),
  );
}

void main() {
  tearDown(() => wrEnglish = false);

  group('youtubeVideoId', () {
    test('nhận các dạng link web hay dán', () {
      for (final url in [
        'https://youtu.be/iKs4vZjT7rs',
        'https://youtu.be/iKs4vZjT7rs?si=abc',
        'https://www.youtube.com/watch?v=iKs4vZjT7rs&t=30',
        'https://m.youtube.com/watch?v=iKs4vZjT7rs',
        'https://www.youtube.com/embed/iKs4vZjT7rs',
        'https://youtube.com/shorts/iKs4vZjT7rs',
        'https://www.youtube.com/live/iKs4vZjT7rs',
        '  https://youtu.be/iKs4vZjT7rs  ',
      ]) {
        expect(youtubeVideoId(url), 'iKs4vZjT7rs', reason: url);
      }
    });

    test('không phải YouTube hoặc mã hỏng thì null', () {
      for (final url in [
        null,
        '',
        'https://vimeo.com/123456',
        'https://cdn.example/video.mp4',
        'https://www.youtube.com/channel/UC123',
        'https://youtu.be/short',
        'https://notyoutube.com/watch?v=iKs4vZjT7rs',
      ]) {
        expect(youtubeVideoId(url), isNull, reason: '$url');
      }
    });
  });

  group('LearningResource', () {
    test('tài liệu không phải YouTube thì không phải video, mở link file', () {
      expect(_pdf.isVideo, isFalse);
      expect(_pdf.youtubeId, isNull);
      expect(_pdf.url, 'https://cdn.example/so-tay.pdf');
    });

    test('nhãn loại và thời lượng theo ngôn ngữ', () {
      expect(_series.kindLabel, 'Video');
      expect(_series.durationLabel, '9 phút');
      expect(_pdf.kindLabel, 'Tài liệu');
      expect(_pdf.durationLabel, isNull);
      wrSetLocale('en');
      expect(_series.durationLabel, '9 min');
      expect(_pdf.kindLabel, 'Reading');
    });

    test('ô chữ rỗng của web đọc thành null, không ra dòng trắng', () {
      final r = LearningResource.fromJson({
        'id': 'x',
        'title': ' T ',
        'description': '   ',
        'category': '',
        'external_url': 'https://youtu.be/iKs4vZjT7rs',
      });
      expect(r.title, 'T');
      expect(r.description, isNull);
      expect(r.category, isNull);
    });
  });

  group('Thẻ ở tab Phát triển', () {
    testWidgets('tập mới nhất làm thẻ, bấm là phát luôn', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrGrowthScreen(), _FakeLearningRepo([_series])),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('wr_growth_learning_library'));
      await tester.scrollUntilVisible(card, 200);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(find.text('Thư viện học tập'), findsOneWidget);
      expect(find.text('VIDEO · 9 PHÚT'), findsOneWidget);
      expect(find.text(_series.title), findsOneWidget);
      // Không ảnh bìa (người dùng 10/10): không một Image mạng nào.
      expect(_networkImages, findsNothing);

      await tester.tap(find.text(_series.title));
      await tester.pumpAndSettle();
      expect(find.text('VideoScreen f0d7658d'), findsOneWidget);
    });

    testWidgets('"Xem tất cả" mở danh sách', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrGrowthScreen(), _FakeLearningRepo([_series])),
      );
      await tester.pumpAndSettle();

      final seeAll = find.byKey(const Key('wr_learning_see_all'));
      await tester.scrollUntilVisible(seeAll, 200);
      await tester.ensureVisible(seeAll);
      await tester.pumpAndSettle();
      await tester.tap(seeAll);
      await tester.pumpAndSettle();
      expect(find.text('LibraryScreen'), findsOneWidget);
    });

    testWidgets('từ hai tài liệu thì "Xem tất cả" kèm số, chỉ một thẻ', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const WrGrowthScreen(), _FakeLearningRepo([_series, _pdf])),
      );
      await tester.pumpAndSettle();

      final seeAll = find.byKey(const Key('wr_learning_see_all'));
      await tester.scrollUntilVisible(seeAll, 200);
      expect(find.text('Xem tất cả (2)'), findsOneWidget);
      expect(find.text(_pdf.title, skipOffstage: false), findsNothing);
    });

    testWidgets('thư viện trống thì không có thẻ', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrGrowthScreen(), _FakeLearningRepo(const [])),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('wr_growth_learning_library'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    });

    testWidgets('tải lỗi thì cũng không có thẻ, màn vẫn dựng bình thường', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const WrGrowthScreen(), _FakeLearningRepo(const [], fail: true)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(
          const Key('wr_growth_learning_library'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    });
  });

  group('Màn Thư viện học tập', () {
    testWidgets('mỗi tài liệu chỉ hiện tiêu đề — không ảnh, không mô tả', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const WrLearningLibraryScreen(),
          _FakeLearningRepo([_series, _pdf]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_series.title), findsOneWidget);
      expect(find.text(_pdf.title), findsOneWidget);
      // Người dùng 10/10: "hiển thị tiêu đề là được rồi".
      expect(find.text('Communication'), findsNothing);
      expect(find.text('Video · 9 phút'), findsNothing);
      expect(find.textContaining('hệ sinh của WorkReflection'), findsNothing);
      expect(_networkImages, findsNothing);
    });

    testWidgets('bấm video YouTube thì mở màn phát trong app', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrLearningLibraryScreen(), _FakeLearningRepo([_series])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wr_learning_resource_f0d7658d')));
      await tester.pumpAndSettle();
      expect(find.text('VideoScreen f0d7658d'), findsOneWidget);
    });

    testWidgets('thư viện trống nói thẳng là trống', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrLearningLibraryScreen(), _FakeLearningRepo(const [])),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_learning_library_empty')),
        findsOneWidget,
      );
    });

    testWidgets('tải lỗi thì có nút thử lại', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const WrLearningLibraryScreen(),
          _FakeLearningRepo(const [], fail: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_learning_library_error')),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
