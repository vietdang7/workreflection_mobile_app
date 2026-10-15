// Hiểu mình — Meaning Surface (WXS §8.5), bố cục theo mockup v47
// `screenUnderstand`.
//
// Thứ tự khối, đúng mockup:
//   hero `understand` "Những điều đang lặp lại"
//   → thẻ đầu trang: "Trong N lần nhìn lại gần đây, điều quay lại với bạn
//     nhiều nhất là …" + "Điều này có đúng với bạn không?"
//   → "Những vòng lặp quen thuộc": mỗi tình huống một dòng, chạm mở ra từng lần
//   → thẻ Self-Check → "Xem theo nhóm trải nghiệm" (thu gọn, mở ra mới thấy
//     Career Snapshot) → thẻ navy Premium "Diễn giải sâu & xu hướng".
//
// Khối "Điều bạn đang tìm kiếm" (đọc vị nhu cầu, Premium) đã rời màn này: thẻ
// đầu trang v47 thay đúng chỗ của nó.
//
// Nhãn cố tình không kèm chữ "SCA" (v1.6 §XII.5: thuật ngữ nội bộ không phơi
// ra người dùng), dù bên dưới vẫn là ba trụ SCA.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_career_health.dart';
import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/logic/wr_sca_deep_dive.dart'
    show ScaPillarStatus, scaPillarStatus;
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text_scale.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_link_row.dart';
import 'wr_sca_deep_dive_screen.dart' show openScaDeepDive;
import '../growth_providers.dart'
    show practiceEnrollmentsProvider, practiceThemesProvider;
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

/// Số lần lặp tối thiểu để hệ thống dám đọc ra nguyên nhân sâu.
/// Yêu cầu khách: "người dùng lặp lại một vấn đề 5 lần".
const int kInsightThreshold = 5;

/// Dưới ngưỡng này thanh so sánh mờ đi — vừa chớm thành nếp thì chưa tô đậm.
///
/// Buộc vào [kRepeatedSituationsMinCount]: bậc thấp nhất còn được hiện là bậc
/// mờ. Để nguyên số 2 như trước thì mọi dòng lọt qua ngưỡng đều đậm và trạng
/// thái mờ thành nhánh chết.
const int kPatternFaintThreshold = kRepeatedSituationsMinCount + 1;

// ---------------------------------------------------------------------------
// Trạng thái một trụ SCA, suy từ điểm tự đánh giá gần nhất (thang 1–5).
// Ngưỡng giữ đúng như màn Tự đánh giá để hai nơi không nói khác nhau.
// ---------------------------------------------------------------------------

/// null = chưa từng tự đánh giá trụ này.
///
/// Ngưỡng và bộ chữ đều UỶ LẠI `scaPillarStatus` / `ScaPillarStatus.label`, chứ
/// không chép lại. Bản trước chép — và A7 lộ ra đúng cái giá của việc chép: đổi
/// bộ nhãn phải nhớ đổi ở hai chỗ, quên một chỗ thì hai màn cùng nói về một
/// điểm số bằng hai giọng, đúng lỗi §7.2 changelog đang bắt sửa.
String pillarStatusLabel(double? score) {
  if (score == null || score <= 0) return tr('Chưa đánh giá', 'Not rated yet');
  return scaPillarStatus(score).label;
}

/// Điểm một trụ trong một lần tự đánh giá.
double? scaScoreFor(ScaSelfCheckResponse? r, SelfCheckPillar pillar) =>
    switch (pillar) {
      SelfCheckPillar.s => r?.structureScore,
      SelfCheckPillar.c => r?.cultureScore,
      SelfCheckPillar.a => r?.activityScore,
    };

/// Cột "Bạn đánh giá" của Career Snapshot có gì để hiện chưa.
///
/// Đòi CẢ BA trụ có điểm chứ không chỉ đòi `latest != null`: có bản ghi thiếu
/// câu thật trong DB (di chứng lỗi nuốt câu đã vá ở `wr_self_check_screen`), và
/// một cột hiện hai dòng rồi bỏ trống dòng thứ ba đọc như lỗi tải dở.
bool snapshotHasSelfCheck(ScaSelfCheckResponse? latest) =>
    latest != null &&
    SelfCheckPillar.values.every((p) => (scaScoreFor(latest, p) ?? 0) > 0);

/// Người dùng đang tự chấm trụ này là ỔN.
///
/// Chỉ mức cao nhất mới tính, đúng luật `ScaPillarStatus.isReassuring` của màn
/// Diễn giải sâu: "Ổn, còn dư địa" nằm giữa thang 1–5 và người tự chấm như vậy
/// KHÔNG nói rằng mình ổn — gộp nó vào đây thì câu "bạn tự đánh giá phần này
/// ổn, nhưng…" sẽ bịa lại lời của họ.
///
/// So với chính `ScaPillarStatus.developing.label` chứ không viết thẳng chuỗi:
/// đợt sau đổi chữ lần nữa thì hàm này đi theo, không âm thầm trả về false cho
/// mọi trụ.
bool pillarStatusIsReassuring(String label) =>
    label == ScaPillarStatus.developing.label;

Color pillarStatusColor(double? score) {
  if (score == null || score <= 0) return WrColors.muted;
  return scaStatusColor(scaPillarStatus(score));
}

/// Màu của ba mức, đúng `pillarLevelText` của script: xanh #0E7A76 · vàng nâu
/// #B8862F · đỏ #C6402F.
Color scaStatusColor(ScaPillarStatus status) => switch (status) {
  ScaPillarStatus.developing => WrColors.pillTealText,
  ScaPillarStatus.needsAttention => const Color(0xFF94681A),
  ScaPillarStatus.priority => WrColors.pillCoralText,
};

/// Màu chấm của ba trụ trong các màn Diễn giải, đúng `SNAPSHOT_PILLARS` của
/// script: Sự rõ ràng navy · Mối quan hệ coral · Cách làm việc teal.
Color scriptPillarColor(SelfCheckPillar pillar) => switch (pillar) {
  SelfCheckPillar.s => WrColors.navy,
  SelfCheckPillar.c => WrColors.coral,
  SelfCheckPillar.a => WrColors.teal,
};

