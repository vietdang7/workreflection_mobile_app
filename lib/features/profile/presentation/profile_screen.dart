import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../wr/wr_providers.dart';
import '../profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
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
                  _PremiumCard(),
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
          // v1.6 §9.1: màn này không còn là tab, nên phải tự có lối quay lại.
          // Không có nút này thì mở từ avatar xong là kẹt.
          if (GoRouter.maybeOf(context) != null && context.canPop())
            GestureDetector(
              key: const Key('profile_back'),
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pop(),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new,
                        size: 14, color: WrColors.muted),
                    SizedBox(width: 6),
                    Text(
                      'Quay lại',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: WrColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Tên đã nằm ở khối nhận diện căn giữa ngay bên dưới — in lại ở đây
          // là đọc tên người dùng hai lần trong một màn hình.
          Text(l10n.profileGreeting, style: WrTextStyles.greeting),
        ],
      ),
    );
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
    // Nhãn gói đọc thẳng từ `wrEntitlementProvider` — đúng cái quyết định mọi
    // cổng Premium trong app, nên nhãn và khoá không bao giờ nói hai điều khác
    // nhau (kể cả khi bật công tắc thử nghiệm, vốn đã được áp bên trong
    // provider đó).
    //
    // Trước đây màn này tự suy ra gói từ `cc_profiles.subscription_expires_at`.
    // Bỏ đi từ 2026-08-01, khi khách chốt Premium web và app là một: nguồn thật
    // là `cc_profiles.role`, và cột hạn dùng kia không phải thứ web dùng để
    // quyết định ai là Premium.
    final isPremium =
        ref.watch(wrEntitlementProvider).valueOrNull?.isPremium ?? false;

    final avatarUrl = ccData['avatar_url'] as String?;

    // Giao diện mẫu Sprint 2 (screenProfile): khối nhận diện căn giữa —
    // ảnh, tên, email, rồi mới tới nhãn gói. Bố cục hàng ngang cũ đẩy email
    // lên ngang hàng avatar và không có chỗ cho tên, nên màn "Tôi" mở ra mà
    // không nói ngay được đây là ai.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar circle — network image when available, else initials
          Container(
            width: 64,
            height: 64,
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
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: WrColors.navy,
              height: 1.2,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: WrTextStyles.body.copyWith(fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          // Nhãn gói dạng viên thuốc — người dùng biết ngay mình đang ở bản nào.
          Container(
            key: const Key('profile_plan_pill'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isPremium
                  ? WrColors.coral.withValues(alpha: 0.14)
                  : WrColors.navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPremium ? l10n.profileBadgePremium : l10n.profileBadgeMember,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isPremium ? WrColors.coral : WrColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thẻ mời nâng cấp — chỉ hiện với bản miễn phí (giao diện mẫu Sprint 2)
// ---------------------------------------------------------------------------

class _PremiumCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cùng nguồn với nhãn gói và mọi cổng Premium khác — mời nâng cấp một
    // người đã là Premium bên web là lỗi dễ thấy nhất của việc để hai nguồn.
    final isPremium =
        ref.watch(wrEntitlementProvider).valueOrNull?.isPremium ?? false;
    if (isPremium) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: GestureDetector(
        key: const Key('profile_premium_card'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/wr/paywall'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: WrColors.coral.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mở khoá bản đầy đủ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: WrColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Phần đọc vị nhu cầu, diễn biến theo thời gian, toàn bộ '
                'Career Memory và thực hành không giới hạn.',
                style: TextStyle(
                  fontSize: 13,
                  color: WrColors.muted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Xem chi tiết',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WrColors.coral,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward, size: 14, color: WrColors.coral),
                ],
              ),
            ],
          ),
        ),
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
// Công tắc Premium thử nghiệm — chỉ tài khoản nội bộ thấy
// ---------------------------------------------------------------------------
//
// Không phải tính năng sản phẩm: đây là cách chủ sản phẩm xem qua lại hai bản
// trên cùng một máy khi nghiệm thu. Xem `wr_premium_override.dart` để hiểu vì
// sao công tắc nằm ở máy chứ không ghi vào `wr_entitlements`.

class _PremiumOverrideRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(premiumOverrideProvider);
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull;
    final on = entitlement?.isPremium ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingRow(
          key: const Key('profile_premium_override_row'),
          label: 'Bật Premium (thử nghiệm)',
          onTap: () =>
              ref.read(premiumOverrideProvider.notifier).set(!on),
          trailing: AnimatedContainer(
            key: const Key('profile_premium_override_toggle'),
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 22,
            decoration: BoxDecoration(
              color: on ? WrColors.coral : WrColors.muted,
              borderRadius: BorderRadius.circular(11),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: WrColors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),

        // Lối quay về gói thật. Không có nó thì sau khi chạm một lần, máy này
        // vĩnh viễn nói dối về gói — kể cả khi thanh toán thật đã đổi trạng
        // thái, và không cách nào biết mình đang xem bản giả hay bản thật.
        if (override != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: GestureDetector(
              key: const Key('profile_premium_override_reset'),
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  ref.read(premiumOverrideProvider.notifier).set(null),
              child: Text(
                'Đang ép ${override ? 'Premium' : 'miễn phí'} trên máy này · '
                'chạm để dùng lại gói thật',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: WrColors.coral.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
      ],
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

        // Reminder toggle — bấm đâu trên dòng cũng bật/tắt được.
        _SettingRow(
          label: l10n.profileSettingReminder,
          onTap: () => ref.read(reminderProvider.notifier).toggle(),
          trailing: AnimatedContainer(
            key: const Key('profile_reminder_toggle'),
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 22,
            decoration: BoxDecoration(
              color: reminderEnabled ? WrColors.teal : WrColors.muted,
              borderRadius: BorderRadius.circular(11),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: reminderEnabled
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: WrColors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),

        // Language
        _SettingRow(
          key: const Key('profile_language_row'),
          label: l10n.profileSettingLanguage,
          onTap: () => _showLanguageDialog(context, ref),
          trailing: Row(
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

        // Edit profile
        _SettingRow(
          key: const Key('profile_edit_profile_btn'),
          label: l10n.profileSettingEditProfile,
          onTap: () => context.push('/profile/edit'),
          trailing:
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
        ),

        // Thông tin công việc — Hai Lớp v1.6 §XI. Màn này gom cả mô tả tự viết
        // lẫn lối vào Tài liệu bối cảnh (JD/CV) của v1.2 §III, nên không còn
        // dòng riêng cho tài liệu nữa.
        _SettingRow(
          key: const Key('profile_work_info_btn'),
          label: 'Thông tin công việc',
          onTap: () => context.push('/wr/work-info'),
          trailing:
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
        ),

        // Đăng ký Premium
        _SettingRow(
          key: const Key('profile_paywall_btn'),
          label: 'Bản Premium',
          onTap: () => context.push('/wr/paywall'),
          trailing:
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
        ),

        // Công tắc thử nghiệm — chỉ hiện với tài khoản nội bộ. Đặt ngay dưới
        // "Bản Premium" để hai thứ nói về cùng một chuyện nằm cạnh nhau.
        if (ref.watch(canTogglePremiumProvider)) _PremiumOverrideRow(),

        // Change password
        _SettingRow(
          key: const Key('profile_change_password_btn'),
          label: l10n.profileSettingChangePassword,
          onTap: () => _showChangePasswordDialog(context, ref),
          trailing:
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
        ),

        // Export data
        _SettingRow(
          key: const Key('profile_export_btn'),
          label: l10n.profileSettingExport,
          onTap: () => _exportData(context, ref),
          trailing: const Icon(
            Icons.download_outlined,
            color: WrColors.coral,
            size: 18,
          ),
        ),

        // Logout — dòng cuối, không kẻ vạch dưới
        _SettingRow(
          key: const Key('profile_logout_btn'),
          label: l10n.profileSettingLogout,
          labelColor: WrColors.destructive,
          showBorder: false,
          onTap: () => _logout(context, ref),
          trailing: const SizedBox.shrink(),
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

      // Trên web không có thư mục tài liệu để ghi — path_provider ném lỗi và
      // nút này im lặng không làm gì. Chép vào clipboard là đường dùng được.
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: json));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã chép dữ liệu vào clipboard.')),
          );
        }
        return;
      }

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

/// Một dòng cài đặt.
///
/// Cả dòng là vùng bấm, không phải riêng mũi tên bên phải: một icon 16px là
/// đích quá nhỏ để trúng, nên trước đây các mục ở đây gần như không bấm được.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.label,
    required this.trailing,
    this.onTap,
    this.labelColor,
    this.showBorder = true,
  });

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? labelColor;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: showBorder
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: WrColors.navy.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: labelColor == null
                    ? WrTextStyles.hMedium
                    : WrTextStyles.hMedium.copyWith(color: labelColor),
              ),
            ),
            trailing,
          ],
        ),
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
