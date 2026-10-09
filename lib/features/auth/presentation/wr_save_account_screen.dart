// Khách tạo tài khoản bằng Email để giữ hành trình.
//
// Không gọi `signUp`: tạo một user MỚI thì mọi thứ khách đã ghi nằm lại ở user
// ẩn danh cũ. Ở đây gắn email + mật khẩu vào chính user khách
// (`AuthRepository.attachEmail`), nên dữ liệu ở nguyên chỗ.
//
// Dòng điều khoản nằm ngay trên nút tạo tài khoản — mockup v47 chuyển nó từ
// Onboarding sang đây ("nó thuộc về màn ĐĂNG KÝ TÀI KHOẢN").

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../wr/presentation/wr_paywall_screen.dart'
    show kAppleStandardEulaUrl, kPrivacyPolicyUrl;
import '../data/auth_repository.dart';
import '../guest_session.dart';

class WrSaveAccountScreen extends ConsumerStatefulWidget {
  const WrSaveAccountScreen({super.key});

  @override
  ConsumerState<WrSaveAccountScreen> createState() =>
      _WrSaveAccountScreenState();
}

class _WrSaveAccountScreenState extends ConsumerState<WrSaveAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  /// Email đã gửi đi nhưng còn chờ người dùng bấm link xác nhận.
  String? _pendingEmail;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _emailCtrl.text.trim();
    try {
      final active = await ref
          .read(authRepositoryProvider)
          .attachEmail(email, _passwordCtrl.text, _nameCtrl.text.trim());
      if (!mounted) return;
      markGuestSaved(ref);
      if (!active) {
        setState(() => _pendingEmail = email);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('wr_save_account_done'),
          backgroundColor: WrColors.navy,
          behavior: SnackBarBehavior.floating,
          content: Text(
            tr('Đã lưu hành trình của bạn', 'Your journey is saved'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: WrColors.cream,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('already') ||
        raw.contains('exists') ||
        raw.contains('duplicate') ||
        raw.contains('unique')) {
      return tr(
        'Email này đã có tài khoản. Bạn có thể đăng nhập bằng tài khoản đó, '
            'nhưng hành trình đang ghi ở đây sẽ không đi theo.',
        'This email already has an account. You can sign in with it, but '
            'the journey recorded here will not come along.',
      );
    }
    if (raw.contains('password')) {
      return tr(
        'Mật khẩu chưa đạt yêu cầu. Hãy dùng ít nhất 6 ký tự.',
        'The password is too weak. Use at least 6 characters.',
      );
    }
    return tr(
      'Chưa lưu được. Kiểm tra kết nối rồi thử lại.',
      'Could not save. Check your connection and try again.',
    );
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: WrColors.pageBg,
      prefixIcon: Icon(icon, size: 20, color: WrColors.text3),
      suffixIcon: suffix,
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
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: WrColors.navy,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: _pendingEmail != null ? _pendingView() : _form(),
        ),
      ),
    );
  }

  Widget _header(String eyebrow, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: WrColors.eyebrow,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: WrColors.navy,
            height: 1.32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            fontSize: 14.5,
            color: WrColors.text2,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _pendingView() {
    return Column(
      key: const Key('wr_save_account_pending'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          tr('Gần xong', 'Almost done'),
          tr('Kiểm tra hộp thư của bạn', 'Check your inbox'),
          tr(
            'Chúng tôi đã gửi một liên kết xác nhận tới $_pendingEmail. Bấm '
                'vào đó là hành trình được lưu. Trong lúc chờ, bạn vẫn dùng '
                'app bình thường.',
            'We sent a confirmation link to $_pendingEmail. Tap it and your '
                'journey is saved. Meanwhile you can keep using the app.',
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            style: _primaryStyle,
            child: Text(tr('Quay lại', 'Back')),
          ),
        ),
      ],
    );
  }

  ButtonStyle get _primaryStyle => FilledButton.styleFrom(
    backgroundColor: WrColors.coral,
    foregroundColor: WrColors.navy,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(
            tr('Lưu hành trình', 'Save your journey'),
            tr('Tạo tài khoản bằng email', 'Create an account with email'),
            tr(
              'Mọi điều bạn đã ghi lại được giữ nguyên trong tài khoản này.',
              'Everything you have recorded stays with this account.',
            ),
          ),
          WrCard(
            child: Column(
              children: [
                TextFormField(
                  key: const Key('wr_save_name'),
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    tr('Tên của bạn', 'Your name'),
                    Icons.person_outline_rounded,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? tr('Nhập tên để app gọi bạn', 'Enter a name')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('wr_save_email'),
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Email', Icons.mail_outline_rounded),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                      return tr('Email chưa đúng', 'Invalid email');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('wr_save_password'),
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _busy ? null : _submit(),
                  decoration: _decoration(
                    tr('Mật khẩu', 'Password'),
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: WrColors.text3,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v ?? '').length < 6
                      ? tr('Ít nhất 6 ký tự', 'At least 6 characters')
                      : null,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('wr_save_account_error'),
              style: const TextStyle(
                fontSize: 13.5,
                color: WrColors.destructive,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const _LegalLine(key: Key('wr_save_account_legal')),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('wr_save_account_submit'),
              onPressed: _busy ? null : _submit,
              style: _primaryStyle,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: WrColors.navy,
                      ),
                    )
                  : Text(tr('Tạo tài khoản', 'Create account')),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Bằng việc tiếp tục, bạn đồng ý với Điều khoản sử dụng và Chính sách dữ
/// liệu của WorkReflection." — hai cụm gạch chân bấm mở được, như mockup.
///
/// Dùng cùng hai đường dẫn đã khai với App Store ở màn Premium.
class _LegalLine extends StatefulWidget {
  const _LegalLine({super.key});

  @override
  State<_LegalLine> createState() => _LegalLineState();
}

class _LegalLineState extends State<_LegalLine> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => _open(kAppleStandardEulaUrl);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _open(kPrivacyPolicyUrl);

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Không mở được trình duyệt thì thôi; dòng chữ vẫn đọc được.
    }
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 12.5, color: WrColors.text3, height: 1.5);
    const link = TextStyle(decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(
            text: tr(
              'Bằng việc tiếp tục, bạn đồng ý với ',
              'By continuing, you agree to the ',
            ),
          ),
          TextSpan(
            text: tr('Điều khoản sử dụng', 'Terms of Use'),
            style: link,
            recognizer: _terms,
          ),
          TextSpan(text: tr(' và ', ' and ')),
          TextSpan(
            text: tr('Chính sách dữ liệu', 'Data Policy'),
            style: link,
            recognizer: _privacy,
          ),
          TextSpan(text: tr(' của WorkReflection.', ' of WorkReflection.')),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
