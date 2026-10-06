import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

// Hệ thẻ dùng chung cho cả bốn tab. Brand identity mới, chốt với khách
// 2026-08-04, thay hệ kem-cam của bản 2026-07-30:
//
// Nền màn là XÁM #F4F4F6, thẻ nội dung là TRẮNG viền mảnh `--line`, thẻ
// "đọc chậm" vẫn là NAVY. Kem #FFF3E6 trở lại đúng một vai duy nhất của spec
// §01: CHỮ trên nền navy. Không còn mảng kem nào làm nền.
//
// ⚠ Không dựng lại thẻ kem cho một màn lẻ, và không thêm đổ bóng. Nền xám là
//   thứ làm thẻ trắng nổi lên; một màn đổi mặt phẳng là màn đó lệch hẳn khỏi
//   ba màn kia — đúng lỗi khách đã báo với hệ cũ.

class WrCardMinimal extends StatelessWidget {
  const WrCardMinimal({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WrColors.line),
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }
}

/// Thẻ navy: cùng khuôn [WrCardMinimal] nhưng đảo màu — nền navy, chữ kem.
///
/// Navy dành cho MỘT loại nội dung: câu để đọc chậm về chính người dùng —
/// "Hệ thống nhận ra", "Insight gần nhất", diễn biến theo thời gian, lời mời
/// Trà Chiều. Thẻ kem là thứ để LÀM. Màu ở đây phân biệt hai giọng đó, nên đừng
/// đổi thẻ sang navy chỉ vì muốn nó nổi hơn.
///
/// Không phải [WrCardDark]: thẻ đó vẽ thêm một vòng tròn trang trí ở góc, chỉ
/// đúng cho khối "hệ thống" của bản thiết kế cũ.
class WrCardNavy extends StatelessWidget {
  const WrCardNavy({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Thẻ luôn chiếm hết bề ngang khối chứa nó: một thẻ navy co lại theo chữ
      // sẽ lệch cạnh với thẻ kem ngay bên trên nó.
      width: double.infinity,
      decoration: BoxDecoration(
        color: WrColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }
}

class WrCardDark extends StatelessWidget {
  const WrCardDark({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: WrColors.navy,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: padding ?? const EdgeInsets.all(20),
        child: Stack(
          children: [
            // Decorative circle top-right (mirrors .card-system::before)
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WrColors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Thẻ chuẩn của mockup v47 (`.card` + `.card-pad`).
///
/// Khách 06/10: mọi danh sách đều nằm trong thẻ. Đây là thẻ dùng chung cho các
/// màn làm lại theo v47. [WrCardMinimal] giữ nguyên bo 20 / lề 20 cho các màn
/// chưa chuyển, vì nó đang nằm ở hàng chục màn khác.
class WrCard extends StatelessWidget {
  const WrCard({
    super.key,
    required this.child,
    this.padding = kPadding,
    this.dashed = false,
    this.color = WrColors.white,
    this.onTap,
  });

  /// `.card { border-radius: 18px }`
  static const kRadius = 18.0;

  /// `.card-pad { padding: 16px 18px }`
  static const kPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 16);

  /// `.card + .card { margin-top: 12px }`
  static const kGap = 12.0;

  /// `.section-gap { margin: 0 22px 14px }`
  static const kSectionPadding = EdgeInsets.fromLTRB(22, 0, 22, 14);

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Viền nét đứt: thẻ "Tự thêm", thẻ hết lượt, thẻ "Điều khác".
  final bool dashed;

  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(kRadius));
    Widget body = Padding(padding: padding, child: child);
    if (onTap != null) {
      body = Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: radius, onTap: onTap, child: body),
      );
    }
    if (dashed) {
      return CustomPaint(
        foregroundPainter: const _DashedRRectPainter(
          color: WrColors.line,
          radius: kRadius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(color: color, child: body),
        ),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: WrColors.line),
      ),
      child: body,
    );
  }
}

/// Thẻ lựa chọn (`.rf-mentor-card`): viền đậm hơn thẻ thường, chọn thì viền
/// coral và nền ửng coral.
class WrMentorCard extends StatelessWidget {
  const WrMentorCard({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  WrColors.coral.withValues(alpha: 0.045),
                  WrColors.white,
                )
              : WrColors.white,
          borderRadius: radius,
          border: Border.all(
            color: selected ? WrColors.coral : const Color(0x1F093774),
            width: 1.5,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(14), child: child),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  // Chrome vẽ `border: 1px dashed` thành gạch ~3px, hở ~3px.
  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
