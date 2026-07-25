// Khối tính năng Premium bị khoá.
//
// Spec: Kiến trúc Dữ liệu Hai Lớp v1.2 §IV — khoá cấp tính năng:
// "Ẩn hoặc hiện dạng mờ kèm nút nâng cấp."

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/wr_colors.dart';

class WrPremiumLock extends StatelessWidget {
  const WrPremiumLock({
    super.key,
    required this.description,
    required this.ctaLabel,
    this.paywallTrigger,
  });

  /// Mô tả người dùng sẽ mở khoá được gì — bằng ngôn ngữ giá trị, không phải
  /// tên tính năng nội bộ.
  final String description;

  final String ctaLabel;

  /// Giá trị `?trigger=` truyền sang `/wr/paywall` để paywall nói đúng ngữ cảnh.
  final String? paywallTrigger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline, size: 15, color: WrColors.amber),
              SizedBox(width: 6),
              Text(
                'Premium',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: WrColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.65,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(
                paywallTrigger == null
                    ? '/wr/paywall'
                    : '/wr/paywall?trigger=$paywallTrigger',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.dark,
                foregroundColor: WrColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                ctaLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
