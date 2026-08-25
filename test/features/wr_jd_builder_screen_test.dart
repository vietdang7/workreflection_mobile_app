// Màn "Viết JD cùng app" — changelog 24/08/2026 §6, mockup v16 `screenJdDay*`.
//
// §6 nói rõ hai chỗ mockup mới chỉ là demo và bản thật phải làm khác:
//   · "Dừng ở đây, làm tiếp sau" phải LƯU THẬT, không chỉ đóng màn;
//   · buổi sau phải khoá cho đến khi xong buổi trước, không cho nhảy cóc.
// Hai điều đó là phần lớn nhóm test này.
//
// Run: flutter test test/features/wr_jd_builder_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_jd_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_jd_builder.dart';
import 'package:workreflection_mobile/core/models/wr_jd_draft.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_jd_builder_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

class SaveCall {
  const SaveCall(this.day, this.fields, this.markDayDone);
  final int day;
  final Map<String, String?> fields;
  final bool markDayDone;
}

class FakeWrJdRepository implements WrJdRepository {
  FakeWrJdRepository({WrJdDraft? seed}) : _draft = seed;

  WrJdDraft? _draft;
  final List<SaveCall> calls = [];

  /// Bật lên để mô phỏng mất mạng ở lần lưu tiếp theo.
  bool failNextSave = false;

  @override
  Future<WrJdDraft?> fetch() async => _draft;

  @override
  Future<WrJdDraft> save({
    required int day,
    required Map<String, String?> fields,
    required bool markDayDone,
  }) async {
    calls.add(SaveCall(day, fields, markDayDone));
    if (failNextSave) {
      failNextSave = false;
      throw StateError('offline');
    }
    final current = _draft ?? WrJdDraft.empty();
    final completed = markDayDone
        ? markJdDayDone(day, current.completedDays)
        : current.completedDays;
    _draft = current.copyWith(
      values: {...current.values, ...fields},
      currentDay: markDayDone && day < kJdDayCount ? day + 1 : day,
      completedDays: completed,
    );
    return _draft!;
  }
}