/// Màu nhận diện của từng trụ — trùng với màn Tự đánh giá.
Color pillarColor(SelfCheckPillar pillar) => switch (pillar) {
  SelfCheckPillar.s => const Color(0xFF5B8CC9),
  SelfCheckPillar.c => WrColors.teal,
  SelfCheckPillar.a => const Color(0xFF5E7A5A),
};

class WrDiscoverScreen extends ConsumerWidget {
  const WrDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final selfChecks =
        ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];
    // Nguồn sự thật duy nhất của cả màn này (Kiến trúc v2.0 §4.3). Không còn
    // đọc `wr_pattern_counts` ở đâu trên màn Hiểu mình.
    final recent = recentSituationIds(episodes);

    final sitMap = {for (final s in situations) s.code: s.text};
    final latestCheck = selfChecks.isEmpty ? null : selfChecks.first;

    // Những điều đang lặp lại — v2.0 §4.3: đếm số lần xuất hiện của từng
    // situationId trong recentSituationIds. Chỉ những điều đã trở lại từ
    // [kRepeatedSituationsMinCount] lần mới được gọi là đang lặp (họp 26_1).
    final repeated = rankSituations(
      recent,
      minCount: kRepeatedSituationsMinCount,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Không bọc SafeArea: ảnh hero tràn lên dưới thanh trạng thái.
      body: ListView(
        // Padding tường minh: `ListView` không có padding sẽ xoá phần thanh
        // trạng thái khỏi `MediaQuery` của con, ảnh hero hết tràn lên.
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          WrHeroHeader.inner(
            key: const Key('wr_discover_hero'),
            art: WrHeroArt.understand,
            eyebrow: tr('Hiểu mình', 'Understand'),
            title: tr('Những điều đang lặp lại', 'What keeps coming back'),
            subtitle: tr(
              // Ngắt sẵn thành hai dòng (họp khách 14/10).
              'Sau một thời gian nhìn lại,\ncó những điều thường lặp lại.',
              'After a while of looking back,\ncertain things tend to recur.',
            ),
            // v1.6 §9.1: "Tôi" là avatar ở mọi màn tab, không còn tab riêng.
            trailing: const WrProfileAvatar(),
          ),
          const SizedBox(height: WrHeroHeader.kContentGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WrTabBackLink(currentTab: WrTab.discover),
                _TopPatternCard(
                  key: const Key('wr_discover_top_pattern'),
                  recentTotal: recent.length,
                  reflectionTotal: episodes.length,
                  repeated: repeated,
                  labels: sitMap,
                ),
                const SizedBox(height: 18),
                const _SystemExperienceCard(),
                const SizedBox(height: 18),
                _SelfCheckInviteCard(
                  answered: latestCheck?.answers.length ?? 0,
                  onStart: () => context.push('/wr/self-check'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thẻ đầu trang — "Trong N lần nhìn lại gần đây, điều quay lại với bạn nhiều
// nhất là …" (mockup v47). Hỏi lại người dùng có đúng không; câu trả lời được
// nhớ theo từng tình huống để lần sau mở tab không hỏi lại.
// ---------------------------------------------------------------------------

/// Câu trả lời cho "Điều này có đúng với bạn không?".
enum PatternFeedback { yes, no }

String _patternFeedbackKey(String uid, String code) =>
    'wr_pattern_feedback_${uid}_$code';

class _TopPatternCard extends ConsumerStatefulWidget {
  const _TopPatternCard({
    super.key,
    required this.recentTotal,
    required this.reflectionTotal,
    required this.repeated,
    required this.labels,
  });

  /// Số lần nhìn lại có chọn tình huống trong cửa sổ gần đây — mẫu số của
  /// câu "N lần trong T lần nhìn lại", cùng phạm vi với số đếm N, và cùng con
  /// số ở màn danh sách.
  final int recentTotal;

  /// Tổng số lần nhìn lại thật (mọi thời gian).
  final int reflectionTotal;
  final List<RepeatedSituation> repeated;
  final Map<String, String> labels;

  @override
  ConsumerState<_TopPatternCard> createState() => _TopPatternCardState();
}

class _TopPatternCardState extends ConsumerState<_TopPatternCard> {
  PatternFeedback? _feedback;

  String? get _topCode =>
      widget.repeated.isEmpty ? null : widget.repeated.first.situationCode;

  @override
  void initState() {
    super.initState();
    _clearPersistedFeedback();
  }

  Future<void> _clearPersistedFeedback() async {
    final uid = ref.read(currentUserIdProvider);
    final code = _topCode;
    if (uid == null || code == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_patternFeedbackKey(uid, code));
    } catch (_) {
      /* ignore */
    }
  }

  void _answer(PatternFeedback f) {
    setState(() => _feedback = f);
  }

  void _resetAnswer() {
    setState(() => _feedback = null);
    _clearPersistedFeedback();
  }

  @override
  Widget build(BuildContext context) {
    final code = _topCode;

    // Hai kiểu rỗng khác hẳn nhau: chưa chọn tình huống lần nào, và đã chọn
    // mà chưa điều nào lặp tới ngưỡng. Kiểu thứ hai phải nói rõ là đã ghi
    // nhận, kẻo người dùng tưởng app nuốt mất dữ liệu.
    if (code == null) {
      return WrCard(
        child: WrParagraph(
          widget.recentTotal == 0
              ? tr(
                  'Sau vài lần nhìn lại có chọn tình huống, những điều lặp lại '
                      'sẽ hiện ra ở đây.',
                  'After a few look-backs where you pick a situation, the '
                      'things that repeat will show up here.',
                )
              : tr(
                  'Bạn đã chọn tình huống ${widget.recentTotal} lần, nhưng chưa '
                      'điều nào trở lại đủ $kRepeatedSituationsMinCount lần. Khi '
                      'một điều quay lại tới đó, nó sẽ hiện ở đây.',
                  'You have picked a situation ${widget.recentTotal} times, but '
                      'none has come back $kRepeatedSituationsMinCount times '
                      'yet. Once one does, it will appear here.',
                ),
          key: Key(
            widget.recentTotal == 0
                ? 'wr_discover_patterns_empty'
                : 'wr_discover_patterns_below_threshold',
          ),
          textAlign: TextAlign.start,
          style: _muted,
        ),
      );
    }

    final top = widget.repeated.first;
    final others = widget.repeated.skip(1).toList();

    return WrCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('/wr/patterns'),
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wrKeepCompounds(tr('QUAY LẠI NHIỀU NHẤT', 'RETURNED MOST')),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: WrColors.text3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  wrKeepCompounds('“${situationLabelFor(widget.labels, code)}”'),
                  key: const Key('wr_discover_top_title'),
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    fontStyle: FontStyle.italic,
                    fontSize: 17,
                    color: WrColors.navy,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  wrKeepCompounds(tr(
                    '${top.count} lần trong ${widget.recentTotal} lần nhìn lại',
                    '${top.count} times in ${widget.recentTotal} look-backs',
                  )),
                  key: const Key('wr_discover_top_count'),
                  style: const TextStyle(fontSize: 11.5, color: WrColors.text3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          switch (_feedback) {
            null => _askView(),
            PatternFeedback.yes => _yesView(context),
            PatternFeedback.no => _noView(),
          },
          if (others.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 13),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: WrColors.lineSoft)),
              ),
              child: InkWell(
                key: const Key('wr_discover_repeat_list_link'),
                onTap: () => context.push('/wr/patterns'),
                child: Row(
                  children: [
                    // Script: 13px w600 navy, một dòng. Cỡ chữ hệ thống lớn
                    // (máy thật 1.15) thì thu chữ cho vừa thay vì xuống hàng.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          wrKeepCompounds(tr(
                            'Những điều khác đang lặp lại',
                            'Other recurring patterns',
                          )),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: WrColors.navy,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Script `.tiny` teal 700: 11px.
                    Text(
                      wrKeepCompounds(tr('${others.length} điều ›', '${others.length} items ›')),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: WrColors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _askView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Script `.tiny` 700: 11px, màu chữ phụ, một dòng. Cỡ chữ hệ thống lớn
      // (máy thật 1.15, 13/10) thì thu chữ cho vừa thay vì xuống hàng.
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          wrKeepCompounds(tr('Điều này có đúng với bạn không?', 'Does this ring true for you?')),
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: WrColors.text3,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _GhostSmallButton(
              key: const Key('wr_discover_feedback_yes'),
              label: tr('Đúng với tôi', 'That is me'),
              onTap: () => _answer(PatternFeedback.yes),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _GhostSmallButton(
              key: const Key('wr_discover_feedback_no'),
              label: tr('Chưa đúng lắm', 'Not quite'),
              onTap: () => _answer(PatternFeedback.no),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _yesView(BuildContext context) => _SoftTop(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                wrKeepCompounds(tr(
                  'Vậy thì đây có thể là chỗ đáng để bạn dành thêm chú ý trong thời '
                      'gian tới.',
                  'Then this may be worth a bit more of your attention in the '
                      'coming weeks.',
                )),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: WrColors.text2,
                  height: 1.6,
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _resetAnswer,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: WrColors.text3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Align(
          alignment: Alignment.centerLeft,
          child: _PrimarySmallButton(
            key: const Key('wr_discover_feedback_practice'),
            label: tr(
              'Xem chủ đề thực hành liên quan',
              'See related practice themes',
            ),
            onTap: () async {
              final route = await _relatedPracticeRoute();
              if (context.mounted) context.go(route);
            },
          ),
        ),
      ],
    ),
  );

  /// Chủ đề đang theo cùng chiều SCA với điều lặp lại ở đầu trang. Trước đây nút
  /// chỉ mở tab Phát triển chung chung, người dùng phải tự dò xem chủ đề nào
  /// "liên quan". Chưa theo chủ đề nào cùng chiều thì vẫn về tab Phát triển:
  /// chủ đề do phần mềm tự thêm, không mở một chủ đề chưa ghi danh.
  Future<String> _relatedPracticeRoute() async {
    final code = _topCode;
    final situations = ref.read(wrSituationsProvider).valueOrNull ?? const [];
    final dim = situations
        .where((s) => s.code == code)
        .firstOrNull
        ?.scaDimension;
    if (dim == null) return '/wr/growth';
    final themes = await ref.read(practiceThemesProvider.future);
    final enrollments = await ref.read(practiceEnrollmentsProvider.future);
    for (final e in enrollments.where((e) => e.completedAt == null)) {
      final t = themes.where((t) => t.themeId == e.themeId).firstOrNull;
      if (t != null && !t.isRetired && t.scaDimension == dim) {
        return '/wr/growth/theme/${t.themeId}';
      }
    }
    return '/wr/growth';
  }

  Widget _noView() => _SoftTop(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            wrKeepCompounds(tr(
              'Cảm ơn bạn đã cho biết. Quan sát này sẽ được đọc lại sau vài lần nhìn lại nữa.',
              'Thanks for letting us know. This observation will be revisited after a few more reflections.',
            )),
            style: const TextStyle(
              fontSize: 12.5,
              color: WrColors.text2,
              height: 1.6,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _resetAnswer,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.refresh_rounded, size: 18, color: WrColors.text3),
          ),
        ),
      ],
    ),
  );
}

/// Phần trả lời nằm dưới một vạch mảnh (`border-top: 1px solid --line-soft`).
class _SoftTop extends StatelessWidget {
  const _SoftTop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: WrColors.lineSoft)),
    ),
    child: child,
  );
}

