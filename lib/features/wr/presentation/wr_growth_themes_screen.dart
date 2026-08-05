// Chủ đề thực hành — màn phụ, mở khi cần xem chủ đề ngoài cái được đề xuất.
//
// Chủ đề KHÔNG phải một thực đơn để người dùng tự chọn: phần mềm chuẩn bị nó từ
// những tình huống họ gặp lại nhiều lần và từ bộ tự đánh giá (khách 2026-08-04).
// Vì vậy màn này dẫn bằng ĐÚNG MỘT chủ đề kèm lý do; cả thư viện nằm sau một
// dòng "Xem tất cả chủ đề" cho ai muốn tự đi đường khác.
//
// Trước 04/8 màn này đổ thẳng 7 đến 10 chủ đề với 7 đến 10 nút "Bắt đầu" giống
// hệt nhau, không một dòng nào nói vì sao lại là những chủ đề đó.
//
// Bản miễn phí mở tối đa 2 chủ đề cùng lúc (yêu cầu khách 2026-07-27) —
// vượt quota thì dòng chủ đề dẫn sang paywall thay vì nút bắt đầu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_practice_match.dart';
import '../../../core/logic/wr_tra_chieu.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';

class WrGrowthThemesScreen extends ConsumerStatefulWidget {
  const WrGrowthThemesScreen({super.key});

  @override
  ConsumerState<WrGrowthThemesScreen> createState() =>
      _WrGrowthThemesScreenState();
}

class _WrGrowthThemesScreenState extends ConsumerState<WrGrowthThemesScreen> {
  final Set<String> _enrolling = {};

  /// Đã bấm "Xem tất cả chủ đề" chưa. Trạng thái của một lần xem màn.
  bool _showAll = false;

