import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/mobile_profile.dart';
import '../../../core/theme/wr_colors.dart';
import '../wr_providers.dart';

class WrHomeScreen extends ConsumerStatefulWidget {
  const WrHomeScreen({super.key});

  @override
  ConsumerState<WrHomeScreen> createState() => _WrHomeScreenState();
}

class _WrHomeScreenState extends ConsumerState<WrHomeScreen> {
  CheckinEnergy? _energy;
  CheckinDirection? _direction;
  bool _saved = false;
  bool _saving = false;

  String _dateLabel() {
    final now = todayVn();
    final weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return '${weekdays[now.weekday - 1]}, ${now.day} tháng ${now.month}';
  }

  Future<void> _save() async {
    if (_energy == null || _direction == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(wrRepositoryProvider);
      await repo.upsertCheckin(
        _energy!.toMood(),
        energy: _energy,
        direction: _direction,
      );
      if (mounted) setState(() { _saved = true; _saving = false; });
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayCheckinAsync = ref.watch(todayCheckinProvider);
    final profileAsync = ref.watch(_mobileProfileProvider);

    // Pre-populate saved state from today's existing check-in
    todayCheckinAsync.whenData((checkin) {
      if (checkin != null && !_saved) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _saved = true; });
        });
      }
    });

    final displayName = profileAsync.valueOrNull?.displayName ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dateLabel(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFA3A3A3),
                              letterSpacing: 0.02,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            displayName.isNotEmpty ? 'Chào $displayName,' : 'Chào buổi sáng,',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: WrColors.dark,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/profile'),
                      child: Container(
                        width: 34, height: 34,
                        decoration: const BoxDecoration(
                          color: WrColors.dark, shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: WrColors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Check-in card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: _CheckinCard(
                  energy: _energy,
                  direction: _direction,
                  saved: _saved,
                  saving: _saving,
                  onEnergySelected: (e) => setState(() => _energy = e),
                  onDirectionSelected: (d) => setState(() => _direction = d),
                  onSave: _save,
                ),
              ),
            ),

            // Low-energy share card
            if (_saved && _energy == CheckinEnergy.low)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: _ShareCard(onShare: () => context.push('/wr/situation')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider: mobile profile (local, only for home screen)
// ---------------------------------------------------------------------------

final _mobileProfileProvider = FutureProvider<MobileProfile?>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  return repo.getMobileProfile();
});

// ---------------------------------------------------------------------------
// _CheckinCard
// ---------------------------------------------------------------------------

class _CheckinCard extends StatelessWidget {
  const _CheckinCard({
    required this.energy,
    required this.direction,
    required this.saved,
    required this.saving,
    required this.onEnergySelected,
    required this.onDirectionSelected,
    required this.onSave,
  });

  final CheckinEnergy? energy;
  final CheckinDirection? direction;
  final bool saved;
  final bool saving;
  final ValueChanged<CheckinEnergy> onEnergySelected;
  final ValueChanged<CheckinDirection> onDirectionSelected;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHECK-IN NHANH',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFA3A3A3), letterSpacing: 0.05),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ngày hôm nay của bạn như thế nào?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.dark, height: 1.5),
          ),
          const SizedBox(height: 14),
          // Energy row
          Row(
            children: [
              _OptionChip(label: 'Có năng lượng', selected: energy == CheckinEnergy.good, onTap: () => onEnergySelected(CheckinEnergy.good)),
              const SizedBox(width: 8),
              _OptionChip(label: 'Bình thường', selected: energy == CheckinEnergy.ok, onTap: () => onEnergySelected(CheckinEnergy.ok)),
              const SizedBox(width: 8),
              _OptionChip(label: 'Mệt mỏi', selected: energy == CheckinEnergy.low, onTap: () => onEnergySelected(CheckinEnergy.low)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Bạn cảm thấy mình đang:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.dark, height: 1.5),
          ),
          const SizedBox(height: 10),
          // Direction row
          Row(
            children: [
              _OptionChip(label: 'Tiến lên', selected: direction == CheckinDirection.forward, onTap: () => onDirectionSelected(CheckinDirection.forward)),
              const SizedBox(width: 8),
              _OptionChip(label: 'Đứng yên', selected: direction == CheckinDirection.steady, onTap: () => onDirectionSelected(CheckinDirection.steady)),
              const SizedBox(width: 8),
              _OptionChip(label: 'Thụt lùi', selected: direction == CheckinDirection.backward, onTap: () => onDirectionSelected(CheckinDirection.backward)),
            ],
          ),
          const SizedBox(height: 16),
          if (saved)
            const _SavedBadge()
          else
            ElevatedButton(
              onPressed: (energy != null && direction != null && !saving) ? onSave : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.navy,
                foregroundColor: WrColors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: WrColors.white))
                  : const Text('Lưu check-in', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0x14FF6859) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? WrColors.coral : const Color(0x1A2C335D),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? WrColors.navy : WrColors.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedBadge extends StatelessWidget {
  const _SavedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 16),
          SizedBox(width: 6),
          Text('Đã lưu · Check-in hôm nay', style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.onShare});
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFF6859)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bạn mệt vì điều gì?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.dark)),
          const SizedBox(height: 8),
          const Text(
            'Đôi khi hiểu được nguyên nhân giúp bạn nhẹ hơn một chút.',
            style: TextStyle(fontSize: 13, color: Color(0xFF737373), height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onShare,
            style: OutlinedButton.styleFrom(
              foregroundColor: WrColors.navy,
              side: const BorderSide(color: WrColors.navy),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Chia sẻ thêm', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
