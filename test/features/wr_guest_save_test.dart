// Khách dùng thử → lưu hành trình (mockup v47, chốt 06/10/2026).
//
// Khoá:
//   1. Router: khách được ở lại Onboarding và mở màn đăng nhập; màn chờ đưa
//      khách về Home. Tài khoản thật giữ nguyên luật cũ.
//   2. Màn Xong: khách thấy sheet "Lưu lại hành trình" sau 1,1 giây, đúng MỘT
//      lần; tài khoản thật không bao giờ thấy.
//   3. Sheet: "Dùng email" mở màn lưu, "Để sau" chỉ đóng.
//   4. Màn lưu: gắn email vào chính user khách (không signUp), có dòng điều
//      khoản trên nút, báo lỗi email đã có tài khoản, và có nhánh chờ xác nhận.
//
// Run: flutter test test/features/wr_guest_save_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/router/app_router.dart';
import 'package:workreflection_mobile/features/auth/data/auth_repository.dart';
import 'package:workreflection_mobile/features/auth/guest_session.dart';
import 'package:workreflection_mobile/features/auth/presentation/wr_save_account_screen.dart';
import 'package:workreflection_mobile/features/auth/presentation/wr_save_journey_sheet.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_done_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

class _Auth implements AuthRepository {
  String? attachedEmail;
  String? attachedName;
  bool fail = false;
  bool confirmsImmediately = true;
  int signUps = 0;

  @override
  Future<bool> attachEmail(String email, String password, String name) async {
    if (fail) throw Exception('AuthApiException: User already registered');
    attachedEmail = email;
    attachedName = name;
    return confirmsImmediately;
  }

  @override
  Future<void> signUp(String email, String password, String name) async =>
      signUps++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app({
  required String initial,
  required bool guest,
  _Auth? auth,
  String uid = 'guest-1',
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(path: '/wr/flow/done', builder: (_, _) => const WrDoneScreen()),
      GoRoute(
        path: '/sheet',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showSaveJourneySheet(context),
              child: const Text('MỞ'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/auth/save',
        builder: (_, _) => const WrSaveAccountScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      isGuestProvider.overrideWith((ref) => guest),
      currentUserIdProvider.overrideWith((ref) => uid),
      authRepositoryProvider.overrideWithValue(auth ?? _Auth()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {
    wrEnglish = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('computeRedirect · khách', () {
    String? go(String loc, {bool guest = true, bool seen = true}) =>
        computeRedirect(
          hasSession: true,
          seenOnboarding: seen,
          location: loc,
          isGuest: guest,
        );

    test('khách ở lại Onboarding (phiên mở giữa Onboarding)', () {
      expect(go('/onboarding', seen: false), isNull);
    });
    test('khách mở được màn đăng nhập để vào tài khoản cũ', () {
      expect(go('/auth'), isNull);
    });
    test('khách ở màn chờ → Home', () {
      expect(go('/splash'), '/home');
    });
    test('khách vào được luồng nhìn lại và màn lưu', () {
      expect(go('/wr/flow/step'), isNull);
      expect(go('/auth/save'), isNull);
    });
    test('tài khoản thật giữ luật cũ: Onboarding/đăng nhập → Home', () {
      expect(go('/onboarding', guest: false), '/home');
      expect(go('/auth', guest: false), '/home');
    });
  });

  group('màn Xong', () {
    testWidgets('khách: sheet hiện sau 1,1 giây, và chỉ một lần', (
      tester,
    ) async {
      await tester.pumpWidget(_app(initial: '/wr/flow/done', guest: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byKey(const Key('wr_save_journey_sheet')), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_save_journey_sheet')), findsOneWidget);
      expect(find.text('Lưu lại hành trình của bạn'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_save_sheet_later')));
      await tester.pumpAndSettle();
      expect(await saveSheetSeen('guest-1'), isTrue);

      // Lần nhìn lại thứ hai: không tự mời nữa.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(initial: '/wr/flow/done', guest: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_save_journey_sheet')), findsNothing);
    });

    testWidgets('tài khoản thật không bao giờ thấy sheet', (tester) async {
      await tester.pumpWidget(_app(initial: '/wr/flow/done', guest: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_save_journey_sheet')), findsNothing);
    });
  });

  testWidgets('sheet: Dùng email mở màn lưu', (tester) async {
    await tester.pumpWidget(_app(initial: '/sheet', guest: true));
    await tester.tap(find.text('MỞ'));
    await tester.pumpAndSettle();
    expect(find.text('Dùng email'), findsOneWidget);
    expect(
      find.textContaining('hành trình chỉ nằm trên thiết bị này'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('wr_save_sheet_email')));
    await tester.pumpAndSettle();
    expect(find.byType(WrSaveAccountScreen), findsOneWidget);
  });

  group('màn lưu tài khoản', () {
    Future<void> fill(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('wr_save_name')), 'Yumi');
      await tester.enterText(
        find.byKey(const Key('wr_save_email')),
        ' yumi@example.com ',
      );
      await tester.enterText(
        find.byKey(const Key('wr_save_password')),
        'matkhau1',
      );
      await tester.tap(find.byKey(const Key('wr_save_account_submit')));
      // Không `pumpAndSettle`: nó chờ tới khi SnackBar 4 giây tắt hẳn.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('gắn email vào user khách, không signUp, có dòng điều khoản', (
      tester,
    ) async {
      final auth = _Auth();
      await tester.pumpWidget(
        _app(initial: '/auth/save', guest: true, auth: auth),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wr_save_account_legal')), findsOneWidget);

      await fill(tester);
      expect(auth.attachedEmail, 'yumi@example.com');
      expect(auth.attachedName, 'Yumi');
      expect(auth.signUps, 0);
      expect(find.text('Đã lưu hành trình của bạn'), findsOneWidget);
      // Không còn gì để quay lại thì về Home.
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('email đã có tài khoản → nói rõ hành trình không đi theo', (
      tester,
    ) async {
      final auth = _Auth()..fail = true;
      await tester.pumpWidget(
        _app(initial: '/auth/save', guest: true, auth: auth),
      );
      await tester.pumpAndSettle();
      await fill(tester);
      expect(find.byKey(const Key('wr_save_account_error')), findsOneWidget);
      expect(find.textContaining('sẽ không đi theo'), findsOneWidget);
    });

    testWidgets('project bật xác nhận email → màn chờ hộp thư', (tester) async {
      final auth = _Auth()..confirmsImmediately = false;
      await tester.pumpWidget(
        _app(initial: '/auth/save', guest: true, auth: auth),
      );
      await tester.pumpAndSettle();
      await fill(tester);
      expect(find.byKey(const Key('wr_save_account_pending')), findsOneWidget);
      expect(find.textContaining('yumi@example.com'), findsOneWidget);
    });

    testWidgets('chưa nhập đủ thì không gửi', (tester) async {
      final auth = _Auth();
      await tester.pumpWidget(
        _app(initial: '/auth/save', guest: true, auth: auth),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_save_account_submit')));
      await tester.pumpAndSettle();
      expect(auth.attachedEmail, isNull);
      expect(find.text('Email chưa đúng'), findsOneWidget);
    });
  });
}