  Future<void> _enroll(String themeId) async {
    if (_enrolling.contains(themeId)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _enrolling.add(themeId));
    try {
      await ref.read(wrIntelligenceRepositoryProvider).enrollTheme(
            PracticeEnrollment(
              userId: userId,
              themeId: themeId,
              completedSteps: const [],
            ),
          );
      ref.invalidate(practiceEnrollmentsProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không bắt đầu được. Thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _enrolling.remove(themeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final enrollments =
        ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);

    // Chủ đề đã ngưng đề xuất không nằm trong danh sách mời — người đã ghi danh
    // vẫn thấy nó ở "CHỦ ĐỀ CỦA BẠN" bên màn Phát triển và đi tiếp bình thường.
    //
    // Lọc cả theo TÊN chứ không chỉ theo id: thư viện có hai hàng cùng tên
    // "Dám lên tiếng" (`pt-voice` đời đầu và `pt-c2`), và bộ đếm thực hành nhận
    // sự kiện theo tên. Mời một chủ đề trùng tên chủ đề đang theo là mời vào
    // đúng cái đang làm, với một bộ đếm dùng chung.
    final enrolledIds = enrollments.map((e) => e.themeId).toSet();
    final enrolledTitles = {
      for (final t in themes)
        if (enrolledIds.contains(t.themeId)) t.title,
    };
    final available = themes
        .where((t) =>
            !enrolledIds.contains(t.themeId) &&
            !enrolledTitles.contains(t.title) &&
            !t.isRetired)
        .toList();
    final activeCount = enrollments.where((e) => e.completedAt == null).length;
    final canEnroll = entitlement.canEnrollPracticeTheme(activeCount);
    final quota = entitlement.maxActivePracticeThemes;

    // Chủ đề được đề xuất — cùng nguồn với tab Phát triển.
    final suggestion = ref.watch(wrPracticeSuggestionProvider);
    final suggestedId = suggestion?.theme.themeId;
    final rest = available.where((t) => t.themeId != suggestedId).toList();

    return WrDetailScaffold(
      eyebrow: 'THỰC HÀNH KHÁC',
      title: suggestion != null
          ? 'Chủ đề dành cho bạn'
          : 'Chủ đề bạn có thể bắt đầu',
      children: [
        if (quota != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              canEnroll
                  ? 'Bạn đang mở $activeCount/$quota chủ đề.'
                  : 'Bản miễn phí mở tối đa $quota chủ đề cùng lúc. '
                      'Hoàn thành một chủ đề để mở chỗ mới.',
              key: const Key('wr_growth_themes_quota'),
              style: const TextStyle(
                fontSize: 15.5,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          ),

        // Chủ đề được đề xuất, kèm lý do. Đứng riêng một thẻ để không bị đọc
        // lẫn thành "một dòng nữa trong danh sách".
        if (suggestion != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 26),
            child: _SuggestionCard(
              suggestion: suggestion,
              situations: situations,
              need: ref.watch(wrDominantNeedProvider),
              canEnroll: canEnroll,
              isEnrolling: _enrolling.contains(suggestion.theme.themeId),
              onEnroll: () => _enroll(suggestion.theme.themeId),
              onPaywall: () => context.push('/wr/paywall'),
            ),
          )
        else if (available.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 26),
            child: Text(
              'Bạn đã bắt đầu tất cả chủ đề hiện có.',
              style: TextStyle(
                fontSize: 15.5,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 26),
            child: Text(
              'Chủ đề thực hành được chọn từ những tình huống bạn gặp lại nhiều '
              'lần. Bạn nhìn lại thêm vài lần nữa, hoặc làm bộ tự đánh giá, rồi '
              'WorkReflection sẽ chỉ ra chủ đề hợp với bạn. Trong lúc chờ, bạn '
              'vẫn tự chọn được ở danh sách bên dưới.',
              style: TextStyle(
                fontSize: 15.5,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          ),

        // Cả thư viện, xếp sau một dòng xổ. Ai muốn tự đi đường khác vẫn đi
        // được, nhưng đó không còn là điều màn hình mời làm đầu tiên.
        if (rest.isNotEmpty) ...[
          WrActionLink(
            key: const Key('wr_growth_themes_show_all'),
            label: _showAll ? 'Thu gọn' : 'Xem tất cả chủ đề (${rest.length})',
            onTap: () => setState(() => _showAll = !_showAll),
          ),
          const SizedBox(height: 20),
        ],

        // Trà Chiều nằm CHUNG danh sách chủ đề, chèn ngay sau "Tư duy hệ thống"
        // (họp khách 2026-07-29). Nó không phải chủ đề để ghi danh — không có
        // chuỗi bước, không tính vào quota — nên dòng của nó dẫn sang màn Trà
        // Chiều thay vì có nút "Bắt đầu". Danh sách còn thu gọn thì Trà Chiều
        // vẫn hiện: nó là chương trình offline có thật, không phải một chủ đề
        // nữa để chọn, nên không bị giấu cùng thư viện.
        ...(){
          final rows = <Widget>[
            if (_showAll)
              for (final t in rest)
                _ThemeRow(
                  key: Key('wr_growth_theme_${t.themeId}'),
                  theme: t,
                  canEnroll: canEnroll,
                  isEnrolling: _enrolling.contains(t.themeId),
                  onEnroll: () => _enroll(t.themeId),
                  onPaywall: () => context.push('/wr/paywall'),
                ),
          ];
          if (rows.isEmpty) return const <Widget>[_TraChieuRow()];
          final at = traChieuInsertIndex([for (final t in rest) t.title]);
          return [...rows]..insert(at, const _TraChieuRow());
        }(),
      ],
    );
  }
}

/// Thẻ chủ đề được đề xuất, kèm câu nói vì sao lại là chủ đề này.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.situations,
    required this.need,
    required this.canEnroll,
    required this.isEnrolling,
    required this.onEnroll,
    required this.onPaywall,
  });

  final PracticeSuggestion suggestion;
  final List<WrSituation> situations;
  final HumanNeed? need;
  final bool canEnroll;
  final bool isEnrolling;
  final VoidCallback onEnroll;
  final VoidCallback onPaywall;

  @override
  Widget build(BuildContext context) {
    final theme = suggestion.theme;
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrEyebrow('CHỦ ĐỀ ĐƯỢC ĐỀ XUẤT'),
          const SizedBox(height: 10),
          Text(
            theme.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.3,
            ),
          ),
          if (theme.description != null) ...[
            const SizedBox(height: 6),
            Text(
              theme.description!,
              style: const TextStyle(
                fontSize: 14.5,
                color: WrColors.muted,
                height: 1.5,
              ),
            ),
          ],
          if (practiceSuggestionReason(suggestion, situations, need)
              case final reason?) ...[
            const SizedBox(height: 6),
            Text(
              reason,
              key: const Key('wr_growth_themes_reason'),
              style: const TextStyle(
                fontSize: 13.5,
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
              key: Key('wr_growth_theme_${theme.themeId}'),
              onPressed: isEnrolling ? null : (canEnroll ? onEnroll : onPaywall),
              style: TextButton.styleFrom(
                backgroundColor: WrColors.navy,
                foregroundColor: WrColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isEnrolling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: WrColors.white,
                        strokeWidth: 1.5,
                      ),
                    )
                  : Text(
                      canEnroll ? 'Bắt đầu' : 'Mở với Premium',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng Trà Chiều trong danh sách chủ đề — dẫn sang màn riêng, không ghi danh.
class _TraChieuRow extends StatelessWidget {
  const _TraChieuRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: GestureDetector(
        key: const Key('wr_growth_theme_tra_chieu'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/wr/tra-chieu'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    kTraChieuLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                      height: 1.35,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: WrColors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.pillTealText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '10 đến 12 người ngồi quanh một bàn trà, cùng trả lời một câu hỏi '
              'duy nhất. Phản chiếu như trong app, chỉ khác là nói thành lời.',
              style: TextStyle(
                fontSize: 15.5,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Xem lịch các buổi',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.coral,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: WrColors.coral),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    super.key,
    required this.theme,
    required this.canEnroll,
    required this.isEnrolling,
    required this.onEnroll,
    required this.onPaywall,
  });

  final PracticeTheme theme;
  final bool canEnroll;
  final bool isEnrolling;
  final VoidCallback onEnroll;
  final VoidCallback onPaywall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            theme.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.35,
            ),
          ),
          if (theme.description != null) ...[
            const SizedBox(height: 6),
            Text(
              theme.description!,
              style: const TextStyle(
                fontSize: 15.5,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (canEnroll)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isEnrolling ? null : onEnroll,
                style: TextButton.styleFrom(
                  backgroundColor: WrColors.navy,
                  foregroundColor: WrColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isEnrolling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: WrColors.white,
                          strokeWidth: 1.5,
                        ),
                      )
                    : const Text(
                        'Bắt đầu',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            )
          else
            GestureDetector(
              onTap: onPaywall,
              child: const Text(
                '⭐ Premium',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD4A017),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
