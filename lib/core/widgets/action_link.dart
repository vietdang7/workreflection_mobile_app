import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

class WrActionLink extends StatelessWidget {
  const WrActionLink({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `behavior: opaque` không phải trang trí. Row này là `mainAxisSize.min`,
    // nên khi widget được đặt ở chỗ chiếm trọn bề ngang (trong Column chẳng
    // hạn), phần trống bên phải chữ vẫn thuộc vùng của GestureDetector nhưng
    // KHÔNG có gì để bắt chạm — nhìn thì như bấm được, chạm vào lại không ăn.
    // Chỉ lộ ra lúc viết widget test bấm vào tâm dòng.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: WrColors.coral,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward,
            size: 14,
            color: WrColors.coral,
          ),
        ],
      ),
    );
  }
}
