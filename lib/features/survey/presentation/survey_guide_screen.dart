import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/survey_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../survey_providers.dart';

class SurveyGuideScreen extends ConsumerWidget {
  const SurveyGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeAsync = ref.watch(surveyTypeProvider);

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: typeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (type) => _GuideBody(type: type),
      ),
    );
  }
}

class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.type});

  final SurveyType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = type == SurveyType.premium;

    final title =
        isPremium ? l10n.surveyGuidePremiumTitle : l10n.surveyGuideFreeTitle;
    final intro =
        isPremium ? l10n.surveyGuidePremiumIntro : l10n.surveyGuideFreeIntro;
    final details = isPremium
        ? l10n.surveyGuidePremiumDetails
        : l10n.surveyGuideFreeDetails;
    final benefits = isPremium
        ? [
            l10n.surveyGuidePremiumBenefit1,
            l10n.surveyGuidePremiumBenefit2,
            l10n.surveyGuidePremiumBenefit3,
            l10n.surveyGuidePremiumBenefit4,
          ]
        : [
            l10n.surveyGuideFreeBenefit1,
            l10n.surveyGuideFreeBenefit2,
            l10n.surveyGuideFreeBenefit3,
          ];
    final closing = isPremium
        ? l10n.surveyGuidePremiumClosing
        : l10n.surveyGuideFreeClosing;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          WrEyebrow(l10n.surveyGuideEyebrow),
          const SizedBox(height: 12),
          Text(title, style: WrTextStyles.hLarge),
          const SizedBox(height: 16),
          Text(intro, style: WrTextStyles.body),
          if (!isPremium) ...[
            const SizedBox(height: 8),
            Text(l10n.surveyGuideFreeDescription, style: WrTextStyles.body),
          ],
          const SizedBox(height: 8),
          Text(details, style: WrTextStyles.body),
          const SizedBox(height: 16),
          ...benefits.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    key: Key('guide_benefit_${e.key}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 18, color: WrColors.teal),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(e.value, style: WrTextStyles.body)),
                    ],
                  ),
                ),
              ),
          if (isPremium) ...[
            const SizedBox(height: 8),
            Text(l10n.surveyGuidePremiumReportDesc, style: WrTextStyles.body),
            const SizedBox(height: 10),
            ...[
              l10n.surveyGuidePremiumReport1,
              l10n.surveyGuidePremiumReport2,
              l10n.surveyGuidePremiumReport3,
            ].asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 18, color: WrColors.coral),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(e.value, style: WrTextStyles.body)),
                      ],
                    ),
                  ),
                ),
          ],
          if (!isPremium) ...[
            const SizedBox(height: 8),
            Text(
              l10n.surveyGuideFreeNote,
              style: WrTextStyles.body.copyWith(
                fontStyle: FontStyle.italic,
                color: WrColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(closing, style: WrTextStyles.body),
          const SizedBox(height: 32),
          WrPillButton(
            label: l10n.surveyGuideCta,
            onPressed: () => context.push('/survey/questions'),
            variant: WrPillVariant.coral,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
