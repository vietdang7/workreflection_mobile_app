import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_sca_deep_dive.dart';
import '../../../core/logic/wr_self_check_narrative.dart';
import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_link_row.dart';
import 'wr_sca_deep_dive_screen.dart' show openScaDeepDive;
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

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

  /// Lượt hẹn tự nhảy sang câu kế. Luôn nhiều nhất MỘT lượt đang chờ.
  ///
  /// Trước đây đây là `Future.delayed` không giữ tay cầm, nên mỗi lượt chạm hẹn
  /// thêm một lần nhảy. Chọn "Đôi khi đúng" rồi đổi ý bấm "Khá đúng" — thao tác
  /// hoàn toàn bình thường — là `_step` nhảy hai bước: một câu bị bỏ qua mà bộ
  /// vẫn tính là làm xong. Ở câu cuối thì cả hai lượt cùng gọi `_finishSurvey`,
  /// ghi xuống DB hai bản ghi cho một lần làm.
  ///
  /// Cả hai đã xảy ra thật: DB có ba cặp bản ghi trùng (23/7, 29/7, 30/7) và
  /// bản 30/7 chỉ còn 12/15 câu, thiếu scq-04, scq-05, scq-07.
  Timer? _advanceTimer;

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
    // Đổi ý thì huỷ lượt hẹn cũ rồi hẹn lại, chứ không chặn lượt chạm: mức được
    // ghi phải là mức người dùng chọn SAU CÙNG.
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (_step < kSelfCheckQuestions.length) {
        setState(() => _step++);
      } else {
        _finishSurvey();
      }
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  /// Thoát khỏi bộ câu hỏi.
  ///
  /// Bài làm dở KHÔNG được lưu ở đâu cả — `_answers` chỉ nằm trong bộ nhớ màn
  /// này, đóng là mất sạch. Vì thế đã trả lời được câu nào thì phải hỏi lại một
  /// nhịp: mất mười câu vừa nghĩ kỹ chỉ vì chạm nhầm chữ "Đóng" là cái giá quá
  /// đắt cho một lượt chạm. Chưa trả lời gì thì đóng thẳng, không cản đường.
  Future<void> _confirmClose() async {
    _advanceTimer?.cancel();
    if (_answers.isEmpty) {
      context.pop();
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WrColors.white,
        title: const Text(
          'Thoát khỏi bộ câu hỏi?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: WrColors.dark,
          ),
        ),
        content: WrParagraph(
          '${_answers.length} câu bạn đã trả lời sẽ không được giữ lại. '
          'Bộ câu hỏi chỉ được lưu khi bạn trả lời xong cả '
          '${kSelfCheckQuestions.length} câu.',
          style: const TextStyle(
            fontSize: 15.5,
            height: 1.6,
            color: WrColors.text2,
          ),
        ),
        actions: [
          // Navigator.pop chứ không phải context.pop của go_router: ở đây phải
          // đóng đúng hộp thoại, không phải đóng cả màn.
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Làm tiếp'),
          ),
          TextButton(
            key: const Key('wr_self_check_close_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: WrColors.destructive),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );

    if (leave == true && mounted) context.pop();
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
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: WrColors.dark,
                tooltip: 'Quay lại',
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              // Khối giới thiệu canh GIỮA phần trống, không dán lên mép trên.
              // Trước đây một `Spacer` đẩy nút xuống đáy và để lại nguyên nửa
              // màn hình trắng ở giữa — màn nhìn như đang tải dở.
              //
              // `Center` bọc ngoài chỗ cuộn: nội dung ngắn thì nằm giữa, máy nhỏ
              // hoặc cỡ chữ lớn thì cuộn được thay vì tràn khung.
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF3FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              '◉',
                              style: TextStyle(
                                fontSize: 26,
                                color: WrColors.navy,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          '${kSelfCheckQuestions.length} câu phản chiếu',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: WrColors.dark,
                            height: 1.2,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const WrParagraph(
                          'Trả lời thành thật theo cảm nhận thực tế trong môi '
                          'trường làm việc của bạn, không có câu trả lời đúng '
                          'hay sai.',
                          style: TextStyle(
                            fontSize: 16.5,
                            color: WrColors.text2,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _InfoRow(icon: '⏱', text: 'Khoảng 3–4 phút'),
                        const SizedBox(height: 12),
                        _InfoRow(icon: '🔒', text: 'Chỉ bạn thấy kết quả'),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: '↺',
                          text: 'Có thể làm lại bất cứ lúc nào',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrColors.navy,
                    foregroundColor: WrColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Bắt đầu →',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // Thanh tiến độ + điều hướng
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: WrColors.lineSoft,
                      color: WrColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Vùng chạm 44×44 quanh mũi tên: cái icon 16px trần
                      // trước đây là một mục tiêu bé bằng đầu que diêm.
                      IconButton(
                        onPressed: () {
                          // Không huỷ ở đây thì lượt hẹn đang chờ vẫn nổ và
                          // đẩy người dùng ngược lại đúng câu vừa rời khỏi.
                          _advanceTimer?.cancel();
                          setState(() {
                            if (_step > 1) {
                              _step--;
                            } else {
                              _step = 0;
                            }
                          });
                        },
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        color: WrColors.dark,
                        tooltip: 'Câu trước',
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      const Spacer(),
                      Text(
                        'Câu ${_questionIndex + 1} / '
                        '${kSelfCheckQuestions.length}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: WrColors.text2,
                        ),
                      ),
                      const Spacer(),
                      // Lối thoát. Trước đây chỉ có mũi tên lùi MỘT câu: đang ở
                      // câu 12 mà muốn ra thì phải bấm mười hai lần, nên trên
                      // thực tế màn này không có cửa ra.
                      TextButton(
                        key: const Key('wr_self_check_close'),
                        onPressed: _confirmClose,
                        style: TextButton.styleFrom(
                          foregroundColor: WrColors.text2,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Đóng',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              // Cuộn được, và câu hỏi KHÔNG còn bị `Spacer` đẩy dính mép trên
              // trong khi năm ô chọn dính mép dưới. Câu hỏi dài hoặc máy chỉnh
              // cỡ chữ lớn thì trước đây tràn khung; giờ chỉ cần cuộn.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: pillarBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        q.pillar.displayName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: pillarColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      q.text,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: WrColors.dark,
                        height: 1.5,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Năm mức Likert.
                    //
                    // Ô CHƯA chọn có nền TRẮNG ĐẶC, không phải trong suốt: nền
                    // màn là kem #FBF9F5, ô trong suốt viền navy 10% thì gần
                    // như tàng hình — nhìn ra thì thấy năm vệt trắng mờ chứ
                    // không thấy năm cái nút.
                    ...List.generate(_likertLabels.length, (i) {
                      final score = i + 1; // 1-5
                      final selected = current == score;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _answer(score),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 56),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? WrColors.coral.withValues(alpha: 0.10)
                                    : WrColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? WrColors.coral
                                      : WrColors.line,
                                  width: selected ? 2 : 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _likertLabels[i],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: WrColors.dark,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  if (selected) ...[
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: WrColors.coral,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
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
      backgroundColor: WrColors.pageBg,
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
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: WrColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dựa trên 15 câu phản chiếu',
                      style: TextStyle(fontSize: 15.5, color: WrColors.muted),
                    ),
                    if (_saving) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(color: WrColors.navy),
                    ],
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMsg!,
                        style: const TextStyle(
                          fontSize: 14.5,
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
                            fontSize: 16.5,
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
                          foregroundColor: WrColors.navy,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Xem Hành trình',
                          style: TextStyle(
                            fontSize: 16.5,
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
          _NarrativeCard(
            title: n.title,
            text: n.text,
            pillarName: n.pillarName,
            collapsible: true,
          ),
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
    // recentSituationIds — nguồn duy nhất (Kiến trúc v2.0 §4.3), không còn đọc
    // `wr_pattern_counts`.
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final sitText = {for (final s in situations) s.code: s.text};

    final lowest = lowestPillar(_sScore, _cScore, _aScore);
    final relatedPatterns = patternsForPillar(
      lowest,
      recentSituationIds(episodes),
      situations,
    );

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
                collapsible: true,
              );
            }),
            const SizedBox(height: 10),
          ],

          if (imbalance != null) ...[
            const SizedBox(height: 8),
            _CollapsibleSection(
              title: 'MẤT CÂN BẰNG GIỮA CÁC MẶT',
              child: _NarrativeCard(text: imbalanceNarrative(imbalance)),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 8),
          _CollapsibleSection(
            title: 'XU HƯỚNG THEO THỜI GIAN',
            child: trend == null
                ? const _NarrativeCard(
                    text: 'Đây là lần tự soi đầu tiên được ghi lại. Làm lại '
                        'sau vài tuần, WorkReflection sẽ cho bạn thấy điều gì '
                        'đã đổi và điều gì vẫn ở nguyên đó.',
                  )
                : _NarrativeCard(
                    title: 'Đã ghi ${trend.takenCount} lần tự soi',
                    text: trend.summary,
                    footer: 'Sự rõ ràng ${_delta(trend.structureDelta)} · '
                        'Mối quan hệ ${_delta(trend.cultureDelta)} · '
                        'Cách làm việc ${_delta(trend.activityDelta)}',
                  ),
          ),

          if (relatedPatterns.isNotEmpty) ...[
            const SizedBox(height: 18),
            _CollapsibleSection(
              title: 'ĐỐI CHIẾU VỚI ĐIỀU BẠN HAY GẶP',
              child: _NarrativeCard(
                text: 'Những gì bạn ghi lại trong các câu chuyện cũng chỉ về '
                    'cùng một hướng với "${lowest.displayName}":',
                footer: relatedPatterns
                    .map((p) =>
                        '${sitText[p.situationCode] ?? p.situationCode}'
                        ' · lần thứ ${p.count}')
                    .join('\n'),
              ),
            ),
          ],

          // Lối vào màn Diễn giải sâu (changelog 24/08 §7).
          //
          // Khối ở trên chỉ đối chiếu Pattern cho trụ THẤP NHẤT. §7 muốn cả ba
          // trụ đều có lớp đối chiếu riêng, vì lệch pha hay xảy ra ở trụ người
          // dùng tự chấm cao — đúng trụ mà khối này bỏ qua.
          WrLinkRow(
            key: const Key('wr_self_check_deep_dive_link'),
            label: 'Diễn giải sâu & xu hướng',
            onTap: () => openScaDeepDive(context, ref),
          ),
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

/// Một mục ở trang kết quả, THU GỌN sẵn: chỉ hiện dòng chữ in hoa của mục, nội
/// dung nằm im tới khi người dùng chạm vào.
///
/// Dùng cho các mục mà thẻ bên trong không có câu chốt riêng để làm đầu đề —
/// mất cân bằng, xu hướng, đối chiếu pattern. Với các thẻ diễn giải theo trụ thì
/// [_NarrativeCard.collapsible] lo phần này, vì ở đó câu chốt mới là thứ đáng
/// đọc trước.
///
/// Vùng chạm lấy cả hàng và có đệm dọc: dòng chữ in hoa chỉ cao 10px, chạm đúng
/// vào nó thì trượt nhiều hơn trúng.
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: Key('self_check_section_${widget.title}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: WrEyebrow(widget.title)),
                const SizedBox(width: 8),
                // Mũi tên là thứ duy nhất báo rằng mục còn nội dung bên trong.
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: WrColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 4),
          widget.child,
        ],
      ],
    );
  }
}

/// Khối diễn giải dạng văn xuôi dùng chung cho Free và Paid.
///
/// Với [collapsible] bật, thẻ chỉ hiện phần đầu đề — tên mặt và câu chốt, ví dụ
/// "Cách làm việc · Có nhịp, nhưng chưa đều" — còn đoạn diễn giải nằm im tới khi
/// người dùng chạm vào.
///
/// Trang kết quả có tới bốn đoạn văn xuôi liền nhau, mỗi đoạn năm sáu dòng. Đọc
/// hết là đúng ý đồ, nhưng đọc hết TRƯỚC KHI biết mình muốn đọc gì thì không:
/// người vừa trả lời xong 15 câu cần thấy ngay bức tranh tổng thể, rồi mới tự
/// chọn chỗ nào đáng đào sâu.
///
/// Chỉ bật cho các thẻ diễn giải theo trụ, vì chúng có sẵn câu chốt làm đầu đề.
/// Thẻ mất cân bằng và thẻ đối chiếu pattern không có [title] — thu chúng lại sẽ
/// chừa ra một ô trống chẳng nói lên điều gì, nên chúng vẫn mở sẵn.
class _NarrativeCard extends StatefulWidget {
  const _NarrativeCard({
    required this.text,
    this.title,
    this.pillarName,
    this.footer,
    this.collapsible = false,
  });

  final String text;
  final String? title;
  final String? pillarName;
  final String? footer;
  final bool collapsible;

  @override
  State<_NarrativeCard> createState() => _NarrativeCardState();
}

class _NarrativeCardState extends State<_NarrativeCard> {
  bool _open = false;

  /// Không có đầu đề thì không thu lại được: sẽ chẳng còn gì để đọc.
  bool get _canCollapse => widget.collapsible && widget.title != null;

  @override
  Widget build(BuildContext context) {
    final showBody = !_canCollapse || _open;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WrColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.pillarName != null) ...[
            Text(
              widget.pillarName!,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: WrColors.text3,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (widget.title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: WrParagraph(
                    widget.title!,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: WrColors.dark,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
                if (_canCollapse) ...[
                  const SizedBox(width: 8),
                  // Mũi tên là thứ duy nhất báo rằng thẻ còn chữ bên trong. Bỏ
                  // nó đi thì phần diễn giải xem như biến mất hẳn: không ai chạm
                  // vào một đoạn chữ trông đã trọn vẹn.
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: WrColors.text3,
                    ),
                  ),
                ],
              ],
            ),
            if (showBody) const SizedBox(height: 6),
          ],
          if (showBody) ...[
            Text(
              widget.text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.65,
                color: WrColors.muted,
              ),
            ),
            if (widget.footer != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.footer!,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: WrColors.dark,
                ),
              ),
            ],
          ],
        ],
      ),
    );

    if (!_canCollapse) return card;

    return Semantics(
      button: true,
      expanded: _open,
      label: widget.title,
      child: GestureDetector(
        // Cả thẻ là vùng chạm, không riêng mũi tên: mũi tên 20px là mục tiêu
        // quá nhỏ, và người dùng có xu hướng chạm vào câu chữ họ đang đọc.
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = !_open),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: card,
        ),
      ),
    );
  }
}

