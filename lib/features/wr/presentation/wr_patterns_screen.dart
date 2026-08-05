// Toàn bộ điều lặp lại — mở từ "Xem thêm" ở tab Hiểu mình.
//
// Tab Hiểu mình chỉ giữ ba dòng đầu cho gọn; phần còn lại nằm ở đây. Màn này
// vẫn chỉ LIỆT KÊ: số lần và thanh so sánh, không diễn giải. Phần đọc ra điều
// đứng sau nằm ở màn chi tiết của từng dòng (Premium, và chỉ khi đủ 5 lần).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../wr_providers.dart';
import 'wr_discover_screen.dart' show WrPatternRow, situationLabelFor;

class WrPatternsScreen extends ConsumerWidget {
  const WrPatternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final sitMap = {for (final s in situations) s.code: s.text};

    // Cùng recentSituationIds VÀ cùng ngưỡng lặp với tab Hiểu mình — khác chỗ
    // duy nhất là màn kia cắt lấy ba dòng đầu, màn này liệt kê hết. Lệch một
    // trong hai thì "Xem thêm N điều lặp lại" sẽ dẫn tới một danh sách không
    // khớp con số vừa hứa.
    final repeated = repeatedSituations(
      episodes,
      minCount: kRepeatedSituationsMinCount,
    );
    final maxCount =
        repeated.fold<int>(1, (m, p) => p.count > m ? p.count : m);

    return WrDetailScaffold(
      eyebrow: 'TÌNH HUỐNG LẶP LẠI',
      title: 'Những điều đang trở đi trở lại',
      children: [
        if (repeated.isEmpty)
          Text(
            recentSituationIds(episodes).isEmpty
                ? 'Sau vài lần nhìn lại có chọn tình huống, những điều lặp lại '
                    'sẽ hiện ra ở đây.'
                : 'Chưa điều nào trở lại đủ $kRepeatedSituationsMinCount lần. '
                    'Những gì bạn đã ghi vẫn còn nguyên trong Hành trình.',
            key: const Key('wr_patterns_empty'),
            style: const TextStyle(
                fontSize: 15.5, color: WrColors.muted, height: 1.6),
          )
        else ...[
          const Text(
            // Nói rõ ba điều người dùng không đoán được: cửa sổ chỉ 30 lần gần
            // nhất, phải lặp đủ ngưỡng mới vào bảng, và lượt tự viết không có
            // mã nào để đếm nên không bao giờ vào.
            'Đếm trên $kRecentSituationsWindow lần nhìn lại gần nhất có chọn '
            'tình huống, hiện những điều đã trở lại từ '
            '$kRepeatedSituationsMinCount lần.',
            key: Key('wr_patterns_window_note'),
            style: TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          for (final p in repeated) ...[
            WrPatternRow(
              key: Key('wr_patterns_row_${p.situationCode}'),
              label: situationLabelFor(sitMap, p.situationCode),
              count: p.count,
              ratio: p.count / maxCount,
              onTap: () => context.push('/wr/pattern/${p.situationCode}'),
            ),
            if (p != repeated.last) const SizedBox(height: 18),
          ],
        ],
      ],
    );
  }
}
