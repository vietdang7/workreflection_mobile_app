import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/features/wr/episode_flow_controller.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_detail_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

/// Câu kể mặc định khi phiên được nạp lại chưa có chữ ở bước 2/4.
///
/// Mockup v47 bắt buộc ô kể ("Tôi đã kể xong" khoá khi trống), nên phiên nào
/// chưa có `notes['explore']` thì phải gõ một câu mới qua được bước này. Câu
/// được chọn để KHÔNG chứa từ khoá nào của `reflectionAhaFor` (im, sợ, chờ…),
/// tránh lặng lẽ đổi biến thể Insight của các test phía sau.
const kResumeDefaultDetail = 'Một khoảnh khắc trong buổi làm việc hôm nay';

Future<void> resumeOpenEpisode(
  WidgetTester tester, {
  bool stopAtDetail = false,
  String detail = kResumeDefaultDetail,
}) async {
  final element = tester.element(find.byType(WrHomeScreen));
  final container = ProviderScope.containerOf(element);

  final episode = await container.read(wrOpenEpisodeProvider.future);
  expect(episode, isNotNull, reason: 'không có phiên nào đang mở để tiếp tục');

  await container.read(episodeFlowProvider.notifier).resume(episode!);
  GoRouter.of(element).push('/wr/flow/step');
  await tester.pumpAndSettle();

  if (!stopAtDetail && find.byType(WrDetailScreen).evaluate().isNotEmpty) {
    final field = find.byKey(const Key('wr_detail_field'));
    final current = tester.widget<TextField>(field).controller?.text ?? '';
    if (current.trim().isEmpty) {
      await tester.enterText(field, detail);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();
  }
}
