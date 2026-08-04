// Widget tests — WrCareerSetupScreen (3 bước thiết lập hồ sơ).
// Spec: giao-dien-ho-tro.jsx — CareerSetupScreen.
// Run: flutter test test/features/wr_career_setup_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_career_profile.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_career_setup_screen.dart';

import '../support/fake_repository.dart';

Widget _wrap(FakeWrRepository repo) {
  final router = GoRouter(
    initialLocation: '/wr/career-setup',
    routes: [
      GoRoute(
        path: '/wr/career-setup',
        builder: (_, __) => const WrCareerSetupScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
    ],
  );
  return ProviderScope(
    overrides: [wrRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: router),
  );
}

/// Chọn [label] rồi chờ auto-advance (300ms) hoàn tất.
Future<void> _pick(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bước 1 hiện câu hỏi vai trò và đủ 6 lựa chọn', (tester) async {
    await tester.pumpWidget(_wrap(FakeWrRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Vai trò hiện tại của bạn là gì?'), findsOneWidget);
    expect(find.text('THIẾT LẬP HỒ SƠ · 1/3'), findsOneWidget);
    for (final r in kCareerRoleOptions) {
      expect(find.text(r), findsOneWidget);
    }
  });

  testWidgets('chọn xong bước 1 thì tự sang bước 2', (tester) async {
    await tester.pumpWidget(_wrap(FakeWrRepository()));
    await tester.pumpAndSettle();

    await _pick(tester, 'Team Leader');

    expect(find.text('THIẾT LẬP HỒ SƠ · 2/3'), findsOneWidget);
    expect(
      find.text('Điều bạn đang quan tâm nhất trong sự nghiệp hiện tại?'),
      findsOneWidget,
    );
  });

  testWidgets('đi hết 3 bước thì lưu đủ cả ba trường', (tester) async {
    final repo = FakeWrRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await _pick(tester, 'Manager');
    await _pick(tester, 'Thăng tiến');
    await _pick(tester, 'Áp lực công việc');

    expect(repo.saveCareerSnapshotCalls, hasLength(1));
    final saved = repo.saveCareerSnapshotCalls.single;
    expect(saved.currentRole, 'Manager');
    expect(saved.careerGoal, 'Thăng tiến');
    expect(saved.currentChallenge, 'Áp lực công việc');
    expect(saved.isComplete, isTrue);
  });

  testWidgets('bỏ qua bước giữa vẫn lưu các bước đã trả lời', (tester) async {
    final repo = FakeWrRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await _pick(tester, 'Director');

    await tester.tap(find.text('Bỏ qua bước này'));
    await tester.pumpAndSettle();

    await _pick(tester, 'Thiếu động lực');

    final saved = repo.saveCareerSnapshotCalls.single;
    expect(saved.currentRole, 'Director');
    expect(saved.careerGoal, isNull);
    expect(saved.currentChallenge, 'Thiếu động lực');
  });

  testWidgets('bỏ qua toàn bộ thì không gọi lưu', (tester) async {
    final repo = FakeWrRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bỏ qua bước này'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ qua bước này'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ qua, vào app'), findsOneWidget);
    await tester.tap(find.text('Bỏ qua, vào app'));
    await tester.pumpAndSettle();

    expect(repo.saveCareerSnapshotCalls, isEmpty);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('lỗi lưu thì báo lỗi và giữ nguyên màn hình', (tester) async {
    final repo = FakeWrRepository()..failSaveCareerSnapshot = true;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await _pick(tester, 'Chuyên viên');
    await _pick(tester, 'Khởi nghiệp');
    await _pick(tester, 'Không rõ hướng đi');

    expect(
      find.text('Chưa lưu được hồ sơ. Bạn có thể thử lại sau.'),
      findsOneWidget,
    );
    expect(find.text('HOME'), findsNothing);
  });
}
