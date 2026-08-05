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
