// Một nhóm danh sách nằm trong một khối thẻ chung.
//
// Bản đối chiếu UX/UI 05/08: các dòng đang nằm TRẦN trên nền trang, nên không
// có gì nói cho người dùng biết chúng thuộc về nhau và bắt đầu/kết thúc ở đâu.
// Thẻ trắng viền mảnh gom chúng lại; các dòng bên trong ngăn nhau bằng
// `--line-soft`, dòng cuối không có viền.

import 'package:flutter/material.dart';

import '../theme/wr_colors.dart';

/// Bo góc thẻ theo `.card` của Đặc tả UX/UI (mục 05): `border-radius:18px`.
///
/// Cố ý KHÔNG dùng [WrCardMinimal] (bo 20, lấy theo mockup Sprint 2): hai con
/// số này đang lệch nhau trong hai tài liệu, và đổi hằng số của một widget
/// dùng chung khắp app để chiều đúng một màn là việc phải hỏi trước, không
/// phải việc lặng lẽ làm kèm.
const double kWrCardRadius = 18;

class WrListCard extends StatelessWidget {
  const WrListCard({
    super.key,
    required this.children,
    this.rowPadding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  });

  final List<Widget> children;

  /// Đệm của mỗi dòng. Danh sách chữ ngắn dùng mặc định; khối nội dung dài
  /// (chuỗi bước thực hành) cần rộng rãi hơn.
  final EdgeInsets rowPadding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        border: Border.all(color: WrColors.line),
        borderRadius: BorderRadius.circular(kWrCardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++)
            Container(
              width: double.infinity,
              padding: rowPadding,
              decoration: i == children.length - 1
                  ? null
                  : const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: WrColors.lineSoft),
                      ),
                    ),
              child: children[i],
            ),
        ],
      ),
    );
  }
}
