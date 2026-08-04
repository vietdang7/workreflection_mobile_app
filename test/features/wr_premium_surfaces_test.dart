// Widget tests — ba bề mặt Premium bổ sung theo Hai Lớp v1.2 §III/§IV:
//   • Pattern Nâng cao      → Hành trình
//   • Growth Journey        → Phát triển
//   • Context Document      → /wr/context-docs
// Run: flutter test test/features/wr_premium_surfaces_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_context_doc_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_narrative_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

WrEntitlementRecord _premium() => WrEntitlementRecord(
      userId: 'u1',
      plan: WrPlan.premium,
      validUntil: DateTime.now().add(const Duration(days: 30)),
    );

Widget _wrap(
  Widget screen, {
  required FakeWrIntelligenceRepository intel,
  FakeWrContentRepository? content,
  FakeWrRepository? wr,
}) {
  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(path: '/screen', builder: (_, __) => screen),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('PAYWALL')),
      ),
      GoRoute(path: '/wr/discover', builder: (_, __) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      wrContentRepositoryProvider
          .overrideWithValue(content ?? FakeWrContentRepository()),
      wrRepositoryProvider.overrideWithValue(wr ?? FakeWrRepository()),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: router),
  );
}

Future<bool> _seenWhileScrolling(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.drag(scrollable, const Offset(0, 4000));
  await tester.pumpAndSettle();
  for (var i = 0; i < 20; i++) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.drag(scrollable, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
  return finder.evaluate().isNotEmpty;
}

void main() {
  group('Pattern Nâng cao (màn Diễn biến theo thời gian)', () {
    testWidgets('Free: khối bị khoá kèm nút nâng cấp', (tester) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(const WrJourneyNarrativeScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(
        await _seenWhileScrolling(tester, find.text('DIỄN BIẾN THEO THỜI GIAN')),
        isTrue,
      );
      expect(
        await _seenWhileScrolling(
            tester, find.text('Mở diễn biến theo thời gian')),
        isTrue,
      );
    });

    testWidgets('Paid: hiện nội dung tường thuật', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(_premium())
        ..seedPatternNarratives([
          PatternNarrative(
            userId: 'u1',
            narrative: 'Ba tháng qua bạn ít né tránh đối thoại hơn trước.',
            periodStart: DateTime(2026, 5, 1),
            periodEnd: DateTime(2026, 7, 1),
          ),
        ]);
      await tester.pumpWidget(_wrap(const WrJourneyNarrativeScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(
        await _seenWhileScrolling(
          tester,
          find.text('Ba tháng qua bạn ít né tránh đối thoại hơn trước.'),
        ),
        isTrue,
      );
      expect(
        await _seenWhileScrolling(
            tester, find.text('Mở diễn biến theo thời gian')),
        isFalse,
      );
    });

    testWidgets('Paid nhưng chưa có dữ liệu: hiện thông điệp mời quay lại',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(_premium());
      await tester.pumpWidget(_wrap(const WrJourneyNarrativeScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(
        await _seenWhileScrolling(
            tester, find.textContaining('Chưa đủ dữ liệu để kể lại diễn biến')),
        isTrue,
      );
    });
  });

  group('Context Document (JD/CV)', () {
    // Từ 2026-08-04 màn này KHÔNG còn là kho lưu file: `wr-doc-analyze` đọc
    // tài liệu bằng AI, và nội dung đọc được chảy sang trợ lý trò chuyện, gợi ý
    // chủ đề và đối chiếu kỹ năng.

    WrContextDocument docFixture({
      String id = 'doc-1',
      String docType = 'jd',
      DocAnalysisStatus status = DocAnalysisStatus.pending,
      WrDocAnalysis? analysis,
    }) =>
        WrContextDocument(
          id: id,
          userId: 'u1',
          docType: docType,
          filePath: 'u1/$docType-1.pdf',
          uploadedAt: DateTime(2026, 8, 1),
          analysisStatus: status,
          analysis: analysis,
          extractedText: analysis == null ? null : 'Chữ đọc được.',
        );

    testWidgets('Free: trống, quota 1, phần AI đọc bị khoá', (tester) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Tài liệu bối cảnh'), findsOneWidget);
      expect(find.text('Chưa có tài liệu nào.'), findsOneWidget);
      expect(find.text('Thêm tài liệu'), findsOneWidget);
      expect(find.text('AI ĐỌC TÀI LIỆU'), findsOneWidget);
      expect(find.byKey(const Key('wr_context_doc_lock')), findsOneWidget);
    });

    testWidgets('Free đã đủ quota: nút thêm bị khoá và nêu lý do',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(null)
        ..seedContextDocuments([docFixture()]);
      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Mô tả công việc (JD)'), findsOneWidget);
      expect(
        find.textContaining('Bản miễn phí lưu được 1 tài liệu'),
        findsOneWidget,
      );
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Thêm tài liệu'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('Free: không bấm đọc được, nút nói rõ đây là phần Premium',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(null)
        ..seedContextDocuments([docFixture()]);
      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Đọc tài liệu (Premium)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_context_doc_analyze_doc-1')));
      await tester.pumpAndSettle();
      expect(intel.analyzeContextDocumentCalls, isEmpty);
    });

    testWidgets('Premium: bấm đọc thì gọi máy chủ và đổi sang Đã đọc',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(_premium())
        ..seedContextDocuments([docFixture()]);
      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Chưa đọc'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_context_doc_analyze_doc-1')));
      await tester.pumpAndSettle();

      expect(intel.analyzeContextDocumentCalls, ['doc-1']);
      expect(find.text('Đã đọc'), findsOneWidget);
      // Người dùng phải KIỂM được máy đã hiểu gì: OCR đọc nhầm một dòng thì mọi
      // gợi ý phía sau lệch theo.
      expect(find.text('Chuyên viên nhân sự'), findsOneWidget);
      expect(find.textContaining('Tuyển dụng nhân sự mới'), findsOneWidget);
    });

    testWidgets('tài liệu đã đọc hiện bản phân tích, kèm lối đọc lại',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(_premium())
        ..seedContextDocuments([
          docFixture(
            status: DocAnalysisStatus.ready,
            analysis: const WrDocAnalysis(
              title: 'Trưởng nhóm kinh doanh',
              organization: 'Công ty ABC',
              summary: 'Dẫn dắt nhóm bán hàng khu vực phía Nam.',
              requirements: ['3 năm kinh nghiệm quản lý'],
            ),
          ),
        ]);
      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Trưởng nhóm kinh doanh'), findsOneWidget);
      expect(find.text('Công ty ABC'), findsOneWidget);
      expect(find.textContaining('3 năm kinh nghiệm quản lý'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_context_doc_reanalyze_doc-1')),
        findsOneWidget,
      );
    });

    testWidgets('máy chủ từ chối thì hiện đúng câu máy chủ soạn',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(_premium())
        ..seedContextDocuments([docFixture()]);
      intel.nextAnalysisError = const WrDocAnalysisException(
        'Mình chưa đọc được chữ trong tài liệu này. Bạn thử chụp rõ hơn nhé.',
      );

      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_context_doc_analyze_doc-1')));
      await tester.pumpAndSettle();

      expect(
        find.text('Mình chưa đọc được chữ trong tài liệu này. Bạn thử chụp rõ hơn nhé.'),
        findsOneWidget,
      );
    });

    testWidgets('tải lên xong là đọc luôn, không bắt bấm thêm nút nữa',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(_premium());
      final wr = FakeWrRepository();

      await tester.pumpWidget(_wrap(
        WrContextDocScreen(
          picker: () async => (
            name: 'jd.pdf',
            ext: 'pdf',
            bytes: <int>[1, 2, 3],
          ),
        ),
        intel: intel,
        wr: wr,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm tài liệu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mô tả công việc (JD)'));
      await tester.pumpAndSettle();

      expect(wr.uploadContextDocumentCalls.single.ext, 'pdf');
      expect(intel.insertContextDocumentCalls, hasLength(1));
      expect(intel.analyzeContextDocumentCalls, hasLength(1));
      expect(find.text('Đã đọc'), findsOneWidget);
    });

    testWidgets('xoá tài liệu thì bản đọc được cũng đi theo', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(_premium())
        ..seedContextDocuments([docFixture(status: DocAnalysisStatus.ready)]);
      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wr_context_doc_delete_doc-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_context_doc_delete_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có tài liệu nào.'), findsOneWidget);
    });
  });
}
