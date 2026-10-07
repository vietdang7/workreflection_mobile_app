// "Bạn muốn tự thêm điều gì?" — mockup v47 `screenAddPracticeTheme`.
//
// Bốn câu, đúng bốn câu của mockup (khách 06/10: không hỏi thêm gì ngoài
// script). Ba câu đầu bắt buộc, "Đã thử" thì không. Bấm "Tạo chủ đề" là ghi
// chủ đề + bốn bước (`buildUserPracticeSteps`) + ba cách
// (`buildUserThemeMentorOptions`), ghi danh luôn rồi mở màn chủ đề vừa tạo.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_flow_error.dart';
import '../../../core/logic/wr_practice_v47.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_back_circle.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_voice_field.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';

class WrAddPracticeThemeScreen extends ConsumerStatefulWidget {
  const WrAddPracticeThemeScreen({super.key});

  @override
  ConsumerState<WrAddPracticeThemeScreen> createState() =>
      _WrAddPracticeThemeScreenState();
}

class _WrAddPracticeThemeScreenState
    extends ConsumerState<WrAddPracticeThemeScreen> {
  final _name = TextEditingController();
  final _situation = TextEditingController();
  final _goal = TextEditingController();
  final _tried = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _situation.dispose();
    _goal.dispose();
    _tried.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _situation.text.trim().isNotEmpty &&
      _goal.text.trim().isNotEmpty;

  static String _newThemeId() {
    final r = Random();
    final tail = List.generate(
      6,
      (_) => r.nextInt(36).toRadixString(36),
    ).join();
    return 'u-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$tail';
  }

  Future<void> _create() async {
    if (_busy || !_valid) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    // Thẻ "Tự thêm" ở tab đã chặn khi hết quota, nhưng màn này vào thẳng được
    // bằng đường dẫn: kiểm lại ở đây.
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entitlement = await ref.read(wrEntitlementProvider.future);
      final enrollments = await ref.read(practiceEnrollmentsProvider.future);
      final active = enrollments.where((e) => e.completedAt == null).length;
      if (!entitlement.canEnrollPracticeTheme(active)) {
        if (!mounted) return;
        setState(() => _busy = false);
        context.push('/wr/paywall?trigger=practice_limit');
        return;
      }
    } catch (_) {
      // Đọc quota hỏng thì vẫn cho tạo: chặn nhầm người dùng tệ hơn lố một
      // chủ đề.
    }
    if (!mounted) return;
    final intake = PracticeIntake(
      situation: _situation.text.trim(),
      goal: _goal.text.trim(),
      tried: _tried.text.trim().isEmpty ? null : _tried.text.trim(),
    );
    final themeId = _newThemeId();
    final theme = PracticeTheme(
      themeId: themeId,
      title: _name.text.trim(),
      source: PracticeThemeSource.user,
      ownerId: userId,
      intake: intake,
      mentorOptions: buildUserThemeMentorOptions(
        intake.goal,
        tried: intake.tried,
      ),
    );
    try {
      await ref
          .read(wrIntelligenceRepositoryProvider)
          .createUserTheme(
            userId: userId,
            theme: theme,
            steps: buildUserPracticeSteps(themeId: themeId, intake: intake),
          );
      ref.invalidate(practiceThemesProvider);
      ref.invalidate(practiceEnrollmentsProvider);
      ref.invalidate(allPracticeStepsProvider);
      if (mounted) context.pushReplacement('/wr/growth/theme/$themeId');
    } catch (e, s) {
      logFlowError('createUserTheme', e, s);
      if (mounted) {
        setState(
          () => _error = flowErrorMessage(
            tr(
              'Không tạo được chủ đề. Thử lại.',
              'Could not create it. Try again.',
            ),
            e,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
              child: Row(
                children: [
                  WrBackCircle(
                    key: const Key('wr_add_theme_back'),
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('wr_add_theme_close'),
                    onPressed: () => context.pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: WrColors.text2,
                    ),
                    child: Text(
                      tr('Đóng', 'Close'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrEyebrow(tr('CHỦ ĐỀ CỦA BẠN', 'YOUR THEME')),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Bạn muốn tự thêm điều gì?',
                      'What would you like to add?',
                    ),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Không cần gọi tên thật chính xác. Chỉ cần kể đủ để hệ '
                          'thống hiểu bạn đang gặp chuyện gì và muốn điều gì '
                          'khác đi.',
                      'No need to name it exactly. Just say enough for the app '
                          'to understand what is happening and what you want '
                          'to change.',
                    ),
                    style: _muted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Question(
                    eyebrow: tr('01 · CHỦ ĐỀ', '01 · THEME'),
                    label: tr(
                      'Bạn gọi chuyện này là gì?',
                      'What do you call this?',
                    ),
                    field: WrVoiceField(
                      fieldKey: const Key('wr_add_theme_name'),
                      controller: _name,
                      hintText: tr(
                        'Ví dụ: Phản hồi hiệu quả',
                        'For example: Giving useful feedback',
                      ),
                      minLines: 1,
                      maxLines: 2,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Question(
                    eyebrow: tr('02 · TÌNH HUỐNG', '02 · SITUATION'),
                    label: tr('Điều gì đang xảy ra?', 'What is happening?'),
                    hint: tr(
                      'Một tình huống thật gần đây sẽ giúp gợi ý bám sát hơn.',
                      'A real recent situation helps the suggestions fit.',
                    ),
                    field: WrVoiceField(
                      fieldKey: const Key('wr_add_theme_situation'),
                      controller: _situation,
                      hintText: tr(
                        'Ví dụ: Mỗi khi cần góp ý cho đồng nghiệp, tôi thường '
                            'vòng vo...',
                        'For example: Whenever I need to give a colleague '
                            'feedback, I beat around the bush...',
                      ),
                      minLines: 3,
                      maxLines: 6,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Question(
                    eyebrow: tr('03 · ĐIỀU BẠN MUỐN', '03 · WHAT YOU WANT'),
                    label: tr(
                      'Bạn muốn điều gì khác đi?',
                      'What do you want to be different?',
                    ),
                    hint: tr(
                      'Viết về thay đổi bạn muốn thấy ở cách mình hành động, '
                          'không cần đặt thành mục tiêu lớn.',
                      'Write about the change you want in how you act. It '
                          'does not need to be a big goal.',
                    ),
                    field: WrVoiceField(
                      fieldKey: const Key('wr_add_theme_goal'),
                      controller: _goal,
                      hintText: tr(
                        'Ví dụ: Tôi muốn nói rõ hơn mà không làm người kia '
                            'phòng thủ...',
                        'For example: I want to be clearer without making the '
                            'other person defensive...',
                      ),
                      minLines: 3,
                      maxLines: 6,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Question(
                    eyebrow: tr('04 · ĐÃ THỬ', '04 · ALREADY TRIED'),
                    label: tr('Bạn đã thử gì rồi?', 'What have you tried?'),
                    hint: tr(
                      'Không bắt buộc. Thông tin này giúp gợi ý không lặp lại '
                          'đúng cách bạn đã thử trước đó.',
                      'Optional. It helps the suggestions avoid repeating what '
                          'you already tried.',
                    ),
                    field: WrVoiceField(
                      fieldKey: const Key('wr_add_theme_tried'),
                      controller: _tried,
                      hintText: tr(
                        'Ví dụ: Tôi đã thử góp ý ngay trong cuộc họp nhưng...',
                        'For example: I tried giving feedback right in the '
                            'meeting but...',
                      ),
                      minLines: 3,
                      maxLines: 5,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      key: const Key('wr_add_theme_error'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: WrColors.coral,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const Key('wr_add_theme_create'),
                    onPressed: _valid && !_busy ? _create : null,
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
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WrColors.navy,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr('Tạo chủ đề', 'Create theme'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một câu hỏi trong thẻ (`.card.card-pad` + eyebrow + nhãn đậm + gợi ý).
class _Question extends StatelessWidget {
  const _Question({
    required this.eyebrow,
    required this.label,
    required this.field,
    this.hint,
  });

  final String eyebrow;
  final String label;
  final String? hint;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    return WrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WrEyebrow(eyebrow),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
          SizedBox(height: hint == null ? 6 : 3),
          if (hint != null) ...[
            Text(
              hint!,
              style: const TextStyle(fontSize: 12.5, color: WrColors.text3),
            ),
            const SizedBox(height: 7),
          ],
          field,
        ],
      ),
    );
  }
}

/// `.muted` (12.5px) +1.5.
const _muted = TextStyle(fontSize: 14, color: WrColors.text2, height: 1.6);
