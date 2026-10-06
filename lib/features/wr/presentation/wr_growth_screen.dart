import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_reflect_v47.dart' show insightGist;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Phát triển — Practice Surface (WXS §8.6), bố cục theo mockup v47 `screenAct`.
//
// Thứ tự khối, đúng mockup:
//   hero `act` "Thực hành" → thẻ cầu nối "Điều bạn từng viết" (Insight gần
//   nhất → "Xem 3 cách để cân nhắc") → "Điều bạn đang thử" (tối đa 3 chủ đề +
//   "Xem thêm") → thẻ nét đứt "Tự thêm · Một chủ đề chưa có trong thư viện" →
//   "Ghi nhận một điều · Bạn vừa học được điều hữu ích" → "Free: tối đa N chủ
//   đề" + thẻ Trà Chiều.
// Dưới cùng, ngoài mockup (theo chữ của khách): "Kỹ năng của bạn" và "Cập nhật
// bối cảnh công việc" (JD/CV).
//
// "Việc bạn tự đặt" đã rời màn này (chủ dự án chốt 06/10, Q3); bảng và dữ liệu
// vẫn giữ nguyên.

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_practice_theme_grant.dart';
import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/logic/wr_tra_chieu.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_small_button.dart';
import '../../../core/logic/wr_practice_v47.dart';
import '../../../core/models/wr_episode.dart';
import '../../../core/widgets/wr_link_row.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../../workshops/workshops_providers.dart';
import '../growth_providers.dart';
import '../owned_skill_providers.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

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
    // Themes chưa enroll (loại bỏ MỌI enrollment, kể cả completed) và chưa bị
    // ngưng đề xuất. `pt-voice` / `pt-rhythm` đời đầu trùng chiều với `pt-c2` /
    // `pt-a2` nên đã đánh dấu retired — mời người mới vào chúng là mời vào một
    // bản cũ của cùng một chủ đề.
    final enrolledThemeIds = enrollments.map((e) => e.themeId).toSet();
    final unenrolledThemes = themes
        .where((t) => !enrolledThemeIds.contains(t.themeId) && !t.isRetired)
        .toList();

    // Số lần đã nhìn lại — cùng con số với câu "Bạn đã nhìn lại N lần" ở tab
    // Hiểu mình, và là một trong hai đường đổi ra chủ đề (xem
    // `wr_practice_theme_grant.dart`).
    final reflectionCount =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull?.length ?? 0;

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
    final hiddenThemeCount = (enrolledCards.length - kGrowthThemesPreview)
        .clamp(0, 1 << 30);
    final visibleCards = _showAllThemes || hiddenThemeCount == 0
        ? enrolledCards
        : enrolledCards.take(kGrowthThemesPreview).toList();

    final canAddTheme = entitlement.canEnrollPracticeTheme(activeCount);

    return ListView(
      // Padding tường minh: `ListView` không có padding sẽ xoá phần thanh
      // trạng thái khỏi `MediaQuery` của con, ảnh hero hết tràn lên.
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        WrHeroHeader.inner(
          key: const Key('wr_growth_hero'),
          art: WrHeroArt.act,
          eyebrow: tr('Phát triển', 'Grow'),
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
              // ── Điều bạn từng viết ──────────────────────────────────────
              _BridgeCard(
                themes: themes,
                enrollments: enrollments,
                situations: situations,
              ),
              const SizedBox(height: 14),

              // ── Điều bạn đang thử ───────────────────────────────────────
              Text(tr('Điều bạn đang thử', 'What you are trying'), style: _h2),
              const SizedBox(height: 2),
              Text(
                tr(
                  'Những chủ đề bắt đầu từ chính hành trình của bạn',
                  'Themes that started from your own journey',
                ),
                style: _tiny,
              ),
              const SizedBox(height: 10),
              if (enrolledCards.isEmpty)
                _buildEmptyThemeCard(
                  context,
                  eyebrow: tr('TRỌNG TÂM HIỆN TẠI', 'YOUR CURRENT FOCUS'),
                  hasAnyTheme: themes.isNotEmpty,
                  hasCandidates: unenrolledThemes.isNotEmpty,
                  reflectionCount: reflectionCount,
                )
              else ...[
                for (final pair in visibleCards)
                  WrPracticeThemeCard(
                    key: Key('wr_growth_theme_card_${pair.$1.themeId}'),
                    theme: pair.$1,
                    enrollment: pair.$2,
                  ),
                if (hiddenThemeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: WrActionLink(
                      key: const Key('wr_growth_themes_more'),
                      label: _showAllThemes
                          ? tr('Thu gọn', 'Show less')
                          : tr(
                              'Xem thêm $hiddenThemeCount chủ đề',
                              'See $hiddenThemeCount more themes',
                            ),
                      onTap: () =>
                          setState(() => _showAllThemes = !_showAllThemes),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              // ── Tự thêm ─────────────────────────────────────────────────
              WrCard(
                key: const Key('wr_growth_add_theme'),
                dashed: true,
                onTap: () => context.push(
                  canAddTheme
                      ? '/wr/growth/add-theme'
                      : '/wr/paywall?trigger=practice_limit',
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WrEyebrow(tr('TỰ THÊM', 'ADD YOUR OWN')),
                          const SizedBox(height: 6),
                          Text(
                            tr(
                              'Một chủ đề chưa có trong thư viện',
                              'A theme that is not in the library',
                            ),
                            style: _cardTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(
                              'Kể lại tình huống thật, điều bạn muốn khác đi và '
                                  'cách bạn đã thử.',
                              'Describe a real situation, what you want to '
                                  'change and what you have tried.',
                            ),
                            style: _tiny.copyWith(height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: WrColors.navy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Ghi nhận một điều ───────────────────────────────────────
              WrCard(
                key: const Key('wr_growth_learning_card'),
                dashed: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WrEyebrow(tr('GHI NHẬN MỘT ĐIỀU', 'NOTE ONE THING')),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'Bạn vừa học được điều hữu ích',
                        'You just learned something useful',
                      ),
                      style: _cardTitle,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tr(
                        'Một bài học vừa nhận ra cũng là một phần của hành '
                            'trình, không phải một việc cần làm tiếp.',
                        'A lesson you just noticed is part of the journey too, '
                            'not another thing to do.',
                      ),
                      style: _tiny.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    WrSmallButton(
                      key: const Key('wr_growth_learning'),
                      kind: WrSmallButtonKind.ghost,
                      label: tr('Ghi lại', 'Write it down'),
                      arrow: true,
                      onTap: () => context.push('/wr/growth/learning'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Quota + Trà Chiều ───────────────────────────────────────
              if (entitlement.maxActivePracticeThemes != null) ...[
                _QuotaCard(quota: entitlement.maxActivePracticeThemes!),
                const SizedBox(height: WrCard.kGap),
              ],
              const _OpportunitySliver(),
              const SizedBox(height: 14),

              // ── Ngoài mockup, theo chữ của khách ────────────────────────
              WrLinkRow(
                key: const Key('wr_growth_skills_row'),
                label: tr('Kỹ năng của bạn', 'Your skills'),
                onTap: () => context.push('/wr/growth/skills'),
              ),
              WrLinkRow(
                key: const Key('wr_growth_context_docs_row'),
                label: tr(
                  'Cập nhật bối cảnh công việc',
                  'Update your work context',
                ),
                onTap: () => context.push('/wr/context-docs'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Thẻ trạng thái khi chưa có chủ đề nào ────────────────────────────────

  /// Thẻ nói vì sao chưa có chủ đề nào, và còn thiếu gì để có.
  ///
  /// KHÔNG có nút "Bắt đầu thực hành" ở đây nữa (khách 2026-08-04): chủ đề là
  /// việc phần mềm tự thêm khi người dùng đã tích đủ dữ liệu, bắt họ bấm để
  /// nhận thứ đáng lẽ tự đến là thừa một bước.
  ///
  /// Bốn trạng thái, bốn câu khác nhau — [hasAnyTheme] = thư viện có chủ đề nào
  /// không, [hasCandidates] = còn chủ đề nào chưa ghi danh không,
  /// [reflectionCount] = số lần đã nhìn lại. Gộp lại thành một câu là nói sai
  /// với ít nhất hai nhóm người dùng.
  Widget _buildEmptyThemeCard(
    BuildContext context, {
    required String eyebrow,
    required bool hasAnyTheme,
    required bool hasCandidates,
    required int reflectionCount,
  }) {
    final (title, body) = switch ((hasAnyTheme, hasCandidates)) {
      // Thư viện chưa có chủ đề nào — không phải lỗi của người dùng, đừng bảo
      // họ đi nhìn lại thêm.
      (false, _) => (
        tr('Chưa có chủ đề nào đang thực hành', 'No theme in practice yet'),
        tr(
          'WorkReflection sẽ đề xuất chủ đề dựa trên những gì bạn đã nhìn lại.',
          'WorkReflection will suggest a theme based on what you have looked back on.',
        ),
      ),
      // Còn chủ đề để mời, chỉ là chưa tích đủ. Nói đúng quãng đường còn lại
      // thay vì bảo họ chờ một điều không đo được.
      (true, true) => (
        tr('Chưa xác định chủ đề trọng tâm', 'No focus theme yet'),
        tr(
          'Bạn đã tích lũy $reflectionCount/$kReflectionsPerPracticeTheme lượt '
              'nhìn lại. Khi đạt mốc $kReflectionsPerPracticeTheme lượt, ứng '
              'dụng sẽ tự động gợi ý chủ đề phù hợp nhất với bạn. Bạn cũng có '
              'thể hoàn thành Self-Check để mở khóa ngay.',
          'You have $reflectionCount of $kReflectionsPerPracticeTheme look-backs so '
              'far. At $kReflectionsPerPracticeTheme the app will suggest the '
              'theme that fits you best. You can also finish the Self-Check to '
              'unlock it now.',
        ),
      ),
      (true, false) => (
        tr(
          'Bạn đã bắt đầu tất cả chủ đề hiện có',
          'You have started every theme available',
        ),
        tr(
          'Hoàn thành một chủ đề đang theo, rồi quay lại đây.',
          'Finish one you are already on, then come back here.',
        ),
      ),
    };

    return WrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(eyebrow, color: WrColors.muted),
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
          WrParagraph(
            body,
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
          if (hasAnyTheme && hasCandidates) ...[
            const SizedBox(height: 14),
            WrActionLink(
              key: const Key('wr_growth_suggestion_self_check'),
              label: tr('Làm Self-Check ngay', 'Take the Self-Check now'),
              onTap: () => context.push('/wr/self-check'),
            ),
          ],
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
    final workshops =
        ref.watch(activeWorkshopsProvider).valueOrNull ?? const [];
    final next = nextTraChieu(workshops, now: DateTime.now());

    return Padding(
      padding: EdgeInsets.zero,
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
                      color: WrColors.teal.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    // Chữ teal sáng, không dùng teal đậm của `.pill-teal`: trên
                    // nền navy teal đậm gần như chìm (script khách: chữ phải
                    // đủ tương phản với nền).
                    child: Text(
                      'Offline · $kTraChieuLabel',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.teal,
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
                    ? tr(
                        'Hiện chưa có lịch sự kiện mới.',
                        'No sessions scheduled yet.',
                      )
                    : '"${next.title}"',
                style: WrText.serifQuote(fontSize: 15.5, color: WrColors.cream),
              ),
              const SizedBox(height: 8),
              Text(
                next == null
                    ? kTraChieuFormatLabel
                    : '${traChieuWhenLabel(next)} · $kTraChieuFormatLabel',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: WrColors.cream.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('Xem chi tiết', 'See details'),
                    style: TextStyle(
                      fontSize: 12.5,
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
                      ? tr('Đang thử', 'Trying')
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

/// Dòng chữ đậm 13px trong thẻ nét đứt, +1.5.
const _cardTitle = TextStyle(
  fontSize: 14.5,
  fontWeight: FontWeight.w700,
  color: WrColors.navy,
  height: 1.4,
);

/// `.tiny` (11px) +1.5.
const _tiny = TextStyle(fontSize: 12.5, color: WrColors.text3);

// ─────────────────────────────────────────────────────────────────────────────
// _BridgeCard — "Điều bạn từng viết" (mockup v47).
//
// Cầu nối từ Hiểu mình sang Phát triển: nhắc lại Insight gần nhất người dùng đã
// giữ, rồi mời xem ba cách của chủ đề liên quan. Chủ đề liên quan = chủ đề đang
// theo cùng chiều SCA với tình huống đó; không có thì chủ đề đang theo đầu
// tiên; không theo chủ đề nào thì không có nút.
// ─────────────────────────────────────────────────────────────────────────────

class _BridgeCard extends ConsumerWidget {
  const _BridgeCard({
    required this.themes,
    required this.enrollments,
    required this.situations,
  });

  final List<PracticeTheme> themes;
  final List<PracticeEnrollment> enrollments;
  final List<WrSituation> situations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ??
        const <ReflectionEpisode>[];
    ReflectionEpisode? latest;
    for (final e in recentEpisodes(episodes)) {
      if ((e.draftMeaning?.trim().isNotEmpty ?? false)) {
        latest = e;
        break;
      }
    }
    WrSituation? situation;
    for (final s in situations) {
      if (s.code == latest?.situationCode) situation = s;
    }

    final active = [
      for (final e in enrollments)
        if (e.completedAt == null)
          if (themes.where((t) => t.themeId == e.themeId).firstOrNull
              case final t?)
            t,
    ];
    final related =
        active
            .where(
              (t) =>
                  situation != null && t.scaDimension == situation.scaDimension,
            )
            .firstOrNull ??
        active.firstOrNull;

    // Nhánh "Điều khác" không có mã tình huống: vẫn nhắc lại điều đã viết,
    // chỉ bỏ tên tình huống.
    final has = latest != null;
    return Container(
      key: const Key('wr_growth_bridge'),
      padding: WrCard.kPadding,
      decoration: BoxDecoration(
        color: WrColors.teal.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(WrCard.kRadius),
        border: Border.all(color: WrColors.teal.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(
            tr('ĐIỀU BẠN TỪNG VIẾT', 'WHAT YOU ONCE WROTE'),
            color: WrColors.pillTealText,
          ),
          const SizedBox(height: 7),
          if (has)
            Text.rich(
              key: const Key('wr_growth_bridge_text'),
              TextSpan(
                children: [
                  if (situation != null) ...[
                    TextSpan(
                      text: tr(
                        'Lần gần nhất bạn viết về ',
                        'The last time you wrote about ',
                      ),
                    ),
                    TextSpan(
                      text: '“${situation.text}”',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: tr(
                        ', bạn nhận ra: ${insightGist(latest.draftMeaning!)}',
                        ', you noticed: ${insightGist(latest.draftMeaning!)}',
                      ),
                    ),
                  ] else
                    TextSpan(
                      text: tr(
                        'Lần gần nhất bạn nhìn lại, bạn nhận ra: '
                            '${insightGist(latest.draftMeaning!)}',
                        'The last time you looked back, you noticed: '
                            '${insightGist(latest.draftMeaning!)}',
                      ),
                    ),
                ],
              ),
              style: WrText.serifQuote(fontSize: 16, color: WrColors.navy),
            )
          else
            Text(
              tr(
                'Những điều bạn từng nhìn lại có thể trở thành điểm bắt đầu cho '
                    'một cách thử mới.',
                'What you have looked back on can become the starting point '
                    'for a new way to try.',
              ),
              style: WrText.serifQuote(fontSize: 16, color: WrColors.navy),
            ),
          const SizedBox(height: 8),
          Text(
            has
                ? tr(
                    'Bạn muốn thử một cách khác trong lần tới?',
                    'Want to try a different way next time?',
                  )
                : tr(
                    'Khi một điều lặp lại đủ lâu, chúng ta có thể thử một cách '
                        'khác.',
                    'When something repeats long enough, we can try a '
                        'different way.',
                  ),
            style: const TextStyle(
              fontSize: 14,
              color: WrColors.text2,
              height: 1.65,
            ),
          ),
          if (related != null) ...[
            const SizedBox(height: 11),
            WrSmallButton(
              key: const Key('wr_growth_bridge_open'),
              kind: WrSmallButtonKind.dark,
              label: tr('Xem 3 cách để cân nhắc', 'See 3 ways to consider'),
              arrow: true,
              onTap: () => context.push('/wr/growth/theme/${related.themeId}'),
            ),
          ],
        ],
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
  const _QuotaCard({required this.quota});

  final int quota;

  @override
  Widget build(BuildContext context) {
    // Mockup v47: thẻ nét đứt, canh giữa, KHÔNG có số "đang mở x/y" — bản
    // trước hiện cả badge "/3" sai với Premium.
    return WrCard(
      key: const Key('wr_growth_quota_card'),
      dashed: true,
      onTap: () => context.push('/wr/paywall?trigger=practice_limit'),
      child: Column(
        children: [
          Text(
            tr(
              'Free: tối đa $quota chủ đề cùng lúc',
              'Free: up to $quota themes at a time',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: WrColors.text2,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 6),
          const _PremiumPill(),
        ],
      ),
    );
  }
}

class _PremiumPill extends StatelessWidget {
  const _PremiumPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: WrColors.coral.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      tr('Premium: không giới hạn', 'Premium: no limit'),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: WrColors.pillCoralText,
      ),
    ),
  );
}
