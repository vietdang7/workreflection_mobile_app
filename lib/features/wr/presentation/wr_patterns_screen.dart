// Toàn bộ điều lặp lại — mở từ "Xem thêm" ở tab Hiểu mình.
//
// Tab Hiểu mình chỉ giữ ba dòng đầu cho gọn; phần còn lại nằm ở đây. Màn này
// vẫn chỉ LIỆT KÊ: số lần và thanh so sánh, không diễn giải. Phần đọc ra điều
// đứng sau nằm ở màn chi tiết của từng dòng (Premium, và chỉ khi đủ 5 lần).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../wr_providers.dart';
import 'wr_discover_screen.dart' show WrPatternRow, situationLabelFor;

class WrPatternsScreen extends ConsumerWidget {
  const WrPatternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patterns = ref.watch(wrPatternCountsProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final sitMap = {for (final s in situations) s.code: s.text};
    final maxCount = patterns.fold<int>(
        1, (m, p) => p.occurrenceCount > m ? p.occurrenceCount : m);

    return WrDetailScaffold(
      eyebrow: 'TÌNH HUỐNG LẶP LẠI',
      title: 'Những điều đang trở đi trở lại',
      children: [
        if (patterns.isEmpty)
          const Text(
            'Sau vài lần nhìn lại, những điều lặp lại sẽ hiện ra ở đây.',
            key: Key('wr_patterns_empty'),
            style: TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
          )
        else
          for (final p in patterns) ...[
            WrPatternRow(
              key: Key('wr_patterns_row_${p.situationCode ?? ''}'),
              label: situationLabelFor(sitMap, p.situationCode),
              count: p.occurrenceCount,
              ratio: p.occurrenceCount / maxCount,
              onTap: () =>
                  context.push('/wr/pattern/${p.situationCode ?? ''}'),
            ),
            if (p != patterns.last) const SizedBox(height: 18),
          ],
      ],
    );
  }
}
