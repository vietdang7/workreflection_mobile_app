import 'package:flutter/material.dart';
import '../../../core/theme/wr_colors.dart';

class WrDiscoverScreen extends StatelessWidget {
  const WrDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Đọc câu chuyện đầu tiên',
      'Trả lời câu hỏi phản chiếu',
      'Nhận Aha Moment đầu tiên',
      'Bức tranh bắt đầu xuất hiện',
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
                      'Bức tranh của tôi',
                      style: TextStyle(fontSize: 10, color: Color(0xFFA3A3A3), letterSpacing: 0.02),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Chưa có dữ liệu',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: WrColors.dark),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sau khi phản chiếu, bức tranh về môi trường làm việc của bạn sẽ hiện ra tại đây.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF737373), height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: WrColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x0F000000)),
                  ),
                  child: Column(
                    children: List.generate(steps.length, (i) {
                      return Container(
                        decoration: BoxDecoration(
                          border: i < steps.length - 1
                              ? const Border(bottom: BorderSide(color: Color(0x0D000000)))
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Color(0x0D000000),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFA3A3A3),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              steps[i],
                              style: const TextStyle(fontSize: 12, color: Color(0xFF737373)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
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
                      'Bắt đầu phản chiếu →',
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
