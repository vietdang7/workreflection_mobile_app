// Dải phụ đề nằm đè lên đáy khung video. Dùng chung cho video báo cáo và
// video hướng dẫn ở màn chào.

import 'package:flutter/material.dart';

import '../../../core/widgets/wr_paragraph.dart';

class VideoSubtitleOverlay extends StatelessWidget {
  const VideoSubtitleOverlay({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black.withValues(alpha: 0.55),
      child: WrParagraph(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16.5,
          height: 1.3,
        ),
      ),
    );
  }
}
