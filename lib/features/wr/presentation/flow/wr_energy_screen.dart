// Màn 1 của luồng phản tư — mức năng lượng.
//
// Chỉ một việc trên màn này: chọn năng lượng. Không mood, không hướng đi,
// không thẻ gợi ý (yêu cầu khách: bỏ trùng lặp trạng thái/năng lượng).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/checkin.dart';
import '../../episode_flow_controller.dart';
import 'wr_flow_scaffold.dart';

String energyLabel(CheckinEnergy energy) => switch (energy) {
      CheckinEnergy.good => 'Có năng lượng',
      CheckinEnergy.ok => 'Bình thường',
      CheckinEnergy.low => 'Mệt mỏi',
    };

class WrEnergyScreen extends ConsumerWidget {
  const WrEnergyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(pendingEnergyProvider);

    return WrFlowScaffold(
      eyebrow: 'Hôm nay',
      title: 'Năng lượng của bạn lúc này thế nào?',
      progress: 0.2,
      onClose: () => context.go('/home'),
      primaryLabel: 'Tiếp',
      onPrimary: selected == null
          ? null
          : () => context.push('/wr/flow/moment'),
      child: Column(
        children: [
          for (final energy in CheckinEnergy.values) ...[
            if (energy != CheckinEnergy.values.first)
              const SizedBox(height: 12),
            WrBigChoiceTile(
              key: Key('wr_energy_${energy.dbValue}'),
              label: energyLabel(energy),
              selected: selected == energy,
              onTap: () =>
                  ref.read(pendingEnergyProvider.notifier).state = energy,
            ),
          ],
        ],
      ),
    );
  }
}
