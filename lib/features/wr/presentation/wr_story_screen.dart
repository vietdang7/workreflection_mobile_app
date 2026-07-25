import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wr_colors.dart';

/// Trải nghiệm tab — opens the reflective story flow.
class WrStoryScreen extends StatelessWidget {
  const WrStoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trải nghiệm của tôi',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFA3A3A3),
                        letterSpacing: 0.02,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Story của tôi',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: WrColors.dark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Câu chuyện từ Career Memory của bạn sẽ hiện ra tại đây.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF737373),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Đọc câu chuyện phù hợp với bạn lúc này.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF737373),
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.push('/wr/story/flow'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WrColors.navy,
                        foregroundColor: WrColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      child: const Text(
                        'Bắt đầu đọc',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
