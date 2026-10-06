// Onboarding năm bước — mockup v47 (06/10/2026).
//
// Khoá:
//   1. Chữ đúng v47 ở từng bước; bước Riêng tư KHÔNG còn chip giờ nhắc và
//      dòng điều khoản (v47 chuyển sang Hồ sơ và màn đăng ký).
//   2. Hết bước Riêng tư mới phát video hướng dẫn, đóng video thì sang bước
//      chọn cảm xúc. Nút lùi quay về bước trước.
//   3. Chọn cảm xúc: mở phiên khách đúng một lần, ghi check-in đúng cảm xúc,
//      vào `/wr/flow/step` với Home nằm dưới (nút lùi của luồng có chỗ về).
//   4. Bỏ qua: phiên khách rồi về Home. "Đăng nhập": KHÔNG mở phiên khách.
//   5. Không tràn ở màn hẹp, cả tiếng Anh.
//
// Run: flutter test test/features/onboarding_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/router/app_router.dart';
import 'package:workreflection_mobile/core/router/auth_change_notifier.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/auth/data/auth_repository.dart';
import 'package:workreflection_mobile/features/auth/guest_session.dart';
import 'package:workreflection_mobile/features/onboarding/intro_video_providers.dart';
import 'package:workreflection_mobile/features/onboarding/onboarding_state.dart';
import 'package:workreflection_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:workreflection_mobile/features/onboarding/presentation/wr_intro_video_sheet.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';

class _GuestAuth implements AuthRepository {
  _GuestAuth(this.notifier);

  final AuthChangeNotifier notifier;
  int anonymousSignIns = 0;

  @override
  Future<void> signInAnonymously() async {
    anonymousSignIns++;
    // Giống app.dart: xử lý xong sự kiện đăng nhập thì báo router.
    notifier.notify();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness({this.hasSession = false}) {
    auth = _GuestAuth(notifier);
  }

  final bool hasSession;
  final notifier = AuthChangeNotifier();
  late final _GuestAuth auth;
  final repo = FakeWrRepository();
  late final GoRouter router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (_, _) => const Text('HOME')),
      GoRoute(path: '/wr/flow/step', builder: (_, _) => const Text('STEP')),
    ],
  );

  Widget app({Locale locale = const Locale('vi')}) => ProviderScope(
    overrides: [
      introTimingSourceProvider.overrideWithValue((_) async => null),
      authChangeNotifierProvider.overrideWithValue(notifier),
      authRepositoryProvider.overrideWithValue(auth),
      hasAuthSessionProvider.overrideWithValue(() => hasSession),
      wrRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      routerConfig: router,
    ),
  );
}

/// Một bước chuyển: khung đầu khởi động hiệu ứng, khung giữa chạy hết, khung
/// cuối gỡ màn cũ (không thì hai nút cùng khoá).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding_next')));
  await _settle(tester);
}

/// Đi tới bước chọn cảm xúc: ba bước hero, Riêng tư, xem rồi đóng video.
Future<void> _toMoodStep(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await _next(tester);
  }
  await _toMoodStepFromPrivacy(tester);
}

void main() {
  setUp(() {
    wrEnglish = false;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => wrEnglish = false);

  test('OnboardingState không còn bước, tình huống luôn null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(onboardingNotifierProvider).selectedSituation,
      isNull,
    );
  });

  testWidgets('bước đầu: chữ v47, năm vạch, lối đăng nhập, chưa có nút lùi', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness().app());
    await _settle(tester);

    expect(find.text('DỪNG LẠI MỘT CHÚT'), findsOneWidget);
    expect(
      find.text('Có những ngày làm việc trôi qua rất vội.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onboarding_segments')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_sign_in')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_back')), findsNothing);
    expect(find.text('Chào mừng bạn đến với WorkReflection'), findsNothing);
    expect(find.byType(WrIntroVideoSheet), findsNothing);
  });

  testWidgets('bước Riêng tư chỉ có chữ; nút lùi quay về bước trước', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness().app());
    await _settle(tester);

    await _next(tester);
    expect(
      find.text('Nhận ra những điều đang âm thầm lặp lại.'),
      findsOneWidget,
    );
    await _next(tester);
    expect(find.text('Những điều bạn ghi lại sẽ ở lại.'), findsOneWidget);
    await _next(tester);
    expect(find.text('Những gì bạn viết là của bạn'), findsOneWidget);
    for (final gone in ['Đầu ngày', 'Để tôi tự nhớ', 'Đêm khuya']) {
      expect(find.text(gone), findsNothing, reason: 'v47 bỏ chip "$gone"');
    }
    expect(find.textContaining('Bằng việc tiếp tục'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding_back')));
    await _settle(tester);
    expect(find.text('Những điều bạn ghi lại sẽ ở lại.'), findsOneWidget);
  });

  testWidgets(
    'chọn cảm xúc → một phiên khách, ghi check-in, vào luồng với Home bên dưới',
    (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await _settle(tester);
      await _toMoodStep(tester);

      expect(find.byKey(const Key('onboarding_mood_stress')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_mood_stress')));
      await tester.pumpAndSettle();

      expect(h.auth.anonymousSignIns, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('seen_onboarding'), isTrue);
      expect(h.repo.upsertCheckinCalls.single.mood, Mood.stressed);
      expect(find.text('STEP'), findsOneWidget);
      expect(h.router.canPop(), isTrue);
      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets('đã có phiên thì không mở phiên khách thứ hai', (tester) async {
    final h = _Harness(hasSession: true);
    await tester.pumpWidget(h.app());
    await _settle(tester);
    await _toMoodStep(tester);

    await tester.tap(find.byKey(const Key('onboarding_mood_ok')));
    await tester.pumpAndSettle();
    expect(h.auth.anonymousSignIns, 0);
    expect(find.text('STEP'), findsOneWidget);
  });

  testWidgets('Bỏ qua → phiên khách rồi về Home', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());
    await _settle(tester);

    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(h.auth.anonymousSignIns, 1);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Đăng nhập → ghi đã xem, KHÔNG mở phiên khách', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());
    await _settle(tester);

    await tester.tap(find.byKey(const Key('onboarding_sign_in')));
    await tester.pumpAndSettle();
    expect(h.auth.anonymousSignIns, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('seen_onboarding'), isTrue);
  });

  for (final (width, en) in [(320.0, false), (320.0, true), (390.0, false)]) {
    testWidgets('năm bước không tràn (rộng $width, ${en ? 'EN' : 'VI'})', (
      tester,
    ) async {
      wrEnglish = en;
      tester.view.physicalSize = Size(width * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Harness().app(locale: Locale(en ? 'en' : 'vi')));
      await _settle(tester);
      for (var i = 0; i < 3; i++) {
        expect(tester.takeException(), isNull, reason: 'bước $i');
        await _next(tester);
      }
      expect(tester.takeException(), isNull, reason: 'bước Riêng tư');
      await _toMoodStepFromPrivacy(tester);
      expect(find.byKey(const Key('onboarding_mood_happy')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'bước chọn cảm xúc');
    });
  }
}

Future<void> _toMoodStepFromPrivacy(WidgetTester tester) async {
  await _next(tester);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.byKey(const Key('intro_video_close')));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
