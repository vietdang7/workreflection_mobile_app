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
import '../../../core/theme/wr_text_scale.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/logic/wr_practice_v47.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../growth_providers.dart';
import '../owned_skill_providers.dart';
import '../wr_providers.dart';
import 'wr_practice_step_completion.dart' show practiceReachableDone;
import 'wr_skill_moment.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';
import 'wr_learning_library_screen.dart'
    show kLearningLibraryIntro, kLearningLibraryLabel, kLearningLibraryMeta;
import '../../../core/logic/wr_tra_chieu.dart'
    show kTraChieuCardDescription, kTraChieuCardLine, nextTraChieu, traChieuCardLabel;
import '../../workshops/workshops_providers.dart'
    show activeWorkshopsProvider;

// ─────────────────────────────────────────────────────────────────────────────
// WrGrowthScreen — ConsumerStatefulWidget for enroll double-tap guard
// ─────────────────────────────────────────────────────────────────────────────

class WrGrowthScreen extends ConsumerStatefulWidget {
  const WrGrowthScreen({super.key});

  @override
  ConsumerState<WrGrowthScreen> createState() => _WrGrowthScreenState();
}

/// Số thẻ chủ đề hiện sẵn, và số thêm vào mỗi lần bấm "Xem thêm" (script
/// `actShowLearn`).
///
/// Không phải một trần: danh sách KHÔNG bị cắt, phần dôi ra nằm sau nút xổ.
/// Ai theo mười chủ đề vẫn đọc được cả mười.
const kGrowthThemesPreview = 3;

/// Số dòng "Đang duy trì" ở tab Phát triển (script `KEEPING.slice(0,3)`).
const kGrowthKeepPreview = 3;

class _WrGrowthScreenState extends ConsumerState<WrGrowthScreen> {
  /// Số chủ đề đang hiện; mỗi lần "Xem thêm" cộng 3. Đặt ở State chứ không
  /// phải provider: đây là trạng thái của một lần xem màn, mở lại tab thì thu
  /// gọn về như cũ là đúng.
  int _learnShow = kGrowthThemesPreview;

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
      backgroundColor: Colors.transparent,
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
    // Chủ đề đã đưa vào duy trì (`completedAt`) rời phần "Đang làm quen" và
    // nằm ở "Đang duy trì" bên dưới.
    final seenTitles = <String>{};
    final enrolledCards = [
      for (final card in cardsOf(
        enrollments.where((e) => e.completedAt == null),
      ))
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
            'Không cần thay đổi tất cả.\nChỉ cần thử một cách khác.',
            'You do not need to change everything.\nJust try one different way.',
          ),
          // v1.6 §9.1: "Tôi" là avatar ở mọi màn tab.
          trailing: const WrProfileAvatar(),
        ),
        const SizedBox(height: WrHeroHeader.kContentGap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WrTabBackLink(currentTab: WrTab.growth),

              // ── PHẦN 1a: ĐANG LÀM QUEN ──────────────────────────────────
              _LearningSection(
                enrolledCards: enrolledCards,
                // Không mời chủ đề thư viện (khách 04/8): chủ đề do phần mềm
                // tự thêm. Chưa có chủ đề nào thì phần này ẩn.
                allThemes: const [],
                show: _learnShow,
                onShowMore: () =>
                    setState(() => _learnShow += kGrowthThemesPreview),
              ),

              // ── PHẦN 1b: ĐANG DUY TRÌ ───────────────────────────────────
              const _KeepingSection(),
              const SizedBox(height: 6),

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
    required this.show,
    required this.onShowMore,
  });

  final List<(PracticeTheme, PracticeEnrollment?)> enrolledCards;
  final List<PracticeTheme> allThemes;
  final int show;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final displayCards = enrolledCards.isNotEmpty
        ? enrolledCards
        : allThemes
              .take(3)
              .map((t) => (t, null as PracticeEnrollment?))
              .toList();
    if (displayCards.isEmpty) return const SizedBox.shrink();

    final visible = displayCards.take(show).toList();
    final moreCount = displayCards.length - visible.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: WrCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wrKeepCompounds(tr('ĐANG LÀM QUEN', 'PRACTICING')),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WrColors.text3,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              wrKeepCompounds(
                tr(
                  'Những chủ đề bạn đang đi qua bốn bước làm quen.',
                  'Themes you are going through four introductory steps.',
                ),
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
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: WrColors.lineSoft,
                ),
              _PracticeThemeRow(
                theme: visible[i].$1,
                enrollment: visible[i].$2,
              ),
            ],
            if (moreCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: InkWell(
                    key: const Key('wr_growth_learn_more'),
                    onTap: onShowMore,
                    child: Text(
                      wrKeepCompounds(
                        tr(
                          'Xem thêm ${moreCount < kGrowthThemesPreview ? moreCount : kGrowthThemesPreview} chủ đề',
                          'See ${moreCount < kGrowthThemesPreview ? moreCount : kGrowthThemesPreview} more themes',
                        ),
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
      ),
    );
  }
}

