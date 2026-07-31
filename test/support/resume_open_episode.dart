// Tiếp tục phiên phản tư đang mở, không đi qua màn Home.
//
// Trước 2026-07-30, Home có thẻ "ĐANG CHỜ BẠN" và mọi test muốn vào giữa luồng
// đều bấm thẻ đó. Khách yêu cầu bỏ thẻ (mockup Sprint 2 không có nó), nên các
// test cần một lối vào khác.
//
// Helper này làm đúng hai việc mà thẻ kia từng làm: nạp phiên đang mở vào
// `episodeFlowProvider` rồi mở `/wr/flow/step` — cùng một điểm vào mà app thật
// dùng cho nút "Hiểu lại chuyện này" ở chi tiết Episode.
//
// Từ 2026-07-31 (luồng 5 bước của v2.0 §V), phiên đã qua bước chọn tình huống
// thì `/wr/flow/step` chuyển tiếp sang `/wr/flow/detail` — bước viết chi tiết,
// vốn KHÔNG bắt buộc. Phần lớn test muốn đi tiếp tới màn Ý nghĩa, nên mặc định
// helper bấm "Tiếp tục" qua bước đó. Test nào muốn dừng lại ở chính bước chi
// tiết thì truyền `stopAtDetail: true`.
//
// Trong app thật, lối vào tương ứng là tab Hành trình → chi tiết Episode → "Hiểu
// lại chuyện này": rời luồng gọi `pause()` nên phiên thành dormant, và nút đó
// hiện ra.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/features/wr/episode_flow_controller.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_detail_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

/// Gọi khi đang ĐỨNG Ở HOME: neo vào element của Home để lấy được cả
/// ProviderScope lẫn GoRouter (`GoRouter.of` cần context nằm dưới router).
Future<void> resumeOpenEpisode(
  WidgetTester tester, {
  bool stopAtDetail = false,
}) async {
  final element = tester.element(find.byType(WrHomeScreen));
  final container = ProviderScope.containerOf(element);

  final episode = await container.read(wrOpenEpisodeProvider.future);
  expect(episode, isNotNull, reason: 'không có phiên nào đang mở để tiếp tục');

  await container.read(episodeFlowProvider.notifier).resume(episode!);
  GoRouter.of(element).push('/wr/flow/step');
  await tester.pumpAndSettle();

  if (!stopAtDetail && find.byType(WrDetailScreen).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();
  }
}
