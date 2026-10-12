import '../../../core/l10n/wr_tr.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_practice_theme_grant.dart';
import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_small_button.dart';
import '../../../core/logic/wr_practice_v47.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../growth_providers.dart';
import '../owned_skill_providers.dart';
import '../wr_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WrGrowthScreen — ConsumerStatefulWidget for enroll double-tap guard
// ─────────────────────────────────────────────────────────────────────────────

class WrGrowthScreen extends ConsumerStatefulWidget {
  const WrGrowthScreen({super.key});

  @override
  ConsumerState<WrGrowthScreen> createState() => _WrGrowthScreenState();
}

/// Số thẻ chủ đề hiện sẵn trước khi phải bấm "Xem thêm".
///
/// Không phải một trần: danh sách KHÔNG bị cắt, phần dôi ra nằm sau nút xổ.
/// Ai theo mười chủ đề vẫn đọc được cả mười.
const kGrowthThemesPreview = 3;

class _WrGrowthScreenState extends ConsumerState<WrGrowthScreen> {
  /// Đã bấm "Xem thêm" chưa. Đặt ở State chứ không phải provider: đây là trạng
  /// thái của một lần xem màn, mở lại tab thì thu gọn về như cũ là đúng.
  bool _showAllThemes = false;

  /// Đang tự thêm chủ đề — chặn chạy chồng khi build lại giữa chừng.
  bool _autoEnrolling = false;

  /// Lượt xem màn này đã tự thêm một chủ đề rồi. Thêm xong là màn dựng lại và
  /// gọi lại `_maybeAutoEnroll`; không có cờ này thì ai nợ bốn chủ đề sẽ nhận
  /// cả bốn trong một nhịp.
  bool _addedThisVisit = false;

  @override
  void initState() {
    super.initState();
    // Chạy sau frame đầu: `build` không được phép có tác dụng phụ, mà đây là
    // ghi vào DB.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoEnroll());
  }

