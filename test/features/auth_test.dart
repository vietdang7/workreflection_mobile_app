import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/features/auth/data/auth_repository.dart';
import 'package:workreflection_mobile/features/auth/presentation/auth_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake AuthRepository for widget tests — no network calls.
// ---------------------------------------------------------------------------

class FakeAuthRepository implements AuthRepository {
  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastSignUpEmail;
  String? lastSignUpPassword;
  String? lastSignUpName;
  bool signInShouldFail = false;
  bool signUpShouldFail = false;
  int signInWithGoogleCalls = 0;

  @override
  Future<void> signIn(String email, String password) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (signInShouldFail) throw Exception('Invalid credentials');
  }

  @override
  Future<void> signUp(String email, String password, String displayName) async {
    lastSignUpEmail = email;
    lastSignUpPassword = password;
    lastSignUpName = displayName;
    if (signUpShouldFail) throw Exception('Email already in use');
  }

  @override
  Future<void> signInWithGoogle() async {
    signInWithGoogleCalls++;
  }

  @override
  Future<void> signOut() async {}
}

Widget _wrap(Widget child, {AuthRepository? repo}) {
  final fake = repo ?? FakeAuthRepository();
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fake),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: child,
    ),
  );
}

void main() {
  group('AuthScreen widget', () {
    testWidgets('renders login mode by default with correct title', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      expect(find.text('Chào mừng trở lại'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsWidgets); // title text + button
    });

    testWidgets('shows email and password fields in login mode', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Mật khẩu'), findsOneWidget);
    });

    testWidgets('switches to register mode showing name field', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      // Tap switch link
      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pump();

      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Tên của bạn'), findsOneWidget);
    });

    testWidgets('shows Google button with correct label', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      expect(find.text('Tiếp tục với Google'), findsOneWidget);
    });

    testWidgets('shows divider "hoặc"', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      expect(find.text('hoặc'), findsOneWidget);
    });

    testWidgets('calls signIn with typed email and password', (tester) async {
      final fake = FakeAuthRepository();
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'secret123',
      );

      // Tap the Đăng nhập button (ElevatedButton, not the title text)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(fake.lastSignInEmail, 'user@test.com');
      expect(fake.lastSignInPassword, 'secret123');
    });

    testWidgets('shows inline error when signIn fails', (tester) async {
      final fake = FakeAuthRepository()..signInShouldFail = true;
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'bad@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'wrong',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      // Error text should appear
      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('Google button calls signInWithGoogle on repository', (tester) async {
      final fake = FakeAuthRepository();
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      await tester.tap(find.text('Tiếp tục với Google'));
      await tester.pumpAndSettle();

      expect(fake.signInWithGoogleCalls, 1);
    });

    testWidgets('register mode calls signUp with name email password', (tester) async {
      final fake = FakeAuthRepository();
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      // Switch to register
      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên của bạn'),
        'Test User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'pass123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.lastSignUpName, 'Test User');
      expect(fake.lastSignUpEmail, 'new@test.com');
      expect(fake.lastSignUpPassword, 'pass123');
    });
  });
}
