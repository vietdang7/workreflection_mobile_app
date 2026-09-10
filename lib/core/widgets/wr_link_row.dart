import 'package:flutter/material.dart';

import '../theme/wr_colors.dart';
import 'wr_paragraph.dart';

/// Một dòng dẫn sang màn khác.
///
/// Dùng thay cho việc xổ nội dung ngay tại chỗ: màn danh sách chỉ nêu tên và
/// một con số, bấm vào mới mở màn đọc riêng (yêu cầu "một màn – một hành động").
///
/// ---------------------------------------------------------------------------
/// VÌ SAO PHẢI TỰ ĐO THAY VÌ ĐẶT CỨNG MỘT HÀNG
///
/// Bản đầu đặt [label] trong `Expanded` còn [hint] là một `Text` trần. `Text`
/// trần không co được, nên nó lấy trọn bề rộng nó cần và `Expanded` nhận phần
/// thừa lại — bao nhiêu cũng được, kể cả vài pixel.
///
/// Với tiếng Việt thì không sao vì câu gợi ý đủ ngắn. Sang tiếng Anh, "So the
/// prompts fit better" rộng hơn hẳn "Để gợi ý chính xác hơn", nó ăn gần hết
/// dòng và cột nhãn bị bóp tới mức xuống dòng MỖI KÝ TỰ MỘT DÒNG — chữ
/// "Update your work context" đổ dọc thành một cột.
///
/// Đây là kiểu lỗi chỉ lộ ra khi đổi ngôn ngữ, vì nó không phụ thuộc vào chữ
/// nghĩa mà phụ thuộc vào BỀ RỘNG của chữ. Chữa bằng cách nới `Flexible` cho
/// [hint] thì hết vỡ nhưng hai khối chữ cùng xuống dòng nằm cạnh nhau đọc rất
/// chật. Nên ở đây đo trước: đủ chỗ thì giữ một hàng như cũ, không đủ thì xếp
/// [hint] xuống dưới [label].
///
/// Đo lúc DỰNG chứ không đoán theo số ký tự: bề rộng phụ thuộc phông chữ, cỡ
/// chữ hệ thống người dùng đang đặt, và bề ngang máy. Ba thứ đó chỉ biết được
/// tại đây.
///
/// ⚠ Trong `flutter test`, phông mặc định là Ahem — mọi ký tự rộng bằng nhau và
/// bằng cỡ chữ, nên số đo KHÔNG giống lúc chạy thật và nhánh xếp dọc gần như
/// luôn được chọn. Bài test vì thế phải tìm chữ, đừng khoá vào hình dạng hàng.
class WrLinkRow extends StatelessWidget {
  const WrLinkRow({
    super.key,
    required this.label,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final VoidCallback onTap;

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: WrColors.navy,
    height: 1.4,
  );

  static const TextStyle _hintStyle =
      TextStyle(fontSize: 15.5, color: WrColors.muted);

  /// Khoảng cách giữa nhãn và gợi ý khi còn nằm chung một hàng.
  static const double _gap = 12;

  /// Chỗ mũi tên chiếm ở cuối hàng: khoảng đệm cộng bề ngang biểu tượng.
  static const double _trailing = 8 + 13;

  @override
  Widget build(BuildContext context) {
    final hintText = hint;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final chevron = Padding(
              // Xếp dọc thì hai dòng chữ cao hơn hẳn, mũi tên căn giữa theo cả
              // khối trông như bị trôi xuống. Đẩy nhẹ lên cho ngang tầm dòng
              // đầu, là dòng mang tên hành động.
              padding: const EdgeInsets.only(top: 2),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: WrColors.muted,
              ),
            );

            if (hintText == null) {
              return Row(
                children: [
                  Expanded(child: _label()),
                  const SizedBox(width: 8),
                  chevron,
                ],
              );
            }

            final scaler = MediaQuery.textScalerOf(context);
            final direction = Directionality.of(context);

            double widthOf(String text, TextStyle style) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: style),
                textDirection: direction,
                textScaler: scaler,
                maxLines: 1,
              )..layout();
              return painter.width;
            }

            final needed = widthOf(label, _labelStyle) +
                _gap +
                widthOf(hintText, _hintStyle) +
                _trailing;

            if (needed <= constraints.maxWidth) {
              return Row(
                children: [
                  Expanded(child: _label()),
                  const SizedBox(width: _gap),
                  Text(hintText, style: _hintStyle),
                  const SizedBox(width: 8),
                  chevron,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(),
                      const SizedBox(height: 4),
                      Text(hintText, style: _hintStyle),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                chevron,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _label() => WrParagraph(
        label,
        style: _labelStyle,
        textAlign: TextAlign.start,
      );
}
