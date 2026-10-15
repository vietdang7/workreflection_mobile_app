import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/data/wr_iap_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_pricing.dart';
import '../../../core/models/wr_intelligence.dart' show WrPlan;
import '../../../core/logic/wr_store_policy.dart';
import '../../../core/logic/wr_tra_chieu.dart' show kWebAppBaseUrl;
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_app_background.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../iap_providers.dart';
import '../wr_providers.dart';

/// Trigger cho các headline khác nhau của Paywall.
enum PaywallTrigger {
  defaultTrigger,
  aiInsight,
  trialEnd,
  benchmark,

  /// Hai Lớp v1.6 §11.4 — Cơ hội phát triển thuộc lớp Paid.
  growthOpportunity,

  /// Đọc vị nhu cầu ở tab Hiểu mình (khách chốt 2026-07-29).
  needReading,

  /// Toàn bộ Career Memory ở tab Hành trình (khách chốt 2026-07-29).
  careerMemory,

  /// Diễn giải sâu + theo dõi xu hướng của Self-Check (mockup Sprint 2,
  /// trigger `sca_deep`).
  selfCheckDeep,

  /// Đã đủ số chủ đề Thực hành của bản miễn phí (script `practice_limit`).
  practiceLimit,

  /// Bước cuối của một chủ đề Thực hành (script `practice_step`).
  practiceStep,
}

/// Mở màn thanh toán, và tự đóng Paywall nếu người dùng quay lại sau khi đã mua.
///
/// Đường thường thì màn thanh toán tự `go('/home')` khi bấm nút trên màn thành
/// công, nên hàm này không phải làm gì. Nhưng người dùng có thể bấm nút quay
/// lại thay vì bấm nút đó — tiền đã trả rồi mà lại rơi về trang mời mua thì vô
/// lý, nên hỏi lại quyền một lần trước khi quyết định.
///
/// Ngược lại, người CHƯA mua quay lại thì Paywall phải ở nguyên đó: đóng nhầm
/// là cướp mất lối vào duy nhất.
/// Cả router lẫn container đều lấy TRƯỚC khi đi, và không đụng lại `context`
/// sau đó. Lý do: trả tiền xong thì quyền đổi, mà quyền đổi thì chính cái nút
/// gọi hàm này bị gỡ khỏi cây (Paywall chuyển sang dáng "đã có bản đầy đủ").
/// Bám vào `context` của nút là bám vào thứ vừa chết — người dùng bấm quay lại
/// sẽ kẹt ở Paywall đúng như lúc chưa sửa.
Future<void> _openPayment(
  BuildContext context,
  WidgetRef ref,
  WrPremiumPricing plan,
) async {
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context, listen: false);

  await router.push('/wr/payment', extra: plan);

  var premium = false;
  try {
    premium = (await container.read(wrEntitlementProvider.future)).isPremium;
  } catch (_) {
    /* không đọc được thì cứ để nguyên Paywall, không đoán bừa */
  }

  if (premium && router.canPop()) router.pop();
}

/// Có hiện khối giá lấy từ `cc_products` không.
///
/// Giấu ở ba trường hợp:
///
///   • Bản im lặng. (Bản dẫn-sang-web thì vẫn phải cho biết giá, không thì
///     người dùng bấm sang trình duyệt trong tình trạng mù thông tin.)
///   • Người đã có quyền — chào giá cho người vừa trả tiền là vô duyên, và với
///     người duyệt app của Apple (dùng tài khoản demo Premium) thì cái nút dẫn
///     ra web nằm ngay đó chính là thứ Guideline 3.1.3 cấm.
///   • Bản bán bằng IAP. Giá phải là giá StoreKit trả về cho đúng kho của người
///     dùng, không phải con số VND trong `cc_products` — hai số này khác nhau
///     và Apple bắt hiện đúng số của họ. Khối giá riêng của IAP nằm trong
///     [_NativeIapCta].
bool _showsPrice(WrStorePolicy policy, {required bool alreadyPremium}) =>
    !alreadyPremium &&
    !policy.allowsNativeIap &&
    (policy.allowsVietQrCheckout || policy.allowsWebPurchaseLink);

