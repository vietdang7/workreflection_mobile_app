import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../survey_providers.dart';

// Provider that runs the submission once and returns the report id.
final _submitProvider = FutureProvider.autoDispose<String>((ref) async {
  final type = await ref.watch(surveyTypeProvider.future);
  final answers = ref.watch(surveyAnswersProvider);
  final questions = await ref.watch(surveyQuestionsProvider(type).future);
  final repo = ref.watch(surveyRepositoryProvider);

  final report = await repo.submitSurvey(
    type: type,
    answers: answers,
    questions: questions,
  );
  return report.id;
});

class SurveyProcessingScreen extends ConsumerWidget {
  const SurveyProcessingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final submitAsync = ref.watch(_submitProvider);

    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: submitAsync.when(
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: WrColors.coral),
                const SizedBox(height: 24),
                Text(l10n.surveyProcessingTitle,
                    style: WrTextStyles.hMedium,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.surveyProcessingError,
                    style: WrTextStyles.body, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                WrPillButton(
                  label: l10n.surveyProcessingRetry,
                  onPressed: () => ref.invalidate(_submitProvider),
                  variant: WrPillVariant.coral,
                ),
              ],
            ),
          ),
          data: (reportId) {
            // Navigate on next frame to avoid calling during build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.pushReplacement('/survey/report/$reportId');
              }
            });
            return const Center(
              child: CircularProgressIndicator(color: WrColors.teal),
            );
          },
        ),
      ),
    );
  }
}
