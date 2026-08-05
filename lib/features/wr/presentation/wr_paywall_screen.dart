import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/logic/wr_pricing.dart';
import '../../../core/logic/wr_store_policy.dart';
import '../../../core/logic/wr_tra_chieu.dart' show kWebAppBaseUrl;
import '../../../core/theme/wr_colors.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

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
Future<void> _openPayment(
  BuildContext context,
  WidgetRef ref,
  WrPremiumPricing plan,
) async {
  await context.push('/wr/payment', extra: plan);
  if (!context.mounted) return;

  var premium = false;
  try {
    premium = (await ref.read(wrEntitlementProvider.future)).isPremium;
  } catch (_) {
    /* không đọc được thì cứ để nguyên Paywall, không đoán bừa */
  }

  if (!context.mounted) return;
  if (premium) context.pop();
}

/// Có hiện con số giá không.
///
/// Chỉ giấu ở bản im lặng: bản dẫn-sang-web vẫn phải cho biết giá, không thì
/// người dùng bấm sang trình duyệt trong tình trạng mù thông tin.
bool _showsPrice(WrStorePolicy policy) =>
    policy.allowsInAppPurchase || policy.allowsWebPurchaseLink;

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
      const SnackBar(content: Text('Không mở được trang nâng cấp.')),
    );
  }
}

/// Nút cuối paywall. Ba dáng ứng với ba chính sách bán hàng.
class _PaywallCta extends ConsumerWidget {
  const _PaywallCta({required this.policy, required this.pricing});

