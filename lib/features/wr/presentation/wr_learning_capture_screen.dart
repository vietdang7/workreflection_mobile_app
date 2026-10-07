// "Bạn vừa học được điều hữu ích" — mockup v47 `screenLearningCapture`.
//
// Một ô viết, một nút. Chữ dẫn lấy từ chính tình huống P-08 ("Tôi vừa học được
// một điều nhỏ nhưng hữu ích") trong thư viện Story: câu chuyện, gợi ý thực
// hành, câu aha — thiếu câu nào thì dùng câu dự phòng của mockup.
//
// Lưu là ghi một Cột mốc vào Career Memory (`kLearningBehavior`), mang đúng
// câu bài học của người dùng. Đây là sự thật đã xảy ra, không phải việc cần
// làm tiếp (mockup §CAREER MEMORY, MILESTONE).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_career_memory_rules.dart';
import '../../../core/logic/wr_flow_error.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_back_circle.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_voice_field.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';

/// Tình huống "Tôi vừa học được một điều nhỏ nhưng hữu ích".
const String kLearningSituationCode = 'P-08';

class WrLearningCaptureScreen extends ConsumerStatefulWidget {
  const WrLearningCaptureScreen({super.key});

  @override
  ConsumerState<WrLearningCaptureScreen> createState() =>
      _WrLearningCaptureScreenState();
}

class _WrLearningCaptureScreenState
    extends ConsumerState<WrLearningCaptureScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/wr/growth');
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    final userId = ref.read(currentUserIdProvider);
    if (_busy || text.isEmpty || userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(wrContentRepositoryProvider)
          .insertMemoryEvent(
            CareerMemoryEvent(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: userId,
              behavior: kLearningBehavior,
              situationCode: kLearningSituationCode,
              reflectionText: text,
            ),
          );
      ref.invalidate(wrMemoryEventsProvider);
      ref.invalidate(practiceMemoryEventsProvider);
      if (mounted) setState(() => _saved = true);
    } catch (e, s) {
      logFlowError('saveLearningCapture', e, s);
      if (mounted) {
        setState(
          () => _error = flowErrorMessage(
            tr('Không lưu được. Thử lại.', 'Could not save. Try again.'),
            e,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  WrStory? _p08() {
    final stories = ref.watch(wrStoriesProvider).valueOrNull ?? const [];
    for (final s in stories) {
      if (s.situation == kLearningSituationCode) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: _saved ? _savedView() : _writeView(),
    );
  }

  Widget _closeButton() => TextButton(
    key: const Key('wr_learning_close'),
    onPressed: _back,
    style: TextButton.styleFrom(foregroundColor: WrColors.text2),
    child: Text(
      tr('Đóng', 'Close'),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  Widget _writeView() {
    final p08 = _p08();
    final story = p08?.storyContent.trim();
    final practice = p08?.practiceAction?.trim();
    final aha = p08?.ahaMessage?.trim();
    final hasText = _controller.text.trim().isNotEmpty;
    return Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: WrReflectBand(mood: 'happy'),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                child: Row(
                  children: [
                    WrBackCircle(
                      key: const Key('wr_learning_back'),
                      onTap: _back,
                    ),
                    const Spacer(),
                    _closeButton(),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                  children: [
                    WrEyebrow(
                      tr('MỘT ĐIỀU VỪA Ở LẠI', 'SOMETHING THAT STAYED'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'Bạn vừa học được điều hữu ích',
                        'You just learned something useful',
                      ),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      (story != null && story.isNotEmpty)
                          ? story
                          : tr(
                              'Không cần điều gì lớn lao. Chỉ cần một điều giúp '
                                  'bạn làm việc khác đi một chút.',
                              'It does not need to be big. Just one thing that '
                                  'helps you work a little differently.',
                            ),
                      style: _muted,
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: WrColors.navy.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WrEyebrow(
                            tr(
                              'GHI LẠI ĐIỀU BẠN MUỐN GIỮ',
                              'WRITE DOWN WHAT YOU WANT TO KEEP',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (practice != null && practice.isNotEmpty)
                                ? practice
                                : tr(
                                    'Viết lại điều mình vừa học, bằng chính lời '
                                        'của mình.',
                                    'Write down what you just learned, in your '
                                        'own words.',
                                  ),
                            style: WrText.serifQuote(
                              fontSize: 16,
                              color: WrColors.navy,
                            ),
                          ),
                          const SizedBox(height: 10),
                          WrVoiceField(
                            fieldKey: const Key('wr_learning_field'),
                            controller: _controller,
                            hintText: tr(
                              'Ví dụ: Gửi brief sớm hơn một chút giúp tôi ít '
                                  'phải sửa lại hơn...',
                              'For example: Sending the brief a bit earlier '
                                  'means less rework for me...',
                            ),
                            italic: true,
                            minLines: 4,
                            maxLines: 7,
                            onChanged: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      (aha != null && aha.isNotEmpty)
                          ? aha
                          : tr(
                              'Phần lớn sự tiến bộ đến từ những điều nhỏ được '
                                  'nhận ra và giữ lại.',
                              'Most progress comes from small things that get '
                                  'noticed and kept.',
                            ),
                      style: _muted,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: WrColors.coral,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                child: FilledButton(
                  key: const Key('wr_learning_save'),
                  onPressed: hasText && !_busy ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: WrColors.coral,
                    foregroundColor: WrColors.navy,
                    disabledBackgroundColor: WrColors.line,
                    disabledForegroundColor: WrColors.text3,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    tr('Lưu bài học', 'Save the lesson'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _savedView() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: _closeButton(),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                key: const Key('wr_learning_saved'),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: WrColors.teal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 28,
                        color: WrColors.teal,
                      ),
                    ),
                    const SizedBox(height: 18),
                    WrEyebrow(
                      tr('ĐÃ GIỮ LẠI MỘT BÀI HỌC', 'A LESSON WAS KEPT'),
                      color: WrColors.pillTealText,
                      center: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _controller.text.trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                        color: WrColors.navy,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('wr_learning_memory'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: WrColors.coral.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: WrColors.coral.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WrEyebrow(
                            tr(
                              'CAREER MEMORY · CỘT MỐC',
                              'CAREER MEMORY · MILESTONE',
                            ),
                            color: WrColors.pillCoralText,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            tr(
                              'Bạn vừa học được điều hữu ích',
                              'You just learned something useful',
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: WrColors.navy,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            tr(
                              'Được ghi nhận hôm nay · sẽ xuất hiện trong “Những '
                                  'gì bạn đã học”',
                              'Recorded today · will appear in “What you have '
                                  'learned”',
                            ),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: WrColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('wr_learning_done'),
                        onPressed: _back,
                        style: FilledButton.styleFrom(
                          backgroundColor: WrColors.navy,
                          foregroundColor: WrColors.cream,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          tr('Quay lại Phát triển', 'Back to Grow'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.muted` (12.5px) +1.5.
const _muted = TextStyle(fontSize: 14, color: WrColors.text2, height: 1.6);
