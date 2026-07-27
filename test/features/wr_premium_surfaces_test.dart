// Widget tests — ba bề mặt Premium bổ sung theo Hai Lớp v1.2 §III/§IV:
//   • Pattern Nâng cao      → Hành trình
//   • Growth Journey        → Phát triển
//   • Context Document      → /wr/context-docs
// Run: flutter test test/features/wr_premium_surfaces_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    child: MaterialApp.router(routerConfig: router),
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
    testWidgets('Free: trống, quota 1, phân tích sâu bị khoá', (tester) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Tài liệu bối cảnh'), findsOneWidget);
      expect(find.text('Chưa có tài liệu nào.'), findsOneWidget);
      expect(find.text('Thêm tài liệu'), findsOneWidget);
      expect(find.text('PHÂN TÍCH SÂU'), findsOneWidget);
      expect(find.text('Mở phân tích sâu'), findsOneWidget);
    });

    testWidgets('Free đã đủ quota: nút thêm bị khoá và nêu lý do',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(null)
        ..seedContextDocuments([
          WrContextDocument(
            userId: 'u1',
            docType: 'jd',
            filePath: 'u1/jd-1.png',
            uploadedAt: DateTime(2026, 7, 1),
          ),
        ]);
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

    testWidgets('Paid: không giới hạn số lượng, phân tích sâu mở',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(_premium())
        ..seedContextDocuments([
          WrContextDocument(
            userId: 'u1',
            docType: 'cv',
            filePath: 'u1/cv-1.png',
          ),
        ]);
      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ năng lực (CV)'), findsOneWidget);
      expect(find.text('Mở phân tích sâu'), findsNothing);
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Thêm tài liệu'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Free: nút nâng cấp mở paywall', (tester) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(const WrContextDocScreen(), intel: intel));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mở phân tích sâu'));
      await tester.pumpAndSettle();

      expect(find.text('PAYWALL'), findsOneWidget);
    });
  });
}