/// Mở trang mua Premium trên web (bản iOS).
///
/// Mở bằng trình duyệt ngoài chứ không WebView trong app: Apple coi WebView
/// bọc trang thanh toán là "mua trong app trá hình". Ra hẳn Safari thì rành
/// mạch là giao dịch xảy ra ngoài app.
///
/// Không mở được thì nói ra — người dùng vừa bấm một nút, im lặng là tệ nhất.
Future<void> _openWebPurchase(
  BuildContext context,
  WrPremiumPricing plan,
) async {
  final url = wrWebPremiumUrl(
    baseUrl: kWebAppBaseUrl,
    planProductId: plan.productId,
    source: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios_app',
      TargetPlatform.android => 'android_app',
      _ => 'app',
    },
  );
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wrKeepCompounds(tr(
            'Không mở được trang nâng cấp.',
            'Could not open the upgrade page.',
          )),
        ),
      ),
    );
  }
}

/// Nút cuối paywall. Ba dáng ứng với ba chính sách bán hàng.
class _PaywallCta extends ConsumerWidget {
  const _PaywallCta({
    required this.policy,
    required this.pricing,
    required this.alreadyPremium,
  });

  final WrStorePolicy policy;
  final WrPremiumPricing pricing;

  /// Tài khoản đã có quyền đầy đủ. Khi đó màn này không còn là trang bán hàng
  /// mà là trang xác nhận — không nút mua, không nút dẫn sang web.
  final bool alreadyPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alreadyPremium) {
      return Container(
        key: const Key('wr_paywall_cta_owned'),
        decoration: BoxDecoration(
          color: WrColors.teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WrColors.pillTealText),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outlined,
              color: WrColors.pillTealText,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: WrParagraph(
                tr(
                  'Tài khoản của bạn đang dùng bản đầy đủ. Mọi phần ở trên đã mở '
                      'sẵn, không cần làm gì thêm.',
                  'Your account is on the full version. Everything above is already '
                      'unlocked, nothing more to do.',
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: WrColors.navy,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Bán bằng IAP của kho ứng dụng — đặt TRƯỚC nhánh QR: hai nhánh loại trừ
    // nhau theo chính sách, nhưng thứ tự này nói rõ nhánh nào là đường phát
    // hành thật.
    if (policy.allowsNativeIap) {
      return const _NativeIapCta();
    }

    if (policy.allowsVietQrCheckout) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const Key('wr_paywall_cta'),
          onPressed: () => _openPayment(context, ref, pricing),
          style: _ctaStyle,
          // Script: "Bắt đầu Premium, 499.000đ/năm" — giá ghép từ gói đang
          // chọn trong `cc_products`, không viết cứng.
          child: Text(
            wrKeepCompounds(tr(
              'Bắt đầu Premium, ${pricing.currentLabel}/${pricing.durationSuffix}',
              'Start Premium, ${pricing.currentLabel}/${pricing.durationSuffix}',
            )),
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (policy.allowsWebPurchaseLink) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            key: const Key('wr_paywall_cta_web'),
            onPressed: () => _openWebPurchase(context, pricing),
            style: _ctaStyle,
            child: Text(
              wrKeepCompounds(tr('Nâng cấp trên web →', 'Upgrade on the web →')),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          WrParagraph(
            tr(
              'Bạn sẽ được đưa sang trang WorkReflection để đăng nhập và hoàn '
                  'tất. Xong quay lại app là bản đầy đủ đã mở.',
              'We will take you to the WorkReflection site to sign in and finish '
                  'up. Come back to the app and the full version is open.',
            ),
            style: const TextStyle(
              fontSize: 11.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
        ],
      );
    }

    // Bản im lặng: không nút, không giá, chỉ nói cho người dùng biết bản đầy đủ
    // đến từ tài khoản của họ chứ không phải thứ mua trong app.
    return Container(
      key: const Key('wr_paywall_cta_silent'),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WrColors.line),
      ),
      padding: const EdgeInsets.all(14),
      child: WrParagraph(
        tr(
          'Bản đầy đủ đi theo tài khoản WorkReflection của bạn. Khi tài khoản đã '
              'có quyền, những phần trên tự mở trong app.',
          'The full version follows your WorkReflection account. Once the account '
              'has access, everything above opens inside the app.',
        ),
        style: const TextStyle(
          fontSize: 12.5,
          color: WrColors.muted,
          height: 1.6,
        ),
      ),
    );
  }

  static final ButtonStyle _ctaStyle = ElevatedButton.styleFrom(
    backgroundColor: WrColors.coral,
    foregroundColor: WrColors.navy,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 0,
  );
}

/// Trang Điều khoản sử dụng.
///
/// Dùng EULA mẫu của Apple vì WorkReflection chưa có trang điều khoản riêng
/// trên web. Apple chấp nhận đường dẫn này, và nó CÓ BẮT BUỘC phải nằm trong
/// app khi bán gói đăng ký — thiếu là một lý do từ chối riêng.
const String kAppleStandardEulaUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/// Trang Chính sách quyền riêng tư, đúng đường dẫn đã khai với App Store.
const String kPrivacyPolicyUrl =
    'https://www.workreflection.app/privacy-policy';

/// Mở một trang pháp lý bằng trình duyệt ngoài.
Future<void> _openLegal(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wrKeepCompounds(tr('Không mở được trang này.', 'Could not open this page.')),
        ),
      ),
    );
  }
}

