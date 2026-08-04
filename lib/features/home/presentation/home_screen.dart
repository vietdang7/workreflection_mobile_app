import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/checkin.dart';
import '../../../core/models/insight.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../../features/profile/profile_providers.dart';
import '../../../features/survey/survey_providers.dart';
import '../home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(mobileProfileProvider);
    final displayName = profileAsync.valueOrNull?.displayName ?? 'bạn';
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _HomeHeader(displayName: displayName)),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SurveyCta(),
                  const SizedBox(height: 20),
                  _CheckinSection(),
                  const SizedBox(height: 28),
                  _SystemNoticeCard(),
                  const SizedBox(height: 28),
                  _SuggestionSection(),
                  const SizedBox(height: 28),
                  _InsightSection(),
                  const SizedBox(height: 80), // tab bar clearance
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header (greeting + date)
// ---------------------------------------------------------------------------

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.displayName});

  final String displayName;

  String _buildDateTitle() {
    final now = DateTime.now();
    // Format: "Thứ Ba, 24/06"
    // DateFormat 'EEEE' in 'vi' locale gives "Thứ Ba", etc.
    final dayName = DateFormat('EEEE', 'vi').format(now);
    final dayMonth = DateFormat('dd/MM').format(now);
    final raw = '$dayName, $dayMonth';
    // Capitalize first letter
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeGreeting(displayName),
            style: WrTextStyles.greeting,
          ),
          const SizedBox(height: 4),
          Text(
            key: const Key('home_date_title'),
            _buildDateTitle(),
            style: WrTextStyles.dateTitle,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Check-in grid
// ---------------------------------------------------------------------------

class _CheckinSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final checkinAsync = ref.watch(checkinProvider);
    final selectedMood = checkinAsync.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.homeCheckinQuestion, style: WrTextStyles.hLarge),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _MoodButton(
              mood: Mood.stressed,
              label: l10n.homeMoodStressed,
              isSelected: selectedMood == Mood.stressed,
            ),
            _MoodButton(
              mood: Mood.tired,
              label: l10n.homeMoodTired,
              isSelected: selectedMood == Mood.tired,
            ),
            _MoodButton(
              mood: Mood.okay,
              label: l10n.homeMoodOkay,
              isSelected: selectedMood == Mood.okay,
            ),
            _MoodButton(
              mood: Mood.happy,
              label: l10n.homeMoodHappy,
              isSelected: selectedMood == Mood.happy,
            ),
          ],
        ),
      ],
    );
  }
}

class _MoodButton extends ConsumerWidget {
  const _MoodButton({
    required this.mood,
    required this.label,
    required this.isSelected,
  });

  final Mood mood;
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = Key('mood_btn_${mood.name}${isSelected ? '_selected' : ''}');
    return GestureDetector(
      key: key,
      onTap: () => ref.read(checkinProvider.notifier).selectMood(mood),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? WrColors.coral : WrColors.cream,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? WrColors.white : WrColors.dark,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// System notice card (WrCardDark) — from top recurring situation
// ---------------------------------------------------------------------------

class _SystemNoticeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final situationsAsync = ref.watch(recurringSituationsProvider);

    return situationsAsync.when(
      loading: () => const _LoadingCard(),
      error: (e, _) => _ErrorCard(onRetry: () => ref.invalidate(recurringSituationsProvider)),
      data: (situations) {
        if (situations.isEmpty) return const SizedBox.shrink();
        final top = situations.first;
        return WrCardDark(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WrEyebrow(l10n.homeEyebrowSystem),
              const SizedBox(height: 12),
              Text(
                l10n.homeSystemNoticeQuote(top.occurrenceCount, top.label),
                style: WrTextStyles.insightQuote.copyWith(
                  fontSize: 16,
                  color: WrColors.white,
                ),
              ),
              const SizedBox(height: 16),
              WrActionLink(
                key: const Key('home_system_notice_learn_more'),
                label: l10n.homeLinkLearnMore,
                onTap: () => context.go('/understand'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Survey CTA — state-aware, positioned FIRST below the greeting header.
//   • No report  → full-width coral button "Bắt đầu phản chiếu" (unmissable).
//   • Has report → navy "Xem báo cáo mới nhất" + text link "Làm lại bài phản chiếu".
//   • Loading / error → SizedBox.shrink (silent).
// ---------------------------------------------------------------------------

class _SurveyCta extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportsAsync = ref.watch(myReportsProvider);
    final latestAsync = ref.watch(latestReportProvider);

    return reportsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (reports) {
        if (reports.isEmpty) {
          // ── No report: prominent coral CTA ──────────────────────────────
          return SizedBox(
            key: const Key('home_survey_cta_no_report'),
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('home_survey_cta_start_btn'),
              onPressed: () => context.push('/survey'),
              icon: const Icon(Icons.edit_note_rounded, size: 22),
              label: Text(l10n.homeStartReflection),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
                shadowColor: WrColors.coral.withValues(alpha: 0.35),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        }

        // ── Has report: navy view-report + retake text link ──────────────
        return latestAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (latest) {
            if (latest == null) return const SizedBox.shrink();
            return Column(
              key: const Key('home_survey_cta_has_report'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WrPillButton(
                  key: const Key('home_survey_cta_view_report_btn'),
                  label: l10n.homeCtaReportTitle,
                  onPressed: () =>
                      context.push('/survey/report/${latest.id}'),
                  variant: WrPillVariant.navy,
                ),
                const SizedBox(height: 10),
                Center(
                  child: WrActionLink(
                    key: const Key('home_survey_cta_retake_link'),
                    label: l10n.homeCtaRetakeSurvey,
                    onTap: () => context.push('/survey'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Suggestion card (static content)
// ---------------------------------------------------------------------------

class _SuggestionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.homeEyebrowSuggestion),
        const SizedBox(height: 12),
        WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: WrColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      color: WrColors.navy,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.homeSuggestionTitle,
                          style: WrTextStyles.hMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.homeSuggestionMeta,
                          style: WrTextStyles.body.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              WrProgressTrack(value: 0.35, color: WrColors.navy),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.homeSuggestionProgress,
                    style: WrTextStyles.body.copyWith(fontSize: 12),
                  ),
                  Text(
                    l10n.homeSuggestionStatus,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WrColors.coral,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Insight section
// ---------------------------------------------------------------------------

class _InsightSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final insightAsync = ref.watch(latestInsightProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.homeEyebrowInsight),
        const SizedBox(height: 12),
        insightAsync.when(
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(
            onRetry: () => ref.invalidate(latestInsightProvider),
          ),
          data: (insight) {
            if (insight == null) {
              return const _InsightEmpty();
            }
            return _InsightContent(insight: insight);
          },
        ),
      ],
    );
  }
}

class _InsightEmpty extends StatelessWidget {
  const _InsightEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('home_insight_empty'),
      child: Text(
        l10n.homeInsightEmpty,
        style: WrTextStyles.body,
      ),
    );
  }
}

class _InsightContent extends StatelessWidget {
  const _InsightContent({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateStr = DateFormat('dd/MM').format(insight.savedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '"${insight.content}"',
          style: WrTextStyles.insightQuote,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.homeInsightSavedDate(dateStr),
          style: WrTextStyles.body.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared loading / error helpers
// ---------------------------------------------------------------------------

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(l10n.homeErrorLoadData, style: WrTextStyles.body),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onRetry,
          child: Text(l10n.homeRetry),
        ),
      ],
    );
  }
}
