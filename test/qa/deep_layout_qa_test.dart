import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_canonical_catalog.dart';
import 'package:workreflection_mobile/core/logic/wr_entitlement.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_sca_deep_dive_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

void main() {
  testWidgets('QA pending comparisons occupy one physical line on phone', (
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
    expect(tester.getSize(footer).height, lessThanOrEqualTo(22));
  });
}
