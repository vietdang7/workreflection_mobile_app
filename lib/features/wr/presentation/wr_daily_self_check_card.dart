import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_daily_self_check_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_daily_self_check.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../wr_providers.dart';

final wrDailySelfCheckDraftProvider = FutureProvider<WrDailySelfCheckDraft?>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(wrDailySelfCheckRepositoryProvider).fetchDraft(userId);
});

SelfCheckPillar pillarForDimension(ScaDimension dimension) {
  return switch (dimension) {
    ScaDimension.s1 || ScaDimension.s2 || ScaDimension.s3 => SelfCheckPillar.s,
    ScaDimension.c1 || ScaDimension.c2 || ScaDimension.c3 => SelfCheckPillar.c,
    ScaDimension.a1 ||
    ScaDimension.a2 ||
    ScaDimension.a3 ||
    ScaDimension.a4 => SelfCheckPillar.a,
  };
}

WrSelfCheckQuestion? nextDailySelfCheckQuestion({
  required Map<String, int> answers,
  required SelfCheckPillar preferredPillar,
}) {
  final preferred = kSelfCheckQuestions
      .where((q) => q.pillar == preferredPillar)
      .where((q) => !answers.containsKey(q.id));
  if (preferred.isNotEmpty) return preferred.first;
  return kSelfCheckQuestions
      .where((q) => !answers.containsKey(q.id))
      .firstOrNull;
}

/// Một câu Self-Check nhỏ sau khi người dùng ghi nhận tình huống.
///
/// Người dùng có thể bỏ qua. Mỗi lần mở chỉ hỏi một câu; đủ 15 câu thì tạo
/// đúng cùng một ScaSelfCheckResponse như luồng Self-Check đầy đủ.
class WrDailySelfCheckCard extends ConsumerStatefulWidget {
  const WrDailySelfCheckCard({super.key, required this.dimension});

  final ScaDimension dimension;

  @override
  ConsumerState<WrDailySelfCheckCard> createState() =>
      _WrDailySelfCheckCardState();
}

class _WrDailySelfCheckCardState extends ConsumerState<WrDailySelfCheckCard> {
  bool _busy = false;
  bool _dismissed = false;
  int? _savedProgress;
  bool _completed = false;
  String? _error;

  Future<void> _answer(
    WrDailySelfCheckDraft draft,
    WrSelfCheckQuestion question,
    int value,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;
      final updated = await ref
          .read(wrDailySelfCheckRepositoryProvider)
          .saveAnswer(userId: userId, questionId: question.id, value: value);
      final count = updated.answers.length;
      if (count >= kSelfCheckQuestions.length) {
        final answers = updated.answers;
        await ref
            .read(wrIntelligenceRepositoryProvider)
            .insertSelfCheckResponse(
              ScaSelfCheckResponse(
                userId: userId,
                answers: Map<String, dynamic>.from(answers),
                structureScore: computePillarScore(SelfCheckPillar.s, answers),
                cultureScore: computePillarScore(SelfCheckPillar.c, answers),
                activityScore: computePillarScore(SelfCheckPillar.a, answers),
                takenAt: DateTime.now(),
              ),
            );
        await ref
            .read(wrDailySelfCheckRepositoryProvider)
            .markCompleted(userId);
        ref.invalidate(wrSelfCheckHistoryProvider);
        _completed = true;
      }
      ref.invalidate(wrDailySelfCheckDraftProvider);
      if (mounted) setState(() => _savedProgress = count);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa lưu được câu trả lời. Thử lại nhé.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final history =
        ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];
    if (history.isNotEmpty && !_completed) return const SizedBox.shrink();

    if (_completed) {
      return WrCardMinimal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WrEyebrow('BỨC TRANH ĐÃ SẴN SÀNG'),
            const SizedBox(height: 10),
            const Text(
              '15 câu trả lời nhỏ đã ghép thành bức tranh công việc của bạn.',
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/wr/discover'),
              child: const Text('Xem Bức tranh →'),
            ),
          ],
        ),
      );
    }

    if (_savedProgress != null) {
      return WrCardMinimal(
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: WrColors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đã ghi nhận · $_savedProgress/${kSelfCheckQuestions.length} '
                'mảnh ghép cho Bức tranh của bạn.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: WrColors.muted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final draftAsync = ref.watch(wrDailySelfCheckDraftProvider);
    return draftAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (draft) {
        if (draft == null || draft.isCompleted) return const SizedBox.shrink();
        final question = nextDailySelfCheckQuestion(
          answers: draft.answers,
          preferredPillar: pillarForDimension(widget.dimension),
        );
        if (question == null) return const SizedBox.shrink();
        return WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WrEyebrow('MỘT CÂU NHỎ, NẾU BẠN MUỐN'),
              const SizedBox(height: 10),
              Text(
                question.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                  color: WrColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var value = 1; value <= 5; value++) ...[
                    Expanded(
                      child: Semantics(
                        label: value == 1
                            ? 'Hoàn toàn không đúng'
                            : value == 5
                            ? 'Hoàn toàn đúng'
                            : 'Mức $value trên 5',
                        button: true,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _answer(draft, question, value),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Color(0x1A2C335D)),
                          ),
                          child: Text('$value'),
                        ),
                      ),
                    ),
                    if (value < 5) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Không đúng',
                    style: TextStyle(fontSize: 10, color: WrColors.muted),
                  ),
                  Text(
                    'Rất đúng',
                    style: TextStyle(fontSize: 10, color: WrColors.muted),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 11, color: WrColors.coral),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _dismissed = true),
                  child: const Text('Để lúc khác'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
