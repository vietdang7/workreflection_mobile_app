// Minh hoạ mở đầu Home — "một chiếc ghế đang chờ bạn".
//
// Nguồn: WorkReflection_Changelog_20260824.docx §5, mockup v16 `HERO_SCENES`.
//
// Bốn bản cùng MỘT bố cục (cửa sổ, ghế, bàn, đèn bàn, sàn) — chỉ ánh sáng và
// tông màu đổi theo khung giờ. Cùng một khung hình ở bốn thời điểm chính là ý
// đồ: nó phải đọc ra như "vẫn chỗ ngồi ấy, giờ đã khác", không phải bốn bức
// tranh rời.
//
// ---------------------------------------------------------------------------
// Vì sao vẽ tay bằng CustomPainter chứ không nhúng SVG
// ---------------------------------------------------------------------------
//
// Mockup viết bằng SVG, nhưng dự án không có `flutter_svg` và bốn hình này chỉ
// gồm hình chữ nhật, đường thẳng, hình tròn và một đa giác. Thêm một phụ thuộc
// (kèm phần đọc/parse XML lúc chạy) cho ngần ấy hình là cái giá không đáng, và
// còn phải bundle bốn chuỗi SVG vào assets.
//
// Toạ độ giữ NGUYÊN hệ 335×170 của mockup và được co giãn ở [paint], nên đối
// chiếu từng con số với file HTML vẫn đọc thẳng được.
//
// ---------------------------------------------------------------------------
// Không có nút xem trước
// ---------------------------------------------------------------------------
//
// §5, ghi chú cho dev: "Đã thêm dãy nút Sáng / Chiều / Tối / Khuya ngay dưới
// ảnh để xem trước thủ công — đây CHỈ phục vụ demo, không nên đưa vào bản thật.
// Bản thật chỉ cần giữ logic tự động theo getDayPeriod()." Trường `heroPreview`
// trong phụ lục state của changelog cũng chỉ tồn tại cho dãy nút đó.
//
// [WrHeroScene.period] vẫn nhận tham số, nhưng để TEST chụp được cả bốn khung
// giờ mà không phải đổi đồng hồ hệ thống — không có màn nào cho người dùng đổi.

import 'package:flutter/material.dart';

/// Bốn khung giờ của §5.
enum WrDayPeriod {
  morning,
  afternoon,
  evening,
  latenight;

  /// Khung giờ ứng với [hour] (0–23), nguyên văn `getDayPeriod()` của mockup:
  /// 5h–11h sáng · 11h–18h chiều · 18h–22h tối · còn lại khuya.
  ///
  /// Nhận [hour] thay vì tự gọi `DateTime.now()`: hàm này phải kiểm được bằng
  /// test ở cả bốn nhánh, kể cả nhánh khuya vắt qua nửa đêm.
  static WrDayPeriod fromHour(int hour) {
    if (hour >= 5 && hour < 11) return WrDayPeriod.morning;
    if (hour >= 11 && hour < 18) return WrDayPeriod.afternoon;
    if (hour >= 18 && hour < 22) return WrDayPeriod.evening;
    return WrDayPeriod.latenight;
  }
}

/// Bảng màu của một khung giờ.
///
/// Chỉ dùng đúng ba màu brand (Navy, Coral, Cream) trên hai nền sáng/tối, và
/// KHÔNG có gradient nào — §5 nói rõ điều này.
class _SceneTheme {
  const _SceneTheme({
    required this.background,
    required this.ink,
    required this.inkOpacity,
    required this.sun,
    required this.sunCenter,
    required this.sunRadius,
    this.sunGlow,
    this.stars = const [],
    this.lampGlow = false,
    this.hasLampShade = true,
    this.floorOpacity = 0.15,
  });

  /// Nền cả khung.
  final Color background;

  /// Màu nét vẽ — Navy trên nền sáng, Cream trên nền tối.
  final Color ink;

