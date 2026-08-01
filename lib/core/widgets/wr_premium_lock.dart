// Khối tính năng Premium bị khoá.
//
// Spec: Kiến trúc Dữ liệu Hai Lớp v1.2 §IV — khoá cấp tính năng:
// "Ẩn hoặc hiện dạng mờ kèm nút nâng cấp."

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/wr_colors.dart';
import 'wr_card.dart';

class WrPremiumLock extends StatelessWidget {
  const WrPremiumLock({
    super.key,
    required this.description,
    required this.ctaLabel,
    this.title,
    this.paywallTrigger,
  });

  /// Tên của thứ đang khoá, một dòng. Tuỳ chọn: phần lớn khối khoá nằm ngay
  /// dưới một tiêu đề mục nên tự nói được mình khoá cái gì; chỉ khối đứng lẻ
  /// giữa trang mới cần tự xưng tên.
  final String? title;

  /// Mô tả người dùng sẽ mở khoá được gì — bằng ngôn ngữ giá trị, không phải
  /// tên tính năng nội bộ.
  final String description;

  final String ctaLabel;

  /// Giá trị `?trigger=` truyền sang `/wr/paywall` để paywall nói đúng ngữ cảnh.
  final String? paywallTrigger;

  @override
  Widget build(BuildContext context) {
    // Thẻ kem như mọi thẻ nội dung khác (xem `wr_card.dart`). Trước đây khối này
    // dùng nền xám #F4F4F1 + viền đen 8%: một cặp màu không có trong hệ màu nào
    // của app, và vì khối khoá xuất hiện ở cả bốn tab nên nó là chỗ lệch màu dễ
    // thấy nhất. Cái phân biệt "đang khoá" là ổ khoá + chữ Premium màu hổ phách,
    // không phải nền xám.
    return WrCardMinimal(
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
          if (title != null) ...[
            const SizedBox(height: 10),
            Text(
              title!,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.65,
              color: WrColors.muted,
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
                // Navy như mọi nút đặc khác trong app (nút "Bắt đầu thực hành").
                backgroundColor: WrColors.navy,
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
