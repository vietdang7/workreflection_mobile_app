// Hero đầu màn theo mockup v55 Watercolor (09/10): `.hero2`, `.onb-hero`,
// `.rf-band`.
//
// v55 thay toàn bộ tranh SVG (thành phố theo khung giờ, phong cảnh ba tab,
// dải theo cảm xúc) bằng ảnh màu nước khách gửi ở `hero_assets/`. Ảnh KHÔNG
// chứa chữ, mọi chữ do app vẽ đè lên. Ảnh nằm ở `assets/images/hero/`:
//
//   hero_homnay / hero_hieu / hero_phat / hero_hanh   hero bốn tab + onboarding
//   band_a / band_b                                   dải đầu màn con
//
// Chữ đọc được là nhờ lớp phủ kem (`.hero-scrim`), không nhờ ảnh. Đổi ảnh thì
// chỉ thay file, không đụng lớp phủ.

import 'package:flutter/material.dart';

import '../theme/wr_colors.dart';
import 'wr_paragraph.dart';

/// Ảnh hero của bốn tab (`HERO_PHOTO` + `TAB_PHOTO` của mockup v55).
enum WrHeroArt {
  home('homnay'),
  understand('hieu'),
  act('phat'),
  grow('hanh');

  const WrHeroArt(this._file);

  final String _file;

  String get asset => 'assets/images/hero/hero_$_file.webp';
}

/// `.hero-photo { background-position: 18% 62% }`: neo trái-dưới để giữ bàn
/// và cửa sổ khi ảnh bị cắt.
const kWrHeroPhotoAlignment = Alignment(-0.64, 0.24);

/// `.onb-hero .hero-photo { background-position: 18% 58% }`.
const kWrOnboardingPhotoAlignment = Alignment(-0.64, 0.16);

/// `.hero-scrim`: lớp phủ kem bắt buộc, đậm ở trên (chỗ chữ) và trong dần
/// xuống dưới.
const kWrHeroScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xF7FFF7EE), // .97
    Color(0xEDFFF7EE), // .93
    Color(0x8AFFF7EE), // .54
    Color(0x14FFF7EE), // .08
  ],
  stops: [0, 0.44, 0.72, 1],
);

/// `.onb-hero-fade`: mờ nhẹ ở trên, đặc dần ở dưới để nối vào phần chữ. Mockup
/// kết thúc bằng `--cream`; app kết thúc bằng màu nền màn để không lộ mép.
const kWrOnboardingFade = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x57FFF7EE), // .34
    Color(0x1AFFF7EE), // .10
    Color(0x9EFFF7EE), // .62
    WrColors.pageBg,
  ],
  stops: [0, 0.34, 0.80, 1],
);

/// Ảnh hero kèm lớp phủ. Không có chữ.
///
/// Dùng riêng ở Onboarding (`.onb-hero`). Các tab dùng [WrHeroHeader].
class WrHeroBackdrop extends StatelessWidget {
  const WrHeroBackdrop({
    super.key,
    required this.asset,
    this.alignment = kWrHeroPhotoAlignment,
    this.overlay = kWrHeroScrim,
    this.landscapeTint = false,
  });

  final String asset;

  /// `background-size: cover` kèm `background-position`.
  final Alignment alignment;

  /// Lớp phủ ngay trên ảnh (`.hero-scrim` hoặc `.onb-hero-fade`).
  final Gradient overlay;

