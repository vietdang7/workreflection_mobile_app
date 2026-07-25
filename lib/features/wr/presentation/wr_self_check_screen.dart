import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_self_check_narrative.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../wr_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route: /wr/self-check
// ─────────────────────────────────────────────────────────────────────────────

class WrSelfCheckScreen extends ConsumerStatefulWidget {
  const WrSelfCheckScreen({super.key});

  @override
  ConsumerState<WrSelfCheckScreen> createState() => _WrSelfCheckScreenState();
}

class _WrSelfCheckScreenState extends ConsumerState<WrSelfCheckScreen> {
  // 0 = intro, 1..15 = question index (0-based internally), 16 = result
  int _step = 0; // 0=intro, 1-15=questions, 16=result
  final Map<String, int> _answers = {}; // questionId → score 1-5
  bool _saving = false;
  String? _errorMsg;

  // Computed scores after completion
  double _sScore = 0;
  double _cScore = 0;
  double _aScore = 0;

  static const _likertLabels = [
    'Hoàn toàn không đúng',
    'Không đúng lắm',
    'Đôi khi đúng',
    'Khá đúng',
    'Hoàn toàn đúng',
  ];

  int get _questionIndex => _step - 1; // 0-based
  WrSelfCheckQuestion get _currentQuestion =>
      kSelfCheckQuestions[_questionIndex];

