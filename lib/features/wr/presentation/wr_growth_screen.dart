import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Phát triển — Practice Surface (WXS §8.6).
//
// Màn này chỉ giữ đúng một việc: chủ đề đang thực hành và bước kế tiếp.
// "Thực hành khác" và "Kỹ năng đã hình thành" đã tách thành màn riêng — bấm
// vào dòng mới mở, không xổ tại chỗ. Dòng "Chặng đường phát triển" đã bỏ khỏi
// màn này (2026-08-03); màn `/wr/growth/journey` vẫn còn nhưng không còn lối
// vào từ tab Phát triển.

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_practice_match.dart';
import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/logic/wr_tra_chieu.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_link_row.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../../workshops/workshops_providers.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_practice_theme_screen.dart';

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
  // Guard chống double-tap khi đang enroll
  final Set<String> _enrollingThemeIds = {};

  /// Đã bấm "Xem thêm" chưa. Đặt ở State chứ không phải provider: đây là trạng
  /// thái của một lần xem màn, mở lại tab thì thu gọn về như cũ là đúng.
  bool _showAllThemes = false;

  Future<void> _enroll(String themeId) async {
    if (_enrollingThemeIds.contains(themeId)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _enrollingThemeIds.add(themeId));
    try {
      final repo = ref.read(wrIntelligenceRepositoryProvider);
      await repo.enrollTheme(PracticeEnrollment(
        userId: userId,
        themeId: themeId,
        completedSteps: const [],
      ));
      ref.invalidate(practiceEnrollmentsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không bắt đầu được. Thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _enrollingThemeIds.remove(themeId));
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

    return Scaffold(
      // Nền TRẮNG như ba tab kia — xem `wr_card.dart`. Trước đây màn này dùng
      // #FBFBF9, một sắc ngà không có trong hệ màu nào cả: đứng riêng thì không
      // ai thấy, nhưng chuyển tab từ Home sang là thấy màn tối đi một chút.
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: themesAsync.when(
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
            final enrollments = enrollmentsAsync.valueOrNull ?? const [];
            final entitlement = entitlementAsync.valueOrNull ??
                WrEntitlement(plan: WrPlan.free);
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
    // Find the first active (non-completed) enrollment
    final activeEnrollment =
        enrollments.where((e) => e.completedAt == null).firstOrNull;
    final activeTheme = activeEnrollment != null
        ? themes.where((t) => t.themeId == activeEnrollment.themeId).firstOrNull
        : null;

    // Themes chưa enroll (loại bỏ MỌI enrollment, kể cả completed) và chưa bị
    // ngưng đề xuất. `pt-voice` / `pt-rhythm` đời đầu trùng chiều với `pt-c2` /
    // `pt-a2` nên đã đánh dấu retired — mời người mới vào chúng là mời vào một
    // bản cũ của cùng một chủ đề.
    final enrolledThemeIds = enrollments.map((e) => e.themeId).toSet();
    final unenrolledThemes = themes
        .where((t) => !enrolledThemeIds.contains(t.themeId) && !t.isRetired)
        .toList();

    // Nhu cầu chủ đạo và chủ đề gợi ý đều đọc từ provider dùng chung, để màn
    // này và màn thư viện chủ đề không bao giờ đề xuất hai thứ khác nhau.
    // Hai hướng mở khoá (khách 2026-07-31 — tích luỹ hàng ngày / Self-Check 15
    // câu) và thứ tự khớp theo CHIỀU tình huống nằm trong provider đó.
    final dominantNeed = ref.watch(wrDominantNeedProvider);
    final suggestion = ref.watch(wrPracticeSuggestionProvider);

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

    final enrolledCards = [
      ...cardsOf(enrollments.where((e) => e.completedAt == null)),
      ...cardsOf(enrollments.where((e) => e.completedAt != null)),
    ];
    final hiddenThemeCount =
        (enrolledCards.length - kGrowthThemesPreview).clamp(0, 1 << 30);
    final visibleCards = _showAllThemes || hiddenThemeCount == 0
        ? enrolledCards
        : enrolledCards.take(kGrowthThemesPreview).toList();


    return CustomScrollView(
      slivers: [
        // ── Top area ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WrTabBackLink(currentTab: WrTab.growth),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phát triển',
                            style: TextStyle(
                              fontSize: 14,
                              color: WrColors.muted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Thực hành',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: WrColors.navy,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // v1.6 §9.1: "Tôi" là avatar ở mọi màn tab.
                    const WrProfileAvatar(),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Task C: Card "Bước đang chờ bạn" (khi có active theme) ─────────
        if (activeTheme != null)
          _NextStepCardSliver(
            theme: activeTheme,
            enrollment: activeEnrollment!,
            entitlement: entitlement,
          ),

        // ── Danh sách chủ đề, hoặc lời mời khi chưa có chủ đề nào ──────────
        //
        // Giao diện mẫu Sprint 2: màn này liệt kê CHỦ ĐỀ, không liệt kê bước.
        // Mỗi thẻ nói đủ ba điều — chủ đề nào, đang ở giai đoạn nào, còn mấy
        // bước — rồi bấm vào mới mở chuỗi bước ở màn riêng.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: enrolledCards.isEmpty
                ? _buildSuggestionCard(
                    context,
                    eyebrow: 'GỢI Ý TỪ HIỂU MÌNH',
                    emptyEyebrow: 'TRỌNG TÂM HIỆN TẠI',
                    suggestion: suggestion,
                    dominantNeed: dominantNeed,
                    situations: situations,
                    canEnroll:
                        entitlement.canEnrollPracticeTheme(activeCount),
                    hasAnyTheme: themes.isNotEmpty,
                    hasCandidates: unenrolledThemes.isNotEmpty,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WrEyebrow('CHỦ ĐỀ CỦA BẠN'),
                      const SizedBox(height: 12),
                      for (final pair in visibleCards)
                        WrPracticeThemeCard(
                          key: Key('wr_growth_theme_card_${pair.$1.themeId}'),
                          theme: pair.$1,
                          enrollment: pair.$2,
                        ),
                      if (hiddenThemeCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: WrActionLink(
                            key: const Key('wr_growth_themes_more'),
                            label: _showAllThemes
                                ? 'Thu gọn'
                                : 'Xem thêm $hiddenThemeCount chủ đề',
                            onTap: () => setState(
                              () => _showAllThemes = !_showAllThemes,
                            ),
                          ),
                        ),
                      // Chủ đề tiếp theo. Chỉ hiện khi còn chỗ trong quota —
                      // premium thì luôn còn, free thì hết 2 chỗ là nhường
                      // cho _QuotaCard bên dưới nói lý do và dẫn sang paywall.
                      //
                      // Đây là một THẺ GỢI Ý kèm lý do, không phải một dòng dẫn
                      // sang danh sách chủ đề. Chủ đề là thứ phần mềm chuẩn bị
                      // từ những gì người dùng đã nhìn lại và từ bộ tự đánh giá
                      // — bày cả thư viện ra cho họ tự chọn thì họ không có căn
                      // cứ nào để chọn (khách 2026-08-04).
                      //
                      // Trước đó màn này không có lối nào để theo thêm chủ đề
                      // (bỏ theo yêu cầu 30/7), nên premium ghi danh vài chủ đề
                      // xong là kẹt, nhìn ra ngoài y như bị giới hạn cứng.
                      if (entitlement.canEnrollPracticeTheme(activeCount))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildSuggestionCard(
                            context,
                            eyebrow: 'CHỦ ĐỀ TIẾP THEO CHO BẠN',
                            suggestion: suggestion,
                            dominantNeed: dominantNeed,
                            situations: situations,
                            canEnroll: true,
                            hasAnyTheme: themes.isNotEmpty,
                            hasCandidates: unenrolledThemes.isNotEmpty,
                          ),
                        ),
                      _QuotaCard(
                        quota: entitlement.maxActivePracticeThemes,
                        activeCount: activeCount,
                      ),
                    ],
                  ),
          ),
        ),

        // ── Divider ──────────────────────────────────────────────────────
        if (enrolledCards.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 16),
              child: WrSectionDivider(),
            ),
          ),

        // ── Cơ hội phát triển — workshop gần nhất sắp diễn ra ────────────
        const _OpportunitySliver(),

        // ── Lối rẽ còn lại, mở thành màn riêng ──────────────────────────
        //
        // "Chặng đường phát triển" đã bỏ khỏi màn này (yêu cầu 2026-08-03).
        // Màn `/wr/growth/journey` vẫn còn, chỉ là không còn lối vào từ đây.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeTheme == null) const WrSectionDivider(),
                WrLinkRow(
                  key: const Key('wr_growth_skills_row'),
                  label: 'Kỹ năng đã hình thành',
                  onTap: () => context.push('/wr/growth/skills'),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ── Thẻ gợi ý chủ đề ──────────────────────────────────────────────────────

  /// Thẻ "chủ đề phần mềm chuẩn bị cho bạn".
  ///
  /// Dùng ở hai chỗ trên màn này: khi chưa theo chủ đề nào (thay cho danh sách),
  /// và ngay dưới danh sách khi còn chỗ trong quota. Cùng một thẻ để hai chỗ nói
  /// cùng một câu — chủ đề đến từ những gì người dùng đã nhìn lại, kèm lý do.
  ///
  /// Ba trạng thái rỗng khác nhau, ba câu khác nhau — [hasAnyTheme] = thư viện
  /// có chủ đề nào không, [hasCandidates] = còn chủ đề nào chưa ghi danh không.
  /// Gộp cả ba thành một câu là nói sai với ít nhất hai nhóm người dùng.
  Widget _buildSuggestionCard(
    BuildContext context, {
    required String eyebrow,
    String? emptyEyebrow,
    required PracticeSuggestion? suggestion,
    required HumanNeed? dominantNeed,
    required List<WrSituation> situations,
    required bool canEnroll,
    required bool hasAnyTheme,
    required bool hasCandidates,
  }) {
    final suggestedTheme = suggestion?.theme;
    if (suggestedTheme == null) {
      // Chưa đề xuất được. Nói thẳng vì sao và chỉ ra việc cần làm để có đề
      // xuất, thay vì mở một danh sách chủ đề cho người dùng tự đoán.
      final (title, body) = switch ((hasAnyTheme, hasCandidates)) {
        // Thư viện chưa có chủ đề nào — không phải lỗi của người dùng, đừng bảo
        // họ đi nhìn lại thêm.
        (false, _) => (
            'Chưa có chủ đề nào đang thực hành',
            'WorkReflection sẽ đề xuất chủ đề dựa trên những gì bạn đã nhìn lại.',
          ),
        // Còn chủ đề để mời, chỉ là chưa đủ căn cứ để chọn cái nào.
        (true, true) => (
            'Chưa đủ dữ liệu để đề xuất chủ đề',
            'Chủ đề thực hành được chọn từ những tình huống bạn gặp lại nhiều '
                'lần. Bạn nhìn lại thêm vài lần nữa, hoặc làm bộ tự đánh giá '
                'để có ngay một chủ đề.',
          ),
        (true, false) => (
            'Bạn đã bắt đầu tất cả chủ đề hiện có',
            'Hoàn thành một chủ đề đang theo, rồi quay lại đây.',
          ),
      };
      final canSelfCheck = hasAnyTheme && hasCandidates;

      return WrCardMinimal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WrEyebrow(emptyEyebrow ?? eyebrow, color: WrColors.muted),
            const SizedBox(height: 10),
            Text(
              title,
              key: const Key('wr_growth_suggestion_empty'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: WrColors.dark,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
            if (canSelfCheck) ...[
              const SizedBox(height: 14),
              WrActionLink(
                key: const Key('wr_growth_suggestion_self_check'),
                label: 'Làm bộ tự đánh giá',
                onTap: () => context.push('/wr/self-check'),
              ),
            ],
          ],
        ),
      );
    }

    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(eyebrow),
          const SizedBox(height: 10),
          Text(
            suggestedTheme.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.3,
            ),
          ),
          if (suggestedTheme.description != null) ...[
            const SizedBox(height: 6),
            Text(
              suggestedTheme.description!,
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.muted,
                height: 1.5,
              ),
            ),
          ],
          // Lý do — nói ĐÚNG cái đã dẫn tới chủ đề này. Khớp được theo tình
          // huống thì gọi thẳng tên tình huống và số lần: đó là điều người dùng
          // tự nhận ra được, khác hẳn một câu chung chung về nhu cầu.
          if (practiceSuggestionReason(suggestion, situations, dominantNeed)
              case final reason?) ...[
            const SizedBox(height: 6),
            Text(
              reason,
              key: const Key('wr_growth_suggestion_reason'),
              style: const TextStyle(
                fontSize: 12,
                color: WrColors.muted,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              key: const Key('wr_growth_suggestion_start'),
              onPressed: canEnroll
                  ? () => _enroll(suggestedTheme.themeId)
                  : () => context.push('/wr/paywall'),
              style: TextButton.styleFrom(
                backgroundColor: WrColors.navy,
                foregroundColor: WrColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Bắt đầu thực hành',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          WrActionLink(
            label: 'Xem trong Hiểu mình',
            onTap: () => context.go('/wr/discover?from=growth'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OpportunitySliver — thẻ mời buổi Trà Chiều Nghề Nghiệp sắp tới.
//
// Họp khách 2026-07-29 thu hẹp thẻ này lại: trước đây nó gợi buổi workshop gần
// nhất BẤT KỲ của web app. Khách không muốn thế — "nếu offline cho Work
// Reflection thì nó sẽ là một chương trình riêng cho Work Reflection thôi".
// Đẩy cả kho workshop sang làm app có mùi bán hàng, đúng thứ khách đang tránh.
//
// Vì vậy thẻ chỉ đọc các buổi có category Trà Chiều, và KHÔNG rơi về một
// workshop khác cho có khi chưa buổi nào được mở.
//
// Nhưng thẻ vẫn hiện: chương trình có thật kể cả khi lịch còn trống, và màn chi
// tiết đã nói thẳng "chưa mở buổi nào" chứ không dựng thẻ rỗng. Bản trước ẩn cả
// khối khi `nextTraChieu` trả null — trên máy khách 2026-07-30 chưa có buổi nào
// mang category Trà Chiều trong `cc_workshops`, nên Trà Chiều mất hẳn khỏi tab
// Phát triển: "tôi không còn thấy cái mục giao diện trà chiều đâu cả".
//
// Ẩn cả cửa vào vì lịch trống là nhầm hai chuyện: KHÔNG CÓ BUỔI NÀO SẮP TỚI ≠
// KHÔNG CÓ CHƯƠNG TRÌNH. Ba luật, cách buổi diễn ra, lịch dự kiến — người dùng
// vẫn nên đọc được để quyết định có muốn dự lần sau hay không.
//
// Hình thức theo mockup Sprint 2 (`screenAct`, thẻ cuối màn Phát triển): nền
// NAVY, pill teal "Offline · Trà Chiều Nghề Nghiệp", chủ đề buổi là câu trích
// serif in nghiêng, rồi một dòng nhỏ nói khuôn buổi. Navy là có chủ đích — đây
// là khối duy nhất trên màn dẫn ra NGOÀI app, và nó phải khác hẳn các thẻ chủ
// đề trắng để không bị đọc lẫn thành "một chủ đề nữa để thực hành".
//
// 2026-07-30: khách bỏ dòng "Thực hành khác" ở màn này và đặt thẻ Trà Chiều vào
// đúng chỗ đó — mockup không có màn danh sách chủ đề, chủ đề đến từ gợi ý.
// ⚠ Hệ quả: `/wr/growth/themes` giờ chỉ còn một lối vào — khối "Tiếp tục hôm
//   nay" ở Home khi chưa theo chủ đề nào.
// ─────────────────────────────────────────────────────────────────────────────

class _OpportunitySliver extends ConsumerWidget {
  const _OpportunitySliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshops = ref.watch(activeWorkshopsProvider).valueOrNull ?? const [];
    final next = nextTraChieu(workshops, now: DateTime.now());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
        child: InkWell(
          key: const Key('wr_growth_opportunity'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/wr/tra-chieu'),
          child: WrCardNavy(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.home_outlined,
                      size: 16,
                      color: WrColors.coral,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: WrColors.teal.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Offline · $kTraChieuLabel',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: WrColors.pillTealText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Lịch trống thì nói đúng như vậy, không mượn câu chủ đề của
                // buổi cũ đã diễn ra để thẻ trông có nội dung.
                Text(
                  next == null
                      ? 'Chưa có buổi nào được mở.'
                      : '"${next.title}"',
                  style: WrText.serifQuote(
                    fontSize: 14,
                    color: WrColors.cream,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  next == null
                      ? kTraChieuFormatLabel
                      : '${traChieuWhenLabel(next)} · $kTraChieuFormatLabel',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: WrColors.cream.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Xem chi tiết',
                      style: TextStyle(
                        fontSize: 11,
                        color: WrColors.cream.withValues(alpha: 0.55),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: WrColors.cream.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task C: _NextStepCardSliver — card "BƯỚC ĐANG CHỜ BẠN"
// ─────────────────────────────────────────────────────────────────────────────

class _NextStepCardSliver extends ConsumerWidget {
  const _NextStepCardSliver({
    required this.theme,
    required this.enrollment,
    required this.entitlement,
  });

  final PracticeTheme theme;
  final PracticeEnrollment enrollment;
  final WrEntitlement entitlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(practiceStepsProvider(theme.themeId));

    return SliverToBoxAdapter(
      child: stepsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (rawSteps) {
          final steps = List.of(rawSteps)
            ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
          final completed = enrollment.completedSteps;

          // Bước tiếp theo: chưa xong, không bị premium lock
          final nextStep = steps
              .where(
                (s) =>
                    !completed.contains(s.stepId) &&
                    !(s.isPremium &&
                        !entitlement.canAccessPracticeStep(isPremiumStep: true)),
              )
              .firstOrNull;

          if (nextStep == null) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: GestureDetector(
              key: const Key('wr_growth_next_step_card'),
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  context.push('/wr/growth/theme/${theme.themeId}'),
              child: WrCardMinimal(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Ô vuông trắng với icon — ô lồng trong thẻ kem thì trắng, y
                  // như ô icon của thẻ "Gợi ý" và ô "Tiếp tục hôm nay" ở Home.
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: WrColors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    // Icon, không phải chữ '◎': glyph đó không có trong mọi font
                    // và máy nào thiếu thì hiện ra ô vuông rỗng.
                    child: const Icon(
                      Icons.adjust,
                      size: 17,
                      color: WrColors.coral,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BƯỚC ĐANG CHỜ BẠN',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: WrColors.coral,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '"${theme.title}" · ${nextStep.title}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: WrColors.navy,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// WrPracticeThemeCard — một chủ đề trên tab Phát triển (giao diện mẫu Sprint 2)
//
// Thẻ nói ba điều và chỉ ba điều: chủ đề nào, đang ở giai đoạn nào, còn mấy
// bước. Nội dung từng bước nằm ở màn chủ đề — một màn một việc.
// ─────────────────────────────────────────────────────────────────────────────

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
    final total = steps.length;
    final done =
        steps.where((s) => enrollment.completedSteps.contains(s.stepId)).length;
    final finished = enrollment.completedAt != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/wr/growth/theme/${theme.themeId}'),
        child: WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      finished ? 'Đã hoàn thành' : 'Đang thực hành',
                      style: const TextStyle(
                        fontSize: 12,
                        color: WrColors.muted,
                      ),
                    ),
                  ),
                  if (total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // Trắng, không phải navy mờ: navy 6% trên nền kem ra
                        // một sắc xám ngà, gần như không thấy được viên pill.
                        color: WrColors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        finished
                            ? 'Trọn chuỗi'
                            : 'Giai đoạn ${min(done + 1, total)}/$total',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                theme.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: WrColors.navy,
                  height: 1.25,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(height: 12),
                WrPracticeProgressDots(total: total, done: done),
                const SizedBox(height: 10),
                Text(
                  '$done/$total bước hoàn thành',
                  style: const TextStyle(fontSize: 12.5, color: WrColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuotaCard — "Free: tối đa 2 chủ đề cùng lúc" (giao diện mẫu Sprint 2)
//
// Chỉ hiện với bản miễn phí: Premium không có trần nên nói ra là nói thừa.
// ─────────────────────────────────────────────────────────────────────────────

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota, required this.activeCount});

  final int? quota;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final max = quota;
    if (max == null) return const SizedBox.shrink();

    return GestureDetector(
      key: const Key('wr_growth_quota_card'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/wr/paywall?trigger=practice_limit'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: WrColors.navy.withValues(alpha: 0.16),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Text(
              'Bản miễn phí mở tối đa $max chủ đề cùng lúc '
              '(đang mở $activeCount/$max).',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.muted,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Premium: không giới hạn',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: WrColors.coral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
