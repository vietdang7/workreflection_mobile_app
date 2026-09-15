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

void main() {
  testWidgets('QA no-Self-Check invitation stays compact and available', (
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
          wrSelfCheckHistoryProvider.overrideWith((ref) async => []),
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
    expect(find.byKey(const Key('wr_deep_waiting_line')), findsNothing);
    expect(
      find.byKey(const Key('wr_sca_deep_dive_start_self_check')),
      findsOneWidget,
    );
    final invitation = find.byKey(const Key('wr_deep_no_self_check_yet'));
    expect(invitation, findsOneWidget);

    // Cùng lý do với `deep_layout_qa_test`: khách chốt 15/09/2026 là đọc đủ câu
    // quan trọng hơn gọn một dòng. Trước đó bài này khoá `height <= 24`.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: invitation, matching: find.byType(RichText)),
    );
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'lời mời Self-Check bị cắt cụt — phải hiện đủ câu',
    );
  });
}