/// Khối Premium bị khoá — hiện mờ kèm nút nâng cấp (Hai Lớp v1.2 §IV,
/// khoá cấp tính năng: "ẩn hoặc hiện dạng mờ kèm nút nâng cấp").
class _DeepDiveLocked extends ConsumerWidget {
  const _DeepDiveLocked();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              color: WrColors.pageBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WrColors.line),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: WrColors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const WrParagraph(
                  'Bản đầy đủ đọc kỹ từng mặt theo khoảng điểm của bạn, chỉ ra '
                  'chỗ mất cân bằng giữa ba mặt, so với những lần tự soi trước '
                  'và đối chiếu với những tình huống bạn hay gặp.',
                  style: TextStyle(
                    fontSize: 16.5,
                    height: 1.65,
                    color: WrColors.muted,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // Mua xong đi thẳng vào màn Diễn giải sâu (§7), không rơi
                    // lại đúng cái khối khoá vừa bấm.
                    onPressed: () => openScaDeepDive(context, ref),
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
                          TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
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
        Text(icon, style: const TextStyle(fontSize: 17)),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 16.5, color: WrColors.text2),
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

  // Nhãn và ngưỡng nằm ở wr_sca_deep_dive.dart, không ở đây: từ changelog
  // 24/08 §7, màn Diễn giải sâu phải hiện ĐÚNG nhãn này. Hai màn chép cùng một
  // ngưỡng là bắt đầu đếm ngược tới ngày chúng lệch nhau.
  ScaPillarStatus get _status => scaPillarStatus(score);

  String get _badge => _status.label;

  Color get _badgeColor => _status.isReassuring
      ? WrColors.pillTealText
      : WrColors.pillCoralText;
  Color get _badgeBg => _status.isReassuring
      ? const Color(0xFFE6F7F7)
      : const Color(0xFFFFEEEB);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WrColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Flexible chứ không phải Text trần: từ 2026-08-04 tên trụ là
              // 17px, đứng cạnh nhãn trạng thái trong một Row có Spacer thì
              // máy chỉnh cỡ chữ lớn là tràn hàng.
              Flexible(
                child: Text(
                  pillarName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: WrColors.dark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                    fontSize: 13.5,
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
              backgroundColor: WrColors.line,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(score * 20).round()}%',
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}