  /// Độ đậm của nét. Bản khuya mờ hẳn đi: đêm muộn thì mọi thứ bớt rõ.
  final double inkOpacity;

  /// Mặt trời (sáng/chiều) hoặc mặt trăng (tối/khuya).
  final Color sun;
  final Offset sunCenter;
  final double sunRadius;

  /// Vệt nắng đổ xuống sàn — tam giác từ mặt trời. Null với hai bản đêm.
  final ({Offset a, Offset b, Offset c, double opacity})? sunGlow;

  /// Sao trên cửa sổ.
  final List<Offset> stars;

  /// Quầng sáng ấm quanh ghế — chỉ bản tối, khi đèn bàn là nguồn sáng duy nhất.
  final bool lampGlow;

  /// Chao đèn bàn. Bản khuya tắt đèn nên không vẽ.
  final bool hasLampShade;

  final double floorOpacity;
}

const Color _kNavy = Color(0xFF093774);
const Color _kCoral = Color(0xFFFF6859);
const Color _kCream = Color(0xFFFFF3E6);

const Map<WrDayPeriod, _SceneTheme> _kThemes = {
  // Sáng: nắng xiên từ trái, nền kem ấm.
  WrDayPeriod.morning: _SceneTheme(
    background: _kCream,
    ink: _kNavy,
    inkOpacity: 1,
    sun: _kCoral,
    sunCenter: Offset(145, 34),
    sunRadius: 9,
    sunGlow: (
      a: Offset(145, 34),
      b: Offset(60, 158),
      c: Offset(250, 158),
      opacity: 0.06,
    ),
  ),
  // Chiều: nắng chếch sang phải, gắt hơn, nền ngả vàng.
  WrDayPeriod.afternoon: _SceneTheme(
    background: Color(0xFFF3E9D6),
    ink: _kNavy,
    inkOpacity: 1,
    sun: _kCoral,
    sunCenter: Offset(196, 32),
    sunRadius: 11,
    sunGlow: (
      a: Offset(196, 32),
      b: Offset(90, 158),
      c: Offset(290, 158),
      opacity: 0.08,
    ),
  ),
  // Tối: nền xanh đêm, trăng và sao, đèn bàn hắt quầng ấm xuống ghế.
  WrDayPeriod.evening: _SceneTheme(
    background: Color(0xFF2C335D),
    ink: _kCream,
    inkOpacity: 1,
    sun: _kCream,
    sunCenter: Offset(195, 32),
    sunRadius: 10,
    stars: [Offset(140, 30), Offset(150, 52), Offset(133, 46)],
    lampGlow: true,
  ),
  // Khuya: nền tối hơn nữa, nét mờ đi, đèn bàn đã tắt.
  WrDayPeriod.latenight: _SceneTheme(
    background: Color(0xFF1B2044),
    ink: _kCream,
    inkOpacity: 0.55,
    sun: _kCream,
    sunCenter: Offset(145, 34),
    sunRadius: 8,
    stars: [Offset(200, 52), Offset(205, 30)],
    hasLampShade: false,
    floorOpacity: 0.12,
  ),
};

/// Minh hoạ mở đầu Home. Tỉ lệ khung cố định 335:170 như mockup.
class WrHeroScene extends StatelessWidget {
  const WrHeroScene({super.key, required this.period});