/// `.muted` (12.5px) +1.5 theo quy ước cỡ chữ của app.
const _muted = TextStyle(fontSize: 14, color: WrColors.text2, height: 1.65);

/// `.btn.btn-ghost.btn-sm`.
class _GhostSmallButton extends StatelessWidget {
  const _GhostSmallButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8.5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: const Color(0x40093774), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      // Cỡ chữ hệ thống lớn (máy thật 1.15, 13/10) làm "Chưa đúng lắm" tràn
      // nửa ô và bị cắt thành "Chưa đúng lần": thu chữ lại cho vừa thay vì cắt.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          wrKeepCompounds(label),
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
      ),
    ),
  );
}

/// `.btn.btn-primary.btn-sm`.
class _PrimarySmallButton extends StatelessWidget {
  const _PrimarySmallButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
      decoration: BoxDecoration(
        color: WrColors.coral,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        wrKeepCompounds(label),
        maxLines: 1,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: WrColors.navy,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Một dòng tình huống lặp lại — số lần + thanh so sánh, không diễn giải.
// ---------------------------------------------------------------------------

class WrPatternRow extends StatelessWidget {
  const WrPatternRow({
    super.key,
    required this.label,
    required this.count,
    required this.ratio,
    required this.onTap,
  });

  final String label;
  final int count;
  final double ratio;
  final VoidCallback onTap;

  bool get _isStrong => count >= kInsightThreshold;
  bool get _isFaint => count < kPatternFaintThreshold;

  @override
  Widget build(BuildContext context) {
    final barColor = _isStrong
        ? WrColors.coral
        : WrColors.navy.withValues(alpha: _isFaint ? 0.4 : 1);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  // Tên tình huống hay dài hơn một dòng; canh trái như cũ,
                  // chỉ chặn chỗ ngắt cuối để không còn "…nhưng đi / đâu?".
                  child: WrParagraph(
                    label,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: WrColors.navy,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  wrKeepCompounds(tr('$count lần', '$count times')),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: _isStrong ? FontWeight.w700 : FontWeight.w600,
                    color: _isStrong
                        ? WrColors.coral
                        : (_isFaint ? WrColors.muted : WrColors.navy),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 11,
                  color: WrColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            WrProgressTrack(value: ratio, color: barColor),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Career Snapshot — MỘT khối, mỗi trụ đúng một dòng, hai nguồn đặt cạnh nhau
// ---------------------------------------------------------------------------
//
// Thay hẳn hai khối cũ: "Trải nghiệm hiện tại" (`_ScaCard`) và "Career Health
// Check" (`_CareerHealthCard`). Nguồn: `Changelog_CareerSnapshot.docx` §3,
// hàm tham chiếu `careerSnapshotCard()` trong mockup v18.
//
// VÌ SAO PHẢI GỘP. Sau khi Career Health Check mở khoá, CÙNG ba trụ xuất hiện
// hai lần trong một màn hình, cách nhau vài dòng, với kết luận ngược nhau:
//
//     Sự rõ ràng      Ổn, còn dư địa   |   Đang hỗ trợ tốt
//     Mối quan hệ     Ổn, còn dư địa   |   Đang cản trở
//     Cách làm việc   Ổn, còn dư địa   |   Ổn, còn dư địa
//
// Người dùng đọc đây là lỗi hệ thống, không phải hai góc nhìn bổ sung nhau. §1
// chỉ đúng dấu hiệu: khi giao diện cần một đoạn văn để giải thích vì sao hai
// bảng giống hệt nhau lại nói ngược nhau, thì thiết kế đang sai, không phải
// người dùng chưa hiểu. Bản trước có đúng đoạn văn đó.
//
// Nguyên nhân kỹ thuật (§1.1): hai khối dùng chung MỘT thang từ vựng đánh giá.
// Dùng chung thang đo thì người đọc mặc định chúng đang đo cùng một đối tượng.
//
// HAI NGUỒN ĐO HAI THỨ KHÁC NHAU (§2):
//
//                  Self-Check                  Pattern Reflection
//   Hỏi            "Môi trường của tôi có       "Chuyện thiếu rõ ràng có hay
//                   rõ ràng không?"              xảy đến với tôi không?"
//   Đo             CHẤT LƯỢNG điều kiện        TẦN SUẤT trải nghiệm
//   Nguồn          tự chấm, 15 câu             hành vi thật, tích luỹ
//   Tính chất      ảnh chụp một thời điểm      dòng chảy liên tục
//   Từ vựng        thang đánh giá              thang tần suất — SỐ LẦN, hết
//
// Nên cột phải KHÔNG có nhãn đánh giá nào. Xem khối chú thích ở
// `wr_career_health.dart` chỗ đã bỏ `behaviourPillarLabel`.
//
// BA TRẠNG THÁI (§4). Hai nguồn độc lập, mỗi nguồn tự mở phần của mình. Không
// bắt buộc phải có cả hai mới hiện khối. Lý do: Reflection là thói quen hàng
// ngày nằm ngay Home, còn Self-Check phải chủ động tìm vào tab Hiểu. Đa số
// người dùng tích luỹ Reflection trước, và nhiều người sẽ không bao giờ làm
// Self-Check. Khoá cả khối cho đến khi đủ hai nguồn là vừa lãng phí dữ liệu họ
// đã tạo ra, vừa biến một việc vốn tuỳ chọn thành cửa ải bắt buộc.
//
// Ô TRỐNG LÀ LỜI MỜI, KHÔNG PHẢI Ổ KHOÁ. Không dùng hiệu ứng mờ cho các ô
// trống này — mờ đang dành riêng cho nội dung Premium. Nhầm hai tín hiệu là để
// người dùng tưởng phải trả tiền mới xem được, trong khi chỉ cần làm thêm một
// việc miễn phí.
// ---------------------------------------------------------------------------

class WrCareerSnapshotCard extends ConsumerWidget {
  const WrCareerSnapshotCard({
    super.key,
    required this.latest,
    required this.counts,
    required this.reflectionTotal,
    required this.classifiedTotal,
    required this.dominant,
    required this.onStartSelfCheck,
  });

  /// Lần tự đánh giá gần nhất. Null = chưa từng làm.
  final ScaSelfCheckResponse? latest;

  /// Số lần mỗi trụ bị chạm, đếm trên toàn bộ lịch sử nhìn lại.
  final Map<SelfCheckPillar, int> counts;

  /// Tổng số lần nhìn lại. Nuôi ngưỡng mở khoá và câu dẫn đầu thẻ.
  ///
  /// KHÔNG phải mẫu số của cột "Xuất hiện" nữa — xem [classifiedTotal]. Vẫn
  /// phải là con số này ở hai chỗ kia, vì đó đúng là con số người dùng nhìn
  /// thấy ở "Hành trình đã đi" và ở thanh tiến độ 15 lần.
  final int reflectionTotal;

  /// Mẫu số của cột "Xuất hiện" — số lượt gắn được vào một trụ.
  ///
  /// Nhỏ hơn [reflectionTotal] đúng bằng số lượt tự viết không có mã tình
  /// huống. §2.3 của `DienGiaiSau v2` đoán hai con số sẽ bằng nhau sau khi gán
  /// trụ cho nhóm P; thực tế còn chênh, vì nhánh "Điều khác" của luồng Reflect
  /// không ghi `situation_code` nào.
  final int classifiedTotal;

  /// Trụ nổi trội, hoặc null khi phân bố tương đối đều.
  ///
  /// TRUYỀN VÀO, không tự tính. Cột "Xuất hiện" của thẻ này đọc [counts] và
  /// [classifiedTotal] — hai con số gồm cả tình huống tích cực — còn trụ nổi
  /// trội thì §2.2 tính trên riêng lượt thách thức. Tự tính lại từ [counts] là
  /// ra một câu trả lời khác với màn cha (khách báo 12/09/2026: hai chỗ tự
  /// tính bằng hai mẫu số thì mất lối vào Diễn giải sâu).
  final SelfCheckPillar? dominant;

  final VoidCallback onStartSelfCheck;

  double? _scoreOf(SelfCheckPillar pillar) => scaScoreFor(latest, pillar);

  bool get _hasSelfCheck => snapshotHasSelfCheck(latest);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReflection = careerHealthUnlocked(reflectionTotal);
    final takenAt = latest?.takenAt;

    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrEyebrow('CAREER SNAPSHOT'),
          const SizedBox(height: 6),
          // Hai câu dẫn, chọn theo việc cột "Xuất hiện" đã mở hay chưa.
          //
          // Câu khi ĐÃ MỞ là nguyên văn khách duyệt (file "Các nội dung cần
          // điều chỉnh" 09/09). Nó nói "Bức tranh tổng quan sau N lần nhìn
          // lại" — một lời tổng kết, chỉ đúng khi thật sự đã có bức tranh.
          //
          // Chưa đủ ngưỡng thì KHÔNG dùng câu ấy: "Bức tranh tổng quan sau 0
          // lần nhìn lại" vừa vô nghĩa vừa hứa một thứ màn hình chưa có. Lúc
          // đó câu dẫn phải làm việc khác — giải thích thẻ này đọc từ HAI
          // nguồn nào — vì ngay dưới nó là hai lời mời bổ sung từng nguồn.
          WrParagraph(
            hasReflection
                ? tr(
                    'Bức tranh tổng quan sau $reflectionTotal lần nhìn lại. Dựa '
                        'trên những ghi nhận của bạn, hệ thống đã đúc kết ra trạng '
                        'thái trải nghiệm của bạn trong thời gian qua.',
                    'An overview after $reflectionTotal look-backs. From what you '
                        'have recorded, the app has drawn out how your experience '
                        'has been lately.',
                  )
                : tr(
                    'Cùng ba trụ, nhìn từ hai phía: điều bạn tự đánh giá, và điều đang '
                        'thực sự lặp lại trong các lần nhìn lại.',
                    'The same three pillars, seen from two sides: what you rate yourself, '
                        'and what actually keeps coming back in your look-backs.',
                  ),
            style: TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),

          // §5 — Self-Check cũ đi theo thời gian, nên LUÔN hiện thời điểm kèm
          // cột đánh giá. Một người chấm hồi tháng 3 rồi phản chiếu đều tới
          // tháng 9 mà màn hình vẫn nói "Bạn đánh giá: Cần chú ý" như đánh giá
          // hiện tại là sai lệch — và hệ thống còn lấy chính con số cũ đó đối
          // chiếu với hành vi mới, nên kết luận khoảng lệch sai theo.
          if (_hasSelfCheck && takenAt != null) ...[
            const SizedBox(height: 10),
            Text(
              wrKeepCompounds(tr(
                'Self-Check gần nhất: ${selfCheckDateLabel(takenAt)}',
                'Last Self-Check: ${selfCheckDateLabel(takenAt)}',
              )),
              key: const Key('wr_snapshot_self_check_date'),
              style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
            ),
            if (selfCheckIsStale(takenAt, DateTime.now())) ...[
              const SizedBox(height: 6),
              WrParagraph(
                tr(
                  'Đã hơn ${kSelfCheckStaleDays ~/ 30} tháng kể từ lần đó. Công '
                      'việc có thể đã khác đi, bạn thử cập nhật lại để bức tranh sát '
                      'với hiện tại hơn nhé.',
                  'That was over ${kSelfCheckStaleDays ~/ 30} months ago. Work may have '
                      'changed since, so it is worth updating to keep the picture '
                      'close to now.',
                ),
                key: const Key('wr_snapshot_self_check_stale'),
                style: const TextStyle(
                  fontSize: 13.5,
                  color: WrColors.muted,
                  height: 1.55,
                ),
              ),
            ],
          ],

          const SizedBox(height: 8),
          for (final pillar in SelfCheckPillar.values)
            _SnapshotRow(
              key: Key('wr_snapshot_pillar_${pillar.name}'),
              pillar: pillar,
              // Nhãn của cột trái vẫn là thang đánh giá đã có (§3: "giữ nguyên
              // thang đánh giá đã có, lấy từ pillarLevelText").
              rating: _hasSelfCheck
                  ? pillarStatusLabel(_scoreOf(pillar))
                  : null,
              ratingColor: pillarStatusColor(_scoreOf(pillar)),
              count: hasReflection ? counts[pillar] ?? 0 : null,
              total: classifiedTotal,
              last: pillar == SelfCheckPillar.values.last,
            ),

          // ── Lời mời cho nguồn còn trống ───────────────────────────────
          //
          // HAI `if` độc lập, không phải if/else. Mockup v18 dùng else-if nên
          // người mới — chưa Self-Check, mới nhìn lại vài lần — chỉ thấy lời
          // mời làm Self-Check và không bao giờ biết cột bên kia còn thiếu bao
          // nhiêu. §4 nói rõ hai nguồn độc lập, mỗi nguồn tự mở phần của mình;
          // vậy thì mỗi nguồn cũng tự nói phần của mình còn thiếu gì.
          if (!_hasSelfCheck)
            _SnapshotInvite(
              key: const Key('wr_snapshot_invite_self_check'),
              text: tr(
                'Cột "Bạn đánh giá" sẽ hiện sau khi bạn trả lời bộ '
                    'khảo sát ${kSelfCheckQuestions.length} câu, để so với '
                    'những gì đang thực sự lặp lại.',
                'The "You rate" column appears once you answer the '
                    '${kSelfCheckQuestions.length}-question survey, so it can '
                    'sit next to what actually keeps repeating.',
              ),
              action: _SnapshotButton(
                label: tr('Làm khảo sát', 'Take the survey'),
                onTap: onStartSelfCheck,
              ),
            ),
          if (!hasReflection)
            _SnapshotInvite(
              key: const Key('wr_snapshot_invite_reflection'),
              text: tr(
                'Cột "Xuất hiện" sẽ mở sau '
                    '${kCareerHealthThreshold - reflectionTotal} lần nhìn lại '
                    'nữa, khi đã đủ dữ liệu để thấy điều gì đang trở đi trở lại. '
                    'Một lần được tính khi bạn đã chọn một tình huống; chạm ô cảm '
                    'xúc rồi rời đi thì lần đó chưa vào đây.',
                'The "Shows up" column opens after '
                    '${kCareerHealthThreshold - reflectionTotal} more look-backs, '
                    'once there is enough to see what keeps returning. One counts '
                    'when you have picked a situation; tapping a feeling and '
                    'leaving does not count yet.',
              ),
              action: WrProgressTrack(
                value: reflectionTotal / kCareerHealthThreshold,
                color: WrColors.coral,
              ),
            ),

          // KHÔNG có lối sang danh sách tình huống lặp lại ở đây.
          //
          // Thẻ này từng mang một `WrLinkRow` "Xem các vấn đề thường lặp lại",
          // trong khi mục "Tình huống lặp lại" ngay phía trên cũng có một lối
          // đi cùng chỗ. Người có nhiều hơn ba tình huống lặp lại thấy hai
          // đường giống hệt nhau cách nhau một màn hình — khách yêu cầu bỏ cái
          // trùng (11/09).
          //
          // Từ v47 tab không còn lối sang danh sách đầy đủ: mục "Những vòng
          // lặp quen thuộc" phía trên bày MỌI điều lặp lại và mở được từng lần
          // ngay tại chỗ.
          //
          // Nói cách khác, lỗi khách báo 24/08 ("đủ 15 lần rồi mà không có nút
          // để click vào xem bức tranh") không tái phát ở đây — lần đó cả THẺ
          // bị ẩn nên nội dung mất thật, còn giờ nội dung nằm ngay trên màn.

          // ── Dòng diễn giải khoảng lệch — chỉ khi có ĐỦ CẢ HAI nguồn ────
          if (_hasSelfCheck && hasReflection)
            _SnapshotGapLine(
              dominant: dominant,
              counts: counts,
              classifiedTotal: classifiedTotal,
              ratingOf: (p) => pillarStatusLabel(_scoreOf(p)),
            ),
        ],
      ),
    );
  }
}

/// Một trụ: tên ở trên, hai nguồn đặt cạnh nhau bên dưới.
///
/// Hai cột không còn "cãi nhau" vì hiển nhiên là hai loại thông tin khác nhau —
/// một bên là chữ đánh giá, một bên là phân số.
class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    super.key,
    required this.pillar,
    required this.rating,
    required this.ratingColor,
    required this.count,
    required this.total,
    required this.last,
  });

  final SelfCheckPillar pillar;

  /// Nhãn cột "Bạn đánh giá". Null = chưa làm Self-Check.
  final String? rating;
  final Color ratingColor;

  /// Số lần cột "Xuất hiện". Null = chưa đủ số lần nhìn lại.
  final int? count;
  final int total;

  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: WrColors.navy.withValues(alpha: 0.08),
                ),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Chấm màu, không phải chữ "S/C/A": ba trụ vẫn phân biệt được
              // bằng màu, nhưng người dùng không phải đọc mã của bộ khung nội bộ.
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pillarColor(pillar),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  wrKeepCompounds(pillar.displayName),
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: WrColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SnapshotCell(
                    caption: tr('Bạn đánh giá', 'You rate'),
                    // Ô trống là LỜI MỜI, không phải ổ khoá — chữ thường, màu
                    // nhạt, không mờ, không ổ khoá.
                    value: rating ?? tr('Chưa có', 'Nothing yet'),
                    color: rating == null ? WrColors.muted : ratingColor,
                    strong: rating != null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SnapshotCell(
                    caption: tr('Xuất hiện', 'Shows up'),
                    // Ngôn ngữ TẦN SUẤT, không nhãn đánh giá nào (§2).
                    value: count == null
                        ? tr('Chưa đủ dữ liệu', 'Not enough data')
                        : tr('$count / $total lần', '$count / $total times'),
                    color: count == null ? WrColors.muted : WrColors.navy,
                    strong: count != null,
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

class _SnapshotCell extends StatelessWidget {
  const _SnapshotCell({
    required this.caption,
    required this.value,
    required this.color,
    required this.strong,
  });

  final String caption;
  final String value;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wrKeepCompounds(caption),
          style: const TextStyle(fontSize: 13, color: WrColors.muted),
        ),
        const SizedBox(height: 3),
        // `Text` chứ KHÔNG phải `WrParagraph`: đây là một GIÁ TRỊ ngắn trong ô
        // hẹp nửa bề ngang, không phải đoạn đọc.
        //
        // `WrParagraph` căn đều hai bên. Căn đều thì dòng nào chưa phải dòng
        // chót đều bị giãn khoảng trắng cho chạm mép phải — với "Fine, room to
        // grow" trong một cột hẹp, kết quả là "Fine,⎵⎵⎵⎵⎵room / to grow", một
        // khoảng trống giữa câu đọc như lỗi hiển thị (ảnh khách 11/09).
        //
        // Bản tiếng Việt "Ổn, còn dư địa" ngắn hơn nên vừa một dòng và không
        // bao giờ lộ.
        Text(
          wrKeepCompounds(value),
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
            color: color,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Lời mời cho nguồn còn trống. Không mờ, không ổ khoá (§4).
class _SnapshotInvite extends StatelessWidget {
  const _SnapshotInvite({super.key, required this.text, required this.action});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrParagraph(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          action,
        ],
      ),
    );
  }
}

