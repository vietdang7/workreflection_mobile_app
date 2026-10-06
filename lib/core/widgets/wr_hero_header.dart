// Hero đầu màn theo mockup v47 (06/10): `.hero2`, `.onb-hero`, `.rf-band`.
//
// Ảnh nằm ở `assets/images/hero/*.webp`, xuất từ chính SVG của mockup bằng
// `tool/render_mockup_heroes.mjs`. SVG đó dùng feTurbulence/feGaussianBlur nên
// không vẽ lại được bằng flutter_svg hay CustomPainter cho giống.
//
// Ảnh là phần vẽ GỐC. Lớp mờ hai mép (`mask-image` trong CSS) do widget này
// phủ, nên chỉnh độ mờ không phải xuất lại ảnh.
//
// Khách 06/10: "chữ trên hero phải đọc rõ". Ở hai khung giờ tối, mép trên của
// ảnh KHÔNG mờ đi: chữ màu kem nằm đúng mép đó, mờ ra nền xám sáng là mất chữ.
// Ở các ảnh sáng, sau khối chữ có một quầng trắng như `.inner-landscape`.

import 'package:flutter/material.dart';

import '../theme/wr_colors.dart';
import 'wr_hero_scene.dart' show WrDayPeriod;

export 'wr_hero_scene.dart' show WrDayPeriod;

/// Ảnh hero của ba tab trong (`HERO_ART` của mockup).
enum WrHeroArt {
  understand,
  act,
  grow;

  String get asset => 'assets/images/hero/inner_$name.webp';
}

/// Ảnh thành phố của Home theo khung giờ (`cityHero(period)`).
String wrCityHeroAsset(WrDayPeriod period) =>
    'assets/images/hero/city_${period.name}.webp';

/// Tối và khuya là hai ảnh nền tối, chữ phải chuyển sang màu kem.
bool wrIsDarkPeriod(WrDayPeriod period) =>
    period == WrDayPeriod.evening || period == WrDayPeriod.latenight;

/// Màu của khung trạng thái khi ảnh tối nằm sau nó
/// (`.screen:has(.onb-hero.p-evening) .statusbar`).
Color? wrDarkPeriodTop(WrDayPeriod period) => switch (period) {
  WrDayPeriod.evening => const Color(0xFF2C335D),
  WrDayPeriod.latenight => const Color(0xFF121633),
  _ => null,
};

/// Ảnh hero kèm lớp mờ mép. Không có chữ.
///
/// Dùng riêng ở Onboarding (`.onb-hero`, cao 292). Các tab dùng [WrHeroHeader].
class WrHeroBackdrop extends StatelessWidget {
  const WrHeroBackdrop({
    super.key,
    required this.asset,
    this.alignment = Alignment.bottomCenter,
    this.fadeTop = true,
    this.fadeStops = const [0, 0.16, 0.76, 1],
    this.landscapeTint = false,
  });

  final String asset;

  /// Ảnh được cắt kiểu `slice` của SVG. Thành phố bám phải
  /// (`xMaxYMid`), tranh phong cảnh bám đáy (`xMidYMax`).
  final Alignment alignment;

  /// Mờ dần ở mép trên. Tắt cho ảnh tối để chữ kem không rơi lên nền sáng.
  final bool fadeTop;

  /// Bốn mốc của `mask-image: linear-gradient(...)`.
  final List<double> fadeStops;

  /// Hai quầng màu coral/teal của `.hero2.inner-landscape::after`.
  final bool landscapeTint;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      // Ảnh trang trí, trình đọc màn hình bỏ qua.
      excludeFromSemantics: true,
      gaplessPlayback: true,
      // Test widget không nạp asset thật. Thiếu ảnh thì để trống chứ không
      // làm đổ cả màn.
      errorBuilder: (_, _, _) => const SizedBox.expand(),
    );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                fadeTop ? Colors.transparent : Colors.black,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: fadeStops,
            ).createShader(rect),
            child: image,
          ),
          if (landscapeTint) ...const [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.52, -0.34),
                  radius: 0.75,
                  colors: [
                    Color(0x1FFF6859),
                    Color(0x09FF6859),
                    Color(0x00FF6859),
                  ],
                  stops: [0, 0.52, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.64, 0.44),
                  radius: 0.78,
                  colors: [
                    Color(0x1A15B5B0),
                    Color(0x0715B5B0),
                    Color(0x0015B5B0),
                  ],
                  stops: [0, 0.54, 1],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Đầu màn của bốn tab: ảnh tràn viền + eyebrow / tiêu đề / mô tả + avatar.
