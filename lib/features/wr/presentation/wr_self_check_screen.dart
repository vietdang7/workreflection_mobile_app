import '../../../core/l10n/wr_tr.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_sca_deep_dive.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import 'wr_discover_screen.dart' show scaStatusColor, scriptPillarColor;
import 'wr_sca_deep_dive_screen.dart' show openScaDeepDive;
import '../wr_providers.dart';
import '../../../core/widgets/wr_title_text.dart';
import '../../../core/widgets/wr_hero_header.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';
import 'package:workreflection_mobile/core/widgets/wr_back_circle.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route: /wr/self-check
// ─────────────────────────────────────────────────────────────────────────────

class WrSelfCheckScreen extends ConsumerStatefulWidget {
  const WrSelfCheckScreen({super.key});

  @override
  ConsumerState<WrSelfCheckScreen> createState() => _WrSelfCheckScreenState();
}

class _WrSelfCheckScreenState extends ConsumerState<WrSelfCheckScreen> {
  // 1..15 = câu hỏi (chỉ số 0-based bên trong), 16 = kết quả.
  //
  // Không còn màn giới thiệu: script (`scaQuestionScreen`) mở thẳng vào câu 1.
  int _step = 1;
  final Map<String, int> _answers = {}; // questionId → score 1-5
  bool _saving = false;
  String? _errorMsg;

  /// Lượt hẹn tự nhảy sang câu kế. Luôn nhiều nhất MỘT lượt đang chờ.
  ///
  /// Trước đây đây là `Future.delayed` không giữ tay cầm, nên mỗi lượt chạm hẹn
  /// thêm một lần nhảy. Chọn "Đôi khi" rồi đổi ý bấm "Thường xuyên" — thao tác
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

