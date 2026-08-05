// Hộp thoại đổi mật khẩu.
//
// Trước đây nằm chôn trong `profile_screen.dart`. Tách ra khi màn Hồ sơ rút danh
// sách cài đặt xuống còn bốn dòng theo mockup Sprint 2 bản (4): dòng "Đổi mật
// khẩu" bị cắt khỏi đó, nhưng việc đổi mật khẩu thì không được mất — nó dời sang
// màn "Sửa hồ sơ", nơi mọi thứ thuộc về tài khoản đã nằm sẵn.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wr_colors.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../l10n/app_localizations.dart';

/// Mở hộp thoại đổi mật khẩu và tự xử lý cả báo lỗi lẫn báo thành công.
///
/// [context] phải là context còn sống sau khi hộp thoại đóng — SnackBar bắn ra
/// từ đó chứ không từ context của hộp thoại.
void showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (ctx) => ChangePasswordDialog(
      l10n: l10n,
      onSubmit: (String newPassword) async {
        Navigator.of(ctx).pop();
        try {
          await ref.read(authRepositoryProvider).changePassword(newPassword);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.changePasswordSuccess)),
            );
          }
        } catch (e) {
          if (context.mounted) {
            final msg = e.toString().toLowerCase();
            final text = msg.contains('session') || msg.contains('expired')
                ? l10n.changePasswordErrorSessionExpired
                : l10n.changePasswordErrorGeneric;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(text)),
            );
          }
        }
      },
      onCancel: () => Navigator.of(ctx).pop(),
    ),
  );
}

/// Stateful để tự bật/tắt hiện mật khẩu.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({
    super.key,
    required this.l10n,
    required this.onSubmit,
    required this.onCancel,
  });

  final AppLocalizations l10n;

  /// Gọi với mật khẩu mới đã qua kiểm tra khi người dùng bấm xác nhận.
  final void Function(String newPassword) onSubmit;
  final VoidCallback onCancel;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(_newPasswordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.changePasswordTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // New password
            TextFormField(
              key: const Key('change_password_new_field'),
              controller: _newPasswordCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: l10n.changePasswordNewLabel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.authValidatorPassword;
                if (v.length < 6) return l10n.changePasswordErrorTooShort;
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Confirm password
            TextFormField(
              key: const Key('change_password_confirm_field'),
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: l10n.changePasswordConfirmLabel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.authValidatorPassword;
                if (v != _newPasswordCtrl.text) {
                  return l10n.changePasswordErrorMismatch;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: const Key('change_password_submit'),
          onPressed: _submit,
          child: Text(
            l10n.changePasswordSubmit,
            style: const TextStyle(color: WrColors.coral),
          ),
        ),
      ],
    );
  }
}
