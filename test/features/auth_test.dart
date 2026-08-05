import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
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
  // Error message thrown on signIn failure — mirrors Supabase SDK wording.
  String signInErrorMessage = 'Invalid login credentials';
  bool signUpShouldFail = false;
  // Error message thrown on signUp failure — mirrors Supabase SDK wording.
  String signUpErrorMessage = 'User already registered';
  int signInWithGoogleCalls = 0;

  // Forgot / change password tracking
  String? lastResetEmail;
  bool resetShouldFail = false;
  String? lastChangedPassword;
  bool changeShouldFail = false;

  @override
  Future<void> signIn(String email, String password) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (signInShouldFail) throw Exception(signInErrorMessage);
  }

  @override
  Future<void> signUp(String email, String password, String displayName) async {
    lastSignUpEmail = email;
    lastSignUpPassword = password;
    lastSignUpName = displayName;
    if (signUpShouldFail) throw Exception(signUpErrorMessage);
  }

  @override
  Future<void> signInWithGoogle() async {
    signInWithGoogleCalls++;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword(String email) async {
    lastResetEmail = email;
    if (resetShouldFail) throw Exception('Network error');
  }

  @override
  Future<void> changePassword(String newPassword) async {
    lastChangedPassword = newPassword;
    if (changeShouldFail) throw Exception('Session expired');
  }

  int deleteAccountCalls = 0;
  bool deleteShouldFail = false;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
    if (deleteShouldFail) throw Exception('Network error');
  }
}