class _SnapshotButton extends StatelessWidget {
  const _SnapshotButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: WrColors.coral,
          foregroundColor: WrColors.navy,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          wrKeepCompounds(label),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dòng khoảng lệch — ranh giới miễn phí / Premium (§6)
// ---------------------------------------------------------------------------
//
// Cách đối chiếu Self-Check với Pattern Reflection CHÍNH LÀ lớp 3 của tính năng
// Premium "Diễn giải sâu". Nếu bản miễn phí đã làm đúng việc đó thì người dùng
// không còn lý do trả tiền.
//
// Nhưng cũng không giấu sạch: khi đã đủ hai nguồn mà chưa Premium, khối vẫn nói
// rằng "hai cột trên đang cho thấy một khoảng lệch", kèm nút mở khoá. Người
// dùng thấy giá trị CỤ THỂ đang bị khoá, thay vì một lời quảng cáo chung chung.
// ---------------------------------------------------------------------------

class _SnapshotGapLine extends ConsumerWidget {
  const _SnapshotGapLine({
    required this.dominant,
    required this.counts,
    required this.classifiedTotal,
    required this.ratingOf,
  });

  /// Trụ nổi trội, hoặc null khi phân bố tương đối đều.
  final SelfCheckPillar? dominant;
  final Map<SelfCheckPillar, int> counts;

