// Kỹ năng đã hình thành — màn riêng, mở từ tab Phát triển.
//
// Dựng lại theo spec "Kỹ năng đã hình thành (Skill Formation)". Bản trước chỉ
// là một danh sách phẳng những chủ đề đã xong, nên người dùng không thấy được
// ba điều quan trọng nhất: mình đang ở đâu trên đường tới ngưỡng, làm gì để đi
// tiếp, và tất cả những cái này có liên quan gì tới công việc thật của mình.
//
// Màn này có ba tầng, theo đúng thứ tự spec:
//   1. ĐÃ HÌNH THÀNH — ghi nhận nỗ lực thật. FREE, không khoá. Khoá phần này
//      sau Premium là "thu phí người dùng để họ được biết chính nỗ lực của
//      mình".
//   2. ĐANG HÌNH THÀNH — bộ đếm, còn bao xa, và hành động tiếp theo (ba bước
//      làm quen, hay nút duy trì).
//   3. ĐỐI CHIẾU VỚI CÔNG VIỆC — tổng hợp và diễn giải, PREMIUM.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_skill_formation.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_premium_lock.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_skill_moment.dart';

/// Số chủ đề đang hình thành hiện sẵn trước khi phải bấm "Xem thêm".
///
/// Không phải một trần: danh sách KHÔNG bị cắt, phần dôi ra nằm sau nút xổ.
/// Cùng con số với thẻ chủ đề ở tab Phát triển (`kGrowthThemesPreview`) để hai
/// màn cạnh nhau cắt cùng một chỗ.
///
/// Vì sao cần: ai theo sáu, bảy chủ đề thì mục "Đang hình thành" đẩy phần đối
/// chiếu với công việc xuống tận đáy, và mỗi dòng lại lặp đúng một câu nhắc
/// giống nhau — dài mà không thêm thông tin nào.
const int kSkillsFormingPreview = 3;

class WrGrowthSkillsScreen extends ConsumerStatefulWidget {
  const WrGrowthSkillsScreen({super.key});

  @override
  ConsumerState<WrGrowthSkillsScreen> createState() =>
      _WrGrowthSkillsScreenState();
}

class _WrGrowthSkillsScreenState extends ConsumerState<WrGrowthSkillsScreen> {
  /// Đã bấm "Xem thêm" chưa. Ở State chứ không phải provider: đây là trạng thái
  /// của một lần xem màn, mở lại thì thu gọn về như cũ là đúng.
  bool _showAllForming = false;