///
/// Ảnh tràn lên cả vùng thanh trạng thái, chữ bắt đầu ngay dưới nó (khách
/// 06/10: "tiêu đề đẩy lên trên, không để khoảng trắng thừa"). Vì vậy màn dùng
/// widget này KHÔNG bọc `SafeArea` ở trên.
///
/// Đặt trong `ListView` thì phải truyền `padding: EdgeInsets.zero` (hoặc một
/// padding tường minh): `ListView` không có padding sẽ tự cộng phần thanh
/// trạng thái rồi xoá nó khỏi `MediaQuery` của con, ảnh sẽ không tràn lên.
class WrHeroHeader extends StatelessWidget {
  const WrHeroHeader({
    super.key,
    required this.asset,
    required this.title,
    this.eyebrow,
    this.overline,
    this.subtitle,
    this.trailing,
    this.dark = false,
    this.alignment = Alignment.bottomCenter,
    this.landscape = true,
    bool? glow,
    this.height = kHeight,
  }) : glow = glow ?? landscape;

  /// Home tạo hero theo khung giờ.
  factory WrHeroHeader.city({
    Key? key,
    required WrDayPeriod period,
    required String title,
    String? overline,
    String? subtitle,
    Widget? trailing,
  }) => WrHeroHeader(
    key: key,
    asset: wrCityHeroAsset(period),
    title: title,
    overline: overline,
    subtitle: subtitle,
    trailing: trailing,
    dark: wrIsDarkPeriod(period),
    alignment: Alignment.centerRight,
    landscape: false,
    // Ảnh sáng/chiều có nhà cao tầng ngay sau dòng chữ phụ: cần quầng trắng
    // để chữ đọc được (ảnh soi M3, khổ 393pt).
    glow: true,
  );

