import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';

/// Story tab screen — shows CTA to launch the full WrStoryFlowScreen.
class WrStoryScreen extends StatelessWidget {
  const WrStoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 22, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: WrColors.dark,
                    ),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 12, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Trải nghiệm của tôi', 'My experience'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: WrColors.text3,
                        letterSpacing: 0.02,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      tr('Story của tôi', 'My Story'),
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: WrColors.dark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      tr('Câu chuyện từ Career Memory của bạn sẽ hiện ra tại đây.', 'Stories from your Career Memory will appear here.'),
                      style: TextStyle(
                        fontSize: 14.5,
                        color: WrColors.muted,
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
                    Text(
                      tr('Đọc câu chuyện phù hợp với bạn lúc này.', 'Read a story that fits where you are right now.'),
                      style: TextStyle(
                        fontSize: 14.5,
                        color: WrColors.muted,
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: Text(
                        tr('Bắt đầu đọc', 'Start reading'),
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