class _PracticeThemeRow extends ConsumerWidget {
  const _PracticeThemeRow({required this.theme, required this.enrollment});

  final PracticeTheme theme;
  final PracticeEnrollment? enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps =
        ref.watch(practiceStepsProvider(theme.themeId)).valueOrNull ?? const [];
    final doneCount = enrollment != null
        ? steps
              .where((s) => enrollment!.completedSteps.contains(s.stepId))
              .length
        : 0;
    // Bước đang làm = bước đầu tiên chưa xong theo thứ tự, như màn chủ đề.
    // Không lấy "đã xong + 1": dữ liệu cũ có thể đã xong bước sau mà chưa xong
    // bước trước.
    final ordered = [...steps]
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    final firstOpen = enrollment == null
        ? -1
        : ordered.indexWhere(
            (s) => !enrollment!.completedSteps.contains(s.stepId),
          );
    final currentStep = firstOpen >= 0
        ? (firstOpen + 1).clamp(1, kPracticeStageCount)
        : (doneCount + 1 > kPracticeStageCount
              ? kPracticeStageCount
              : doneCount + 1);

    // Đã đi hết các bước với tới được (Free không có bước 4 Premium) mà chưa
    // đưa vào duy trì: cùng điều kiện với thẻ "HẾT MỘT VÒNG" của màn chủ đề.
    // Hiện lời mời thay cho "Bước 4 / 4", không thì người dùng không biết còn
    // một bước bấm nữa mới sang "Đang duy trì" (máy thật 13/10).
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull;
    final roundDone =
        enrollment != null &&
        enrollment!.completedAt == null &&
        ordered.isNotEmpty &&
        entitlement != null &&
        practiceReachableDone(
          steps: ordered,
          completed: enrollment!.completedSteps,
          entitlement: entitlement,
        );

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
                    wrKeepCompounds(theme.title),
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
            // Script: "Bước ${d+1} / 4" là bước ĐANG LÀM, không phải số bước
            // đã xong. Hết bước mà chưa đưa vào duy trì thì đứng ở bước cuối.
            if (roundDone)
              Text(
                wrKeepCompounds(
                  tr(
                    'Hết một vòng · Đưa vào phần duy trì ›',
                    'One full round · Move to keeping ›',
                  ),
                ),
                key: Key('wr_growth_theme_round_done_${theme.themeId}'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: WrColors.link,
                ),
              )
            else
              Text(
                wrKeepCompounds(
                  doneCount == 0
                      ? tr('Chưa bắt đầu', 'Not started')
                      : tr(
                          'Bước $currentStep / $kPracticeStageCount',
                          'Step $currentStep / $kPracticeStageCount',
                        ),
                ),
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
                          wrKeepCompounds(
                            tr(
                              'Chủ đề chưa có trong thư viện',
                              'Theme not in the library',
                            ),
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
                          wrKeepCompounds(
                            tr('Bối cảnh công việc', 'Work context'),
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
            ],
          ),
        ),
      ],
    );
  }
}

// ── PHẦN 3: MỞ RỘNG ────────────────────────────────────────────────────────

class _ExpandSection extends ConsumerWidget {
  const _ExpandSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(tr('Mở rộng', 'Expand')),
        const SizedBox(height: 8),

