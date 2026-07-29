import 'package:flutter/material.dart';
import '../../../core/theme/wr_colors.dart';

/// Trigger cho các headline khác nhau của Paywall.
enum PaywallTrigger {
  defaultTrigger,
  aiInsight,
  report,
  trialEnd,
  benchmark,

  /// Hai Lớp v1.6 §11.4 — Cơ hội phát triển thuộc lớp Paid.
  growthOpportunity,

  /// Đọc vị nhu cầu ở tab Hiểu mình (khách chốt 2026-07-29).
  needReading,

  /// Toàn bộ Career Memory ở tab Hành trình (khách chốt 2026-07-29).
  careerMemory,
}

class WrPaywallScreen extends StatelessWidget {
  const WrPaywallScreen({super.key, this.trigger = PaywallTrigger.defaultTrigger});

  final PaywallTrigger trigger;

  ({String title, String sub}) get _headline => switch (trigger) {
        PaywallTrigger.aiInsight => (
            title: 'AI Insight dành riêng cho bạn',
            sub: 'Nhận insight cá nhân hoá từ Career Memory của bạn.',
          ),
        PaywallTrigger.report => (
            title: 'Báo cáo chuyên sâu đang chờ bạn',
            sub: 'Xem đầy đủ bức tranh nghề nghiệp của bạn.',
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
        PaywallTrigger.defaultTrigger => (
            title: 'Mở khoá toàn bộ hành trình',
            sub: 'Tiếp tục phát triển không giới hạn.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final h = _headline;

    const premiumHighlights = [
      _Highlight(
        icon: '◈',
        title: 'AI Insight cá nhân hoá',
        desc: 'Phát hiện mô thức từ Career Memory của bạn. Ngày càng chính xác hơn.',
      ),
      _Highlight(
        icon: '📊',
        title: 'Báo cáo chuyên sâu',
        desc: '49 câu phân tích đầy đủ 3 chiều Sự rõ ràng · Mối quan hệ · Cách làm việc.',
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
      _FeatureRow(label: 'Báo cáo chuyên sâu 49 câu', avail: false),
      _FeatureRow(label: 'Career Pattern Analysis', avail: false),
      _FeatureRow(label: 'Career Benchmark', avail: false),
      _FeatureRow(label: 'Không giới hạn Thực hành', avail: false),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
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
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: WrColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '499.000đ / năm',
                            style: TextStyle(fontSize: 10, color: Color(0x66FFFFFF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        h.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: WrColors.white,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        h.sub,
                        style: const TextStyle(
                          fontSize: 13,
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
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF737373),
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
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF737373),
                            letterSpacing: 0.08,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: WrColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x0F000000)),
                          ),
                          child: const Column(
                            children: freeFeatures,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // CTA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thanh toán sẽ sớm ra mắt'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WrColors.coral,
                          foregroundColor: WrColors.navy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Bắt đầu Premium →',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),

                  // Guarantee
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F0),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(
                          left: BorderSide(color: Color(0xFF91A88D), width: 3),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bảo đảm hoàn tiền 7 ngày',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4A6741),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Nếu không hài lòng trong 7 ngày đầu, chúng tôi hoàn tiền toàn bộ. Không câu hỏi.',
                            style: TextStyle(fontSize: 10, color: Color(0xFF737373), height: 1.6),
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
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2F8),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  highlight.desc,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF737373), height: 1.6),
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
        border: Border(bottom: BorderSide(color: Color(0x0D000000))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: avail ? WrColors.dark : const Color(0xFF737373),
              ),
            ),
          ),
          Icon(
            avail ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: avail ? WrColors.teal : const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }
}