  /// Mẫu số của cột "Xuất hiện" — số lượt gắn được vào một trụ.
  ///
  /// CỐ Ý không nhận tổng số lần nhìn lại. Câu trong [_gapText] dựng từ chính
  /// hai con số đang hiện ở hai cột ngay phía trên nó, nên nó phải chia cho
  /// đúng mẫu số của cột ấy. Bản 11/09 đổi cột sang mẫu số này mà để câu văn ở
  /// lại mẫu số cũ: cột hiện "9 / 31 lần" còn câu ngay dưới nói "9 trong 36
  /// lần" — cùng một tử số, hai mẫu số, cách nhau ba dòng.
  ///
  /// Không truyền `reflectionTotal` vào đây nữa để con số sai không còn với
  /// tới được từ widget này.
  final int classifiedTotal;

  final String Function(SelfCheckPillar) ratingOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pillar = dominant;
    // Chưa trụ nào vượt 40% thì KHÔNG có khoảng lệch nào để nói. Bày một dòng
    // "Khoảng lệch đáng chú ý" lên trên ba con số gần bằng nhau là khẳng định
    // một xu hướng không có thật, và bán một thứ không tồn tại.
    if (pillar == null) return const SizedBox.shrink();

    final entitlement =
        ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final premium = entitlement.canUseFeature(
      WrPremiumFeature.selfCheckDeepDive,
    );