  /// Tự thêm chủ đề khi người dùng đã tích đủ dữ liệu.
  ///
  /// Khách chốt 2026-08-04: "chủ đề là do phần mềm tự thêm sau khi tổng hợp đủ
  /// dữ liệu từ người dùng". Hai hướng đổi ra chủ đề nằm trong
  /// [earnedPracticeThemes]; ở đây chỉ so số được hưởng với số đã ghi danh.
  ///
  /// So SỐ chứ không nhớ "đã thêm lần nào chưa": phép so ấy chạy lại bao nhiêu
  /// lần cũng ra cùng kết quả, nên vào ra tab mấy lượt cũng không thêm trùng, và
  /// không cần cột mới nào trong DB.
  ///
  /// Thêm ĐÚNG MỘT chủ đề mỗi lượt, kể cả khi còn nợ nhiều hơn: người dùng nghỉ
  /// một tháng rồi quay lại mà thấy bốn chủ đề mới đổ ra cùng lúc thì đó là một
  /// đống việc, không phải một lời mời. Còn nợ thì lượt sau thêm tiếp.
  ///
  /// Im lặng khi lỗi: đây là việc phần mềm tự làm, người dùng không yêu cầu gì
  /// nên cũng không có gì để báo hỏng. Lần mở màn sau thử lại.
  Future<void> _maybeAutoEnroll() async {
    if (_autoEnrolling || _addedThisVisit || !mounted) return;

    final userId = ref.read(currentUserIdProvider);
    final enrollments = ref.read(practiceEnrollmentsProvider).valueOrNull;
    final episodes = ref.read(wrEpisodeHistoryProvider).valueOrNull;
    final history = ref.read(wrSelfCheckHistoryProvider).valueOrNull;
    final entitlement = ref.read(wrEntitlementProvider).valueOrNull;
    // Thiếu bất cứ nguồn nào thì chờ, đừng đoán: đoán thiếu là thêm chủ đề trùng.
    if (userId == null ||
        enrollments == null ||
        episodes == null ||
        history == null ||
        entitlement == null) {
      return;
    }
    // Chủ đề người dùng tự khai đã có bị loại khỏi gợi ý (Task D2). Chưa đọc
    // xong danh sách đó mà gợi ý đã chạy thì tập "đã có" đang rỗng, và chủ đề
    // họ đã có có thể bị thêm nhầm. Đọc hỏng thì thôi, chạy như trước.
    if (ref.read(wrOwnedSkillsProvider).isLoading) return;

    final earned = earnedPracticeThemes(
      reflectionCount: episodes.length,
      selfCheckCount: history.length,
    );
    // Chỉ đếm chủ đề thư viện: chủ đề người dùng tự thêm (v47) không ăn vào
    // suất phần mềm tự thêm, nếu không thì tự thêm một chủ đề là mất luôn
    // chủ đề kế tiếp của hành trình. Quota Free bên dưới thì vẫn đếm cả hai.
    final themes = ref.read(practiceThemesProvider).valueOrNull;
    if (themes == null) return;
    final userThemeIds = {
      for (final t in themes)
        if (t.isUserAdded) t.themeId,
    };
    final libraryEnrolled = enrollments
        .where((e) => !userThemeIds.contains(e.themeId))
        .length;
    if (libraryEnrolled >= earned) return;

    // Hết quota thì dừng, thẻ quota bên dưới đã nói lý do và dẫn sang paywall.
    final activeCount = enrollments.where((e) => e.completedAt == null).length;
    if (!entitlement.canEnrollPracticeTheme(activeCount)) return;

    final suggestion = ref.read(wrPracticeSuggestionProvider);
    if (suggestion == null) return;

    _autoEnrolling = true;
    try {
      await ref
          .read(wrIntelligenceRepositoryProvider)
          .enrollTheme(
            PracticeEnrollment(
              userId: userId,
              themeId: suggestion.theme.themeId,
              completedSteps: const [],
            ),
          );
      ref.invalidate(practiceEnrollmentsProvider);
      _addedThisVisit = true;
    } catch (_) {
      // Im lặng — xem doc ở trên.
    } finally {
      _autoEnrolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(practiceThemesProvider);
    final enrollmentsAsync = ref.watch(practiceEnrollmentsProvider);
    final entitlementAsync = ref.watch(wrEntitlementProvider);
    // Nguồn duy nhất cho "đang phản chiếu nhiều về điều gì" (v2.0 §4.3) —
    // trước đây màn này đọc `wrPatternCountsProvider`.
    final episodesAsync = ref.watch(wrEpisodeHistoryProvider);
    final situationsAsync = ref.watch(wrSituationsProvider);
    final selfCheckAsync = ref.watch(wrSelfCheckHistoryProvider);
    // Chỉ để màn dựng lại (và `_maybeAutoEnroll` chạy lại) khi danh sách thứ
    // người dùng đã có đọc xong. Xem chỗ chờ trong `_maybeAutoEnroll`.
    ref.watch(wrOwnedSkillsProvider);

    return Scaffold(
      // Nền TRẮNG như ba tab kia — xem `wr_card.dart`. Trước đây màn này dùng
      // #FBFBF9, một sắc ngà không có trong hệ màu nào cả: đứng riêng thì không
      // ai thấy, nhưng chuyển tab từ Home sang là thấy màn tối đi một chút.
      backgroundColor: WrColors.pageBg,
      body: themesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildContent(
          context,
          themes: const [],
          enrollments: const [],
          entitlement: WrEntitlement(plan: WrPlan.free),
          recent: const [],
          situations: const [],
          latestSelfCheck: null,
        ),
        data: (themes) {
          // Dữ liệu về muộn hơn frame đầu, nên thử lại sau mỗi lần dựng.
          // `_maybeAutoEnroll` chỉ so số nên chạy thừa không hại gì.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _maybeAutoEnroll(),
          );
          final enrollments = enrollmentsAsync.valueOrNull ?? const [];
          final entitlement =
              entitlementAsync.valueOrNull ?? WrEntitlement(plan: WrPlan.free);
          final episodes = episodesAsync.valueOrNull ?? const [];
          final situations = situationsAsync.valueOrNull ?? const [];
          final history = selfCheckAsync.valueOrNull ?? const [];
          final latestSelfCheck = history.isNotEmpty ? history.first : null;
          return _buildContent(
            context,
            themes: themes,
            enrollments: enrollments,
            entitlement: entitlement,
            recent: recentSituationIds(episodes),
            situations: situations,
            latestSelfCheck: latestSelfCheck,
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<PracticeTheme> themes,
    required List<PracticeEnrollment> enrollments,
    required WrEntitlement entitlement,
    required List<String> recent,
    required List<WrSituation> situations,
    required ScaSelfCheckResponse? latestSelfCheck,
  }) {
    // Quota
    final activeCount = enrollments.where((e) => e.completedAt == null).length;

    // Thẻ chủ đề: đang thực hành trước, đã hoàn thành xếp sau; trong mỗi nhóm
    // thì CHỦ ĐỀ MỚI NHẤT LÊN ĐẦU (yêu cầu khách 2026-08-04). Ghi danh trỏ tới
    // một chủ đề không còn trong thư viện thì bỏ qua — không dựng thẻ rỗng.
    //
    // Vẫn tách hai nhóm chứ không xếp thuần theo ngày: một chủ đề vừa hoàn
    // thành sẽ mới hơn mọi chủ đề đang dở, xếp thuần ngày là đẩy việc đang làm
    // xuống dưới việc đã xong.
    List<(PracticeTheme, PracticeEnrollment)> cardsOf(
      Iterable<PracticeEnrollment> source,
    ) {
      final list = <(PracticeTheme, PracticeEnrollment)>[
        for (final e in source)
          if (themes.where((t) => t.themeId == e.themeId).firstOrNull
              case final t?)
            (t, e),
      ];
      // Ghi danh chưa có `startedAt` xuống cuối: không có mốc thì không thể
      // coi là mới.
      list.sort((a, b) {
        final sa = a.$2.startedAt;
        final sb = b.$2.startedAt;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sb.compareTo(sa);
      });
      return list;
    }

    // Một cái TÊN là một chủ đề, dù thư viện có hai hàng. `pt-voice` và `pt-c2`
    // đều tên "Dám lên tiếng"; ai ghi danh cả hai sẽ thấy hai thẻ y hệt nhau,
    // và vì bộ đếm thực hành nhận sự kiện theo tên (Career Memory không lưu
    // theme_id) thì hai thẻ ấy cũng luôn hiện cùng một tiến độ. Giữ thẻ đầu
    // tiên theo thứ tự trên: đang thực hành trước, mới nhất trước.
    final seenTitles = <String>{};
    final enrolledCards = [
      for (final card in [
        ...cardsOf(enrollments.where((e) => e.completedAt == null)),
        ...cardsOf(enrollments.where((e) => e.completedAt != null)),
      ])
        // Chủ đề tự thêm là của riêng người dùng: trùng tên thư viện vẫn giữ.
        if (card.$1.isUserAdded || seenTitles.add(card.$1.title)) card,
    ];

    final canAddTheme = entitlement.canEnrollPracticeTheme(activeCount);

    return ListView(
      // Padding tường minh: `ListView` không có padding sẽ xoá phần thanh
      // trạng thái khỏi `MediaQuery` của con, ảnh hero hết tràn lên.
      // Đáy 80 như tab Hiểu mình: thẻ cuối (Thư viện học tập) phải cuộn lên
      // được khỏi bong bóng chat nổi, không thì bong bóng che chữ (máy thật
      // 10/10).
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        WrHeroHeader.inner(
          key: const Key('wr_growth_hero'),
          art: WrHeroArt.act,
          eyebrow: tr('Phát triển', 'Develop'),
          title: tr('Thực hành', 'Practice'),
          subtitle: tr(
            'Không cần thay đổi tất cả. Chỉ cần thử một cách khác.',
            'You do not need to change everything. Just try one different way.',
          ),
          // v1.6 §9.1: "Tôi" là avatar ở mọi màn tab.
          trailing: const WrProfileAvatar(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WrTabBackLink(currentTab: WrTab.growth),

              // ── PHẦN 1a: ĐANG LÀM QUEN ──────────────────────────────────
              _LearningSection(
                enrolledCards: enrolledCards,
                allThemes: themes,
                showAll: _showAllThemes,
                onToggleShowAll: () =>
                    setState(() => _showAllThemes = !_showAllThemes),
              ),
              const SizedBox(height: 20),

              // ── PHẦN 1b: ĐANG DUY TRÌ ───────────────────────────────────
              const _KeepingSection(),
              const SizedBox(height: 26),

              // ── PHẦN 2: THÊM ────────────────────────────────────────────
              _AddSection(canAddTheme: canAddTheme),
              const SizedBox(height: 26),

              // ── PHẦN 3: MỞ RỘNG ─────────────────────────────────────────
              const _ExpandSection(),
            ],
          ),
        ),
      ],
    );
  }