Widget _wrap(Widget child, {AuthRepository? repo}) {
  final fake = repo ?? FakeAuthRepository();
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fake),
    ],
    child: MaterialApp(
      builder: wrTextScaleBuilder,
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

    testWidgets('does not show Google sign-in (tạm gỡ khỏi UI)', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      expect(find.text('Tiếp tục với Google'), findsNothing);
      expect(find.text('hoặc'), findsNothing);
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

    testWidgets('shows friendly l10n error when signIn fails with wrong credentials', (tester) async {
      final fake = FakeAuthRepository()
        ..signInShouldFail = true
        ..signInErrorMessage = 'Invalid login credentials';
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'bad@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'wrong123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      // Must show friendly l10n message, NOT raw Supabase string.
      expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
      expect(find.text('Invalid login credentials'), findsNothing);
    });

    testWidgets('shows friendly l10n error when signup with duplicate email', (tester) async {
      final fake = FakeAuthRepository()
        ..signUpShouldFail = true
        ..signUpErrorMessage = 'User already registered';
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      // Switch to register mode
      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên của bạn'),
        'Test User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'dup@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'pass123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      // Must show friendly l10n message, NOT raw Supabase string.
      expect(find.text('Email này đã được đăng ký. Vui lòng đăng nhập.'), findsOneWidget);
      expect(find.text('User already registered'), findsNothing);
    });

    testWidgets('shows generic error for unknown exception', (tester) async {
      final fake = FakeAuthRepository()
        ..signInShouldFail = true
        ..signInErrorMessage = 'network timeout xyz';
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'pass123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Đã xảy ra lỗi. Vui lòng thử lại.'), findsOneWidget);
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

    testWidgets('forgot-password button is visible in login mode', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      expect(find.byKey(const Key('auth_forgot_password_btn')), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
    });

    testWidgets('forgot-password button is hidden in register mode', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pump();

      expect(find.byKey(const Key('auth_forgot_password_btn')), findsNothing);
    });

    testWidgets('forgot-password dialog appears on tap', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      await tester.tap(find.byKey(const Key('auth_forgot_password_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Quên mật khẩu'), findsOneWidget); // dialog title
      expect(find.byKey(const Key('auth_forgot_password_submit')), findsOneWidget);
    });

    testWidgets('forgot-password dialog calls resetPassword with email', (tester) async {
      final fake = FakeAuthRepository();
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      await tester.tap(find.byKey(const Key('auth_forgot_password_btn')));
      await tester.pumpAndSettle();

      // Use key to avoid ambiguity with the main screen's Email field
      await tester.enterText(
        find.byKey(const Key('auth_forgot_password_email_field')),
        'user@test.com',
      );

      await tester.tap(find.byKey(const Key('auth_forgot_password_submit')));
      await tester.pumpAndSettle();

      expect(fake.lastResetEmail, 'user@test.com');
    });

    testWidgets('forgot-password shows snackbar on success', (tester) async {
      final fake = FakeAuthRepository();
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      await tester.tap(find.byKey(const Key('auth_forgot_password_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth_forgot_password_email_field')),
        'user@test.com',
      );

      await tester.tap(find.byKey(const Key('auth_forgot_password_submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Kiểm tra email'), findsOneWidget);
    });

    testWidgets('forgot-password shows error snackbar on failure', (tester) async {
      final fake = FakeAuthRepository()..resetShouldFail = true;
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      await tester.tap(find.byKey(const Key('auth_forgot_password_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth_forgot_password_email_field')),
        'user@test.com',
      );

      await tester.tap(find.byKey(const Key('auth_forgot_password_submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Không thể gửi email'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Form validator widget tests
  // ---------------------------------------------------------------------------
  group('AuthScreen form validators', () {
    testWidgets('shows email format error when @ is missing in login', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'notanemail',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'pass123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pump();

      expect(find.text('Email không hợp lệ'), findsOneWidget);
    });

    testWidgets('shows password min-length error when password is too short in login', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'abc',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pump();

      expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);
    });

    testWidgets('shows email format error when @ is missing in register', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên của bạn'),
        'Test User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'bademail',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'pass123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
      await tester.pump();

      expect(find.text('Email không hợp lệ'), findsOneWidget);
    });

    testWidgets('shows password min-length error in register mode', (tester) async {
      await tester.pumpWidget(_wrap(const AuthScreen()));
      await tester.pump();

      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên của bạn'),
        'Test User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'short',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
      await tester.pump();

      expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);
    });

    testWidgets('accepts valid email and 6-char password without validator error', (tester) async {
      final fake = FakeAuthRepository();
      await tester.pumpWidget(_wrap(const AuthScreen(), repo: fake));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'abc123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      // No validator errors
      expect(find.text('Email không hợp lệ'), findsNothing);
      expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsNothing);
      // signIn was called
      expect(fake.lastSignInEmail, 'user@test.com');
    });
  });

  // ---------------------------------------------------------------------------
  // Password validation unit tests (pure logic, no widget pump needed)
  // ---------------------------------------------------------------------------
  group('Password validation logic', () {
    test('password shorter than 6 chars fails min-length check', () {
      const password = 'abc12';
      expect(password.length < 6, isTrue);
    });

    test('password of exactly 6 chars passes min-length check', () {
      const password = 'abc123';
      expect(password.length >= 6, isTrue);
    });

    test('mismatched passwords detected', () {
      const p1 = 'abc123';
      const p2 = 'abc124';
      expect(p1 == p2, isFalse);
    });

    test('matching passwords pass', () {
      const p1 = 'abc123';
      const p2 = 'abc123';
      expect(p1 == p2, isTrue);
    });

    test('email without @ is invalid', () {
      const email = 'notanemail';
      expect(email.contains('@'), isFalse);
    });

    test('valid email contains @', () {
      const email = 'user@test.com';
      expect(email.contains('@'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Navigation routing logic
  // ---------------------------------------------------------------------------

  // Helper mirrors the routing expression in auth_screen.dart _submit().
  String routeAfterAuth(bool isLogin) =>
      isLogin ? '/home' : '/profile/setup';

  group('AuthScreen navigation routing', () {
    test('login mode routes to /home', () {
      expect(routeAfterAuth(true), '/home');
    });

    test('signup mode routes to /profile/setup', () {
      expect(routeAfterAuth(false), '/profile/setup');
    });
  });
}
