// Post-workshop survey screen — Phase 3 Task 13.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/workshop_repository.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../features/profile/profile_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../workshops_providers.dart';

class WorkshopSurveyScreen extends ConsumerStatefulWidget {
  const WorkshopSurveyScreen({super.key, required this.workshopId});

  final String workshopId;

  @override
  ConsumerState<WorkshopSurveyScreen> createState() =>
      _WorkshopSurveyScreenState();
}

class _WorkshopSurveyScreenState extends ConsumerState<WorkshopSurveyScreen> {
  final Map<String, int> _answers = {};
  bool _submitting = false;
  bool _submitted = false;

  Future<void> _submit(WorkshopSurveySet surveySet) async {
    if (_submitting || _submitted) return;
    setState(() => _submitting = true);

    final l10n = AppLocalizations.of(context)!;

    try {
      final repo = ref.read(workshopRepositoryProvider);
      await repo.submitWorkshopSurvey(
        workshopId: widget.workshopId,
        questionSetId: surveySet.questionSetId,
        answers: Map.of(_answers),
      );
      ref.invalidate(hasSubmittedSurveyProvider(widget.workshopId));
      setState(() {
        _submitted = true;
        _submitting = false;
      });
    } catch (_) {
      setState(() => _submitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.wsSurveyError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(appLocaleProvider);
    final surveyAsync = ref.watch(workshopSurveySetProvider(widget.workshopId));

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        title: Text(l10n.wsSurveyTitle, style: WrTextStyles.hMedium),
      ),
      body: surveyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (surveySet) {
          // No survey or no questions.
          if (surveySet == null || surveySet.questions.isEmpty) {
            return Center(
              child: Text(
                l10n.wsSurveyNone,
                key: const Key('ws_survey_none'),
                textAlign: TextAlign.center,
              ),
            );
          }

          // Success state.
          if (_submitted) {
            return Center(
              child: Text(
                l10n.wsSurveyThanks,
                key: const Key('ws_survey_thanks'),
                style: WrTextStyles.hMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          final allAnswered =
              surveySet.questions.every((q) => _answers.containsKey(q.id));

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: surveySet.questions.length,
                  itemBuilder: (context, index) {
                    final question = surveySet.questions[index];
                    final questionText =
                        (locale == 'en' && question.questionTextEn != null)
                            ? question.questionTextEn!
                            : question.questionText;
                    final selected = _answers[question.id];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            questionText,
                            style: WrTextStyles.hMedium
                                .copyWith(color: WrColors.dark),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: List.generate(5, (i) {
                              final value = i + 1;
                              final isSelected = selected == value;
                              return ChoiceChip(
                                key: Key('chip_${question.id}_$value'),
                                label: Text('$value'),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _answers[question.id] = value;
                                  });
                                },
                                selectedColor: WrColors.coral,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? WrColors.white
                                      : WrColors.dark,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: WrPillButton(
                  key: const Key('ws_survey_submit'),
                  label: l10n.wsSurveySubmit,
                  onPressed: allAnswered && !_submitting
                      ? () => _submit(surveySet)
                      : null,
                  variant: WrPillVariant.coral,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