Widget _wrap(FakeWrJdRepository repo) {
  final router = GoRouter(
    initialLocation: '/wr/work-info',
    routes: [
      GoRoute(
        path: '/wr/work-info',
        builder: (_, __) => const Scaffold(body: Text('THÔNG TIN CÔNG VIỆC')),
        routes: [],
      ),
      GoRoute(
        path: '/wr/jd-builder',
        builder: (_, __) => const WrJdBuilderScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      wrJdRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      routerConfig: router,
    ),
  );
}

/// Mở màn JD từ màn Thông tin công việc, để `context.pop()` có chỗ quay về.
Future<void> _openBuilder(WidgetTester tester, FakeWrJdRepository repo) async {
  await tester.pumpWidget(_wrap(repo));
  await tester.pumpAndSettle();
  final ctx = tester.element(find.text('THÔNG TIN CÔNG VIỆC'));
  GoRouter.of(ctx).push('/wr/jd-builder');
  await tester.pumpAndSettle();
}

void main() {
  // Màn có tiêu đề, năm vạch, phần mở đầu và tới ba ô nhiều dòng — dài hơn
  // khung 800px mặc định. Nới khung thay vì cuộn từng lần.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 2400);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetDevicePixelRatio();
    view.resetPhysicalSize();
  });

  group('§6 · Mở màn', () {
    testWidgets('chưa có gì thì mở ở buổi 1 với ô trống', (tester) async {
      final repo = FakeWrJdRepository();
      await _openBuilder(tester, repo);

      expect(find.text(kJdDays.first.title), findsOneWidget);
      for (final f in kJdDays.first.fields) {
        expect(find.byKey(Key('wr_jd_field_${f.column}')), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(Key('wr_jd_field_${f.column}')))
              .controller!
              .text,
          '',
          reason: f.column,
        );
      }
    });

    testWidgets('viết dở thì mở lại đúng buổi đang dở, chữ cũ còn nguyên',
        (tester) async {
      final repo = FakeWrJdRepository(
        seed: WrJdDraft(
          values: const {'job_title': 'Trưởng nhóm nội dung'},
          currentDay: 2,
          completedDays: const [1],
        ),
      );
      await _openBuilder(tester, repo);

      expect(find.text(kJdDays[1].title), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('wr_jd_field_job_title')))
            .controller!
            .text,
        'Trưởng nhóm nội dung',
      );
    });

    testWidgets('buổi cuối mới hiện lời hứa lưu vào hồ sơ', (tester) async {
      final repo = FakeWrJdRepository();
      await _openBuilder(tester, repo);
      expect(find.byKey(const Key('wr_jd_completion_note')), findsNothing);
      expect(find.text('Lưu và tiếp tục'), findsOneWidget);

      final done = FakeWrJdRepository(
        seed: WrJdDraft(
          values: const {},
          currentDay: 5,
          completedDays: const [1, 2, 3, 4],
        ),
      );
      await _openBuilder(tester, done);
      expect(find.byKey(const Key('wr_jd_completion_note')), findsOneWidget);
      expect(find.text('Hoàn tất, lưu vào hồ sơ'), findsOneWidget);
    });
  });

  group('§6 · Khoá buổi sau, không cho nhảy cóc', () {
    testWidgets('vạch của buổi chưa mở khoá không nhận chạm', (tester) async {
      final repo = FakeWrJdRepository();
      await _openBuilder(tester, repo);

      await tester.tap(find.byKey(const Key('wr_jd_step_4')));
      await tester.pumpAndSettle();

      // Vẫn ở buổi 1.
      expect(find.text(kJdDays.first.title), findsOneWidget);
    });

    testWidgets('vạch của buổi đã xong đưa được về để sửa', (tester) async {
      final repo = FakeWrJdRepository(
        seed: WrJdDraft(
          values: const {},
          currentDay: 3,
          completedDays: const [1, 2],
        ),
      );
      await _openBuilder(tester, repo);
      expect(find.text(kJdDays[2].title), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_jd_step_1')));
      await tester.pumpAndSettle();
      expect(find.text(kJdDays.first.title), findsOneWidget);
    });

    testWidgets('buổi khoá được đọc màn hình báo là chưa mở', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = FakeWrJdRepository();
      await _openBuilder(tester, repo);

      expect(find.bySemanticsLabel('Buổi 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Buổi 3, chưa mở khoá'), findsOneWidget);
      handle.dispose();
    });
  });

  group('§6 · Lưu và tiếp tục', () {
    testWidgets('ghi đúng buổi đang mở rồi sang buổi sau', (tester) async {
      final repo = FakeWrJdRepository();
      await _openBuilder(tester, repo);

      final first = kJdDays.first.fields.first.column;
      await tester.enterText(
        find.byKey(Key('wr_jd_field_$first')),
        'Việc bị ngắt quãng suốt',
      );
      await tester.tap(find.byKey(const Key('wr_jd_primary')));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.day, 1);
      expect(repo.calls.single.markDayDone, isTrue);
      expect(repo.calls.single.fields[first], 'Việc bị ngắt quãng suốt');
      // Chỉ gửi các ô của buổi 1 — gửi cả mười ba cột sẽ xoá trắng buổi khác.
      expect(
        repo.calls.single.fields.keys.toSet(),
        kJdDays.first.fields.map((f) => f.column).toSet(),
      );
      expect(find.text(kJdDays[1].title), findsOneWidget);
    });

    testWidgets('xong buổi cuối thì đóng màn, về Thông tin công việc',
        (tester) async {
      final repo = FakeWrJdRepository(
        seed: WrJdDraft(
          values: const {},
          currentDay: 5,
          completedDays: const [1, 2, 3, 4],
        ),
      );
      await _openBuilder(tester, repo);

      await tester.tap(find.byKey(const Key('wr_jd_primary')));
      await tester.pumpAndSettle();

      expect(repo.calls.single.day, kJdDayCount);
      expect(find.text('THÔNG TIN CÔNG VIỆC'), findsOneWidget);
      expect(isJdComplete(repo._draft!.completedDays), isTrue);
    });

    testWidgets('lưu hỏng thì ở lại màn và báo lỗi', (tester) async {
      final repo = FakeWrJdRepository()..failNextSave = true;
      await _openBuilder(tester, repo);

      await tester.tap(find.byKey(const Key('wr_jd_primary')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_jd_error')), findsOneWidget);
      expect(find.text(kJdDays.first.title), findsOneWidget);
    });
  });

  group('§6 · "Dừng ở đây, làm tiếp sau" lưu thật', () {
    testWidgets('ghi nháp rồi mới rời màn, buổi vẫn còn dở', (tester) async {
      final repo = FakeWrJdRepository();
      await _openBuilder(tester, repo);

      final first = kJdDays.first.fields.first.column;
      await tester.enterText(
        find.byKey(Key('wr_jd_field_$first')),
        'Mới viết được một nửa',
      );
      await tester.tap(find.byKey(const Key('wr_jd_pause')));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.markDayDone, isFalse);
      expect(repo.calls.single.fields[first], 'Mới viết được một nửa');
      expect(find.text('THÔNG TIN CÔNG VIỆC'), findsOneWidget);

      // Buổi 1 chưa xong nên buổi 2 vẫn khoá.
      expect(repo._draft!.completedDays, isEmpty);
      expect(canOpenJdDay(2, repo._draft!.completedDays), isFalse);
    });

    testWidgets('lưu nháp hỏng thì giữ người dùng lại, không nuốt chữ',
        (tester) async {
      final repo = FakeWrJdRepository()..failNextSave = true;
      await _openBuilder(tester, repo);

      final first = kJdDays.first.fields.first.column;
      await tester.enterText(
        find.byKey(Key('wr_jd_field_$first')),
        'Chữ không được mất',
      );
      await tester.tap(find.byKey(const Key('wr_jd_pause')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_jd_error')), findsOneWidget);
      expect(find.text('THÔNG TIN CÔNG VIỆC'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(Key('wr_jd_field_$first')))
            .controller!
            .text,
        'Chữ không được mất',
      );
    });
  });
}