    return Container(
      key: const Key('wr_snapshot_gap'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: WrColors.navy.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wrKeepCompounds(premium
                ? tr('Khoảng lệch đáng chú ý', 'A gap worth noticing')
                : 'Premium'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: premium ? WrColors.teal : WrColors.coral,
            ),
          ),
          const SizedBox(height: 6),
          WrParagraph(
            premium
                ? _gapText(pillar)
                : tr(
                    'Hai cột trên đang cho thấy một khoảng lệch. Mở khoá để đọc '
                        'ý nghĩa của khoảng lệch đó, và theo dõi nó thay đổi ra sao '
                        'theo thời gian.',
                    'The two columns above show a gap. Unlock to read what that gap '
                        'means, and to follow how it shifts over time.',
                  ),
            key: const Key('wr_snapshot_gap_text'),
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          if (premium)
            WrLinkRow(
              key: const Key('wr_snapshot_gap_open'),
              label: tr(
                'Xem diễn giải sâu & xu hướng',
                'See the deep reading & trends',
              ),
              onTap: () => openScaDeepDive(context, ref),
            )
          else
            // Nút trần, KHÔNG dùng `WrPremiumLock`: khối đó tự dựng một thẻ
            // hoàn chỉnh kèm ổ khoá và chữ "Premium" của riêng nó, đặt vào đây
            // là thẻ lồng trong thẻ và nói chữ "Premium" hai lần cách nhau ba
            // dòng.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wr_snapshot_gap_unlock'),
                // Mua xong đi thẳng vào màn đích, không rơi lại tab Hiểu mình.
                onPressed: () => openScaDeepDive(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.navy,
                  foregroundColor: WrColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  wrKeepCompounds(tr('Mở khoá diễn giải', 'Unlock the reading')),
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Hai nhánh của §6, dựng từ chính hai con số đang hiện ở hai cột.
  String _gapText(SelfCheckPillar pillar) {
    final rating = ratingOf(pillar).toLowerCase();
    final count = counts[pillar] ?? 0;
    final name = pillar.displayName.toLowerCase();

    // Tự chấm là ổn nhất, mà lại là trụ quay lại nhiều nhất — đây là nhánh có
    // giá trị cao nhất của cả tính năng.
    if (pillarStatusIsReassuring(ratingOf(pillar))) {
      return tr(
        'Bạn tự đánh giá $name ở mức "$rating", nhưng đây lại là trụ xuất '
            'hiện nhiều nhất trong các lần nhìn lại gần đây ($count trong '
            '$classifiedTotal lần).',
        'You rate $name as "$rating", yet this is the pillar that shows up '
            'most in your recent look-backs ($count out of '
            '$classifiedTotal).',
      );
    }
    return tr(
      '${pillar.displayName} là trụ bạn quay lại nhiều nhất ($count trong '
          '$classifiedTotal lần), và cũng là trụ bạn tự đánh giá ở mức "$rating". '
          'Hai nguồn đang xác nhận lẫn nhau.',
      '${pillar.displayName} is the pillar you return to most ($count out of '
          '$classifiedTotal), and also the one you rate as "$rating". '
          'Both sources are pointing the same way.',
    );
  }
}

// ---------------------------------------------------------------------------
// Lời mời làm Self-Check — mô tả, tiến độ lần gần nhất, nút bắt đầu.
//
// Thẻ "Trải nghiệm hiện tại" ở trên đã bấm được để mở bộ câu hỏi, nhưng nó nói
// KẾT QUẢ chứ không nói bộ câu hỏi là gì và mất bao lâu. Người chưa từng làm
// không có lý do nào để bấm vào một thẻ ghi "Chưa đánh giá" ba lần.
//
// Đây cũng là cửa của Hướng 2 (khách chốt 2026-07-31): ai không muốn đợi đủ 15
// lần check-in thì làm 15 câu này là có chủ đề thực hành ngay.
// ---------------------------------------------------------------------------

class _SelfCheckInviteCard extends StatelessWidget {
  const _SelfCheckInviteCard({required this.answered, required this.onStart});

  final int answered;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // Cỡ chữ đúng script (bỏ phần cộng thêm của WrTextScaler) và ảnh tan vào
    // nền navy qua một dải chuyển màu như `.chatcard-img::after`, không cắt
    // ngang thẳng.
    return WrScriptTextScale(
      child: WrCardNavy(
        key: const Key('wr_discover_self_check_invite'),
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onStart,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: SizedBox(
                  height: 88,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/card_survey.webp',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, 0.08), // 50% 54%
                      ),
                      // `.chatcard-img::after`: 30px đáy ảnh chuyển từ trong
                      // suốt sang đúng màu nền thẻ.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 30,
                        child: DecoratedBox(
                          key: const Key('wr_discover_self_check_fade'),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                WrColors.navy.withValues(alpha: 0),
                                WrColors.navy,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                // `.chatcard-body{padding:2px 17px 17px}`: chữ bắt đầu ngay dưới
                // dải chuyển màu, liền một mảng với ảnh.
                padding: const EdgeInsets.fromLTRB(17, 2, 17, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wrKeepCompounds(tr('15 CÂU HỎI NGẮN', '15 SHORT QUESTIONS')),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: WrColors.cream.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wrKeepCompounds(tr(
                        'Khảo sát điều kiện làm việc',
                        'Workplace Conditions Survey',
                      )),
                      style: const TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: WrColors.cream,
                        height: 1.32,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      wrKeepCompounds(tr(
                        'Giúp hệ thống hiểu rõ hơn trạng thái hiện tại của bạn. Đừng quên cập nhật lại bất cứ khi nào bạn thấy có sự thay đổi trong công việc nhé.',
                        'Help the system better understand your current state. Remember to update whenever you notice shifts at work.',
                      )),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        color: WrColors.cream.withValues(alpha: 0.84),
                      ),
                    ),
                    if (answered > 0) ...[
                      const SizedBox(height: 11),
                      Text(
                        wrKeepCompounds(tr(
                          'Lần gần nhất: $answered/15 câu',
                          'Last time: $answered/15 questions',
                        )),
                        key: const Key('wr_discover_self_check_progress'),
                        style: TextStyle(
                          fontSize: 11,
                          color: WrColors.cream.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _PrimarySmallButton(
                      key: const Key('wr_discover_self_check_start'),
                      label: answered > 0
                          ? tr('Cập nhật lại →', 'Update again →')
                          : tr('Bắt đầu khảo sát →', 'Start survey →'),
                      onTap: onStart,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemExperienceCard extends StatelessWidget {
  const _SystemExperienceCard();

  @override
  Widget build(BuildContext context) {
    // Cỡ chữ đúng script, như thẻ khảo sát bên dưới.
    return WrScriptTextScale(
      child: WrCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/wr/experience-interpret'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 88,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.66, 1.0],
                  colors: [Colors.black, Colors.transparent],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  'assets/images/hero/bg_hieu.webp',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.2), // 50% 40%
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/card_timeline.webp',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrEyebrow(tr('GHI NHẬN TỪ HỆ THỐNG', 'SYSTEM OBSERVATION')),
                  const SizedBox(height: 4),
                  Text(
                    wrKeepCompounds(tr('Trải nghiệm của bạn', 'Your experience')),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    wrKeepCompounds(tr(
                      'Dựa vào những lần nhìn lại cũng như cập nhật điều kiện bạn '
                          'đang làm việc, đây là những ghi nhận từ hệ thống '
                          'WorkReflection.',
                      'Based on your look-backs and the working conditions you '
                          'have shared, this is what the WorkReflection system '
                          'has noticed.',
                    )),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WrColors.muted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PrimarySmallButton(
                    key: const Key('wr_discover_experience_read'),
                    label: tr('Đọc diễn giải', 'Read the interpretation'),
                    onTap: () => context.push('/wr/experience-interpret'),
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

// ---------------------------------------------------------------------------
// Tiện ích dùng chung cho màn chi tiết.
// ---------------------------------------------------------------------------

/// Tên hiển thị của một tình huống theo mã.
///
/// Không bao giờ trả về chính cái mã. `C2-sit-01` là thuật ngữ nội bộ (v1.6
/// §XII.5) — hiện nó ra là phơi bộ khung SCA cho người dùng, mà đúng lúc tệ
/// nhất: khi thư viện tình huống chưa tải xong hoặc mất mạng.
String situationLabel(List<WrSituation> situations, String? code) {
  if (code == null) return tr('Tình huống', 'Situation');
  for (final s in situations) {
    if (s.code == code) return s.text;
  }
  return tr('Tình huống', 'Situation');
}

/// Bản dùng map — cùng luật với [situationLabel].
String situationLabelFor(Map<String, String> labels, String? code) {
  if (code == null) return tr('Tình huống', 'Situation');
  return labels[code] ?? tr('Tình huống', 'Situation');
}

/// Số lần đã gặp một tình huống.
int occurrenceOf(List<PatternCount> patterns, String code) {
  for (final p in patterns) {
    if (p.situationCode == code) return p.occurrenceCount;
  }
  return 0;
}
