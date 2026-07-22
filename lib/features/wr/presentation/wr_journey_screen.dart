import 'package:flutter/material.dart';
import '../../../core/theme/wr_colors.dart';

class WrJourneyScreen extends StatelessWidget {
  const WrJourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const types = [
      _MemoryType(icon: '◎', label: 'Reflection', desc: 'Nhận ra điều gì đó mới'),
      _MemoryType(icon: '◈', label: 'Insight', desc: 'Góc nhìn thay đổi'),
      _MemoryType(icon: '✦', label: 'Milestone', desc: 'Mốc quan trọng'),
      _MemoryType(icon: '◇', label: 'Quyết định', desc: 'Lựa chọn đã được đưa ra'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 12, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hành trình',
                      style: TextStyle(fontSize: 10, color: Color(0xFFA3A3A3), letterSpacing: 0.02),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Career Memory trống',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: WrColors.dark),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mỗi lần phản chiếu sẽ tạo ra một mảnh ký ức nghề nghiệp được lưu tại đây.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF737373), height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: types.map((t) => _MemoryCard(type: t)).toList(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tạo Memory sẽ ra mắt ở Phase 2'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WrColors.dark,
                      foregroundColor: WrColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Tạo Memory đầu tiên →',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryType {
  const _MemoryType({required this.icon, required this.label, required this.desc});
  final String icon;
  final String label;
  final String desc;
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.type});
  final _MemoryType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type.icon, style: const TextStyle(fontSize: 20, color: WrColors.dark)),
          const SizedBox(height: 6),
          Text(
            type.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WrColors.dark),
          ),
          const SizedBox(height: 2),
          Text(
            type.desc,
            style: const TextStyle(fontSize: 10, color: Color(0xFF737373)),
          ),
        ],
      ),
    );
  }
}
