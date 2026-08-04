import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/wr_colors.dart';

/// Logo WorkReflection — biểu tượng khung ngắm + chữ.
///
/// Dựng theo đúng file logo chuẩn (bản khách gửi 2026-08-03):
///
///   • Khung ngắm: nét TRÊN (góc trên-trái, cạnh trên, góc trên-phải) màu Navy,
///     nét DƯỚI (góc dưới-phải, cạnh dưới, góc dưới-trái) màu Coral. Hai nét
///     dọc hở ở khoảng giữa — đây là một khung ngắm, không phải một hình chữ
///     nhật liền.
///   • Giữa khung: hai vòng hở lồng vào nhau, vòng TRÁI Coral (hở về phía
///     trên-phải), vòng PHẢI Navy (hở về phía dưới-trái).
///   • Chữ: **hai dòng** xếp chồng, canh trái — "WORK" **Coral** ở trên,
///     "REFLECTION" **Navy** ở dưới, viết HOA, cùng cỡ và cùng độ đậm.
///
/// Bản trước đảo ngược màu chữ ("Work" navy + "Reflection" coral), viết
/// thường, và phần biểu tượng là hai dấu ngoặc lệch cùng hai chấm tròn đặc,
/// không phải khung ngắm và không phải hai vòng lồng. Bản sau đó sửa màu và
/// biểu tượng nhưng vẫn đặt hai từ trong MỘT `RichText` liền nhau, nên nó ra
/// một dòng dính liền "WORKREFLECTION".
class WrLogo extends StatelessWidget {
  const WrLogo({super.key, this.width = 160});

  final double width;

  @override
  Widget build(BuildContext context) {
    // Tỉ lệ đo trên chính file logo chuẩn (1024×258): khung ngắm chiếm ~33%
    // chiều ngang, khoảng cách sang chữ ~4.5%, thân chữ cao ~8.4%.
    final markSize = width * 0.225;
    final fontSize = width * 0.086;

    final wordStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.12,
      letterSpacing: -0.2,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          // Khung ngắm của bản chuẩn rộng hơn cao (~1.45:1), không phải vuông.
          width: markSize * 1.45,
          height: markSize,
          child: CustomPaint(painter: _WrMarkPainter()),
        ),
        SizedBox(width: width * 0.045),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WORK', style: wordStyle.copyWith(color: WrColors.coral)),
            Text(
              'REFLECTION',
              style: wordStyle.copyWith(color: WrColors.navy),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vẽ biểu tượng: khung ngắm hai nửa + hai vòng hở lồng nhau.
class _WrMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeW = h * 0.10;
    // Bo góc nhỏ (đo trên bản chuẩn ~0.15h). Để 0.20 thì bốn góc tròn quá, ra
    // một hình chữ nhật bo tròn có hai khe hở chứ không còn đọc ra khung ngắm.
    final corner = h * 0.15;

    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Mép khung, đã trừ nửa nét để nét không bị cắt ở rìa canvas.
    final left = strokeW / 2;
    final right = w - strokeW / 2;
    final top = strokeW / 2;
    final bottom = h - strokeW / 2;

    // Nét dọc dừng ở đây, chừa khoảng hở giữa hai nửa khung.
    final upperStop = h * 0.40;
    final lowerStop = h * 0.60;

    // ── Nửa trên (Navy): ⊓ ────────────────────────────────────────────────
    final upper = Path()
      ..moveTo(left, upperStop)
      ..lineTo(left, top + corner)
      ..arcToPoint(
        Offset(left + corner, top),
        radius: Radius.circular(corner),
        clockwise: true,
      )
      ..lineTo(right - corner, top)
      ..arcToPoint(
        Offset(right, top + corner),
        radius: Radius.circular(corner),
        clockwise: true,
      )
      ..lineTo(right, upperStop);
    canvas.drawPath(upper, stroke(WrColors.navy));

    // ── Nửa dưới (Coral): ⊔ ───────────────────────────────────────────────
    final lower = Path()
      ..moveTo(right, lowerStop)
      ..lineTo(right, bottom - corner)
      ..arcToPoint(
        Offset(right - corner, bottom),
        radius: Radius.circular(corner),
        clockwise: true,
      )
      ..lineTo(left + corner, bottom)
      ..arcToPoint(
        Offset(left, bottom - corner),
        radius: Radius.circular(corner),
        clockwise: true,
      )
      ..lineTo(left, lowerStop);
    canvas.drawPath(lower, stroke(WrColors.coral));

    // ── Hai vòng hở lồng nhau ─────────────────────────────────────────────
    //
    // Mỗi vòng quét 290°, phần hở của vòng này quay về phía vòng kia nên hai
    // vòng đan vào nhau thay vì chỉ chồng lên.
    final radius = h * 0.235;
    const sweep = 290 * math.pi / 180;

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(w * 0.40, h * 0.5),
        radius: radius,
      ),
      // Hở về hướng trên-phải.
      -35 * math.pi / 180,
      sweep,
      false,
      stroke(WrColors.coral),
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(w * 0.63, h * 0.5),
        radius: radius,
      ),
      // Hở về hướng dưới-trái.
      145 * math.pi / 180,
      sweep,
      false,
      stroke(WrColors.navy),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
