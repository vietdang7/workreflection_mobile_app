// Khung chung cho mọi màn trong luồng phản tư.
//
// WXS §8.7 Focused Surface: một Meaning, một nhiệm vụ trên một màn.
// Khung này cố tình chỉ có ba chỗ: một câu hỏi, một khối nội dung, một nút.
// Không có chỗ cho thanh bên, thẻ phụ hay danh sách gợi ý.

import 'package:flutter/material.dart';

import '../../../../core/theme/wr_colors.dart';
import '../../../../core/widgets/wr_paragraph.dart';

class WrFlowScaffold extends StatelessWidget {
  const WrFlowScaffold({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.subtitle,
    this.progress,
    this.onBack,
    this.onClose,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
  });

  /// Câu hỏi hoặc lời mời — chữ lớn, là thứ đầu tiên người dùng đọc.
  final String title;

  /// Nhãn nhỏ phía trên tiêu đề.
  final String? eyebrow;

  /// Một dòng phụ, tối đa một câu. Để null nếu không thật sự cần.
  final String? subtitle;

  /// Nội dung chính — lựa chọn hoặc ô nhập.
  final Widget child;

  /// 0.0–1.0. Null = không hiện thanh tiến trình.
  final double? progress;

  final VoidCallback? onBack;
  final VoidCallback? onClose;

  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FlowHeader(
              progress: progress,
              onBack: onBack,
              onClose: onClose,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: WrColors.muted,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    WrParagraph(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.3,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 12),
                      WrParagraph(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 15.5,
                          color: WrColors.muted,
                          height: 1.55,
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                    child,
                  ],
                ),
              ),
            ),
            if (primaryLabel != null || secondaryLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  children: [
                    if (primaryLabel != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const Key('wr_flow_primary'),
                          onPressed: busy ? null : onPrimary,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WrColors.navy,
                            foregroundColor: WrColors.white,
                            disabledBackgroundColor: WrColors.line,
                            disabledForegroundColor: WrColors.muted,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: WrColors.white,
                                  ),
                                )
                              : Text(
                                  primaryLabel!,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    if (secondaryLabel != null) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        key: const Key('wr_flow_secondary'),
                        onPressed: busy ? null : onSecondary,
                        child: Text(
                          secondaryLabel!,
                          style: const TextStyle(
                            fontSize: 15.5,
                            color: WrColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({this.progress, this.onBack, this.onClose});

  final double? progress;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? null
                : IconButton(
                    key: const Key('wr_flow_back'),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: WrColors.navy,
                    onPressed: onBack,
                  ),
          ),
          Expanded(
            child: progress == null
                ? const SizedBox.shrink()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 3,
                      // Rãnh thanh tiến trình là `--line`, không phải mảng kem:
                      // kem chỉ còn dùng làm chữ trên nền navy.
                      backgroundColor: WrColors.line,
                      color: WrColors.navy,
                    ),
                  ),
          ),
          SizedBox(
            width: 44,
            child: onClose == null
                ? null
                : IconButton(
                    key: const Key('wr_flow_close'),
                    icon: const Icon(Icons.close, size: 20),
                    color: WrColors.muted,
                    onPressed: onClose,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Không còn phiên phản tư nào đang chạy — đưa người dùng về Home nhẹ nhàng.
// Xảy ra khi vào thẳng route của luồng hoặc sau khi phiên đã khép.
// ---------------------------------------------------------------------------

class WrFlowGone extends StatelessWidget {
  const WrFlowGone({super.key, required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return WrFlowScaffold(
      title: 'Phiên phản tư đã khép lại.',
      subtitle: 'Bạn có thể bắt đầu một lần nhìn lại mới bất cứ lúc nào.',
      primaryLabel: 'Về trang chủ',
      onPrimary: onHome,
      child: const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Ô chọn lớn — dùng chung cho màn năng lượng và màn Human Moment.
// ---------------------------------------------------------------------------

class WrBigChoiceTile extends StatelessWidget {
  const WrBigChoiceTile({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.height = 92,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Chiều cao TỐI THIỂU, không phải chiều cao cố định: nhãn tình huống dài hai
  /// dòng, và từ khi cỡ chữ tăng theo brand identity mới thì một ô cao cứng cắt
  /// mất dòng thứ hai. Ô nào cần cao hơn thì tự cao lên.
  final double height;

  /// Dòng chữ nhỏ phía trên nhãn. Dùng cho ô neo ở bước Notice ("Lần trước"),
  /// để người dùng nhận ra ngay đây là điều mình đã chọn lần rồi và chạm lại
  /// được — không có dấu này thì nó trông y hệt bốn gợi ý mới.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    // §03: chữ trên nền Coral là Navy, không phải trắng.
    const fg = WrColors.navy;
    final text = WrParagraph(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: fg,
      ),
      textAlign: TextAlign.start,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected ? WrColors.coral : WrColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: WrColors.line),
        ),
        child: badge == null
            ? text
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: selected
                          ? WrColors.navy.withValues(alpha: 0.75)
                          : WrColors.navy,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Flexible(child: text),
                ],
              ),
      ),
    );
  }
}
