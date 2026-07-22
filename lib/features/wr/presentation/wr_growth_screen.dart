import 'package:flutter/material.dart';
import '../../../core/theme/wr_colors.dart';

class WrGrowthScreen extends StatelessWidget {
  const WrGrowthScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                      'Thực hành',
                      style: TextStyle(fontSize: 10, color: Color(0xFFA3A3A3), letterSpacing: 0.02),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Chưa có chủ đề',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: WrColors.dark),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Đọc story và nhận Insight — WorkReflection sẽ đề xuất thực hành phù hợp.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF737373), height: 1.6),
                    ),
                  ],
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
                          content: Text('Story sẽ ra mắt ở Phase 2'),
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
                      'Đọc story để nhận đề xuất →',
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
