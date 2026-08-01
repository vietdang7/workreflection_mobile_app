import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

// Hệ thẻ dùng chung cho cả bốn tab (chốt với khách 2026-07-30).
//
// Nền màn là TRẮNG, thẻ nội dung là KEM, thẻ "đọc chậm" là NAVY, ô lồng trong
// thẻ kem thì trắng. Mockup Sprint 2 dùng hệ ngược lại — nền kem #FBF9F5, thẻ
// trắng viền mảnh — và bản đó đã bị bỏ: khách chốt lấy bố cục Sprint 2 nhưng
// giữ hệ màu kem-cam của `giao-dien-chinh.html`.
//
// ⚠ Không dựng lại thẻ trắng-viền-mảnh cho một màn lẻ. Thẻ trắng trên nền trắng
//   chỉ còn thấy được nhờ viền, nên một màn đổi là màn đó lệch hẳn khỏi ba màn
//   kia — đúng lỗi khách đã báo.

class WrCardMinimal extends StatelessWidget {
  const WrCardMinimal({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.cream,
        borderRadius: BorderRadius.circular(20),
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