  final WrStorePolicy policy;
  final WrPremiumPricing pricing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (policy.allowsInAppPurchase) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const Key('wr_paywall_cta'),
          onPressed: () => _openPayment(context, ref, pricing),
          style: _ctaStyle,
          child: const Text(
            'Bắt đầu Premium →',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
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
            child: const Text(
              'Nâng cấp trên web →',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          const WrParagraph(
            'Bạn sẽ được đưa sang trang WorkReflection để đăng nhập và hoàn '
            'tất. Xong quay lại app là bản đầy đủ đã mở.',
            style: TextStyle(fontSize: 11.5, color: WrColors.muted, height: 1.6),
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
      child: const WrParagraph(
        'Bản đầy đủ đi theo tài khoản WorkReflection của bạn. Khi tài khoản đã '
        'có quyền, những phần trên tự mở trong app.',
        style: TextStyle(fontSize: 12.5, color: WrColors.muted, height: 1.6),
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

class WrPaywallScreen extends ConsumerStatefulWidget {
  const WrPaywallScreen({super.key, this.trigger = PaywallTrigger.defaultTrigger});

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

  ({String title, String sub}) get _headline => switch (trigger) {
        PaywallTrigger.aiInsight => (
            title: 'AI Insight dành riêng cho bạn',
            sub: 'Nhận insight cá nhân hoá từ Career Memory của bạn.',
          ),
        PaywallTrigger.trialEnd => (
            title: 'Tháng trải nghiệm của bạn kết thúc',
            sub: 'Tiếp tục hành trình với Premium.',
          ),
        PaywallTrigger.benchmark => (
            title: 'So sánh với người đi làm cùng ngành',
            sub: 'Career Benchmark sẽ sớm ra mắt với Premium.',
          ),
        PaywallTrigger.growthOpportunity => (
            title: 'Hướng phát triển tiếp theo của bạn',
            sub: 'Từ những gì bạn đã nhìn lại, bản đầy đủ chỉ ra một hướng '
                'năng lực đáng thử tiếp.',
          ),
        PaywallTrigger.needReading => (
            title: 'Điều bạn đang thật sự tìm kiếm',
            sub: 'Bản đầy đủ đọc ra nhu cầu đứng sau những tình huống cứ lặp '
                'lại với bạn.',
          ),
        PaywallTrigger.careerMemory => (
            title: 'Toàn bộ ký ức nghề nghiệp của bạn',
            sub: 'Mở lại từng mảnh bạn đã để lại, theo đúng dòng thời gian.',
          ),
        PaywallTrigger.selfCheckDeep => (
            title: 'Điều kiện quanh bạn đang đổi thế nào',
            sub: 'Cùng 15 câu đó, chạy lại theo thời gian để thấy xu hướng, và '
                'đối chiếu với những gì bạn đã nhìn lại.',
          ),
        PaywallTrigger.defaultTrigger => (
            title: 'Mở khoá toàn bộ hành trình',
            sub: 'Tiếp tục phát triển không giới hạn.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final h = _headline;
    // Bản iOS không được bán trong app (Guideline 3.1.1) — xem
    // `wr_store_policy.dart`.
    final policy = ref.watch(wrStorePolicyProvider);
    // Các gói APP (`cc_products.product_type = 'premium_mobile'`) — năm 499.000đ
    // và tháng 70.000đ, KHÔNG phải gói web 249.000đ. Sửa ở trang quản trị của
    // web là app đổi theo. Trong lúc chờ tải thì dùng gói mặc định chứ không để
    // trống chỗ ghi giá.
    final plans = ref.watch(wrPremiumPlansProvider).valueOrNull ??
        const [WrPremiumPricing.fallback];

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

    const premiumHighlights = [
      _Highlight(
        icon: '◈',
        title: 'AI Insight cá nhân hoá',
        desc: 'Phát hiện mô thức từ Career Memory của bạn. Ngày càng chính xác hơn.',
      ),
      _Highlight(
        icon: '📈',
        title: 'Career Pattern',
        desc: 'Nhìn thấy các mô thức lặp lại trong hành trình nghề nghiệp theo thời gian.',
      ),
      _Highlight(
        icon: '◎',
        title: 'Không giới hạn',
        desc: 'Story không giới hạn, Thực hành không giới hạn, Career Memory đầy đủ.',
      ),
    ];

    const freeFeatures = [
      _FeatureRow(label: 'Story Reflection hàng ngày', avail: true),
      _FeatureRow(label: 'Check-in nhanh', avail: true),
      _FeatureRow(label: 'Career Memory Timeline', avail: true),
      _FeatureRow(label: '15 câu phản chiếu', avail: true),
      _FeatureRow(label: '3 chủ đề Thực hành', avail: true),
      _FeatureRow(label: 'AI Insight', avail: false),
      _FeatureRow(label: 'Career Pattern Analysis', avail: false),
      _FeatureRow(label: 'Career Benchmark', avail: false),
      _FeatureRow(label: 'Không giới hạn Thực hành', avail: false),
    ];

    return Scaffold(
      backgroundColor: WrColors.pageBg,
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
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
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
                          if (_showsPrice(policy) && pricing.hasDiscount) ...[
                            Text(
                              pricing.originalLabel!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0x66FFFFFF),
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Color(0x66FFFFFF),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          if (_showsPrice(policy))
                            Text(
                              '${pricing.currentLabel} / ${pricing.durationSuffix}',
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
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.close, color: Color(0x99FFFFFF), size: 14),
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
                  // Premium highlights
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BẠN NHẬN ĐƯỢC',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: WrColors.muted,
                            letterSpacing: 0.08,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...premiumHighlights.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _HighlightCard(highlight: item),
                            )),
                      ],
                    ),
                  ),

                  // Free vs Premium comparison
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SO SÁNH GÓI',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: WrColors.muted,
                            letterSpacing: 0.08,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: WrColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WrColors.line),
                          ),
                          child: const Column(
                            children: freeFeatures,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chọn gói — chỉ dựng khi thật sự có nhiều hơn một gói, để
                  // trường hợp một gói không phát sinh thêm một cú chạm vô ích.
                  //
                  // Bản im lặng (Apple bắt bẻ anti-steering) không hiện gói lẫn
                  // giá: nhắc tới con số là đã gợi chuyện mua bán.
                  if (_showsPrice(policy) && plans.length > 1)
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
                  if (_showsPrice(policy))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                      child: _PriceBlock(pricing: pricing),
                    ),

                  // CTA — ba dáng tuỳ chính sách của bản build, xem
                  // `wr_store_policy.dart`.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                    child: _PaywallCta(policy: policy, pricing: pricing),
                  ),

                  // Guarantee
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: WrColors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(
                          left: BorderSide(color: WrColors.pillTealText, width: 3),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bảo đảm hoàn tiền 7 ngày',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: WrColors.pillTealText,
                            ),
                          ),
                          SizedBox(height: 3),
                          WrParagraph(
                            'Nếu không hài lòng trong 7 ngày đầu, chúng tôi hoàn tiền toàn bộ. Không câu hỏi.',
                            style: TextStyle(fontSize: 11.5, color: WrColors.muted, height: 1.6),
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
        const Text(
          'CHỌN GÓI',
          style: TextStyle(
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
            savingsPercent:
                identical(plan, baseline) ? null : plan.savingsPercentVs(baseline),
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
                    // "Một năm" / "Một tháng" — viết hoa chữ đầu.
                    plan.durationLabel[0].toUpperCase() +
                        plan.durationLabel.substring(1),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                    ),
                  ),
                  if (savingsPercent != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '≈ ${formatVndPrice(plan.pricePerMonth, plan.currency)}'
                      ' mỗi tháng',
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
                  'TIẾT KIỆM $savingsPercent%',
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
              plan.currentLabel,
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
                      pricing.currentLabel,
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
                          pricing.originalLabel!,
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
                  'cho ${pricing.durationLabel} Premium',
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
                '−${pricing.discountPercent}%',
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

class _Highlight {
  const _Highlight({required this.icon, required this.title, required this.desc});
  final String icon;
  final String title;
  final String desc;
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.highlight});
  final _Highlight highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WrColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: WrColors.navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(highlight.icon, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlight.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                WrParagraph(
                  highlight.desc,
                  style: const TextStyle(fontSize: 12.5, color: WrColors.muted, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label, required this.avail});
  final String label;
  final bool avail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WrColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: avail ? WrColors.dark : WrColors.muted,
              ),
            ),
          ),
          Icon(
            avail ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: avail ? WrColors.teal : WrColors.text3,
          ),
        ],
      ),
    );
  }
}