  /// Khung giờ đang hiển thị. Home truyền [WrDayPeriod.fromHour] của giờ hệ
  /// thống; test truyền thẳng để chụp đủ bốn bản.
  final WrDayPeriod period;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 335 / 170,
        child: CustomPaint(
          key: Key('wr_hero_scene_${period.name}'),
          painter: _HeroScenePainter(_kThemes[period]!),
          // Người dùng dùng trình đọc màn hình vẫn phải biết đây là gì. Một
          // hình trang trí không tên thì với họ màn Home mở đầu bằng khoảng
          // trống.
          child: Semantics(
            label: 'Minh hoạ: một chỗ ngồi đang chờ bạn',
            image: true,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _HeroScenePainter extends CustomPainter {
  const _HeroScenePainter(this.theme);

  final _SceneTheme theme;

  /// Hệ toạ độ gốc của mockup. Mọi con số dưới đây đọc thẳng được từ
  /// `HERO_SCENES` trong file HTML.
  static const double _w = 335;
  static const double _h = 170;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _w, size.height / _h);

    final ink = theme.ink.withValues(alpha: theme.inkOpacity);

    Paint fill(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.fill;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    // Nền.
    canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), fill(theme.background));

    // ── Cửa sổ: khung 90×56, một nẹp dọc và một nẹp ngang ─────────────────
    final windowInk = theme.ink.withValues(
      alpha: theme.inkOpacity * (theme.hasLampShade ? 1 : 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(127, 20, 90, 56),
        const Radius.circular(3),
      ),
      stroke(windowInk, 1.2),
    );
    canvas.drawLine(
      const Offset(172, 20),
      const Offset(172, 76),
      stroke(windowInk, 0.8),
    );
    canvas.drawLine(
      const Offset(127, 48),
      const Offset(217, 48),
      stroke(windowInk, 0.8),
    );

    // ── Mặt trời hoặc mặt trăng, và vệt nắng ──────────────────────────────
    canvas.drawCircle(
      theme.sunCenter,
      theme.sunRadius,
      fill(theme.sun.withValues(
        alpha: theme.hasLampShade ? 1 : 0.6,
      )),
    );
    for (final s in theme.stars) {
      canvas.drawCircle(
        s,
        theme.hasLampShade ? 1.4 : 1.2,
        fill(theme.sun.withValues(alpha: theme.hasLampShade ? 1 : 0.6)),
      );
    }
    final glow = theme.sunGlow;
    if (glow != null) {
      final path = Path()
        ..moveTo(glow.a.dx, glow.a.dy)
        ..lineTo(glow.b.dx, glow.b.dy)
        ..lineTo(glow.c.dx, glow.c.dy)
        ..close();
      canvas.drawPath(path, fill(_kCoral.withValues(alpha: glow.opacity)));
    }
    // Quầng đèn bàn hắt xuống ghế — chỉ bản tối.
    if (theme.lampGlow) {
      canvas.drawCircle(
        const Offset(118, 140),
        30,
        fill(_kCoral.withValues(alpha: 0.16)),
      );
    }

    // ── Chiếc ghế: mặt ghế, lưng tựa, hai chân ────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(100, 126, 44, 9),
        const Radius.circular(4),
      ),
      fill(ink),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(108, 78, 28, 52),
        const Radius.circular(6),
      ),
      fill(ink),
    );
    canvas.drawLine(
      const Offset(106, 135),
      const Offset(106, 158),
      stroke(ink, 2.2),
    );
    canvas.drawLine(
      const Offset(138, 135),
      const Offset(138, 158),
      stroke(ink, 2.2),
    );

    // ── Bàn làm việc và đèn bàn ───────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(160, 104, 52, 8),
        const Radius.circular(2),
      ),
      fill(ink),
    );
    if (theme.hasLampShade) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(170, 92, 32, 8),
          const Radius.circular(2),
        ),
        fill(ink),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(176, 78, 20, 14),
          const Radius.circular(2),
        ),
        stroke(ink, 1.2),
      );
    }
    canvas.drawLine(
      const Offset(168, 112),
      const Offset(168, 158),
      stroke(ink, 2),
    );
    canvas.drawLine(
      const Offset(204, 112),
      const Offset(204, 158),
      stroke(ink, 2),
    );

    // ── Sàn ───────────────────────────────────────────────────────────────
    canvas.drawRect(
      const Rect.fromLTWH(60, 158, 210, 3),
      fill(theme.ink.withValues(alpha: theme.floorOpacity)),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroScenePainter oldDelegate) =>
      oldDelegate.theme != theme;
}
