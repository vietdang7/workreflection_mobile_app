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
import '../../../features/auth/data/auth_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../wr/org_survey_providers.dart';
import '../../wr/wr_providers.dart';
import '../avatar_providers.dart';
import '../profile_providers.dart';
import 'change_password_dialog.dart';
import '../../../core/widgets/wr_paragraph.dart';

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
                  // Thứ tự và mặt phẳng lấy nguyên từ mockup Sprint 2 bản (4)
                  // §screenProfile: khối nhận diện căn giữa → THẺ số liệu → thẻ
                  // mời Premium → THẺ danh sách cài đặt → thẻ Khảo sát tổ chức
                  // → nút đăng xuất.
                  //
                  // Không còn đường kẻ ngang nào: mockup phân đoạn bằng thẻ chứ
                  // không bằng vạch. Ba vạch cũ chia màn thành các dải rời rạc
                  // trong khi mọi màn khác của app đã là hệ thẻ.
                  _AvatarSection(),
                  const SizedBox(height: 20),
                  _StatsCard(),
                  const SizedBox(height: 12),
                  _PremiumCard(),
                  _SettingsSection(),
                  const SizedBox(height: 12),
                  _OrgSurveyCard(),
                  // Công tắc nghiệm thu — nút chữ mờ, ngay trên nút đăng xuất,
                  // đúng vị trí mockup. Chỉ tài khoản nội bộ thấy.
                  Consumer(
                    builder: (context, ref, _) =>
                        ref.watch(canTogglePremiumProvider)
                            ? _PremiumOverrideRow()
                            : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  _LogoutButton(),
                  const SizedBox(height: 8),
                  _DeleteAccountButton(),
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
                        fontSize: 14.5,
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

/// Chọn ảnh từ thư viện rồi tải lên, dùng chung cho vòng tròn ảnh và dòng
/// "Đổi ảnh đại diện" trong danh sách thiết lập.
///
/// Trước 2026-08-27 màn Hồ sơ **không có lối nào tới đây**: ô đổi ảnh chỉ nằm
/// trong `ProfileEditScreen`, mà màn đó chỉ mở ra qua `/profile/setup` (ngay sau
/// khi đăng ký). Route `/profile/edit` có khai trong `app_router.dart` nhưng
/// không widget nào gọi tới — nên người đã có tài khoản không đổi được ảnh.
///
/// Ở đây gọi thẳng `avatarUploadProvider` chứ không mở lại `ProfileEditScreen`:
/// các trường hồ sơ của màn đó đã dời sang "Thông tin của bạn" (xem ghi chú
/// trong [_SettingsSection]), mở lại là có hai màn sửa cùng một dữ liệu.
Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final url = await ref.read(avatarUploadProvider.notifier).pickAndUpload();
  if (!context.mounted) return;
  // `null` cũng là kết quả của việc người dùng bấm huỷ trong bộ chọn ảnh —
  // im lặng trong trường hợp đó, chỉ báo khi provider thật sự lỗi.
  if (url != null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.avatarUploadSuccess)));
  } else if (ref.read(avatarUploadProvider).hasError) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.avatarUploadError)));
  }
}

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

    final ccData = ccAsync.valueOrNull ?? {};

    // Cùng một nguồn tên với màn Hôm nay, và cùng một luật loại email ra khỏi ô
    // tên — xem `wr_display_name.dart`. Email vẫn hiện, nhưng ở dòng email ngay
    // bên dưới, đúng chỗ của nó.
    final name = ref.watch(greetingNameProvider) ?? 'bạn';
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
    final isUploadingAvatar = ref.watch(avatarUploadProvider).isLoading;

    // Giao diện mẫu Sprint 2 (screenProfile): khối nhận diện căn giữa —
    // ảnh, tên, email, rồi mới tới nhãn gói. Bố cục hàng ngang cũ đẩy email
    // lên ngang hàng avatar và không có chỗ cho tên, nên màn "Tôi" mở ra mà
    // không nói ngay được đây là ai.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar circle — network image when available, else initials.
          // Chạm vào là đổi ảnh: đây là cử chỉ ai cũng thử trước tiên. Huy hiệu
          // máy ảnh ở góc để người dùng biết nó bấm được, vì một vòng tròn
          // trơn không tự nói lên điều đó.
          GestureDetector(
            key: const Key('profile_avatar_tap'),
            behavior: HitTestBehavior.opaque,
            onTap: isUploadingAvatar ? null : () => _pickAvatar(context, ref),
            child: Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: WrColors.navy.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isUploadingAvatar
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WrColors.coral,
                            ),
                          ),
                        )
                      : avatarUrl != null && avatarUrl.isNotEmpty
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
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: WrColors.coral,
                      shape: BoxShape.circle,
                      border: Border.all(color: WrColors.pageBg, width: 2),
                    ),
                    // Icon trên nền Coral là Navy — đặc tả UX/UI §01, không
                    // phải trắng.
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      size: 11,
                      color: WrColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WrParagraph(
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
              style: WrTextStyles.body.copyWith(fontSize: 14.5),
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
                fontSize: 13,
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

    // Giá đọc từ `cc_products` chứ không ghi cứng "499.000đ/năm" như mockup:
    // khách bán hai gói (năm / tháng) và đổi giá ở trang quản trị của web. Một
    // con số ghi cứng ở đây sẽ nói khác Paywall ngay lần đầu khách đổi giá.
    final plan = ref.watch(wrPremiumPricingProvider).valueOrNull;
    final price = plan == null
        ? ''
        : '${plan.currentLabel}/${plan.durationSuffix}, ';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        key: const Key('profile_premium_card'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/wr/paywall'),
        // Nền CORAL ĐẶC, chữ navy — mockup bản (4) `background:var(--coral)`.
        // Đây là chỗ duy nhất trên màn được dùng coral đặc, đúng spec §01: một
        // CTA chính mỗi màn. Bản trước tô coral 12% nên nó chìm ngang hàng với
        // mọi thẻ trắng khác và không còn đọc ra là lời mời.
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: WrColors.coral,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mở khoá Premium',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: WrColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                // §03: chữ trên nền coral là navy, pha loãng cho dòng phụ chứ
                // không đổi sang trắng hay xám.
                '${price}Diễn giải sâu, Pattern nâng cao, Career Memory đầy đủ.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: WrColors.navy.withValues(alpha: 0.75),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                key: const Key('profile_premium_cta'),
                onPressed: () => context.push('/wr/paywall'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.navy,
                  foregroundColor: WrColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Xem chi tiết',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

/// Ba con số trong MỘT thẻ trắng — `<div class="card card-pad">` của mockup.
///
/// Trước đây là ba cột trần ngăn nhau bằng vạch dọc, cỡ số 36px. Mockup dùng cỡ
/// `.h2` và đặt cả ba trong một thẻ: chúng là một câu ("bạn đã đi được tới đâu"),
/// không phải ba mục riêng.
class _StatsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Tổng số ngày đã nhìn lại, KHÔNG phải chuỗi ngày liên tiếp (yêu cầu
    // 05/08). Chuỗi liên tiếp nghỉ một ngày là về 0; con số tích luỹ thì
    // không bao giờ lấy đi thứ người dùng đã làm được.
    final reflectDays = ref.watch(reflectionDayCountProvider).valueOrNull ?? 0;
    final insights = ref.watch(insightCountProvider).valueOrNull ?? 0;
    final milestones = ref.watch(milestoneCountProvider).valueOrNull ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WrColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _StatBlock(
              number: reflectDays,
              label: l10n.profileStatReflectDays,
            ),
          ),
          Expanded(
            child:
                _StatBlock(number: insights, label: l10n.profileStatInsights),
          ),
          Expanded(
            child: _StatBlock(
              number: milestones,
              label: l10n.profileStatMilestones,
            ),
          ),
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
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: WrColors.navy,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        WrParagraph(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: WrColors.text3,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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

    // Mockup bản (4) để nó là NÚT CHỮ MỜ dưới thẻ Khảo sát tổ chức, không phải
    // một dòng trong danh sách cài đặt. Đúng chỗ: bảy dòng kia là thiết lập
    // thật của người dùng, dòng này là đồ nghề nghiệm thu. Để lẫn vào nhau thì
    // công cụ nội bộ trông y hệt một tính năng.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          key: const Key('profile_premium_override_row'),
          onPressed: () => ref.read(premiumOverrideProvider.notifier).set(!on),
          style: TextButton.styleFrom(
            foregroundColor: WrColors.text3,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            '(Demo) Chuyển trạng thái Premium: ${on ? 'Tắt' : 'Bật'}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
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
                  fontSize: 13,
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
// Khảo sát tổ chức (ESI + eNPS) — mockup Sprint 2, `screenProfile`
// ---------------------------------------------------------------------------

/// Lối vào duy nhất của Khảo sát tổ chức.
///
/// Là một THẺ riêng chứ không phải một dòng trong danh sách Cài đặt, đúng như
/// mockup. Bài này không phải một thiết lập của app: nó là một lời mời tham
/// gia, kèm chữ "tuỳ chọn" ngay trên tiêu đề, và người dùng cần thấy đủ để
/// quyết định có bấm hay không.
///
/// Không có cổng Premium ở đây. Màn giới thiệu hứa "không đổi lấy quyền lợi hay
/// tính năng nào trong ứng dụng" — gắn nó vào gói trả tiền theo bất kỳ chiều
/// nào cũng là phá lời hứa đó.
class _OrgSurveyCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Đã làm rồi thì đổi chữ nút. Mời "tham gia" một người vừa trả lời xong 13
    // câu là cho thấy app không nhớ gì về họ.
    final done = ref.watch(wrOrgSurveyLatestProvider).valueOrNull != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: WrColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.apartment_outlined, size: 16, color: WrColors.navy),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Khảo sát tổ chức (tuỳ chọn)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const WrParagraph(
              'Đánh giá đãi ngộ, phát triển và mức sẵn lòng giới thiệu nơi bạn '
              'làm việc.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: WrColors.text2,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('profile_org_survey_btn'),
              onPressed: () => context.push(
                done ? '/wr/org-survey/result' : '/wr/org-survey',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: WrColors.navy,
                side: const BorderSide(color: WrColors.line),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                done ? 'Xem lại kết quả' : 'Tìm hiểu & tham gia',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
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
    final isPremium =
        ref.watch(wrEntitlementProvider).valueOrNull?.isPremium ?? false;

    // Cả danh sách nằm trong MỘT thẻ trắng, mỗi dòng có icon bên trái và ngăn
    // nhau bằng vạch `--line-soft` — `<div class="card">` của mockup bản (4).
    //
    // Bản trước là các dòng trần trên nền màn, không icon. Trên nền TRẮNG cũ nó
    // còn đọc được; từ khi nền màn thành xám (brand identity 04/8) thì danh sách
    // này là mảng duy nhất của màn không có mặt phẳng, nằm lọt thỏm giữa ba thẻ
    // trắng — đúng chỗ khách nói "nhìn chưa giống".
    //
    // Nhãn mục "CÀI ĐẶT" bỏ đi theo mockup: thẻ đã tự tách khối, thêm một dòng
    // chữ hoa nữa chỉ là nói lại điều mắt đã thấy.
    //
    // Ảnh khách gửi 04/8 chỉ có bốn dòng, nhưng khách chốt lại ngay sau đó là
    // GIỮ đủ mục: đổi mật khẩu, sửa hồ sơ, thông tin công việc, bản Premium đều
    // là lối vào duy nhất của chúng — cắt đi là mất hẳn đường tới.
    return Container(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WrColors.line),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Thông tin của bạn" — mockup Sprint 2 bản (4). Đứng ĐẦU danh sách,
        // trên cả nhắc nhở hằng ngày: đây là thứ duy nhất trong danh sách này
        // nói về người dùng, phần còn lại là thiết lập của app.
        //
        // Con số n/7 không phải để giục. Nó trả lời câu người dùng thật sự hỏi
        // khi nhìn một dòng như thế này — "trong đó có gì, mình khai tới đâu
        // rồi" — mà không bắt mở màn ra mới biết.
        _SettingRow(
          key: const Key('profile_my_info_btn'),
          icon: Icons.badge_outlined,
          label: 'Thông tin của bạn',
          onTap: () => context.push('/profile/my-info'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) {
                  final status = ref.watch(myInfoStatusProvider(l10n));
                  return Text(
                    '${status.filled}/${status.total}',
                    key: const Key('profile_my_info_count'),
                    style: WrTextStyles.body.copyWith(fontSize: 14.5),
                  );
                },
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
            ],
          ),
        ),

        // Đổi ảnh đại diện. Vòng tròn ảnh phía trên cũng bấm được, nhưng một
        // dòng chữ rõ ràng ở đây mới là thứ người dùng tìm thấy khi họ đi dò
        // danh sách thiết lập — và trước 27/08 màn này không có lối nào tới ô
        // đổi ảnh cả (xem ghi chú ở [_pickAvatar]).
        _SettingRow(
          key: const Key('profile_change_avatar_btn'),
          icon: Icons.photo_camera_outlined,
          label: 'Đổi ảnh đại diện',
          onTap: ref.watch(avatarUploadProvider).isLoading
              ? null
              : () => _pickAvatar(context, ref),
          trailing: ref.watch(avatarUploadProvider).isLoading
              ? Text(
                  l10n.avatarUploading,
                  key: const Key('profile_avatar_uploading_label'),
                  style: WrTextStyles.body.copyWith(fontSize: 14.5),
                )
              : const Icon(Icons.chevron_right,
                  color: WrColors.muted, size: 16),
        ),

        // Reminder toggle — bấm đâu trên dòng cũng bật/tắt được.
        _SettingRow(
          icon: Icons.notifications_none_outlined,
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
          icon: Icons.language_outlined,
          label: l10n.profileSettingLanguage,
          onTap: () => _showLanguageDialog(context, ref),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.profileLanguageValue,
                style: WrTextStyles.body.copyWith(fontSize: 14.5),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
            ],
          ),
        ),

        // Đã bỏ hai dòng "Chỉnh sửa hồ sơ" và "Thông tin công việc" ở đây.
        // Thông tin công việc đi vào từ màn "Thông tin của bạn" phía trên.

        // Bản Premium. Với người đã có quyền, dòng này là chỗ tra trạng thái
        // chứ không phải lối vào trang bán hàng — nói luôn "Đang dùng" ở đây
        // để không ai phải bấm vào mới biết mình đang có gì.
        _SettingRow(
          key: const Key('profile_paywall_btn'),
          icon: isPremium ? Icons.star : Icons.star_outline,
          label: 'Bản Premium',
          onTap: () => context.push('/wr/paywall'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPremium)
                Text(
                  'Đang dùng',
                  key: const Key('profile_premium_active_label'),
                  style: WrTextStyles.body.copyWith(
                    fontSize: 14.5,
                    color: WrColors.pillTealText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (isPremium) const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
            ],
          ),
        ),

        // Đổi mật khẩu
        _SettingRow(
          key: const Key('profile_change_password_btn'),
          icon: Icons.lock_outline,
          label: l10n.profileSettingChangePassword,
          onTap: () => showChangePasswordDialog(context, ref),
          trailing:
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
        ),

        _SettingRow(
          key: const Key('profile_export_btn'),
          icon: Icons.download_outlined,
          label: l10n.profileSettingExport,
          onTap: () => _exportData(context, ref),
          trailing:
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
        ),

        // Hướng dẫn sử dụng — yêu cầu §4 họp 26_1. Đứng CUỐI theo quy ước quen
        // thuộc của mọi màn thiết lập (trợ giúp nằm dưới cùng), nên không kẻ
        // vạch dưới: vạch cuối sẽ nằm sát mép thẻ và đọc ra như viền thừa.
        //
        // Là dòng trong danh sách chứ không phải thẻ riêng: nó không phải lời
        // mời như Khảo sát tổ chức hay Premium, mà là chỗ để tra khi cần.
        _SettingRow(
          key: const Key('profile_guide_btn'),
          icon: Icons.help_outline,
          label: 'Hướng dẫn sử dụng',
          showBorder: false,
          onTap: () => context.push('/profile/guide'),
          trailing:
              const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
        ),
      ],
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
    this.icon,
    this.onTap,
    this.showBorder = true,
  });

  final String label;
  final Widget trailing;

  /// Icon bên trái, đúng mockup. Mỗi dòng một hình để mắt bắt được dòng cần tìm
  /// mà không phải đọc hết bảy nhãn.
  final IconData? icon;
  final VoidCallback? onTap;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: showBorder
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: WrColors.lineSoft, width: 1),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: WrColors.navy),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: WrTextStyles.hMedium,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Đăng xuất — NÚT viền riêng dưới cùng, ngoài thẻ cài đặt.
///
/// Mockup bản (4) tách nó ra khỏi danh sách vì nó không phải một thiết lập: sáu
/// dòng kia mở ra một màn khác, dòng này kết thúc phiên. Để lẫn trong danh sách
/// thì một cú chạm trượt sẽ đá người dùng ra ngoài.
class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: const Key('profile_logout_btn'),
        onPressed: () => _logout(context, ref),
        style: OutlinedButton.styleFrom(
          foregroundColor: WrColors.navy,
          side: const BorderSide(color: WrColors.line),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          l10n.profileSettingLogout,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
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

/// Xoá tài khoản — App Store Review Guideline 5.1.1(v).
///
/// Apple bắt buộc app nào cho tạo tài khoản thì phải cho xoá NGAY TRONG APP,
/// không được đẩy sang email hay trang web. Thiếu là bị từ chối thẳng.
///
/// Cố ý làm nút chữ mờ nằm dưới nút đăng xuất chứ không phải nút đỏ nổi bật:
/// đây là việc không hoàn tác được, không nên mời gọi. Nhưng cũng KHÔNG được
/// giấu vào tầng thiết lập sâu — Apple xem việc chôn nút này là vi phạm.
class _DeleteAccountButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton(
      key: const Key('profile_delete_account_btn'),
      onPressed: () => _confirmThenDelete(context, ref),
      style: TextButton.styleFrom(
        foregroundColor: WrColors.muted,
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(
        l10n.profileDeleteAccount,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Future<void> _confirmThenDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // Không tự điều hướng: `deleteAccount` đã signOut, router thấy mất phiên
      // là tự đá về /auth. Tự `go` thêm ở đây là đua với redirect của router.
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDeleteAccountError)),
        );
      }
    }
  }
}

/// Hộp xác nhận: phải gõ đúng chữ mới bấm được nút xoá.
///
/// Một cú chạm "Đồng ý" là quá rẻ cho hành động không hoàn tác được — gõ tay
/// buộc người dùng đọc xong mới làm được tiếp.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // So khớp bỏ qua hoa/thường và khoảng trắng thừa: người dùng gõ đúng ý rồi
    // mà bị chặn vì cái dấu cách cuối dòng thì vô lý.
    final ok = _controller.text.trim().toUpperCase() ==
        l10n.profileDeleteAccountConfirmWord.toUpperCase();

    return AlertDialog(
      title: Text(l10n.profileDeleteAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileDeleteAccountBody,
            style: const TextStyle(fontSize: 13.5, height: 1.6),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('profile_delete_confirm_field'),
            controller: _controller,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l10n.profileDeleteAccountHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('profile_delete_cancel_btn'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.profileDeleteAccountCancel),
        ),
        TextButton(
          key: const Key('profile_delete_confirm_btn'),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: WrColors.coral),
          child: Text(l10n.profileDeleteAccountCta),
        ),
      ],
    );
  }
}
