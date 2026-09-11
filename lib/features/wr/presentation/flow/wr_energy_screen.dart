// Màn năng lượng — bản đứng riêng, dùng khi bắt đầu một lần nhìn lại mới
// trong lúc còn phiên đang dở. Lượt đầu tiên trong ngày được hỏi ngay trên
// Home (xem `_EnergyQuestion` trong wr_home_screen.dart).
//
// Chỉ một việc trên màn này: chọn năng lượng. Không mood, không hướng đi,
// không thẻ gợi ý (yêu cầu khách: bỏ trùng lặp trạng thái/năng lượng).
// Chọn xong là đi tiếp luôn — không cần nút xác nhận.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/wr_tr.dart';
import '../../../../core/models/checkin.dart';
import '../../episode_flow_controller.dart';
import 'wr_flow_scaffold.dart';

String energyLabel(CheckinEnergy energy) => switch (energy) {
      CheckinEnergy.good => tr('Có năng lượng', 'Energised'),
      CheckinEnergy.ok => tr('Bình thường', 'Steady'),
      CheckinEnergy.low => tr('Mệt mỏi', 'Drained'),
    };

class WrEnergyScreen extends ConsumerWidget {
  const WrEnergyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WrFlowScaffold(
      eyebrow: tr('Lúc này', 'Right now'),
      title: tr('Năng lượng của bạn thế nào?', 'How is your energy?'),
      progress: 0.2,
      onClose: () => context.go('/home'),
      child: Column(
        children: [
          for (final energy in CheckinEnergy.values) ...[
            if (energy != CheckinEnergy.values.first)
              const SizedBox(height: 12),
            WrBigChoiceTile(
              key: Key('wr_energy_${energy.dbValue}'),
              label: energyLabel(energy),
              onTap: () {
                ref.read(pendingEnergyProvider.notifier).state = energy;
                // Màn này chỉ hỏi năng lượng, không hỏi cảm xúc. Xoá lựa chọn
                // cũ để phiên mới không mang theo cảm xúc của phiên trước.
                ref.read(pendingMoodProvider.notifier).state = null;
                context.push('/wr/flow/moment');
              },
            ),
          ],
        ],
      ),
    );
  }
}