        LayoutBuilder(
          builder: (context, constraints) {
            final seriesTitle = kLearningLibraryLabel;
            final seriesDescription = kLearningLibraryIntro;
            final seriesMeta = kLearningLibraryMeta;

            final teaTitle = tr(
              'Trà chiều nghề nghiệp',
              'Career Afternoon Tea',
            );
            final teaDescription = kTraChieuCardDescription;
            final workshops =
                ref.watch(activeWorkshopsProvider).valueOrNull ?? const [];
            final next = nextTraChieu(workshops, now: DateTime.now());
            final teaMeta = next != null
                ? '${traChieuCardLabel(next)} · ${tr('10 đến 12 người · 2 giờ', '10 to 12 people · 2 hours')}'
                : kTraChieuCardLine;

            final bodyMin = [
              _ExpandCard.bodyHeight(
                context,
                width: constraints.maxWidth,
                title: seriesTitle,
                description: seriesDescription,
                meta: seriesMeta,
              ),
              _ExpandCard.bodyHeight(
                context,
                width: constraints.maxWidth,
                title: teaTitle,
                description: teaDescription,
                meta: teaMeta,
              ),
            ].reduce((a, b) => a > b ? a : b);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Tâm thế người đi làm
                _ExpandCard(
                  key: const Key('wr_growth_youtube_card'),
                  onTap: () => context.push('/wr/learning-library'),
                  image: 'assets/images/hero/bg_hieu.webp',
                  dim: 0.15,
                  badges: [
                    _ExpandBadge(
                      tr('TẬP MỚI', 'NEW EPISODE'),
                      background: WrColors.coral,
                      color: Colors.white,
                    ),
                    _ExpandBadge(
                      tr('YOUTUBE · 9 PHÚT', 'YOUTUBE · 9 MIN'),
                      background: Colors.white.withValues(alpha: 0.92),
                      color: WrColors.navy,
                    ),
                  ],
                  playIcon: true,
                  title: seriesTitle,
                  description: seriesDescription,
                  meta: seriesMeta,
                  bodyMinHeight: bodyMin,
                ),

                const SizedBox(height: 11),

                // 2. Trà chiều nghề nghiệp
                _ExpandCard(
                  key: const Key('wr_growth_tra_chieu_card'),
                  onTap: () => context.push('/wr/tra-chieu'),
                  image: 'assets/images/thumb_trachieu.webp',
                  dim: 0.10,
                  badges: [
                    _ExpandBadge(
                      tr('OFFLINE · TRÀ CHIỀU', 'OFFLINE · AFTERNOON TEA'),
                      background: const Color(0xDC093774),
                      color: WrColors.cream,
                    ),
                  ],
                  title: teaTitle,
                  description: teaDescription,
                  meta: teaMeta,
                  bodyMinHeight: bodyMin,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Nhãn nhỏ góc trên ảnh của thẻ Mở rộng.
class _ExpandBadge extends StatelessWidget {
  const _ExpandBadge(
    this.label, {
    required this.background,
    required this.color,
  });

  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Khuôn chung của thẻ Mở rộng: dải ảnh + tiêu đề + mô tả + meta (script Sprint 2).
class _ExpandCard extends StatelessWidget {
  const _ExpandCard({
    super.key,
    required this.onTap,
    required this.image,
    required this.dim,
    required this.badges,
    required this.title,
    required this.description,
    required this.meta,
    this.playIcon = false,
    this.bodyMinHeight = 0,
  });

  final VoidCallback onTap;
  final String image;
  final double dim;
  final List<Widget> badges;
  final String title;
  final String description;
  final String meta;
  final bool playIcon;

  /// Chiều cao tối thiểu phần chữ: [_ExpandSection] truyền chiều cao của
  /// thẻ có chữ dài nhất, để hai thẻ cao bằng nhau mà không cắt chữ nào.
  final double bodyMinHeight;

  static const double imageHeight = 94;
  static const bodyPadding = EdgeInsets.fromLTRB(15, 12, 15, 14);

  static const titleStyle = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    color: WrColors.navy,
    height: 1.4,
  );

  static const descriptionStyle = TextStyle(
    fontSize: 11.5,
    color: WrColors.muted,
    height: 1.45,
  );

  static const metaStyle = TextStyle(
    fontSize: 9.6,
    color: WrColors.muted,
    height: 1.35,
    letterSpacing: -0.15,
  );

  @override
  Widget build(BuildContext context) {
    return WrCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _FadeBottom(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          image,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0.0, -0.16),
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => const SizedBox.expand(),
                        ),
                        Container(color: Colors.black.withValues(alpha: dim)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 11,
                    child: Row(
                      children: [
                        for (var i = 0; i < badges.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          badges[i],
                        ],
                      ],
                    ),
                  ),
                  if (playIcon)
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
                          Icons.play_arrow_rounded,
                          color: WrColors.navy,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: bodyMinHeight),
            child: Padding(
              padding: bodyPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wrKeepCompounds(title), style: titleStyle),
                  const SizedBox(height: 4),
                  Text(wrKeepWords(description), style: descriptionStyle),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      meta,
                      maxLines: 1,
                      softWrap: false,
                      style: metaStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chiều cao phần chữ của thẻ ở bề rộng [width], theo cỡ chữ của máy.
  static double bodyHeight(
    BuildContext context, {
    required double width,
    required String title,
    required String description,
    required String meta,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    final textWidth = width - bodyPadding.horizontal;
    double measure(String text, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: wrKeepWords(text), style: style),
        textDirection: dir,
        textScaler: scaler,
      )..layout(maxWidth: textWidth);
      final h = p.height;
      p.dispose();
      return h;
    }

    double measureSingleLine(String text, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: dir,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final h = p.height;
      p.dispose();
      return h;
    }

    return bodyPadding.vertical +
        measure(title, titleStyle) +
        4.0 +
        measure(description, descriptionStyle) +
        5.0 +
        measureSingleLine(meta, metaStyle);
  }
}

/// Đáy ảnh mờ dần 30px vào nền thẻ (như thẻ 15 câu hỏi, `.chatcard-img::after`).
/// Làm mờ chính ảnh thay vì phủ một màu: thẻ trắng có vân giấy, một dải màu
/// trơn sẽ lộ thành vạch.
class _FadeBottom extends StatelessWidget {
  const _FadeBottom({required this.child});

  final Widget child;

  static const double fade = 30;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Colors.white, Colors.white, Colors.transparent],
      stops: [0, ((rect.height - fade) / rect.height).clamp(0.0, 1.0), 1],
    ).createShader(rect),
    child: child,
  );
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
                    wrKeepCompounds(
                      practiceThemeSourceLabel(theme, enrollment.startedAt),
                    ),
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
            Text(wrKeepCompounds(theme.title), style: _h2),
            const SizedBox(height: 7),
            Text(
              wrKeepCompounds(
                next != null
                    ? tr(
                        'Tiếp theo: ${practiceStepAction(next.title)}',
                        'Next: ${practiceStepAction(next.title)}',
                      )
                    : tr(
                        'Bạn đã đi hết các bước hiện tại.',
                        'You have gone through all the current steps.',
                      ),
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
      wrKeepCompounds(label),
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

/// "ĐANG DUY TRÌ" — chủ đề đã đi hết bốn bước và đã được đưa vào duy trì.
///
/// Không có chủ đề nào thì ẩn cả khối (script `keep.length ? … : ''`).
class _KeepingSection extends ConsumerWidget {
  const _KeepingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(wrKeepingThemesProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final preview = items.take(kGrowthKeepPreview).toList();
    final remaining = items.length - preview.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        key: const Key('wr_growth_keeping'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      wrKeepCompounds(tr('ĐANG DUY TRÌ', 'MAINTAINING')),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: WrColors.text3,
                        letterSpacing: 0.6,
                      ),
                    ),
                    InkWell(
                      key: const Key('wr_growth_keep_all'),
                      onTap: () => context.push('/wr/growth/stance-keep'),
                      child: Text(
                        wrKeepCompounds(tr('Xem đầy đủ ›', 'See all ›')),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: WrColors.pillTealText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                for (var i = 0; i < preview.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: WrColors.lineSoft,
                    ),
                  WrKeepRow(
                    item: preview[i],
                    now: now,
                    doneLabel: tr('✓ Đã ghi', '✓ Recorded'),
                  ),
                ],
                if (remaining > 0)
                  InkWell(
                    onTap: () => context.push('/wr/growth/stance-keep'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 11, 0, 13),
                      child: Center(
                        child: Text(
                          wrKeepCompounds(
                            tr(
                              'Còn $remaining chủ đề khác',
                              '$remaining more themes',
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: WrColors.text3,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            wrKeepCompounds(
              tr(
                'Những chủ đề đã hoàn thành ở bốn bước làm quen. Mỗi lần bạn thực hành lại trong công việc thật, bấm Ghi nhận để hệ thống giúp bạn lưu giữ.',
                'Themes completed in the four steps. Each time you practise again in real work, tap Record so the app keeps it for you.',
              ),
            ),
            style: const TextStyle(
              fontSize: 12,
              color: WrColors.text3,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng `.keep`: tên chủ đề, "n lần · gần nhất …", nút Ghi nhận.
///
/// Dùng chung cho tab Phát triển và màn Tâm thế & duy trì.
class WrKeepRow extends StatelessWidget {
  const WrKeepRow({
    super.key,
    required this.item,
    required this.now,
    required this.doneLabel,
  });

  final KeepingTheme item;
  final DateTime now;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final last = item.lastAt;
    final meta = last == null
        ? tr('${item.count} lần', '${item.count} times')
        : tr(
            '${item.count} lần · gần nhất ${keepLastLabel(last, now)}',
            '${item.count} times · last ${keepLastLabel(last, now)}',
          );
    // Cỡ chữ đúng script (`.keep`: tên 14px, `.tiny` 11px, `.mark` 11.5px).
    // Để phần cộng của WrTextScaler thì nút "✓ Đã ghi hôm nay" phình ra, ép
    // tên chủ đề vỡ từng chữ (máy thật 13/10, cỡ chữ hệ thống 1.15).
    return WrScriptTextScale(
      child: Padding(
        key: Key('wr_keep_row_${item.theme.themeId}'),
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wrKeepCompounds(item.theme.title),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: WrColors.navy,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    wrKeepCompounds(meta),
                    style: const TextStyle(fontSize: 11, color: WrColors.text3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            WrKeepMarkButton(
              theme: item.theme,
              markedToday: item.markedToday,
              doneLabel: doneLabel,
            ),
          ],
        ),
      ),
    );
  }
}
