// Avatar góc trên bốn tab — `.avatar` / `.avatar.premium` của mockup Sprint 2.
// Run: flutter test test/core/widgets/wr_profile_avatar_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_entitlement.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart'
    show WrPlan;
import 'package:workreflection_mobile/core/theme/wr_colors.dart';
import 'package:workreflection_mobile/core/widgets/wr_profile_avatar.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

Widget _host(WrPlan plan, {String? avatarUrl}) => ProviderScope(
  overrides: [
    wrEntitlementProvider.overrideWith(
      (ref) async => WrEntitlement(plan: plan),
    ),
    ccProfileProvider.overrideWith(
      (ref) async => {if (avatarUrl != null) 'avatar_url': avatarUrl},
    ),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: Center(child: WrProfileAvatar(displayName: 'Yumi Tran')),
    ),
  ),
);

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(
                of: find.byType(WrProfileAvatar),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  testWidgets('miễn phí: chữ cái đầu trên nền navy', (tester) async {
    await tester.pumpWidget(_host(WrPlan.free));
    await tester.pumpAndSettle();

    expect(find.text('YT'), findsOneWidget);
    expect(find.text('★'), findsNothing);
    expect(_decoration(tester).gradient, isNull);
    expect(_decoration(tester).color, WrColors.navy);
  });

  testWidgets('Premium: "★" trên nền chuyển navy → teal', (tester) async {
    await tester.pumpWidget(_host(WrPlan.premium));
    await tester.pumpAndSettle();

    expect(find.text('★'), findsOneWidget);
    expect(find.text('YT'), findsNothing);
    final gradient = _decoration(tester).gradient! as LinearGradient;
    expect(gradient.colors, [WrColors.navy, WrColors.teal]);
  });

  // Máy thật 13/10: người Premium đã cài ảnh mà avatar vẫn hiện "★". Script
  // không có ảnh đại diện; "★" chỉ thay cho chữ viết tắt.
  for (final plan in [WrPlan.free, WrPlan.premium]) {
    testWidgets(
      '${plan.name}: đã cài ảnh thì hiện ảnh, không "★" hay chữ tắt',
      (tester) async {
        await tester.pumpWidget(
          _host(plan, avatarUrl: 'https://example.com/me.jpg'),
        );
        await tester.pump();

        final img = tester.widget<Image>(
          find.byKey(const Key('wr_avatar_photo')),
        );
        expect((img.image as NetworkImage).url, 'https://example.com/me.jpg');
        expect(find.text('★'), findsNothing);
        expect(find.text('YT'), findsNothing);
      },
    );
  }

  testWidgets('ảnh rỗng thì quay về "★"/chữ tắt', (tester) async {
    await tester.pumpWidget(_host(WrPlan.free, avatarUrl: '  '));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wr_avatar_photo')), findsNothing);
    expect(find.text('YT'), findsOneWidget);
  });
}
