import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_canonical_catalog.dart';
import 'package:workreflection_mobile/core/logic/wr_entitlement.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_sca_deep_dive_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

// Khách chốt 15/09/2026: dòng chờ ở đáy màn Diễn giải sâu phải ĐỌC ĐƯỢC ĐỦ
// CÂU, không ép một dòng nữa.
//
// Bài này trước đó khoá đúng chiều ngược lại (`height <= 22`, tức một dòng) theo
// yêu cầu bố cục hôm 14/09. Hai yêu cầu loại trừ nhau; đây là vế khách chọn sau
// khi nhìn thấy hậu quả trên máy thật: câu bị cắt cụt, đọc không hiểu gì.
void main() {
  testWidgets('QA pending comparison line is never truncated on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = (await tester.runAsync(loadWrCanonicalCatalog))!;
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wrEntitlementProvider.overrideWith(
            (ref) async => WrEntitlement(plan: WrPlan.premium),
          ),
          wrSituationsProvider.overrideWith((ref) async => catalog.situations),
          wrSelfCheckHistoryProvider.overrideWith(
            (ref) async => [
              ScaSelfCheckResponse(
                userId: 'qa',
                answers: const {},
                takenAt: now,
                structureScore: 3,
                cultureScore: 3,
                activityScore: 3,
              ),
            ],
          ),
          wrEpisodeHistoryProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < 15; i++)
                ReflectionEpisode(
                  userId: 'qa',
                  humanMoment: HumanMoment.arrival,
                  situationCode: 'C2-01',
                  openedAt: now,
                ),
            ],
          ),
        ],
        child: const MaterialApp(home: WrScaDeepDiveScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final footer = find.byKey(const Key('wr_deep_waiting_line'));
    expect(footer, findsOneWidget);

    // Đo trên chính thứ đã render, không đo trên thuộc tính widget: `maxLines`
    // có thể bị kẹp ở bất kỳ tầng nào bên dưới và cách đo này vẫn bắt được.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: footer, matching: find.byType(RichText)),
    );
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'dòng chờ bị cắt cụt — khách đã chốt là phải hiện đủ câu',
    );
  });
}
