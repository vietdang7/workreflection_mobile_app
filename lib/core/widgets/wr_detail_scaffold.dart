import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/wr_colors.dart';
import 'eyebrow.dart';

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
  });

  final String eyebrow;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        surfaceTintColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('wr_detail_back'),
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.3,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}
