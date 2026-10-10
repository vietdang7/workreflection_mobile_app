import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/wr_tr.dart';
import '../theme/wr_colors.dart';
import 'eyebrow.dart';
import 'wr_hero_header.dart';
import 'wr_paragraph.dart';

/// Khung chung cho các màn đọc mở từ một dòng danh sách.
///
/// Một eyebrow, một tiêu đề, một khối nội dung — không thanh tab, không CTA
/// phụ. Đây là màn để đọc; màn để ghi nằm trong luồng phản tư.
class WrDetailScaffold extends StatelessWidget {
  const WrDetailScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.children,
    this.art,
  });

  final String eyebrow;
  final String title;
  final List<Widget> children;

  /// Tab cha của màn. Có thì đầu màn có dải ảnh của tab đó (`decorateInner`
  /// của mockup v55); không có thì giữ nền trơn như cũ.
  final WrHeroArt? art;

  @override
  Widget build(BuildContext context) {
    final banded = art != null;
    final scaffold = Scaffold(
      backgroundColor: banded ? Colors.transparent : WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: banded ? Colors.transparent : WrColors.pageBg,
        surfaceTintColor: banded ? Colors.transparent : WrColors.white,
        scrolledUnderElevation: banded ? 0 : null,
        elevation: 0,
        leading: IconButton(
          key: const Key('wr_detail_back'),
          tooltip: tr('Quay lại', 'Back'),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: WrColors.navy,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: [
            WrEyebrow(eyebrow),
            const SizedBox(height: 14),
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
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
    return banded ? WrInnerBandBackdrop(art: art!, child: scaffold) : scaffold;
  }
}
