import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/data/seed_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/presentation/wr_logo.dart';
import '../data/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = ref.read(authRepositoryProvider);
    final l10n = context.l10n;
    try {
      if (_isLogin) {
        await repo.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await repo.signUp(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );
      }
      // Best-effort: ensure profile row exists and sample data is seeded.
      // Note: app.dart's auth listener also calls ensureSeeded on SIGNED_IN;
      // the seed service is idempotent so double-calls are safe.
      await ref.read(seedServiceProvider).ensureSeeded();
      if (mounted) {
        context.go(_isLogin ? '/home' : '/profile/setup');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyAuthError(e, l10n);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps raw Supabase / exception messages to friendly l10n strings.
  String _friendlyAuthError(Object e, AppLocalizations l10n) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('already registered') ||
        raw.contains('already in use') ||
        raw.contains('user already exists') ||
        raw.contains('duplicate') ||
        raw.contains('unique constraint')) {
      return l10n.authErrorDuplicateEmail;
    }
    if (raw.contains('invalid login') ||
        raw.contains('invalid credentials') ||
        raw.contains('wrong password') ||
        raw.contains('invalid email or password') ||
        raw.contains('email not confirmed')) {
      return l10n.authErrorInvalidCredentials;
    }
    return l10n.authErrorGeneric;
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        onSubmit: (String email) async {
          Navigator.of(ctx).pop();
          await _sendPasswordReset(email);
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _sendPasswordReset(String email) async {
    final l10n = context.l10n;
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authForgotPasswordSuccess)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authForgotPasswordError)),
        );
      }
    }
  }

  /// Khuôn ô nhập dùng chung cho cả ba trường, để bốn ô không còn mỗi ô một
  /// dáng: cùng bo góc, cùng viền `--line`, cùng nền xám nhạt trên thẻ trắng.
  /// Nhãn vẫn là `labelText` (không tách thành [Text] riêng) — cả bộ test
  /// widget tìm ô bằng `find.widgetWithText(TextFormField, 'Email')`.
  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: WrColors.pageBg,
      prefixIcon: Icon(icon, size: 20, color: WrColors.text3),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      labelStyle: const TextStyle(color: WrColors.text2, fontSize: 15.5),
      floatingLabelStyle: const TextStyle(
        color: WrColors.navy,
        fontWeight: FontWeight.w600,
      ),
      border: border(WrColors.line, 1),
      enabledBorder: border(WrColors.line, 1),
      focusedBorder: border(WrColors.navy, 1.6),
      errorBorder: border(WrColors.destructive, 1),
      focusedErrorBorder: border(WrColors.destructive, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        // Khối đăng nhập/đăng ký canh giữa theo chiều dọc thay vì dồn lên đỉnh
        // rồi bỏ trống nửa dưới màn hình. [LayoutBuilder] + `minHeight` giữ
        // được cả hai: canh giữa khi còn chỗ, cuộn được khi bàn phím bật lên.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    // Trên máy tablet/màn rộng, form kéo hết bề ngang sẽ loãng.
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: WrLogo(width: 240)),
                          const SizedBox(height: 22),
                          Text(
                            _isLogin
                                ? l10n.authLoginTitle
                                : l10n.authRegisterTitle,
                            textAlign: TextAlign.center,
                            style: WrTextStyles.hLarge.copyWith(fontSize: 26),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isLogin
                                ? l10n.authLoginSubtitle
                                : l10n.authRegisterSubtitle,
                            textAlign: TextAlign.center,
                            style: WrTextStyles.body.copyWith(
                              fontSize: 14.5,
                              color: WrColors.text2,
                            ),
                          ),
                          const SizedBox(height: 22),

                          WrCardMinimal(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Name field (register only)
                                if (!_isLogin) ...[
                                  TextFormField(
                                    controller: _nameCtrl,
                                    textInputAction: TextInputAction.next,
                                    decoration: _fieldDecoration(
                                      label: l10n.authNameLabel,
                                      icon: Icons.person_outline,
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? l10n.authValidatorName
                                            : null,
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // Email field
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: _fieldDecoration(
                                    label: l10n.authEmailLabel,
                                    icon: Icons.mail_outline,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return l10n.authValidatorEmail;
                                    }
                                    if (!v.trim().contains('@')) {
                                      return l10n.authValidatorEmailFormat;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Password field
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    if (!_isLoading) _submit();
                                  },
                                  decoration: _fieldDecoration(
                                    label: l10n.authPasswordLabel,
                                    icon: Icons.lock_outline,
                                    suffixIcon: IconButton(
                                      key: const Key('auth_password_toggle'),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: WrColors.text3,
                                      ),
                                      tooltip: _obscurePassword
                                          ? l10n.authPasswordShow
                                          : l10n.authPasswordHide,
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return l10n.authValidatorPassword;
                                    }
                                    if (v.length < 6) {
                                      return l10n.authValidatorPasswordMinLength;
                                    }
                                    return null;
                                  },
                                ),

                                // Forgot password link (login mode only)
                                if (_isLogin)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      key: const Key('auth_forgot_password_btn'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () =>
                                          _showForgotPasswordDialog(context),
                                      child: Text(
                                        l10n.authForgotPassword,
                                        style: const TextStyle(
                                          color: WrColors.coral,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Inline error
                                if (_errorMessage != null) ...[
                                  SizedBox(height: _isLogin ? 8 : 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: WrColors.destructive
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          size: 18,
                                          color: WrColors.destructive,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: WrColors.destructive,
                                              fontSize: 14.5,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                SizedBox(
                                  height: _isLogin && _errorMessage == null
                                      ? 12
                                      : 20,
                                ),

                                // Submit button
                                WrPillButton(
                                  label: _isLogin
                                      ? l10n.authLoginBtn
                                      : l10n.authRegisterBtn,
                                  onPressed: _isLoading ? null : _submit,
                                  variant: WrPillVariant.coral,
                                  isLoading: _isLoading,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Mode switch link
                          Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _errorMessage = null;
                                });
                              },
                              child: Text(
                                _isLogin
                                    ? l10n.authSwitchToRegister
                                    : l10n.authSwitchToLogin,
                                style: const TextStyle(
                                  color: WrColors.coral,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          // Đăng nhập Google tạm gỡ khỏi UI (chưa xử lý
                          // deep-link OAuth). authRepository.signInWithGoogle()
                          // vẫn giữ nguyên để bật lại sau.
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Self-contained forgot-password dialog (owns its own controller lifecycle)
// ---------------------------------------------------------------------------

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.onSubmit,
    required this.onCancel,
  });

  final void Function(String email) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(_emailCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.authForgotPasswordDialogTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('auth_forgot_password_email_field'),
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.authEmailLabel,
            hintText: l10n.authForgotPasswordDialogHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return l10n.authValidatorEmail;
            if (!v.contains('@')) {
              return l10n.authForgotPasswordErrorInvalidEmail;
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: const Key('auth_forgot_password_submit'),
          onPressed: _submit,
          child: Text(
            l10n.authForgotPasswordSubmit,
            style: const TextStyle(color: WrColors.coral),
          ),
        ),
      ],
    );
  }
}
