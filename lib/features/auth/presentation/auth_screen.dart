import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/data/seed_service.dart';
import '../../../l10n/app_localizations.dart';
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
        context.go(_isLogin ? '/home' : '/wr/career-setup');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.authForgotPasswordSuccess)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.authForgotPasswordError)));
      }
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signInWithGoogle();
      // OAuth flow opens browser; deep-link callback handles the redirect.
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Text(
                  _isLogin ? l10n.authLoginTitle : l10n.authRegisterTitle,
                  style: WrTextStyles.hLarge.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 32),

                // Name field (register only)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.authNameLabel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.authValidatorName
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.authEmailLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.authPasswordLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 8),

                // Forgot password link (login mode only)
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('auth_forgot_password_btn'),
                      onPressed: () => _showForgotPasswordDialog(context),
                      child: Text(
                        l10n.authForgotPassword,
                        style: const TextStyle(
                          color: WrColors.coral,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Inline error
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: WrColors.destructive,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Submit button
                WrPillButton(
                  label: _isLogin ? l10n.authLoginBtn : l10n.authRegisterBtn,
                  onPressed: _isLoading ? null : _submit,
                  variant: WrPillVariant.coral,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),

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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // "hoặc" divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(l10n.authOrDivider, style: WrTextStyles.body),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),

                // Google OAuth button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _googleSignIn,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: WrColors.muted),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Simple G icon placeholder (real app would use google_sign_in asset)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: WrColors.coral.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: WrColors.coral,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.authGoogleBtn,
                          style: WrTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: WrColors.dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Self-contained forgot-password dialog (owns its own controller lifecycle)
// ---------------------------------------------------------------------------

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.onSubmit, required this.onCancel});

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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        TextButton(onPressed: widget.onCancel, child: Text(l10n.commonCancel)),
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