/// Phần mua Premium bằng In-App Purchase.
///
/// Ba thứ Apple BẮT BUỘC phải có khi bán gói đăng ký, thiếu thứ nào cũng là một
/// lý do từ chối riêng biệt:
///   • Giá và thời hạn từng gói, lấy từ StoreKit chứ không phải từ `cc_products`.
///   • Nút khôi phục giao dịch đã mua.
///   • Đường dẫn tới Điều khoản sử dụng và Chính sách quyền riêng tư.
class _NativeIapCta extends ConsumerWidget {
  const _NativeIapCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wrIapControllerProvider);

    // Lỗi và tin báo hiện bằng SnackBar rồi xoá ngay, để nó không dính lại khi
    // người dùng thử tiếp lần nữa.
    ref.listen<WrIapState>(wrIapControllerProvider, (prev, next) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      if (next.error != null && next.error != prev?.error) {
        messenger.showSnackBar(SnackBar(content: Text(wrKeepCompounds(next.error!))));
        ref.read(wrIapControllerProvider.notifier).clearMessages();
      } else if (next.restoredNothing && !(prev?.restoredNothing ?? false)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              wrKeepCompounds(tr(
                'Không tìm thấy gói nào đã mua trên tài khoản Apple này.',
                'No purchases found on this Apple account.',
              )),
            ),
          ),
        );
        ref.read(wrIapControllerProvider.notifier).clearMessages();
      }
    });

    return ref
        .watch(wrIapOffersProvider)
        .when(
          loading: () => const Padding(
            key: Key('wr_paywall_iap_loading'),
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          // Provider này đã nuốt mọi lỗi và trả danh sách rỗng, nên nhánh error
          // gần như không xảy ra. Vẫn vẽ đúng như nhánh rỗng thay vì để màn hình
          // đỏ: người dùng không sửa được gì từ một thông báo lỗi ở đây.
          error: (_, __) => const _IapUnavailable(),
          data: (offers) => offers.isEmpty
              ? const _IapUnavailable()
              : _IapOfferList(offers: offers, state: state),
        );
  }
}

/// Khi kho ứng dụng không trả về gói nào.
///
/// Gặp ở giả lập chưa đăng nhập Apple, ở máy bị khoá mua hàng, và ở giai đoạn
/// gói còn đang chờ duyệt bên App Store Connect. Không phải lỗi của người dùng
/// nên không báo đỏ.
class _IapUnavailable extends StatelessWidget {
  const _IapUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_paywall_iap_unavailable'),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WrColors.line),
      ),
      padding: const EdgeInsets.all(14),
      child: WrParagraph(
        tr(
          'Chưa mở bán được trên thiết bị này. Nếu tài khoản của bạn đã có bản '
              'đầy đủ, những phần ở trên vẫn tự mở.',
          'Purchases are not available on this device yet. If your account '
              'already has the full version, the parts above unlock on their own.',
        ),
        style: const TextStyle(
          fontSize: 12.5,
          color: WrColors.muted,
          height: 1.6,
        ),
      ),
    );
  }
}

