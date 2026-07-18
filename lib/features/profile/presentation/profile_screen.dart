import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _ProfileHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _AvatarSection(),
                  const SizedBox(height: 1),
                  _Divider(),
                  _StatsRow(),
                  _Divider(),
                  _CheckinHistorySection(),
                  _Divider(),
                  _SettingsSection(),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profileGreeting, style: WrTextStyles.greeting),
          const SizedBox(height: 4),
          _ProfileTitle(),
        ],
      ),
    );
  }
}

class _ProfileTitle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ccAsync = ref.watch(ccProfileProvider);
    final profileAsync = ref.watch(mobileProfileProvider);

    final name = ccAsync.valueOrNull?['full_name'] as String? ??
        profileAsync.valueOrNull?.displayName ??
        'bạn';

    return Text(name, style: WrTextStyles.dateTitle);
  }
}

// ---------------------------------------------------------------------------
// Avatar + email + badge
// ---------------------------------------------------------------------------

class _AvatarSection extends ConsumerWidget {
  /// Extract initials from a full name (up to 2 chars).
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ccAsync = ref.watch(ccProfileProvider);
    final profileAsync = ref.watch(mobileProfileProvider);

    final ccData = ccAsync.valueOrNull ?? {};
    final profile = profileAsync.valueOrNull;

    final name = ccData['full_name'] as String? ?? profile?.displayName ?? 'bạn';
    final email = ccData['email'] as String? ?? '';
    final expiresAtRaw = ccData['subscription_expires_at'] as String?;
    final isPremium = expiresAtRaw != null &&
        DateTime.tryParse(expiresAtRaw)?.isAfter(DateTime.now()) == true;

    final avatarUrl = ccData['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar circle — network image when available, else initials
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: WrColors.navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: WrTextStyles.body.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 6),
              if (isPremium)
                Text(
                  l10n.profileBadgePremium,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WrColors.coral,
                    letterSpacing: 0.04 * 12,
                  ),
                )
              else
                Text(
                  l10n.profileBadgeMember,
                  style: WrTextStyles.body.copyWith(fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row
// ---------------------------------------------------------------------------

class _StatsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final streakAsync = ref.watch(streakProvider);
    final insightAsync = ref.watch(insightCountProvider);
    final milestoneAsync = ref.watch(milestoneCountProvider);

    final streak = streakAsync.valueOrNull ?? 0;
    final insights = insightAsync.valueOrNull ?? 0;
    final milestones = milestoneAsync.valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: _StatBlock(number: streak, label: l10n.profileStatStreak)),
          _StatDivider(),
          Expanded(child: _StatBlock(number: insights, label: l10n.profileStatInsights)),
          _StatDivider(),
          Expanded(child: _StatBlock(number: milestones, label: l10n.profileStatMilestones)),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.number, required this.label});
  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$number',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: WrColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: WrTextStyles.body.copyWith(fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 48, color: WrColors.navy.withValues(alpha: 0.1));
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: WrColors.coral.withValues(alpha: 0.1),
      margin: const EdgeInsets.symmetric(vertical: 8),
    );
  }
}

// ---------------------------------------------------------------------------
// 30-day check-in history strip
// ---------------------------------------------------------------------------

class _CheckinHistorySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(checkinHistoryProvider);

    return Padding(
      key: const Key('profile_checkin_history'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(l10n.profileCheckinHistory),
          const SizedBox(height: 12),
          historyAsync.when(
            loading: () => const SizedBox(
              height: 36,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (history) => _CheckinDotStrip(history: history),
          ),
        ],
      ),
    );
  }
}

class _CheckinDotStrip extends StatelessWidget {
  const _CheckinDotStrip({required this.history});

  /// 30-element list: index 0 = oldest, index 29 = today.
  final List<bool> history;

