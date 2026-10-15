import 'package:flutter/material.dart';

import '../l10n/wr_tr.dart';
import '../theme/wr_colors.dart';
import 'wr_paragraph.dart';

/// Đoạn chữ dài chỉ hiện vài dòng đầu + nút "Xem thêm" (họp khách 14/10: phần
/// Nhìn lại dòng thời gian "nhiều chữ quá").
///
/// Nút chỉ hiện khi chữ thật sự dài hơn [collapsedLines] dòng ở cỡ chữ của máy;
/// đoạn ngắn hiện trọn, không có nút thừa.
class WrExpandableText extends StatefulWidget {
  const WrExpandableText(
    this.text, {
    super.key,
    required this.style,
    this.collapsedLines = 4,
  });

  final String text;
  final TextStyle style;
  final int collapsedLines;

  @override
  State<WrExpandableText> createState() => _WrExpandableTextState();
}

class _WrExpandableTextState extends State<WrExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = wrKeepCompounds(widget.text);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: widget.style),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: widget.style,
              maxLines: _expanded ? null : widget.collapsedLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (overflows || _expanded)
              GestureDetector(
                key: const Key('wr_expandable_toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Text(
                    _expanded
                        ? tr('Thu gọn', 'Show less')
                        : tr('Xem thêm', 'Read more'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.pillTealText,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Mốc thời gian nổi bật: nền teal nhạt, chữ đậm (họp khách 14/10: "làm nổi
/// bật các mốc ngày tháng để dễ theo dõi").
class WrDateBadge extends StatelessWidget {
  const WrDateBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: WrColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WrColors.teal.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 13,
            color: WrColors.pillTealText,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: WrColors.pillTealText,
            ),
          ),
        ],
      ),
    );
  }
}