/// Danh sách gói bán qua kho ứng dụng, kèm nút khôi phục và liên kết pháp lý.
class _IapOfferList extends ConsumerWidget {
  const _IapOfferList({required this.offers, required this.state});

  final List<WrIapOffer> offers;
  final WrIapState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(wrIapControllerProvider.notifier);
    final busy = state.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < offers.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _IapOfferButton(
            offer: offers[i],
            // Gói đầu danh sách là gói năm — làm nút chính, các gói sau là nút
            // viền. Thứ tự do `kWrIapProducts` quyết định, không do kho trả về.
            primary: i == 0,
            enabled: !busy,
            onPressed: () => controller.buy(offers[i].id),
          ),
        ],
        const SizedBox(height: 6),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (state.phase == WrIapPhase.awaitingApproval)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: WrParagraph(
              tr(
                'Giao dịch đang chờ được duyệt. Bạn cứ dùng app bình thường, khi '
                    'nào duyệt xong bản đầy đủ sẽ tự mở.',
                'Your purchase is waiting for approval. Keep using the app as '
                    'usual; the full version unlocks once it is approved.',
              ),
              style: const TextStyle(
                fontSize: 11.5,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          ),
        TextButton(
          key: const Key('wr_paywall_iap_restore'),
          onPressed: busy ? null : controller.restore,
          child: Text(
            wrKeepCompounds(tr('Khôi phục giao dịch đã mua', 'Restore purchases')),
            style: const TextStyle(fontSize: 13, color: WrColors.pillTealText),
          ),
        ),
        const SizedBox(height: 2),
        WrParagraph(
          tr(
            'Gói tự động gia hạn cho tới khi bạn tắt. Tiền được trừ vào tài khoản '
                'Apple của bạn, và kỳ tiếp theo sẽ được trừ trong vòng 24 giờ trước '
                'khi kỳ hiện tại kết thúc. Bạn tắt gia hạn bất cứ lúc nào trong phần '
                'Cài đặt tài khoản Apple.',
            'Subscriptions renew automatically until you turn them off. Payment '
                'is charged to your Apple account, and the next period is charged '
                'within 24 hours before the current one ends. You can turn off '
                'renewal at any time in your Apple account settings.',
          ),
          style: const TextStyle(
            fontSize: 11,
            color: WrColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegalLink(
              key: const Key('wr_paywall_terms_link'),
              label: tr('Điều khoản sử dụng', 'Terms of Use'),
              url: kAppleStandardEulaUrl,
            ),
            const Text(
              '  ·  ',
              style: TextStyle(fontSize: 11, color: WrColors.muted),
            ),
            _LegalLink(
              key: const Key('wr_paywall_privacy_link'),
              label: tr('Chính sách quyền riêng tư', 'Privacy Policy'),
              url: kPrivacyPolicyUrl,
            ),
          ],
        ),
      ],
    );
  }
}

/// Một nút mua, hiện giá đúng như kho ứng dụng trả về.
class _IapOfferButton extends StatelessWidget {
  const _IapOfferButton({
    required this.offer,
    required this.primary,
    required this.enabled,
    required this.onPressed,
  });

  final WrIapOffer offer;
  final bool primary;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Dán thẳng `priceLabel` của StoreKit, không tự định dạng lại: chuỗi đó đã
    // đúng tiền tệ và đúng quy tắc dấu phân cách của kho người dùng.
    final label = '${offer.title}: ${offer.priceLabel}/${offer.durationSuffix}';

    if (primary) {
      return ElevatedButton(
        key: Key('wr_paywall_iap_buy_${offer.id}'),
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: WrColors.coral,
          foregroundColor: WrColors.navy,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          wrKeepCompounds(label),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      );
    }

