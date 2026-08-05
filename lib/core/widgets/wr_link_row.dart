import 'package:flutter/material.dart';

import '../theme/wr_colors.dart';

/// Một dòng dẫn sang màn khác.
///
/// Dùng thay cho việc xổ nội dung ngay tại chỗ: màn danh sách chỉ nêu tên và
/// một con số, bấm vào mới mở màn đọc riêng (yêu cầu "một màn – một hành động").
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy,
                  height: 1.4,
                ),
              ),
            ),
            if (hint != null) ...[
              const SizedBox(width: 12),
              Text(
                hint!,
                style: const TextStyle(fontSize: 15.5, color: WrColors.muted),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: WrColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