  /// Ba tab trong: Hiểu mình, Phát triển, Hành trình.
  factory WrHeroHeader.inner({
    Key? key,
    required WrHeroArt art,
    required String eyebrow,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) => WrHeroHeader(
    key: key,
    asset: art.asset,
    eyebrow: eyebrow,
    title: title,
    subtitle: subtitle,
    trailing: trailing,
  );

  /// `.hero2 { height: 250px }`, chưa tính thanh trạng thái. Bốn tab dùng
  /// chung một chiều cao để chuyển tab không bị giật.
  static const kHeight = 250.0;

  final String asset;
  final String title;

  /// Dòng chữ hoa nhỏ phía trên tiêu đề (`.eyebrow`).
  final String? eyebrow;

  /// Dòng `.tiny` phía trên tiêu đề, không viết hoa. Home dùng cho ngày.
  final String? overline;

  /// `.hero-copy2`.
  final String? subtitle;

  /// Thường là `WrProfileAvatar`.
  final Widget? trailing;

  /// Ảnh nền tối → chữ kem, mép trên không mờ.
  final bool dark;

  final Alignment alignment;

  /// Thêm quầng màu và quầng trắng sau chữ như `.inner-landscape`.
  final bool landscape;

  /// Quầng trắng sau khối chữ (bỏ qua khi ảnh tối). Mặc định theo [landscape].
  final bool glow;

  final double height;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final titleColor = dark ? WrColors.cream : WrColors.navy;
    final copyColor = dark
        ? WrColors.cream.withValues(alpha: 0.78)
        : const Color(0xA82C335D);
    final smallColor = dark
        ? WrColors.cream.withValues(alpha: 0.62)
        : WrColors.text3;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: smallColor,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (overline != null) ...[
          Text(overline!, style: TextStyle(fontSize: 12.5, color: smallColor)),
          const SizedBox(height: 3),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: titleColor,
            height: 1.32,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 275),
            child: Text(
              subtitle!,
              style: TextStyle(fontSize: 14.5, color: copyColor, height: 1.55),
            ),
          ),
        ],
      ],
    );

    return SizedBox(
      height: height + top,
      child: Stack(
        children: [
          Positioned.fill(
            child: WrHeroBackdrop(
              asset: asset,
              alignment: alignment,
              fadeTop: !dark,
              landscapeTint: landscape,
            ),
          ),
          Padding(
            // `.topbar { padding: 8px 22px 14px }`
            padding: EdgeInsets.fromLTRB(22, top + 8, 22, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Quầng trắng sau khối chữ: `.topbar > div::after`.
                      if (glow && !dark)
                        const Positioned(
                          left: -10,
                          top: -10,
                          right: -10,
                          bottom: -10,
                          child: IgnorePointer(
                            child: SizedBox(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(72),
                                  ),
                                  gradient: RadialGradient(
                                    center: Alignment(-0.5, -0.5),
                                    // CSS lấy bán kính tới góc xa nhất
                                    // (≈217px); Flutter tính theo cạnh ngắn
                                    // 144px.
                                    radius: 1.5,
                                    colors: [
                                      Color(0xA8FFFFFF),
                                      Color(0x29FFFFFF),
                                      Color(0x00FFFFFF),
                                    ],
                                    stops: [0, 0.5, 0.74],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      copy,
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bảng màu theo cảm xúc (`RF_PAL`): [trời, mặt trời, núi xa, núi gần, chấm].
///
/// Màu thứ năm là chấm màu cạnh tên cảm xúc (`.mood-chip i`, `.mood-row i`).
abstract final class WrMoodPalette {
  static const _pal = <String, List<Color>>{
    'happy': [
      Color(0xFFFFE3D4),
      Color(0xFFFBBFA6),
      Color(0xFFB9CCE2),
      Color(0xFFF6D3C3),
      Color(0xFFF08F76),
    ],
    'ok': [
      Color(0xFFE3F2EC),
      Color(0xFFBFE6DA),
      Color(0xFFB5CFDD),
      Color(0xFFD5EAE2),
      Color(0xFF4FB59B),
    ],
    'stress': [
      Color(0xFFE4E9F0),
      Color(0xFFC9D3E3),
      Color(0xFF9FB1C9),
      Color(0xFFC3CFDF),
      Color(0xFF6F86AD),
    ],
    'tired': [
      Color(0xFFE9E6F3),
      Color(0xFFD8D0EC),
      Color(0xFFA9B4D6),
      Color(0xFFCEC9E6),
      Color(0xFF8C84C4),
    ],
    'foggy': [
      Color(0xFFEEF0F3),
      Color(0xFFD9DFE6),
      Color(0xFFBCC7D4),
      Color(0xFFDCE2E9),
      Color(0xFF8FA0B3),
    ],
    'outofsync': [
      Color(0xFFF3E8E4),
      Color(0xFFF1C9BC),
      Color(0xFFA8B8CE),
      Color(0xFFE5D4D0),
      Color(0xFFD48E7E),
    ],
  };

  /// Sáu mã cảm xúc có ảnh dải. Trùng `id` của `kCheckinOptions`.
  static Iterable<String> get moods => _pal.keys;

  /// Mã lạ rơi về `happy`, giống `rfPal` của mockup.
  static String normalize(String? mood) =>
      _pal.containsKey(mood) ? mood! : 'happy';

  static List<Color> of(String? mood) => _pal[normalize(mood)]!;

  /// Chấm màu cạnh tên cảm xúc.
  static Color dot(String? mood) => of(mood)[4];
}

/// Dải phong cảnh 150px ở đầu các màn con (`.rf-band`), màu theo cảm xúc.
///
/// Đặt ở lớp dưới cùng của một `Stack`, nội dung màn nằm đè lên.
class WrReflectBand extends StatelessWidget {
  const WrReflectBand({super.key, required this.mood, this.height = kHeight});

  static const kHeight = 150.0;

  final String? mood;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key('wr_reflect_band_${WrMoodPalette.normalize(mood)}'),
      height: height + MediaQuery.paddingOf(context).top,
      width: double.infinity,
      child: WrHeroBackdrop(
        asset: 'assets/images/hero/band_${WrMoodPalette.normalize(mood)}.webp',
        alignment: Alignment.topCenter,
        // `.rf-band { mask-image: ... 0, 14%, 52%, 100% }`
        fadeStops: const [0, 0.14, 0.52, 1],
      ),
    );
  }
}
