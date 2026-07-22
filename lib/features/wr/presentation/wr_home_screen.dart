import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wr_colors.dart';

class WrHomeScreen extends StatefulWidget {
  const WrHomeScreen({super.key});

  @override
  State<WrHomeScreen> createState() => _WrHomeScreenState();
}

class _WrHomeScreenState extends State<WrHomeScreen> {
  String? _energy; // 'good' | 'ok' | 'low'

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Chào buổi sáng,';
    if (h < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  String _dateLabel() {
    final now = DateTime.now();
    final weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return '${weekdays[now.weekday - 1]}, ${now.day} tháng ${now.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
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
                            _greeting(),
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
                      onTap: () => context.push('/profile'),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: WrColors.dark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: WrColors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: _CheckinBlock(
                  selectedEnergy: _energy,
                  onEnergySelected: (val) {
                    setState(() => _energy = val);
                    // Phase 2 will navigate to story/checkin after both are selected
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Check-in đầy đủ sẽ ra mắt ở Phase 2'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckinBlock extends StatelessWidget {
  const _CheckinBlock({
    required this.selectedEnergy,
    required this.onEnergySelected,
  });

  final String? selectedEnergy;
  final ValueChanged<String> onEnergySelected;

  @override
  Widget build(BuildContext context) {
    final opts = [
      _EnergyOpt(key2: 'good', label: 'Có năng lượng', sub: 'Tập trung, rõ ràng'),
      _EnergyOpt(key2: 'ok', label: 'Bình thường', sub: 'Không quá tệ'),
      _EnergyOpt(key2: 'low', label: 'Mệt mỏi', sub: 'Cần thêm sức lực'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CHECK-IN NHANH',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFFA3A3A3),
                letterSpacing: 0.05,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ngày hôm nay của bạn như thế nào?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: WrColors.dark,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: opts
                  .map((o) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _EnergyCard(
                            opt: o,
                            isSelected: selectedEnergy == o.key2,
                            onTap: () => onEnergySelected(o.key2),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyOpt {
  const _EnergyOpt({required this.key2, required this.label, required this.sub});
  final String key2;
  final String label;
  final String sub;
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({
    required this.opt,
    required this.isSelected,
    required this.onTap,
  });

  final _EnergyOpt opt;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x14FF6859) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? WrColors.coral : const Color(0x1A2C335D),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                opt.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? WrColors.navy : WrColors.dark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                opt.sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFFA3A3A3),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
