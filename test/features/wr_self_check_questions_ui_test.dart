// Widget test — chạy thật màn Self-check, duyệt đủ 15 câu và đối chiếu CHỮ
// HIỂN THỊ TRÊN MÀN HÌNH với bộ câu hỏi chuẩn của khách.
//
// Vì sao cần test này dù đã có test ở tầng dữ liệu: test kia chỉ chứng minh
// hằng số đúng, không chứng minh màn hình vẽ ra đúng chữ đó. Khách đọc màn
// hình chứ không đọc hằng số.
//
// Run: flutter test test/features/wr_self_check_questions_ui_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_self_check_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

void main() {
  testWidgets('màn hình hiện đúng nguyên văn cả 15 câu, theo đúng thứ tự',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final intel = FakeWrIntelligenceRepository();
    final router = GoRouter(
      initialLocation: '/wr/self-check',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('HOME')),
          routes: [
            GoRoute(
              path: 'wr/self-check',
              builder: (_, __) => const WrSelfCheckScreen(),
            ),
            GoRoute(
              path: 'wr/paywall',
              builder: (_, __) => const Scaffold(body: Text('PAYWALL')),
            ),
            GoRoute(path: 'wr/growth', builder: (_, __) => const Scaffold()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wrIntelligenceRepositoryProvider.overrideWithValue(intel),
          wrContentRepositoryProvider
              .overrideWithValue(FakeWrContentRepository()),
          currentUserIdProvider.overrideWithValue('u1'),
        ],
        child: MaterialApp.router(
          builder: wrTextScaleBuilder,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Vào bộ câu hỏi.
    await tester.tap(find.text('Bắt đầu →'));
    await tester.pumpAndSettle();

    // Duyệt từng câu: chữ trên màn phải khớp tuyệt đối, và đúng thứ tự.
    for (var i = 0; i < kSelfCheckQuestions.length; i++) {
      final q = kSelfCheckQuestions[i];

      expect(find.text('Câu ${i + 1} / 15'), findsOneWidget,
          reason: 'phải đang ở câu ${i + 1}');
      expect(find.text(q.text), findsOneWidget,
          reason: 'câu ${i + 1} (${q.id}) hiển thị sai nguyên văn');
      expect(find.textContaining('—'), findsNothing,
          reason: 'câu ${i + 1} không được có dấu gạch ngang dài');

      // Trả lời để sang câu kế (màn tự nhảy sau 260ms).
      await tester.tap(find.text('Đôi khi đúng'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }
  });
}