  @override
  Widget build(BuildContext context) {
    final threshold = ref.watch(wrSkillThresholdProvider);
    final formations = ref.watch(wrSkillFormationsProvider);
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final entitlement =
        ref.watch(wrEntitlementProvider).valueOrNull ?? WrEntitlement(plan: WrPlan.free);

    final formed = formedSkills(formations);
    final forming = formingSkills(formations);
    final themeById = {for (final t in themes) t.themeId: t};

    // Gần đích nhất đứng đầu (đã sắp trong `formingSkills`), nên ba dòng hiện
    // sẵn cũng là ba chủ đề sát ngưỡng nhất — phần đáng nhìn nhất của danh sách.
    final hiddenForming =
        (forming.length - kSkillsFormingPreview).clamp(0, 1 << 30);
    final visibleForming = _showAllForming || hiddenForming == 0
        ? forming
        : forming.take(kSkillsFormingPreview).toList();

    return WrDetailScaffold(
      // A.1: giữ nguyên chữ "kỹ năng", chỉ bỏ chữ "hình thành" ở tên gọi chính.
      // Nhãn nhóm "Đang hình thành" phía dưới thì giữ — đó là mô tả một trạng
      // thái đang diễn ra, không phải một phần của tên gọi.
      eyebrow: 'KỸ NĂNG CỦA BẠN',
      title: formed.isEmpty
          ? 'Chưa có kỹ năng nào'
          : 'Bạn đã hình thành ${formed.length} kỹ năng',
      children: [
        _HowItWorks(threshold: threshold, hasAny: formed.isNotEmpty),
        if (formed.isNotEmpty) ...[
          const SizedBox(height: 26),
          const _SectionLabel('ĐÃ HÌNH THÀNH'),
          const SizedBox(height: 14),
          ...formed.map((s) => _FormedSkillTile(skill: s)),
        ],
        if (forming.isNotEmpty) ...[
          const SizedBox(height: 26),
          const _SectionLabel('ĐANG HÌNH THÀNH'),
          const SizedBox(height: 14),
          ...visibleForming.map(
            (f) => _FormingSkillTile(
              formation: f,
              theme: themeById[f.themeId],
            ),
          ),
          if (hiddenForming > 0)
            // Align chỉ để dòng nằm sát mép trái như mọi liên kết khác.
            Align(
              alignment: Alignment.centerLeft,
              child: WrActionLink(
                key: const Key('wr_skills_forming_more'),
                label: _showAllForming
                    ? 'Thu gọn'
                    : 'Xem thêm $hiddenForming chủ đề',
                onTap: () => setState(() => _showAllForming = !_showAllForming),
              ),
            ),
        ],
        const SizedBox(height: 30),
        _JdSection(isPremium: entitlement.isPremium),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Giải thích cơ chế
// ---------------------------------------------------------------------------

/// Vì sao phải giải thích: ngưỡng "5 lần" chỉ có nghĩa khi người dùng biết cái
/// gì được tính là một lần. Không nói ra thì bộ đếm nhảy số như một trò chơi
/// không luật.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.threshold, required this.hasAny});

  final int threshold;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_skills_how_it_works'),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: WrColors.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasAny
                ? 'Một kỹ năng được ghi nhận khi bạn thực hành nó $threshold lần.'
                : 'Chưa có gì ở đây là bình thường, kỹ năng cần thời gian.',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mỗi chủ đề bắt đầu bằng ba bước làm quen: Nhận diện, Thử nghiệm, '
            'Chuyển hoá. Xong ba bước, chủ đề chuyển sang giai đoạn duy trì — '
            'mỗi ngày bạn thực hành lại, bấm ghi nhận một lần. Đủ $threshold '
            'lần, WorkReflection ghi nó thành kỹ năng của bạn.',
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: WrColors.muted,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Đã hình thành
// ---------------------------------------------------------------------------

class _FormedSkillTile extends StatelessWidget {
  const _FormedSkillTile({required this.skill});

  final SkillFormation skill;

  @override
  Widget build(BuildContext context) {
    final date = skill.skillFormedDate;
    return Padding(
      key: Key('wr_skill_${skill.themeId}'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, size: 20, color: WrColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  date == null
                      ? 'Đã thực hành ${skill.practiceCount} lần.'
                      : 'Hình thành ngày ${DateFormat('dd/MM/yyyy').format(date)} '
                          '· đã thực hành ${skill.practiceCount} lần.',
                  key: Key('wr_skill_meta_${skill.themeId}'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: WrColors.muted,
                    height: 1.55,
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

// ---------------------------------------------------------------------------
// Đang hình thành
// ---------------------------------------------------------------------------

class _FormingSkillTile extends StatelessWidget {
  const _FormingSkillTile({required this.formation, required this.theme});

  final SkillFormation formation;
  final PracticeTheme? theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      key: Key('wr_skill_forming_${formation.themeId}'),
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formation.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 9),
          // MỘT trạng thái tại một thời điểm (Phần C mục 2).
          //
          // Bản trước hiện đồng thời "2/5 lần thực hành, còn 3 lần nữa" và "Đi
          // hết ba bước làm quen của chủ đề này trước đã" — hai câu phủ định
          // nhau: một câu bảo đang đếm tới ngưỡng, câu kia bảo còn chưa xong
          // giai đoạn trước đó. Chưa xong ba bước thì bộ đếm 5 lần chưa phải
          // chuyện của người dùng, nên không hiện số, không hiện dải tiến độ.
          if (formation.stage == SkillStage.onboarding)
            _OnboardingHint(themeId: formation.themeId)
          else ...[
            _ProgressBar(progress: formation.progress),
            const SizedBox(height: 7),
            Text(
              '${formation.practiceCount}/${formation.threshold} lần thực hành '
              '· còn ${formation.remaining} lần nữa',
              key: Key('wr_skill_progress_${formation.themeId}'),
              style: const TextStyle(fontSize: 14, color: WrColors.muted),
            ),
            const SizedBox(height: 10),
            if (t != null) WrMaintainPracticeAction(theme: t),
          ],
        ],
      ),
    );
  }
}

class _OnboardingHint extends StatelessWidget {
  const _OnboardingHint({required this.themeId});

  final String themeId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/wr/growth/theme/$themeId'),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Đi hết ba bước làm quen của chủ đề này trước đã.',
              style: TextStyle(fontSize: 14.5, color: WrColors.muted, height: 1.5),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 12, color: WrColors.navy),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: WrColors.navy.withValues(alpha: 0.1),
        valueColor: const AlwaysStoppedAnimation<Color>(WrColors.teal),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Đối chiếu với công việc — Premium
// ---------------------------------------------------------------------------

class _JdSection extends ConsumerWidget {
  const _JdSection({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isPremium) {
      return const WrPremiumLock(
        key: Key('wr_skills_jd_lock'),
        title: 'Đối chiếu với công việc của bạn',
        description:
            'Xem kỹ năng bạn đã hình thành hợp với công việc mình đang làm ở '
            'đâu, và công việc đó còn cần điều gì bạn chưa thực hành.',
        ctaLabel: 'Mở khoá đối chiếu',
        paywallTrigger: 'skill_jd_match',
      );
    }

    final match = ref.watch(wrSkillJdMatchProvider).valueOrNull;
    if (match == null || match.isEmpty) {
      // Chưa có mô tả vai trò, hoặc mô tả không đủ để nói gì chắc chắn. Im lặng
      // kèm một lối đi, không bịa một bức tranh nghe cho có.
      return Column(
        key: const Key('wr_skills_jd_empty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('ĐỐI CHIẾU VỚI CÔNG VIỆC'),
          const SizedBox(height: 12),
          const Text(
            'Chưa đối chiếu được. Viết một dòng mô tả công việc bạn đang làm, '
            'WorkReflection sẽ chỉ ra kỹ năng nào của bạn đang hợp với nó và '
            'chỗ nào còn trống.',
            style: TextStyle(fontSize: 15, color: WrColors.muted, height: 1.65),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            key: const Key('wr_skills_jd_add_role'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/wr/work-info'),
            child: const Row(
              children: [
                Text(
                  'Thêm mô tả công việc',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 15, color: WrColors.navy),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      key: const Key('wr_skills_jd_match'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('ĐỐI CHIẾU VỚI CÔNG VIỆC'),
        const SizedBox(height: 12),
        Text(
          'Công việc bạn mô tả xoay quanh ${match.pillarSentence.toLowerCase()}.',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        if (match.matchedSkills.isNotEmpty) ...[
          const Text(
            'Bạn đã có sẵn',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          ...match.matchedSkills.map(
            (s) => _BulletLine(
              icon: Icons.check_circle_outline,
              color: WrColors.teal,
              text: s.title,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (match.gapThemes.isNotEmpty) ...[
          const Text(
            'Công việc này còn cần, bạn chưa hình thành',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          // Đã xếp theo bảng B.2 trong `matchSkillsToContext`, nên bốn dòng
          // hiện ra cũng là bốn khoảng trống liên quan nhất với cấp bậc của
          // người dùng.
          ...match.gapThemes.take(4).map(
                (t) => _BulletLine(
                  icon: Icons.radio_button_unchecked,
                  color: WrColors.amber,
                  text: t.title,
                  badge: match.gapRelevance[t.themeId]?.label,
                  onTap: () => context.push('/wr/growth/theme/${t.themeId}'),
                ),
              ),
          const SizedBox(height: 14),
        ],
        // Nguyên tắc 3 (B.1) đã kéo nhóm Kết nối vào dù mô tả không nhắc tới.
        // Nói thẳng ra, không để người dùng tưởng nó đến từ chữ họ viết.
        if (match.autoRaisedDimensions.isNotEmpty) ...[
          const Text(
            'Ở vị trí quản lý, phần Mối quan hệ được tính là cần dù mô tả công '
            'việc không nhắc tới — những điều đó thường được ngầm hiểu.',
            key: Key('wr_skills_jd_auto_raised'),
            style: TextStyle(fontSize: 13.5, color: WrColors.muted, height: 1.6),
          ),
          const SizedBox(height: 12),
        ],
        // §11.2 của Cơ hội phát triển: mọi diễn giải đều phải kèm ghi chú giới
        // hạn. Phép đối chiếu này đọc từ khoá trong mô tả bạn viết, nó không
        // đọc được ngành nghề hay bối cảnh của bạn.
        Text(
          'Đối chiếu dựa trên mô tả công việc bạn đã viết '
          '(${match.basedOnKeywords.take(4).join(', ')}…), độ chính xác còn '
          'giới hạn.',
          key: const Key('wr_skills_jd_note'),
          style: const TextStyle(
            fontSize: 13.5,
            color: WrColors.muted,
            height: 1.6,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.icon,
    required this.color,
    required this.text,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;

  /// Mức độ liên quan theo cấp bậc (bảng B.2). Null khi chưa biết cấp bậc.
  final String? badge;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15.5,
                color: WrColors.navy,
                height: 1.5,
              ),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Text(
              badge!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (onTap != null)
            const Icon(Icons.arrow_forward_ios, size: 11, color: WrColors.muted),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}