  @override
  Widget build(BuildContext context) {
    // Render as 5 rows × 6 columns (oldest top-left, newest bottom-right).
    const cols = 6;
    const rows = 5;
    const dotSize = 10.0;
    const gap = 6.0;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: List.generate(rows * cols, (i) {
        // history has exactly 30 entries; i maps directly.
        final checked = i < history.length && history[i];
        return Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked
                ? WrColors.teal
                : WrColors.navy.withValues(alpha: 0.12),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings section
// ---------------------------------------------------------------------------

class _SettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reminderAsync = ref.watch(reminderProvider);
    final reminderEnabled = reminderAsync.valueOrNull ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.profileEyebrowSettings),
        const SizedBox(height: 12),

        // Reminder toggle
        _SettingRow(
          label: l10n.profileSettingReminder,
          trailing: GestureDetector(
            key: const Key('profile_reminder_toggle'),
            onTap: () => ref.read(reminderProvider.notifier).toggle(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                color: reminderEnabled ? WrColors.teal : WrColors.muted,
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: reminderEnabled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: WrColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Language
        _SettingRow(
          label: l10n.profileSettingLanguage,
          trailing: GestureDetector(
            onTap: () => _showLanguageDialog(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.profileLanguageValue,
                  style: WrTextStyles.body.copyWith(fontSize: 13),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
              ],
            ),
          ),
        ),

        // Edit profile
        _SettingRow(
          label: l10n.profileSettingEditProfile,
          trailing: GestureDetector(
            key: const Key('profile_edit_profile_btn'),
            onTap: () => context.push('/profile/edit'),
            child: const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
          ),
        ),

        // Change password
        _SettingRow(
          label: l10n.profileSettingChangePassword,
          trailing: GestureDetector(
            key: const Key('profile_change_password_btn'),
            onTap: () => _showChangePasswordDialog(context, ref),
            child: const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
          ),
        ),

        // Vouchers
        _SettingRow(
          label: l10n.profileVouchers,
          trailing: GestureDetector(
            key: const Key('profile_vouchers_btn'),
            onTap: () => context.push('/vouchers'),
            child: const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
          ),
        ),

        // Org invitations
        _SettingRow(
          label: l10n.profileInvitations,
          trailing: GestureDetector(
            key: const Key('profile_invitations_btn'),
            onTap: () => context.push('/invitations'),
            child: const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
          ),
        ),

        // My Workshops
        _SettingRow(
          label: l10n.profileMyWorkshops,
          trailing: GestureDetector(
            key: const Key('profile_my_workshops_btn'),
            onTap: () => context.push('/my-workshops'),
            child: const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
          ),
        ),

        // My Coaching
        _SettingRow(
          label: l10n.profileMyCoaching,
          trailing: GestureDetector(
            key: const Key('profile_my_coaching_btn'),
            onTap: () => context.push('/coaching/sessions'),
            child: const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
          ),
        ),

        // Survey History
        _SettingRow(
          label: l10n.profileSurveyHistory,
          trailing: GestureDetector(
            key: const Key('profile_survey_history_btn'),
            onTap: () => context.push('/survey/history'),
            child: const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
          ),
        ),

        // Action Roadmap
        _SettingRow(
          label: l10n.roadmapProfileLink,
          trailing: GestureDetector(
            key: const Key('profile_roadmap_btn'),
            onTap: () => context.push('/roadmap'),
            child: const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
          ),
        ),

        // Export data
        _SettingRow(
          label: l10n.profileSettingExport,
          trailing: GestureDetector(
            onTap: () => _exportData(context, ref),
            child: const Icon(Icons.download_outlined, color: WrColors.coral, size: 18),
          ),
        ),

        // Logout
        GestureDetector(
          key: const Key('profile_logout_btn'),
          onTap: () => _logout(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              l10n.profileSettingLogout,
              style: WrTextStyles.hMedium.copyWith(color: WrColors.destructive),
            ),
          ),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => _ChangePasswordDialog(
        l10n: l10n,
        onSubmit: (String newPassword) async {
          Navigator.of(ctx).pop();
          try {
            await ref
                .read(authRepositoryProvider)
                .changePassword(newPassword);
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

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.languageDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.languageOptionVietnamese),
              onTap: () async {
                Navigator.of(ctx).pop();
                await ref.read(wrRepositoryProvider).updateLanguage('vi');
                ref.read(appLocaleProvider.notifier).state = 'vi';
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('app_language', 'vi');
              },
            ),
            ListTile(
              title: Text(l10n.languageOptionEnglish),
              onTap: () async {
                Navigator.of(ctx).pop();
                await ref.read(wrRepositoryProvider).updateLanguage('en');
                ref.read(appLocaleProvider.notifier).state = 'en';
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('app_language', 'en');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final data = await ref.read(wrRepositoryProvider).exportUserData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/workreflection_export.json');
      await file.writeAsString(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xuất dữ liệu: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xuất dữ liệu.')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      // Router redirect handles navigation to /auth
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể đăng xuất.')),
        );
      }
    }
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: WrTextStyles.hMedium),
          trailing,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change-password dialog (stateful so it can show/hide passwords)
// ---------------------------------------------------------------------------

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({
    required this.l10n,
    required this.onSubmit,
    required this.onCancel,
  });

  final AppLocalizations l10n;
  /// Called with the validated new password when the user taps submit.
  final void Function(String newPassword) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
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