  /// Hai quầng màu coral/teal của `.hero2.inner-landscape::after`.
  final bool landscapeTint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: alignment,
            width: double.infinity,
            height: double.infinity,
            // Ảnh trang trí, trình đọc màn hình bỏ qua.
            excludeFromSemantics: true,
            gaplessPlayback: true,
            // Test widget không nạp asset thật. Thiếu ảnh thì để trống chứ
            // không làm đổ cả màn.
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          ),
          DecoratedBox(decoration: BoxDecoration(gradient: overlay)),
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
    this.landscape = true,
    this.height = kHeight,
  });

  /// Home (`.hero2.home2`): chỉ có ảnh và lớp phủ, không quầng màu, không
  /// quầng trắng sau chữ. v55 bỏ hero theo khung giờ, cả ngày một ảnh.
  factory WrHeroHeader.home({
    Key? key,
    required String title,
    String? overline,
    String? subtitle,
    Widget? trailing,
  }) => WrHeroHeader(
    key: key,
    asset: WrHeroArt.home.asset,
    title: title,
    overline: overline,
    subtitle: subtitle,
    trailing: trailing,
    landscape: false,
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

  /// Chiều cao hero, chưa tính thanh trạng thái. Bốn tab dùng chung một chiều
  /// cao để chuyển tab không bị giật.
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

  /// `.inner-landscape`: hai quầng màu trên ảnh và quầng trắng sau khối chữ.
  final bool landscape;

  final double height;

  // Chữ đặt trên ảnh phải đậm hơn chữ trên nền phẳng (mockup v55 đo trên
  // chính ảnh): `.hero2 .hero-copy2` .94, `.hero2 .tiny` .80, `.eyebrow` .74.
  static const _copyColor = Color(0xF02C335D);
  static const _overlineColor = Color(0xCC2C335D);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: WrColors.eyebrow,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (overline != null) ...[
          Text(
            overline!,
            style: const TextStyle(fontSize: 12.5, color: _overlineColor),
          ),
          const SizedBox(height: 3),
        ],
        // Từ ghép không rớt nửa xuống dòng dưới (họp khách 08/10).
        Text(
          wrKeepCompounds(title),
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: WrColors.navy,
            height: 1.32,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 275),
            child: Text(
              wrKeepWords(subtitle!),
              style: const TextStyle(
                fontSize: 14.5,
                color: _copyColor,
                height: 1.55,
              ),
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
            child: WrHeroBackdrop(asset: asset, landscapeTint: landscape),
          ),
          // Đáy ảnh tan vào màu nền màn. Thiếu lớp này thì ảnh (đáy lớp phủ
          // chỉ còn .08) đứt ngang thành một đường kẻ với phần bên dưới
          // (người dùng chụp 09/10).
          const Positioned.fill(child: IgnorePointer(child: _HeroBottomFade())),
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
                      // Quầng trắng sau khối chữ:
                      // `.inner-landscape .topbar > div::after`.
                      if (landscape)
                        const Positioned(
                          left: -10,
                          top: -10,
                          right: -10,
                          bottom: -10,
                          child: IgnorePointer(
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

/// Ảnh hero mờ dần vào [WrColors.pageBg] ở phần ba dưới cùng.
class _HeroBottomFade extends StatelessWidget {
  const _HeroBottomFade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00F4F4F6), Color(0x99F4F4F6), WrColors.pageBg],
          stops: [0.62, 0.86, 1],
        ),
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

/// Dải ảnh ở đầu các màn con (`.rf-band` của mockup v55).
///
/// Một lớp ảnh thật (`band_a` cho căng thẳng / mơ hồ / khá ổn, `band_b` cho
/// các cảm xúc còn lại) + một lớp phủ rất nhẹ mang màu cảm xúc, để người dùng
/// vẫn nhận ra mình đang ở trạng thái nào. Truyền [asset] thì dùng ảnh đó và
/// bỏ lớp màu cảm xúc (Onboarding bước 3–4 dùng ảnh hero của tab).
///
/// Đặt ở lớp dưới cùng của một `Stack`, nội dung màn nằm đè lên.
class WrReflectBand extends StatelessWidget {
  const WrReflectBand({
    super.key,
    required this.mood,
    this.asset,
    this.height = kHeight,
  });

  /// `.rf-band { height: 112px }`, chưa tính thanh trạng thái: ảnh đã mờ hết
  /// trước khi chạm vào nhãn và tiêu đề bên dưới.
  static const kHeight = 112.0;

  final String? mood;
  final String? asset;
  final double height;

  /// `BAND_PHOTO[['stress','foggy','ok'].includes(id) ? 'a' : 'b']`.
  static String assetFor(String? mood) {
    final m = WrMoodPalette.normalize(mood);
    final key = const {'stress', 'foggy', 'ok'}.contains(m) ? 'a' : 'b';
    return 'assets/images/hero/band_$key.webp';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final total = height + top;
    // `mask-image: linear-gradient(transparent 0, #000 10%, #000 34%,
    // transparent 100%)`, tính trên phần dải dưới thanh trạng thái.
    double at(double f) => (top + height * f) / total;
    final pal = WrMoodPalette.of(mood);
    final sky = pal[0];
    final sun = pal[1];
    return SizedBox(
      key: Key('wr_reflect_band_${WrMoodPalette.normalize(mood)}'),
      height: total,
      width: double.infinity,
      child: IgnorePointer(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, at(0.10), at(0.34), 1],
          ).createShader(rect),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset ?? assetFor(mood),
                fit: BoxFit.cover,
                // `.rf-band-photo { background-position: 50% 42% }`
                alignment: asset == null
                    ? const Alignment(0, -0.16)
                    : kWrOnboardingPhotoAlignment,
                excludeFromSemantics: true,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
              if (asset == null) ...[
                // `.rf-band-tint`: quầng màu "mặt trời" của cảm xúc ...
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.56, -0.4),
                      radius: 1.1,
                      colors: [sun.withAlpha(0x4A), sun.withAlpha(0)],
                      stops: const [0, 0.62],
                    ),
                  ),
                ),
                // ... và lớp màu "trời" nhạt dần về nền kem.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        sky.withAlpha(0x30),
                        sky.withAlpha(0x10),
                        const Color(0xF2FFF7EE),
                      ],
                      stops: const [0, 0.52, 1],
                    ),
                  ),
                ),
              ] else
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: kWrOnboardingFade),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