    return OutlinedButton(
      key: Key('wr_paywall_iap_buy_${offer.id}'),
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: WrColors.navy,
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: const BorderSide(color: WrColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        wrKeepCompounds(label),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({super.key, required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openLegal(context, url),
      child: Text(
        wrKeepCompounds(label),
        style: const TextStyle(
          fontSize: 11,
          color: WrColors.pillTealText,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class WrPaywallScreen extends ConsumerStatefulWidget {
  const WrPaywallScreen({
    super.key,
    this.trigger = PaywallTrigger.defaultTrigger,
  });

  final PaywallTrigger trigger;

  @override
  ConsumerState<WrPaywallScreen> createState() => _WrPaywallScreenState();
}

class _WrPaywallScreenState extends ConsumerState<WrPaywallScreen> {
  /// `cc_products.id` của gói đang chọn.
  ///
  /// Giữ theo id chứ không theo chỉ số: danh sách gói tải về sau khi màn đã
  /// dựng, mà quản trị cũng có thể đổi thứ tự — bám chỉ số là có ngày chọn nhầm
  /// gói. null nghĩa là chưa chọn tay, khi đó lấy gói đầu danh sách.
  String? _selectedProductId;

  PaywallTrigger get trigger => widget.trigger;

  // Tiêu đề và câu phụ của các trigger có trong script `screenPaywall` lấy
  // nguyên văn `headlines` của script. Ba trigger script không có (trial_end,
  // benchmark, need_reading) giữ câu cũ.
  ({String title, String sub}) get _headline => switch (trigger) {
    PaywallTrigger.aiInsight => (
      title: tr(
        'Đọc sâu từ Dấu ấn hành trình',
        'A deeper reading from your Journey marks',
      ),
      sub: tr(
        'Nhận ra điều đang lặp lại mà bạn khó tự thấy.',
        'Spot the patterns that are hard to see on your own.',
      ),
    ),
    PaywallTrigger.practiceLimit => (
      title: tr('Không giới hạn Thực hành', 'Unlimited Practice'),
      sub: tr(
        'Theo đuổi bao nhiêu chủ đề phát triển tuỳ bạn.',
        'Pursue as many growth themes as you like.',
      ),
    ),
    PaywallTrigger.practiceStep => (
      title: tr('Mở khoá bước cuối', 'Unlock the final step'),
      sub: tr(
        'Nơi giá trị luyện tập thật sự tích lũy.',
        'Where the value of practice really builds up.',
      ),
    ),
    PaywallTrigger.trialEnd => (
      title: tr(
        'Tháng trải nghiệm của bạn kết thúc',
        'Your trial month has ended',
      ),
      sub: tr('Tiếp tục hành trình với Premium.', 'Carry on with Premium.'),
    ),
    PaywallTrigger.benchmark => (
      title: tr(
        'So sánh với người đi làm cùng ngành',
        'Compare with others in your field',
      ),
      sub: tr(
        'Career Benchmark sẽ sớm ra mắt với Premium.',
        'Career Benchmark is coming soon with Premium.',
      ),
    ),
    PaywallTrigger.growthOpportunity => (
      title: tr('Cơ hội phát triển từ AI', 'Growth opportunities from AI'),
      sub: tr(
        'Tổng hợp từ toàn bộ hành trình, gợi ý hướng năng lực tiếp theo.',
        'Drawn from your whole journey, suggesting the next skill to build.',
      ),
    ),
    PaywallTrigger.needReading => (
      title: tr(
        'Điều bạn đang thật sự tìm kiếm',
        'What you are really looking for',
      ),
      sub: tr(
        'Bản đầy đủ đọc ra nhu cầu đứng sau những tình huống cứ lặp '
            'lại với bạn.',
        'The full version reads the need behind the situations that keep '
            'coming back to you.',
      ),
    ),
    PaywallTrigger.careerMemory => (
      title: tr(
        'Xem toàn bộ Dấu ấn hành trình',
        'See all of your Journey marks',
      ),
      sub: tr(
        'Mọi dòng bạn từng viết, nối lại thành một hành trình.',
        'Every line you have written, joined into one journey.',
      ),
    ),
    PaywallTrigger.selfCheckDeep => (
      title: tr(
        'Đọc sâu điều kiện làm việc',
        'A deeper reading of your working conditions',
      ),
      sub: tr(
        'Xem điều gì quanh bạn đang nâng đỡ và điều gì đang cản trở.',
        'See what around you is supporting you and what is holding you back.',
      ),
    ),
    PaywallTrigger.defaultTrigger => (
      title: tr('Mở khoá toàn bộ trí tuệ', 'Unlock all the insight'),
      sub: tr(
        'Từ chính dữ liệu bạn đã tạo ra mỗi ngày.',
        'From the very data you create every day.',
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    // Bản iOS không được bán trong app (Guideline 3.1.1) — xem
    // `wr_store_policy.dart`.
    final policy = ref.watch(wrStorePolicyProvider);
    // Người đã có quyền vẫn vào được màn này từ dòng "Bản Premium" ở tab Tôi.
    // Chưa đọc xong quyền thì coi như chưa có: đoán nhầm theo hướng "đã mua"
    // sẽ giấu mất lối mua của người thật sự cần.
    final alreadyPremium =
        ref.watch(wrEntitlementProvider).valueOrNull?.isPremium ?? false;
    final showsPrice = _showsPrice(policy, alreadyPremium: alreadyPremium);
    // Đầu đề của các trigger đều là lời mời mua. Người đã có quyền vào đây để
    // xem mình đang có gì, nên đổi sang lời xác nhận.
    final h = alreadyPremium
        ? (
            title: tr(
              'Bạn đang dùng bản đầy đủ',
              'You are on the full version',
            ),
            sub: tr(
              'Tất cả tính năng dưới đây đã mở sẵn trong tài khoản của bạn.',
              'Every feature below is already open in your account.',
            ),
          )
        : _headline;
    // Các gói APP (`cc_products.product_type = 'premium_mobile'`) — năm 499.000đ
    // và tháng 70.000đ, KHÔNG phải gói web 249.000đ. Sửa ở trang quản trị của
    // web là app đổi theo. Trong lúc chờ tải thì dùng gói mặc định chứ không để
    // trống chỗ ghi giá.
    final plans =
        ref.watch(wrPremiumPlansProvider).valueOrNull ??
        [WrPremiumPricing.fallback];

    // Gói đang chọn. Id đã chọn mà biến mất khỏi bảng (quản trị tắt gói giữa
    // chừng) thì rơi về gói đầu chứ không kẹt ở gói không còn bán.
    final pricing = plans.firstWhere(
      (p) => p.productId != null && p.productId == _selectedProductId,
      orElse: () => plans.first,
    );

    // Gói ngắn hạn nhất làm mốc quy đổi cho nhãn tiết kiệm.
    final baseline = plans.reduce(
      (a, b) => a.durationDays <= b.durationDays ? a : b,
    );

    // Bảng Free/Premium đúng `freeFeatures` của script `screenPaywall`.
    //
    // Số chủ đề Thực hành của bản miễn phí đọc từ luật gói đang chạy
    // ([WrEntitlement.maxActivePracticeThemes]) chứ không viết cứng: script ghi
    // "2 chủ đề Thực hành", khớp luật hiện tại; nếu luật đổi thì chữ đổi theo
    // thay vì hứa một con số app không giữ.
    final freeThemeLimit =
        WrEntitlement(plan: WrPlan.free).maxActivePracticeThemes ?? 2;
    final freeFeatures = [
      _FeatureRow(
        label: tr('Nhìn lại hàng ngày', 'Daily look-backs'),
        avail: true,
      ),
      _FeatureRow(
        label: tr(
          'Những điều đang lặp lại',
          'What keeps coming back',
        ),
        avail: true,
      ),
      _FeatureRow(
        label: tr(
          'Khảo sát điều kiện làm việc (15 câu)',
          'Workplace conditions survey (15 questions)',
        ),
        avail: true,
      ),
      _FeatureRow(
        label: tr(
          '$freeThemeLimit chủ đề Thực hành',
          '$freeThemeLimit Practice themes',
        ),
        avail: true,
      ),
      _FeatureRow(
        label: tr(
          'Tổng quan hai nguồn đặt cạnh nhau',
          'Both sources side by side',
        ),
        avail: false,
      ),
      _FeatureRow(
        label: tr(
          'Xu hướng điều kiện làm việc theo thời gian',
          'Working conditions trends over time',
        ),
        avail: false,
      ),
      _FeatureRow(
        label: tr(
          'Cơ hội phát triển (Growth Intelligence)',
          'Growth opportunities (Growth Intelligence)',
        ),
        avail: false,
      ),
      _FeatureRow(
        label: tr('Dấu ấn hành trình đầy đủ', 'All your Journey marks'),
        avail: false,
      ),
      _FeatureRow(
        label: tr('Thực hành không giới hạn', 'Unlimited Practice'),
        avail: false,
        isLast: true,
      ),
    ];

    return WrAppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
        children: [
          // Header — navy background
          Container(
            color: WrColors.navy,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 22,
              right: 22,
              bottom: 20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: WrColors.coral,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 2,
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: WrColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (showsPrice && pricing.hasDiscount) ...[
                            Text(
                              wrKeepCompounds(pricing.originalLabel!),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0x66FFFFFF),
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Color(0x66FFFFFF),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          if (showsPrice)
                            Text(
                              wrKeepCompounds('${pricing.currentLabel} / ${pricing.durationSuffix}'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xB3FFFFFF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      WrParagraph(
                        h.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: WrColors.white,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.start,
                      ),
                      const SizedBox(height: 5),
                      WrParagraph(
                        h.sub,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0x8CFFFFFF),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  // Trên khối navy: vòng tròn trắng sáng thay vì navy (họp
                  // khách 14/10), để nút đóng nổi hẳn lên.
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(left: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xF2FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: WrColors.navy,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bảng Free/Premium — script `screenPaywall` chỉ có một thẻ
                  // liệt kê tính năng, không khối "Bạn nhận được" riêng.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
                    child: WrCard(
                      key: const Key('wr_paywall_feature_table'),
                      padding: EdgeInsets.zero,
                      child: Column(children: freeFeatures),
                    ),
                  ),

                  // Chọn gói — chỉ dựng khi thật sự có nhiều hơn một gói, để
                  // trường hợp một gói không phát sinh thêm một cú chạm vô ích.
                  //
                  // Bản im lặng (Apple bắt bẻ anti-steering) không hiện gói lẫn
                  // giá: nhắc tới con số là đã gợi chuyện mua bán.
                  if (showsPrice && plans.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                      child: _PlanSelector(
                        plans: plans,
                        selected: pricing,
                        baseline: baseline,
                        onSelect: (p) =>
                            setState(() => _selectedProductId = p.productId),
                      ),
                    ),

                  // Giá — đặt ngay trên nút mua để con số là thứ cuối cùng đọc
                  // được trước khi bấm.
                  if (showsPrice)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                      child: _PriceBlock(pricing: pricing),
                    ),

                  // CTA — ba dáng tuỳ chính sách của bản build, xem
                  // `wr_store_policy.dart`.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                    child: _PaywallCta(
                      policy: policy,
                      pricing: pricing,
                      alreadyPremium: alreadyPremium,
                    ),
                  ),

                  // Script: nút viền "Để sau" ngay dưới nút chính.
                  if (!alreadyPremium)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          key: const Key('wr_paywall_later'),
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: WrColors.navy,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(color: WrColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            wrKeepCompounds(tr('Để sau', 'Maybe later')),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Bảo đảm hoàn tiền — chỉ ở bản bán trong app.
                  //
                  // Đây là điều khoản thương mại của một giao dịch. Ở bản phát
                  // hành qua kho, giao dịch đó xảy ra trên web, nên để lời hứa
                  // hoàn tiền nằm cạnh nút dẫn ra trình duyệt là tự nộp bằng
                  // chứng anti-steering (Guideline 3.1.3). Với người đã mua
                  // rồi thì nó cũng chẳng còn nghĩa gì.
                  if (policy.allowsVietQrCheckout && !alreadyPremium)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: WrColors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: const Border(
                            left: BorderSide(
                              color: WrColors.pillTealText,
                              width: 3,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wrKeepCompounds(tr(
                                'Bảo đảm hoàn tiền 7 ngày',
                                '7-day money-back guarantee',
                              )),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: WrColors.pillTealText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            WrParagraph(
                              tr(
                                'Nếu không hài lòng trong 7 ngày đầu, chúng tôi hoàn tiền toàn bộ. Không câu hỏi.',
                                'Not happy in the first 7 days? We refund everything. No questions asked.',
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: WrColors.muted,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// Chọn gói năm hay gói tháng.
///
/// Dựng từ danh sách `cc_products` chứ không viết cứng hai lựa chọn: quản trị
/// thêm gói 6 tháng là nó tự hiện thêm một hàng.
class _PlanSelector extends StatelessWidget {
  const _PlanSelector({
    required this.plans,
    required this.selected,
    required this.baseline,
    required this.onSelect,
  });

  final List<WrPremiumPricing> plans;
  final WrPremiumPricing selected;

  /// Gói ngắn hạn nhất — mốc để tính "tiết kiệm bao nhiêu phần trăm".
  final WrPremiumPricing baseline;

  final ValueChanged<WrPremiumPricing> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wrKeepCompounds(tr('CHỌN GÓI', 'CHOOSE A PLAN')),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: WrColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        for (final plan in plans) ...[
          _PlanOption(
            plan: plan,
            isSelected: identical(plan, selected),
            savingsPercent: identical(plan, baseline)
                ? null
                : plan.savingsPercentVs(baseline),
            onTap: () => onSelect(plan),
          ),
          if (plan != plans.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.plan,
    required this.isSelected,
    required this.savingsPercent,
    required this.onTap,
  });

  final WrPremiumPricing plan;
  final bool isSelected;
  final int? savingsPercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: Key('wr_paywall_plan_${plan.durationDays}'),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? WrColors.coral : WrColors.line,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Nút tròn tự vẽ: đây là một dòng chạm được cả hàng, dùng Radio thì
            // vùng chạm bị bó lại đúng cái chấm.
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? WrColors.coral : WrColors.line,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: WrColors.coral,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wrKeepCompounds(// "Một năm" / "Một tháng" — viết hoa chữ đầu.
                    plan.durationLabel[0].toUpperCase() +
                        plan.durationLabel.substring(1)),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                    ),
                  ),
                  if (savingsPercent != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      wrKeepCompounds(tr(
                        '≈ ${formatVndPrice(plan.pricePerMonth, plan.currency)}'
                            ' mỗi tháng',
                        '≈ ${formatVndPrice(plan.pricePerMonth, plan.currency)}'
                            ' per month',
                      )),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WrColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (savingsPercent != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: WrColors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  wrKeepCompounds(tr('TIẾT KIỆM $savingsPercent%', 'SAVE $savingsPercent%')),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.pillTealText,
                  ),
                ),
              ),
              const SizedBox(width: 9),
            ],
            Text(
              wrKeepCompounds(plan.currentLabel),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Giá gốc gạch ngang · giá hiện tại · mức giảm — cùng ba con số mà trang quản
/// trị Gói dịch vụ của web hiển thị.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.pricing});

  final WrPremiumPricing pricing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WrColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      wrKeepCompounds(pricing.currentLabel),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (pricing.hasDiscount)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          wrKeepCompounds(pricing.originalLabel!),
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: WrColors.text3,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: WrColors.text3,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  wrKeepCompounds(tr(
                    'cho ${pricing.durationLabel} Premium',
                    'for ${pricing.durationLabel} of Premium',
                  )),
                  style: const TextStyle(fontSize: 12.5, color: WrColors.muted),
                ),
              ],
            ),
          ),
          if (pricing.hasDiscount)
            Container(
              decoration: BoxDecoration(
                color: WrColors.coral,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              child: Text(
                wrKeepCompounds('−${pricing.discountPercent}%'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Một dòng của bảng Free/Premium (`freeFeatures` của script): dấu ✓/✕ trong
/// vòng tròn, tên tính năng, và nhãn gói ở bên phải.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.label,
    required this.avail,
    this.isLast = false,
  });
  final String label;
  final bool avail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: WrColors.lineSoft)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avail
                  ? WrColors.teal.withValues(alpha: 0.15)
                  : WrColors.navy.withValues(alpha: 0.06),
            ),
            child: Text(
              wrKeepCompounds(avail ? '✓' : '✕'),
              style: TextStyle(
                fontSize: 10,
                color: avail ? WrColors.pillTealText : WrColors.text3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              wrKeepCompounds(label),
              style: TextStyle(
                fontSize: 14,
                color: avail ? WrColors.navy : WrColors.text3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            wrKeepCompounds(avail ? 'Free' : 'Premium'),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