  void _answer(int value) {
    final q = _currentQuestion;
    setState(() => _answers[q.id] = value);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (_step < kSelfCheckQuestions.length) {
        setState(() => _step++);
      } else {
        _finishSurvey();
      }
    });
  }

  Future<void> _finishSurvey() async {
    final sScore = computePillarScore(SelfCheckPillar.s, _answers);
    final cScore = computePillarScore(SelfCheckPillar.c, _answers);
    final aScore = computePillarScore(SelfCheckPillar.a, _answers);

    setState(() {
      _sScore = sScore;
      _cScore = cScore;
      _aScore = aScore;
      _saving = true;
      _step = 16; // result view
    });

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        final repo = ref.read(wrIntelligenceRepositoryProvider);
        await repo.insertSelfCheckResponse(
          ScaSelfCheckResponse(
            userId: userId,
            answers: Map<String, dynamic>.fromEntries(
              _answers.entries.map((e) => MapEntry(e.key, e.value)),
            ),
            structureScore: sScore,
            cultureScore: cScore,
            activityScore: aScore,
            takenAt: DateTime.now(),
          ),
        );
        // Lần trả lời vừa rồi phải nằm trong lịch sử để khối xu hướng so đúng.
        ref.invalidate(wrSelfCheckHistoryProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Lưu không thành công: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      0 => _buildIntro(),
      16 => _buildResult(),
      _ => _buildQuestion(),
    };
  }

  // ── Intro ──────────────────────────────────────────────────────────────────

  Widget _buildIntro() {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_ios_new, size: 18, color: WrColors.dark),
              ),
              const SizedBox(height: 28),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('◉', style: TextStyle(fontSize: 22, color: WrColors.dark)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '15 câu phản chiếu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: WrColors.dark,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Trả lời thành thật theo cảm nhận thực tế trong môi trường làm việc của bạn — không có câu trả lời đúng hay sai.',
                style: TextStyle(fontSize: 14, color: Color(0xFF737373), height: 1.65),
              ),
              const SizedBox(height: 16),
              _InfoRow(icon: '⏱', text: 'Khoảng 3–4 phút'),
              const SizedBox(height: 8),
              _InfoRow(icon: '🔒', text: 'Chỉ bạn thấy kết quả'),
              const SizedBox(height: 8),
              _InfoRow(icon: '↺', text: 'Có thể làm lại bất cứ lúc nào'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrColors.dark,
                    foregroundColor: WrColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Bắt đầu →',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Question ───────────────────────────────────────────────────────────────

  Widget _buildQuestion() {
    final q = _currentQuestion;
    final progress = _questionIndex / kSelfCheckQuestions.length;
    final pillarColor = switch (q.pillar) {
      SelfCheckPillar.s => const Color(0xFF5B8CC9),
      SelfCheckPillar.c => WrColors.teal,
      SelfCheckPillar.a => const Color(0xFF5E7A5A),
    };
    final pillarBg = switch (q.pillar) {
      SelfCheckPillar.s => const Color(0xFFEEF3FA),
      SelfCheckPillar.c => const Color(0xFFE6F7F7),
      SelfCheckPillar.a => const Color(0xFFEEF3EE),
    };
    final current = _answers[q.id];

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar + nav
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: const Color(0x0F000000),
                      color: WrColors.dark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          if (_step > 1) {
                            _step--;
                          } else {
                            _step = 0;
                          }
                        }),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 16,
                          color: WrColors.dark,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_questionIndex + 1} / ${kSelfCheckQuestions.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFA3A3A3),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 16),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pillar badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pillarBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        q.pillar.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: pillarColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      q.text,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: WrColors.dark,
                        height: 1.65,
                      ),
                    ),
                    const Spacer(),

                    // Likert options
                    ...List.generate(_likertLabels.length, (i) {
                      final score = i + 1; // 1-5
                      final selected = current == score;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => _answer(score),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0x0EFF6859)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? WrColors.coral
                                    : const Color(0x1A2C335D),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _likertLabels[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? WrColors.dark
                                    : const Color(0xFF737373),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result ─────────────────────────────────────────────────────────────────

  Widget _buildResult() {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bức tranh của bạn',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: WrColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dựa trên 15 câu phản chiếu',
                      style: TextStyle(fontSize: 12, color: Color(0xFFA3A3A3)),
                    ),
                    if (_saving) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(color: WrColors.teal),
                    ],
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMsg!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: WrColors.coral,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 3 pillar score bars
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                child: Column(
                  children: [
                    _PillarScoreCard(
                      pillarName: SelfCheckPillar.s.displayName,
                      score: _sScore,
                      color: const Color(0xFF5B8CC9),
                    ),
                    const SizedBox(height: 10),
                    _PillarScoreCard(
                      pillarName: SelfCheckPillar.c.displayName,
                      score: _cScore,
                      color: WrColors.teal,
                    ),
                    const SizedBox(height: 10),
                    _PillarScoreCard(
                      pillarName: SelfCheckPillar.a.displayName,
                      score: _aScore,
                      color: const Color(0xFF5E7A5A),
                    ),
                  ],
                ),
              ),
            ),

            // ── Free: một đoạn đọc nhanh cho trụ thấp nhất ────────────────
            SliverToBoxAdapter(child: _buildQuickRead()),

            // ── Paid: diễn giải sâu · mất cân bằng · xu hướng · pattern ───
            SliverToBoxAdapter(child: _buildDeepDive()),

            // Action buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.go('/wr/growth'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WrColors.dark,
                          foregroundColor: WrColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Vào Thực hành',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.go('/wr/journey'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6F7F7),
                          foregroundColor: WrColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Xem Hành trình',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  // ── Free: đọc nhanh trụ thấp nhất ────────────────────────────────────────
  // Hai Lớp v1.2 §II: Free nhận "kết quả tức thời cho từng trụ tại thời điểm
  // trả lời, không lưu xu hướng".

  Widget _buildQuickRead() {
    final pillar = lowestPillar(_sScore, _cScore, _aScore);
    final score = switch (pillar) {
      SelfCheckPillar.s => _sScore,
      SelfCheckPillar.c => _cScore,
      SelfCheckPillar.a => _aScore,
    };
    final n = pillarNarrative(pillar, score);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrEyebrow('ĐIỀU ĐÁNG CHÚ Ý NHẤT'),
          const SizedBox(height: 10),
          _NarrativeCard(title: n.title, text: n.text, pillarName: n.pillarName),
        ],
      ),
    );
  }

  // ── Paid: diễn giải sâu ──────────────────────────────────────────────────
  // Hai Lớp v1.2 §II: Paid nhận "diễn giải sâu theo bộ narrative đã có sẵn
  // (theo khoảng điểm, phát hiện mất cân bằng giữa các trụ); theo dõi xu hướng
  // qua nhiều lần trả lời theo thời gian; đối chiếu chéo với Pattern rút ra từ
  // Story tự do".

  Widget _buildDeepDive() {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    if (!entitlement.canUseFeature(WrPremiumFeature.selfCheckDeepDive)) {
      return const _DeepDiveLocked();
    }

    final imbalance = detectPillarImbalance(_sScore, _cScore, _aScore);
    final history = ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];
    final trend = trendFromHistory(history);
    final patterns = ref.watch(wrPatternCountsProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final sitText = {for (final s in situations) s.code: s.text};

    final lowest = lowestPillar(_sScore, _cScore, _aScore);
    final relatedPatterns = patternsForPillar(lowest, patterns);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrEyebrow('DIỄN GIẢI SÂU'),
          const SizedBox(height: 10),
          for (final (pillar, score) in [
            (SelfCheckPillar.s, _sScore),
            (SelfCheckPillar.c, _cScore),
            (SelfCheckPillar.a, _aScore),
          ]) ...[
            Builder(builder: (_) {
              final n = pillarNarrative(pillar, score);
              return _NarrativeCard(
                title: n.title,
                text: n.text,
                pillarName: n.pillarName,
              );
            }),
            const SizedBox(height: 10),
          ],

          if (imbalance != null) ...[
            const SizedBox(height: 8),
            const WrEyebrow('MẤT CÂN BẰNG GIỮA CÁC MẶT'),
            const SizedBox(height: 10),
            _NarrativeCard(text: imbalanceNarrative(imbalance)),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 8),
          const WrEyebrow('XU HƯỚNG THEO THỜI GIAN'),
          const SizedBox(height: 10),
          if (trend == null)
            const _NarrativeCard(
              text: 'Đây là lần tự soi đầu tiên được ghi lại. Làm lại sau vài '
                  'tuần, WorkReflection sẽ cho bạn thấy điều gì đã đổi và điều '
                  'gì vẫn ở nguyên đó.',
            )
          else
            _NarrativeCard(
              title: 'Đã ghi ${trend.takenCount} lần tự soi',
              text: trend.summary,
              footer: 'Sự rõ ràng ${_delta(trend.structureDelta)} · '
                  'Mối quan hệ ${_delta(trend.cultureDelta)} · '
                  'Cách làm việc ${_delta(trend.activityDelta)}',
            ),

          if (relatedPatterns.isNotEmpty) ...[
            const SizedBox(height: 18),
            const WrEyebrow('ĐỐI CHIẾU VỚI ĐIỀU BẠN HAY GẶP'),
            const SizedBox(height: 10),
            _NarrativeCard(
              text: 'Những gì bạn ghi lại trong các câu chuyện cũng chỉ về '
                  'cùng một hướng với "${lowest.displayName}":',
              footer: relatedPatterns
                  .map((p) =>
                      '${sitText[p.situationCode] ?? p.situationCode ?? 'tình huống này'}'
                      ' — lần thứ ${p.occurrenceCount}')
                  .join('\n'),
            ),
          ],
        ],
      ),
    );
  }

  static String _delta(double d) {
    if (d.abs() < 0.05) return 'giữ nguyên';
    final sign = d > 0 ? '+' : '−';
    return '$sign${d.abs().toStringAsFixed(1)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Khối diễn giải dạng văn xuôi dùng chung cho Free và Paid.
class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({
    required this.text,
    this.title,
    this.pillarName,
    this.footer,
  });

  final String text;
  final String? title;
  final String? pillarName;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pillarName != null) ...[
            Text(
              pillarName!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFA3A3A3),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: WrColors.dark,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.65,
              color: Color(0xFF4A5568),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            Text(
              footer!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: WrColors.dark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Khối Premium bị khoá — hiện mờ kèm nút nâng cấp (Hai Lớp v1.2 §IV,
/// khoá cấp tính năng: "ẩn hoặc hiện dạng mờ kèm nút nâng cấp").
class _DeepDiveLocked extends StatelessWidget {
  const _DeepDiveLocked();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrEyebrow('DIỄN GIẢI SÂU'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14000000)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 15, color: WrColors.amber),
                    const SizedBox(width: 6),
                    Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: WrColors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bản đầy đủ đọc kỹ từng mặt theo khoảng điểm của bạn, chỉ ra '
                  'chỗ mất cân bằng giữa ba mặt, so với những lần tự soi trước '
                  'và đối chiếu với những tình huống bạn hay gặp.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push('/wr/paywall'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WrColors.dark,
                      foregroundColor: WrColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Mở diễn giải sâu',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF737373)),
        ),
      ],
    );
  }
}

class _PillarScoreCard extends StatelessWidget {
  const _PillarScoreCard({
    required this.pillarName,
    required this.score,
    required this.color,
  });

  final String pillarName;
  final double score; // 1.0 – 5.0
  final Color color;

  double get _percent => score <= 0 ? 0 : ((score - 1) / 4).clamp(0.0, 1.0);

  String get _badge {
    if (score >= 3.8) return 'Đang phát triển';
    if (score >= 2.5) return 'Cần chú ý';
    return 'Ưu tiên cải thiện';
  }

  Color get _badgeColor =>
      score >= 3.8 ? const Color(0xFF1A7A6A) : const Color(0xFF8B3A2F);
  Color get _badgeBg =>
      score >= 3.8 ? const Color(0xFFE6F7F7) : const Color(0xFFFFEEEB);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                pillarName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WrColors.dark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _badgeBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  _badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _percent,
              minHeight: 4,
              backgroundColor: const Color(0x0F000000),
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(score * 20).round()}%',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFA3A3A3),
            ),
          ),
        ],
      ),
    );
  }
}