  // ── PHẦN 1a: ĐANG LÀM QUEN ───────────────────────────────────────────────
}

class _LearningSection extends StatelessWidget {
  const _LearningSection({
    required this.enrolledCards,
    required this.allThemes,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final List<(PracticeTheme, PracticeEnrollment?)> enrolledCards;
  final List<PracticeTheme> allThemes;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    final displayCards = enrolledCards.isNotEmpty
        ? enrolledCards
        : allThemes
            .take(3)
            .map((t) => (t, null as PracticeEnrollment?))
            .toList();

    final visible = showAll
        ? displayCards
        : displayCards.take(kGrowthThemesPreview).toList();
    final moreCount = displayCards.length - visible.length;

    return WrCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('ĐANG LÀM QUEN', 'PRACTICING'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: WrColors.text3,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'Những chủ đề bạn đang đi qua bốn bước làm quen.',
              'Themes you are going through four introductory steps.',
            ),
            style: const TextStyle(
              fontSize: 13,
              color: WrColors.text2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: WrColors.lineSoft),
            _PracticeThemeRow(
              theme: visible[i].$1,
              enrollment: visible[i].$2,
            ),
          ],
          if (moreCount > 0 ||
              (showAll && displayCards.length > kGrowthThemesPreview))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: InkWell(
                  onTap: onToggleShowAll,
                  child: Text(
                    showAll
                        ? tr('Thu gọn', 'Show less')
                        : tr(
                            'Xem thêm $moreCount chủ đề',
                            'See $moreCount more themes',
                          ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: WrColors.pillTealText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PracticeThemeRow extends ConsumerWidget {
  const _PracticeThemeRow({
    required this.theme,
    required this.enrollment,
  });

  final PracticeTheme theme;
  final PracticeEnrollment? enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref
            .watch(practiceStepsProvider(theme.themeId))
            .valueOrNull ??
        const [];
    final doneCount = enrollment != null
        ? steps
            .where((s) => enrollment!.completedSteps.contains(s.stepId))
            .length
        : 0;

    return InkWell(
      key: Key('wr_growth_theme_row_${theme.themeId}'),
      onTap: () => context.push('/wr/growth/theme/${theme.themeId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    theme.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '›',
                  style: TextStyle(
                    fontSize: 16,
                    color: WrColors.text3,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              doneCount == 0
                  ? tr('Chưa bắt đầu', 'Not started')
                  : tr('Bước $doneCount / 4', 'Step $doneCount / 4'),
              style: const TextStyle(fontSize: 12, color: WrColors.text3),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var k = 0; k < 4; k++) ...[
                  if (k > 0) const SizedBox(width: 4),
                  Container(
                    width: 24,
                    height: 4,
                    decoration: BoxDecoration(
                      color: k < doneCount
                          ? WrColors.teal
                          : WrColors.navy.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── PHẦN 2: THÊM ───────────────────────────────────────────────────────────

class _AddSection extends StatelessWidget {
  const _AddSection({required this.canAddTheme});

  final bool canAddTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(tr('Thêm', 'Add')),
        const SizedBox(height: 8),
        WrCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(
            children: [
              InkWell(
                key: const Key('wr_growth_add_theme'),
                onTap: () => context.push(
                  canAddTheme
                      ? '/wr/growth/add-theme'
                      : '/wr/paywall?trigger=practice_limit',
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          tr(
                            'Chủ đề chưa có trong thư viện',
                            'Theme not in the library',
                          ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: WrColors.text2,
                          ),
                        ),
                      ),
                      const Text(
                        '›',
                        style: TextStyle(fontSize: 16, color: WrColors.text3),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: WrColors.lineSoft),
              InkWell(
                key: const Key('wr_growth_context_docs_row'),
                onTap: () => context.push('/wr/job-context'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          tr('Bối cảnh công việc', 'Work context'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: WrColors.text2,
                          ),
                        ),
                      ),
                      const Text(
                        '›',
                        style: TextStyle(fontSize: 16, color: WrColors.text3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── PHẦN 3: MỞ RỘNG ────────────────────────────────────────────────────────

class _ExpandSection extends StatelessWidget {
  const _ExpandSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(tr('Mở rộng', 'Expand')),
        const SizedBox(height: 8),

        // 1. Chuỗi Series Tâm thế người đi làm Card
        WrCard(
          padding: EdgeInsets.zero,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr(
                    'Mở Chuỗi Series Tâm thế người đi làm trên YouTube',
                    'Open Work Mindset Series on YouTube',
                  ),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 98,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/hero/bg_hieu.webp',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                      Positioned(
                        left: 12,
                        top: 11,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: WrColors.coral,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                tr('YOUTUBE', 'YOUTUBE'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                tr('SERIES CHIA SẺ', 'VIDEO SERIES'),
                                style: const TextStyle(
                                  color: WrColors.navy,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 11,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: WrColors.coral,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        'Chuỗi Series Tâm thế người đi làm',
                        'Work Mindset Series',
                      ),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr(
                        'Các góc nhìn, tâm thế và cách ứng xử trước những tình huống thực tế nơi công sở.',
                        'Perspectives, mindset, and practical responses in the workplace.',
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WrColors.text2,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 11),

        // 2. Trà chiều nghề nghiệp Card
        WrCard(
          padding: EdgeInsets.zero,
          onTap: () => context.push('/wr/tra-chieu'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 88,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/thumb_trachieu.webp',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.10),
                      ),
                      Positioned(
                        left: 12,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xDC093774),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            tr(
                              'OFFLINE · TRÀ CHIỀU',
                              'OFFLINE · AFTERNOON TEA',
                            ),
                            style: const TextStyle(
                              color: WrColors.cream,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Trà chiều nghề nghiệp', 'Career Afternoon Tea'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr(
                        '10 đến 12 người · 2 giờ · một câu hỏi',
                        '10 to 12 people · 2 hours · one question',
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WrColors.text2,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class WrPracticeThemeCard extends ConsumerWidget {
  const WrPracticeThemeCard({
    super.key,
    required this.theme,
    required this.enrollment,
  });

  final PracticeTheme theme;
  final PracticeEnrollment enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps =
        ref.watch(practiceStepsProvider(theme.themeId)).valueOrNull ?? const [];
    final doneCount = steps
        .where((s) => enrollment.completedSteps.contains(s.stepId))
        .length;
    final next = steps
        .where((s) => !enrollment.completedSteps.contains(s.stepId))
        .firstOrNull;
    // Mockup: chủ đề thư viện tô teal, chủ đề tự thêm tô navy.
    final color = theme.isUserAdded ? WrColors.navy : WrColors.teal;

    return Padding(
      padding: const EdgeInsets.only(bottom: WrCard.kGap),
      child: WrCard(
        onTap: () => context.push('/wr/growth/theme/${theme.themeId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    practiceThemeSourceLabel(theme, enrollment.startedAt),
                    style: _tiny,
                  ),
                ),
                _Pill(
                  label: doneCount > 0
                      ? tr('Đang thực hành', 'Practising')
                      : tr('Có thể bắt đầu', 'Ready to start'),
                  teal: doneCount > 0,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(theme.title, style: _h2),
            const SizedBox(height: 7),
            Text(
              next != null
                  ? tr(
                      'Tiếp theo: ${practiceStepAction(next.title)}',
                      'Next: ${practiceStepAction(next.title)}',
                    )
                  : tr(
                      'Bạn đã đi hết các bước hiện tại.',
                      'You have gone through all the current steps.',
                    ),
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.text2,
                height: 1.55,
              ),
            ),
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final s in steps) ...[
                    if (s != steps.first) const SizedBox(width: 6),
                    Container(
                      width: 22,
                      height: 5,
                      decoration: BoxDecoration(
                        color: enrollment.completedSteps.contains(s.stepId)
                            ? color
                            : WrColors.navy.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `.pill.pill-teal` / `.pill.pill-navy`.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.teal = false});

  final String label;
  final bool teal;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: teal
          ? WrColors.teal.withValues(alpha: 0.14)
          : WrColors.navy.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: teal ? WrColors.pillTealText : WrColors.navy,
      ),
    ),
  );
}

/// `.h2` (15.5px) +1.5 theo quy ước cỡ chữ của app.
const _h2 = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  color: WrColors.navy,
  height: 1.35,
);

/// `.tiny` (11px) +1.5.
const _tiny = TextStyle(fontSize: 12.5, color: WrColors.text3);



class _KeepingSection extends ConsumerStatefulWidget {
  const _KeepingSection();

  @override
  ConsumerState<_KeepingSection> createState() => _KeepingSectionState();
}

class _KeepingSectionState extends ConsumerState<_KeepingSection> {
  final Set<String> _marked = {};

  @override
  Widget build(BuildContext context) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final enrollments =
        ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
    final completed = enrollments.where((e) => e.completedAt != null).toList();

    final items = <(String, String, int, String)>[
      for (final e in completed)
        if (themes.where((t) => t.themeId == e.themeId).firstOrNull case final t?)
          (
            e.themeId,
            t.title,
            (e.completedSteps.length).clamp(1, 99),
            tr('hôm qua', 'yesterday'),
          ),
      (
        'k1',
        tr('Rõ ràng về điều được kỳ vọng', 'Clarity on expectations'),
        12,
        tr('hôm qua', 'yesterday'),
      ),
      (
        'k2',
        tr('Thoát khỏi vòng lặp phản ứng', 'Breaking reactive feedback loops'),
        7,
        tr('3 ngày trước', '3 days ago'),
      ),
      (
        'k3',
        tr('Giữ năng lượng đường dài', 'Sustaining energy over time'),
        2,
        tr('tuần trước', 'last week'),
      ),
    ];

    final preview = items.take(3).toList();
    final remaining = items.length - preview.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('ĐANG DUY TRÌ', 'MAINTAINING'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: WrColors.text3,
                      letterSpacing: 0.6,
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push('/wr/growth/stance-keep'),
                    child: Text(
                      tr('Xem đầy đủ ›', 'See all ›'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: WrColors.pillTealText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: WrColors.line),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preview[i].$2,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: WrColors.navy,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${preview[i].$3} ${tr('lần', 'times')} · ${tr('gần nhất', 'last')} ${preview[i].$4}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: WrColors.text3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      WrSmallButton(
                        kind: _marked.contains(preview[i].$1)
                            ? WrSmallButtonKind.ghost
                            : WrSmallButtonKind.dark,
                        label: _marked.contains(preview[i].$1)
                            ? tr('✓ Đã ghi', '✓ Saved')
                            : tr('Ghi nhận', 'Record'),
                        onTap: () {
                          setState(() {
                            if (_marked.contains(preview[i].$1)) {
                              _marked.remove(preview[i].$1);
                            } else {
                              _marked.add(preview[i].$1);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (remaining > 0) ...[
                const Divider(height: 1, thickness: 1, color: WrColors.line),
                InkWell(
                  onTap: () => context.push('/wr/growth/stance-keep'),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Text(
                        tr('Còn $remaining chủ đề khác', 'And $remaining other themes'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: WrColors.text3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Những chủ đề đã hoàn thành ở bốn bước làm quen. Mỗi lần bạn thực hành lại trong công việc thật, bấm Ghi nhận để hệ thống giúp bạn lưu giữ.',
            'Themes completed in the four steps. Each time you practice in real work, tap Record to preserve your journey.',
          ),
          style: const TextStyle(
            fontSize: 12,
            color: WrColors.text3,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}


