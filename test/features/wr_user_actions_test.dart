// "Việc bạn tự đặt" (họp khách 01/10/2026, Task D1).
//
// Mockup v47 đưa khối này ra khỏi tab Phát triển (chủ dự án chốt 06/10), dữ
// liệu vẫn giữ. File này giờ khoá việc tab không còn dựng nó, và nhãn Hành
// trình của mảnh ký ức "user_action_completed" cũ vẫn đọc đúng.
//
// Run: flutter test test/features/wr_user_actions_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_user_action_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_user_action.dart';
import 'package:workreflection_mobile/core/theme/wr_colors.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/widgets/wr_user_actions_section.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_user_action_repository.dart';

const _kInput = Key('wr_growth_user_action_input');

Key _card(String id) => Key('wr_growth_user_action_$id');

GoRouter _router() => GoRouter(
  initialLocation: '/test',
  routes: [
    GoRoute(path: '/test', builder: (_, __) => const WrGrowthScreen()),
    GoRoute(
      path: '/wr/paywall',
      builder: (_, __) => const Scaffold(body: Text('PaywallScreen')),
    ),
    GoRoute(
      path: '/wr/self-check',
      builder: (_, __) => const Scaffold(body: Text('SelfCheckScreen')),
    ),
  ],
);

Widget _wrap({
  required FakeWrUserActionRepository actions,
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
}) {
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(
        content ?? FakeWrContentRepository(),
      ),
      wrIntelligenceRepositoryProvider.overrideWithValue(
        intel ?? FakeWrIntelligenceRepository(),
      ),
      wrEpisodeRepositoryProvider.overrideWithValue(FakeWrEpisodeRepository()),
      wrUserActionRepositoryProvider.overrideWithValue(actions),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: _router(),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
  // Tab Phát triển: "Điều bạn đang thực hành" thu gọn sẵn (họp khách 08/10).
  // Xổ ra để các test về thẻ chủ đề còn thấy thẻ.
  final themesToggle = find.byKey(const Key('wr_growth_themes_toggle'));
  if (themesToggle.evaluate().isNotEmpty) {
    await tester.tap(themesToggle);
    await tester.pumpAndSettle();
  }
}

PracticeTheme _theme(String id, String title) => PracticeTheme(
  themeId: id,
  title: title,
  scaDimension: ScaDimension.c1,
  description: 'Mô tả $title',
);

void main() {
  // Mockup v47 bỏ "Việc bạn tự đặt" khỏi tab Phát triển (chủ dự án chốt 06/10);
  // bảng và dữ liệu vẫn giữ. Các test cũ dựng tab để thao tác trên khối này
  // (thêm, ghi hôm nay, hoàn thành, xoá, chip gợi ý, thứ tự, quota) đã bỏ.
  testWidgets('tab Phát triển không còn khối Việc bạn tự đặt', (tester) async {
    final repo = FakeWrUserActionRepository()
      ..seed([
        WrUserAction(
          id: 'a1',
          title: 'Việc của tôi',
          createdAt: DateTime(2026, 10, 1),
        ),
      ]);
    final intel = FakeWrIntelligenceRepository()
      ..seedPracticeThemes([_theme('t1', 'Chủ đề A')])
      ..seedEnrollments([
        PracticeEnrollment(
          userId: 'u1',
          themeId: 't1',
          startedAt: DateTime(2026, 9, 1),
        ),
      ]);
    await _pump(tester, _wrap(actions: repo, intel: intel));

    // Tab vẫn dựng bình thường với chủ đề đang theo…
    expect(find.byKey(const Key('wr_growth_theme_card_t1')), findsOneWidget);
    // …nhưng không còn khối tự đặt, kể cả khi có sẵn dữ liệu.
    expect(find.byType(WrUserActionsSection), findsNothing);
    expect(find.text('VIỆC BẠN TỰ ĐẶT'), findsNothing);
    expect(find.byKey(_kInput), findsNothing);
    expect(find.byKey(_card('a1')), findsNothing);
    // Không ai đụng tới bảng việc tự đặt khi chỉ mở tab.
    expect(repo.addCalls, isEmpty);
    expect(repo.deleteCalls, isEmpty);
  });

  test('eventTypeLabel và eventColor nhận diện user_action_completed', () {
    final event = CareerMemoryEvent(
      id: 'e1',
      userId: 'u1',
      behavior: 'user_action_completed',
      createdAt: DateTime.now(),
      reflectionText: 'Đã hoàn thành 5 ngày thực hành: Tập lắng nghe',
    );

    expect(eventTypeLabel(event), 'TỰ RÈN LUYỆN');
    expect(eventColor(event), WrColors.teal);
  });
}