  /// Năm mức trả lời, nguyên văn `LIKERT` của script. Mức thứ i lưu là i + 1
  /// (thang 1–5 như mọi bản ghi cũ trong DB); đổi chữ không đổi giá trị lưu.
  static List<String> get _likertLabels => [
    tr('Không bao giờ', 'Never'),
    tr('Hiếm khi', 'Rarely'),
    tr('Đôi khi', 'Sometimes'),
    tr('Thường xuyên', 'Often'),
    tr('Gần như luôn luôn', 'Almost always'),
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
  /// Script đóng thẳng (`setState({screen:'main'})`), không hỏi lại. Bài làm
  /// dở không được lưu ở đâu: bộ câu hỏi chỉ ghi xuống khi trả lời đủ 15 câu.
  void _close() {
    _advanceTimer?.cancel();
    context.pop();
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
      if (mounted) {
        setState(
          () =>
              _errorMsg = tr('Lưu không thành công: $e', 'Could not save: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _step >= 16 ? _buildResult() : _buildQuestion();
  }

  // ── Question ───────────────────────────────────────────────────────────────

  Widget _buildQuestion() {
    final q = _currentQuestion;
    final progress = _questionIndex / kSelfCheckQuestions.length;
    final current = _answers[q.id];

    return WrInnerBandBackdrop(
      art: WrHeroArt.understand,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                        // Nằm trên dải ảnh đầu màn (v55): `lineSoft` chìm vào ảnh.
                        backgroundColor: WrColors.navy.withValues(alpha: 0.18),
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
                            // Câu 1 lùi nữa là rời bộ câu hỏi, đúng script.
                            if (_step > 1) {
                              setState(() => _step--);
                            } else {
                              _close();
                            }
                          },
                          icon: const WrNavCircle.back(),
                          color: WrColors.dark,
                          tooltip: tr('Câu trước', 'Previous'),
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        const Spacer(),
                        Text(
                          wrKeepCompounds(tr(
                            'Câu ${_questionIndex + 1} / '
                                '${kSelfCheckQuestions.length}',
                            'Question ${_questionIndex + 1} / '
                                '${kSelfCheckQuestions.length}',
                          )),
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
                          onPressed: _close,
                          style: TextButton.styleFrom(
                            foregroundColor: WrColors.text2,
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            wrKeepCompounds(tr('Đóng', 'Close')),
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
                      WrTitleText(
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
                                constraints: const BoxConstraints(
                                  minHeight: 56,
                                ),
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
                                        wrKeepCompounds(_likertLabels[i]),
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
                                        Icons.check_circle_outlined,
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
      ),
    );
  }

  // ── Result ─────────────────────────────────────────────────────────────────
  //
  // Đúng `scaResultScreen` của script: eyebrow "Kết quả khảo sát", tiêu đề
  // "Điều kiện xung quanh bạn", MỘT thẻ ba trụ (huy hiệu chữ cái · tên đầy đủ ·
  // mức), rồi thẻ navy khoá Premium với đoạn mẫu làm mờ và một nút.
  //
  // Đã bỏ những gì script không có: khối "ĐIỀU ĐÁNG CHÚ Ý NHẤT", các mục diễn
  // giải sâu xổ ra tại chỗ, phần trăm dưới thanh điểm, hai nút "Vào Thực hành"
  // / "Xem Hành trình". Diễn giải đầy đủ nằm ở màn Diễn giải sâu.

  Widget _buildResult() {
    final entitlement =
        ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final premium = entitlement.canUseFeature(
      WrPremiumFeature.selfCheckDeepDive,
    );
    final scores = [
      (SelfCheckPillar.s, _sScore),
      (SelfCheckPillar.c, _cScore),
      (SelfCheckPillar.a, _aScore),
    ];

    return WrInnerBandBackdrop(
      art: WrHeroArt.understand,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            key: const Key('wr_self_check_result'),
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const WrNavCircle.back(),
                  color: WrColors.dark,
                  tooltip: tr('Quay lại', 'Back'),
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              WrEyebrow(tr('Kết quả khảo sát', 'Survey results')),
              const SizedBox(height: 6),
              WrTitleText(
                tr('Điều kiện xung quanh bạn', 'The conditions around you'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
              if (_saving) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(color: WrColors.navy),
              ],
              if (_errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  wrKeepCompounds(_errorMsg!),
                  style: const TextStyle(fontSize: 14.5, color: WrColors.coral),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: WrColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: WrColors.line),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < scores.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: WrColors.lineSoft),
                      _PillarResultRow(
                        pillar: scores[i].$1,
                        score: scores[i].$2,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ResultLockCard(
                premium: premium,
                onTap: () => openScaDeepDive(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Một hàng của thẻ kết quả: huy hiệu chữ cái của trụ, tên đầy đủ, mức.
class _PillarResultRow extends StatelessWidget {
  const _PillarResultRow({required this.pillar, required this.score});

  final SelfCheckPillar pillar;
  final double score;

  @override
  Widget build(BuildContext context) {
    final rated = score > 0;
    final status = rated ? scaPillarStatus(score) : null;
    final code = switch (pillar) {
      SelfCheckPillar.s => 'S',
      SelfCheckPillar.c => 'C',
      SelfCheckPillar.a => 'A',
    };
    return Padding(
      key: Key('wr_self_check_result_${pillar.name}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scriptPillarColor(pillar),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              wrKeepCompounds(code),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: WrColors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              wrKeepCompounds(scaPillarFullName(pillar)),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            wrKeepCompounds(status?.label ?? tr('Chưa đánh giá', 'Not rated yet')),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: status == null ? WrColors.text3 : scaStatusColor(status),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ navy khoá Premium của màn kết quả.
///
/// Đoạn chữ làm mờ là ĐOẠN MẪU của script (`blurbox`), không phải diễn giải của
/// người dùng: nó chỉ để báo rằng phía sau có một đoạn văn, và không đọc được.
/// Nút mở màn Diễn giải sâu khi đã Premium, chưa thì qua paywall `sca_deep`.
class _ResultLockCard extends StatelessWidget {
  const _ResultLockCard({required this.premium, required this.onTap});

  final bool premium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_self_check_result_lock'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: WrColors.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: WrColors.cream.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 13, color: WrColors.cream),
                SizedBox(width: 4),
                Text(
                  'Premium',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.cream,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
              child: Text(
                wrKeepCompounds(tr(
                  'Cấu trúc đang hỗ trợ khá tốt, nhưng niềm tin để lên tiếng '
                      'chưa đồng đều khi áp lực tăng, đây là điểm nên chú ý '
                      'trước...',
                  'The structure is supporting you fairly well, but trust to '
                      'speak up wavers when pressure rises, and that is the '
                      'point to watch first...',
                )),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: WrColors.cream,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('wr_self_check_result_cta'),
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: WrColors.coral,
              foregroundColor: WrColors.navy,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              wrKeepCompounds(premium
                  ? tr('Xem diễn giải sâu', 'See the deep reading')
                  : tr('Xem diễn giải đầy đủ', 'See the full reading')),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
