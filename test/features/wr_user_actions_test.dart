// "Việc bạn tự đặt" trên tab Phát triển (họp khách 01/10/2026, Task D1).
//
// Trọng tâm review số 4: việc tự đặt KHÔNG được tính như chủ đề thư viện. Nếu
// bị tính, nó chiếm suất Free 2 chủ đề, chặn phần mềm tự thêm chủ đề và lọt vào
// trợ lý trò chuyện. Các test cuối file khoá điều đó.
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
import 'package:workreflection_mobile/features/wr/growth_providers.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_user_action_repository.dart';

const _kInput = Key('wr_growth_user_action_input');
const _kAdd = Key('wr_growth_user_action_add');

Key _card(String id) => Key('wr_growth_user_action_$id');
Key _done(String id) => Key('wr_growth_user_action_done_$id');
Key _complete(String id) => Key('wr_growth_user_action_complete_$id');

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
}

PracticeTheme _theme(String id, String title) => PracticeTheme(
  themeId: id,
  title: title,
  scaDimension: ScaDimension.c1,
  description: 'Mô tả $title',
);

ElevatedButton _addButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(_kAdd));

void main() {
  testWidgets(
    'nhập "Hỏi ý kiến 1 đồng nghiệp mỗi ngày" + Thêm → hiện trong VIỆC BẠN TỰ ĐẶT, 0/5',
    (tester) async {
      final repo = FakeWrUserActionRepository();
      await _pump(tester, _wrap(actions: repo));

      expect(find.text('VIỆC BẠN TỰ ĐẶT'), findsOneWidget);
      await tester.enterText(
        find.byKey(_kInput),
        'Hỏi ý kiến 1 đồng nghiệp mỗi ngày',
      );
      await tester.pump();
      await tester.tap(find.byKey(_kAdd));
      await tester.pumpAndSettle();

      expect(repo.addCalls, ['Hỏi ý kiến 1 đồng nghiệp mỗi ngày']);
      final id = repo.rows.single.id;
      final card = find.byKey(_card(id));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text('Hỏi ý kiến 1 đồng nghiệp mỗi ngày'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('0/5')),
        findsOneWidget,
      );
      // Ô nhập được dọn sạch sau khi thêm.
      expect(
        tester.widget<TextField>(find.byKey(_kInput)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'bấm Hôm nay tôi đã làm → 1/5, nút đổi sang Đã ghi hôm nay, bấm lại không tăng',
    (tester) async {
      final repo = FakeWrUserActionRepository()
        ..seed([
          WrUserAction(
            id: 'a1',
            title: 'Hỏi ý kiến đồng nghiệp',
            createdAt: DateTime(2026, 10, 1),
          ),
        ]);
      await _pump(tester, _wrap(actions: repo));

      expect(find.text('0/5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_done('a1')),
          matching: find.text('Hôm nay tôi đã làm'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(_done('a1')));
      await tester.pumpAndSettle();

      expect(repo.logTodayCalls, ['a1']);
      expect(find.text('1/5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_done('a1')),
          matching: find.text('Đã ghi hôm nay'),
        ),
        findsOneWidget,
      );

      // Bấm lại: nút đã tắt, không gọi repo lần nữa, số không đổi.
      await tester.tap(find.byKey(_done('a1')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.logTodayCalls, ['a1']);
      expect(find.text('1/5'), findsOneWidget);
    },
  );

  testWidgets('đủ 5 lần → hiện Hoàn thành, có nút đánh dấu xong', (
    tester,
  ) async {
    final repo = FakeWrUserActionRepository()
      ..seed([
        WrUserAction(
          id: 'a1',
          title: 'Hỏi ý kiến đồng nghiệp',
          createdAt: DateTime(2026, 9, 20),
          doneDays: [for (var d = 21; d <= 25; d++) DateTime(2026, 9, d)],
        ),
      ]);
    await _pump(tester, _wrap(actions: repo));

    final card = find.byKey(_card('a1'));
    expect(
      find.descendant(of: card, matching: find.text('5/5')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Hoàn thành')),
      findsOneWidget,
    );
    expect(find.byKey(_done('a1')), findsNothing);
    expect(find.byKey(_complete('a1')), findsOneWidget);

    await tester.tap(find.byKey(_complete('a1')));
    await tester.pumpAndSettle();

    expect(repo.completeCalls, ['a1']);
    expect(repo.rows.single.isCompleted, isTrue);
    expect(find.byKey(_complete('a1')), findsNothing);
    expect(
      find.descendant(of: card, matching: find.text('Đã xong')),
      findsOneWidget,
    );
  });

  testWidgets('ô trống hoặc toàn khoảng trắng → nút Thêm tắt', (tester) async {
    final repo = FakeWrUserActionRepository();
    await _pump(tester, _wrap(actions: repo));

    expect(_addButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(_kInput), '     ');
    await tester.pump();
    expect(_addButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(_kInput), '  Hỏi  ');
    await tester.pump();
    expect(_addButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byKey(_kInput), '');
    await tester.pump();
    await tester.tap(find.byKey(_kAdd), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.addCalls, isEmpty);
  });

  testWidgets(
    'thêm việc KHÔNG đổi practiceEnrollmentsProvider và không đổi quota',
    (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([_theme('t-a', 'Chủ đề A')])
        ..seedEnrollments([
          PracticeEnrollment(
            userId: 'u1',
            themeId: 't-a',
            completedSteps: const [],
            startedAt: DateTime(2026, 9, 1),
          ),
        ]);
      final repo = FakeWrUserActionRepository();
      await _pump(tester, _wrap(actions: repo, intel: intel));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(WrGrowthScreen)),
      );
      final before = container.read(practiceEnrollmentsProvider).value!;
      const quotaText =
          'Bản miễn phí mở tối đa 2 chủ đề cùng lúc (đang mở 1/2).';
      expect(find.text(quotaText), findsOneWidget);

      for (final title in ['Việc một', 'Việc hai', 'Việc ba']) {
        await tester.enterText(find.byKey(_kInput), title);
        await tester.pump();
        await tester.tap(find.byKey(_kAdd));
        await tester.pumpAndSettle();
      }
      expect(repo.rows, hasLength(3));

      final after = container.read(practiceEnrollmentsProvider).value!;
      expect(after.map((e) => e.themeId), before.map((e) => e.themeId));
      expect(intel.enrollThemeCalls, isEmpty);
      expect(find.text(quotaText), findsOneWidget);
      // Không thẻ chủ đề nào mọc thêm.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'wr_growth_theme_card_',
              ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tab vẫn không có CHỦ ĐỀ TIẾP THEO CHO BẠN / wr_growth_add_theme_row / Thực hành khác',
    (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes([
          _theme('t-a', 'Chủ đề A'),
          _theme('t-b', 'Chủ đề B'),
        ])
        ..seedEnrollments([
          PracticeEnrollment(
            userId: 'u1',
            themeId: 't-a',
            completedSteps: const [],
          ),
        ]);
      final repo = FakeWrUserActionRepository()
        ..seed([
          WrUserAction(
            id: 'a1',
            title: 'Việc của tôi',
            createdAt: DateTime(2026),
          ),
        ]);
      await _pump(tester, _wrap(actions: repo, intel: intel));

      expect(find.byKey(_card('a1')), findsOneWidget);
      expect(find.text('CHỦ ĐỀ TIẾP THEO CHO BẠN'), findsNothing);
      expect(find.byKey(const Key('wr_growth_add_theme_row')), findsNothing);
      expect(find.text('Thực hành khác'), findsNothing);
      expect(find.text('Bắt đầu thực hành'), findsNothing);
    },
  );

  testWidgets('chưa theo chủ đề nào vẫn thấy ô Việc bạn tự đặt', (
    tester,
  ) async {
    final intel = FakeWrIntelligenceRepository()
      ..seedPracticeThemes([_theme('t-a', 'Chủ đề A')])
      ..seedEnrollments([]);
    await _pump(
      tester,
      _wrap(actions: FakeWrUserActionRepository(), intel: intel),
    );

    // Thẻ "chưa có chủ đề" vẫn ở chỗ cũ, ô tự đặt là khối riêng bên dưới.
    expect(find.text('CHỦ ĐỀ CỦA BẠN'), findsNothing);
    expect(find.text('Chưa xác định chủ đề trọng tâm'), findsOneWidget);
    expect(find.text('VIỆC BẠN TỰ ĐẶT'), findsOneWidget);
    expect(find.byKey(_kInput), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(_kInput)).dy,
      greaterThan(
        tester.getTopLeft(find.text('Chưa xác định chủ đề trọng tâm')).dy,
      ),
    );
  });

  testWidgets('đọc danh sách hỏng vẫn còn ô nhập, không sập màn', (
    tester,
  ) async {
    await _pump(
      tester,
      _wrap(actions: FakeWrUserActionRepository(failList: true)),
    );
    expect(find.text('VIỆC BẠN TỰ ĐẶT'), findsOneWidget);
    expect(find.byKey(_kInput), findsOneWidget);
  });

  testWidgets('xoá một việc phải hỏi lại trước', (tester) async {
    final repo = FakeWrUserActionRepository()
      ..seed([
        WrUserAction(
          id: 'a1',
          title: 'Việc của tôi',
          createdAt: DateTime(2026),
        ),
      ]);
    await _pump(tester, _wrap(actions: repo));

    await tester.tap(find.byKey(const Key('wr_growth_user_action_delete_a1')));
    await tester.pumpAndSettle();
    expect(repo.deleteCalls, isEmpty);

    await tester.tap(
      find.byKey(const Key('wr_growth_user_action_delete_confirm')),
    );
    await tester.pumpAndSettle();
    expect(repo.deleteCalls, ['a1']);
    expect(find.byKey(_card('a1')), findsNothing);
  });

  testWidgets('chạm chip gợi ý → tự động điền vào ô nhập', (tester) async {
    final repo = FakeWrUserActionRepository();
    await _pump(tester, _wrap(actions: repo));

    expect(find.text('Hỏi ý kiến 1 đồng nghiệp'), findsOneWidget);
    await tester.tap(find.text('Hỏi ý kiến 1 đồng nghiệp'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byKey(_kInput)).controller!.text,
      'Hỏi ý kiến 1 đồng nghiệp',
    );
  });

  testWidgets(
    'hoàn thành việc → ghi nhận CareerMemoryEvent behavior user_action_completed',
    (tester) async {
      final repo = FakeWrUserActionRepository()
        ..seed([
          WrUserAction(
            id: 'a1',
            title: 'Lắng nghe trọn vẹn',
            createdAt: DateTime(2026, 9, 20),
            doneDays: [for (var d = 21; d <= 25; d++) DateTime(2026, 9, d)],
          ),
        ]);
      final content = FakeWrContentRepository();
      await _pump(tester, _wrap(actions: repo, content: content));

      await tester.tap(find.byKey(_complete('a1')));
      await tester.pumpAndSettle();

      expect(content.insertMemoryEventCalls, hasLength(1));
      final event = content.insertMemoryEventCalls.single;
      expect(event.behavior, 'user_action_completed');
      expect(event.reflectionText, contains('Lắng nghe trọn vẹn'));
    },
  );

  testWidgets('tiến độ vượt target (6/5) vẫn kẹp trần 5/5', (tester) async {
    final repo = FakeWrUserActionRepository()
      ..seed([
        WrUserAction(
          id: 'a1',
          title: 'Tập thở 3 phút',
          createdAt: DateTime(2026, 9, 20),
          doneDays: [for (var d = 20; d <= 25; d++) DateTime(2026, 9, d)],
        ),
      ]);
    await _pump(tester, _wrap(actions: repo));

    final card = find.byKey(_card('a1'));
    expect(find.descendant(of: card, matching: find.text('5/5')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Hoàn thành')), findsOneWidget);
  });

  testWidgets(
    'thứ tự hiển thị: việc đang làm lên trước, việc đã xong xuống dưới',
    (tester) async {
      final repo = FakeWrUserActionRepository()
        ..seed([
          WrUserAction(
            id: 'done1',
            title: 'Việc cũ đã hoàn thành',
            createdAt: DateTime(2026, 9, 1),
            completedAt: DateTime(2026, 9, 10),
            doneDays: [for (var d = 1; d <= 5; d++) DateTime(2026, 9, d)],
          ),
          WrUserAction(
            id: 'active1',
            title: 'Việc mới đang làm',
            createdAt: DateTime(2026, 9, 15),
            doneDays: [DateTime(2026, 9, 16)],
          ),
        ]);
      await _pump(tester, _wrap(actions: repo));

      final activeCard = find.byKey(_card('active1'));
      final doneCard = find.byKey(_card('done1'));
      expect(activeCard, findsOneWidget);
      expect(doneCard, findsOneWidget);

      expect(
        tester.getTopLeft(activeCard).dy,
        lessThan(tester.getTopLeft(doneCard).dy),
      );
    },
  );

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
