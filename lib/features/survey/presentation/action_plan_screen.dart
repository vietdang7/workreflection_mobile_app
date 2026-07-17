import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/survey_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../l10n/app_localizations.dart';
import '../survey_providers.dart';

class ActionPlanScreen extends ConsumerWidget {
  const ActionPlanScreen({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(l10n.actionPlanTitle, style: WrTextStyles.hMedium),
      ),
      body: typeAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (type) => _ActionPlanBody(
          reportId: reportId,
          surveyType: type,
        ),
      ),
    );
  }
}

class _ActionPlanBody extends ConsumerWidget {
  const _ActionPlanBody({
    required this.reportId,
    required this.surveyType,
  });
  final String reportId;
  final SurveyType surveyType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final planAsync = ref.watch(actionPlanProvider(surveyType));
    final progressAsync = ref.watch(actionProgressProvider);

    return planAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (phases) => progressAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: CircularProgressIndicator()),
        data: (progress) {
          // Init the optimistic notifier with fetched progress
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(actionProgressNotifierProvider(reportId).notifier)
                .init(progress);
          });
          return _PlanList(
            phases: phases,
            reportId: reportId,
            l10n: l10n,
          );
        },
      ),
    );
  }
}

class _PlanList extends ConsumerWidget {
  const _PlanList({
    required this.phases,
    required this.reportId,
    required this.l10n,
  });
  final List<ActionPlanPhase> phases;
  final String reportId;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(actionProgressNotifierProvider(reportId));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
      itemCount: phases.length,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (context, i) {
        final phase = phases[i];
        return _PhaseCard(
          phase: phase,
          progress: progress,
          reportId: reportId,
          l10n: l10n,
          ref: ref,
        );
      },
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.phase,
    required this.progress,
    required this.reportId,
    required this.l10n,
    required this.ref,
  });

  final ActionPlanPhase phase;
  final Map<String, bool> progress;
  final String reportId;
  final AppLocalizations l10n;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.actionPlanDay(phase.day)),
        const SizedBox(height: 8),
        Text(phase.titleVi, style: WrTextStyles.hMedium),
        if (phase.reflectionQuestion != null) ...[
          const SizedBox(height: 8),
          Text(
            '${l10n.actionPlanReflection}: ${phase.reflectionQuestion}',
            style: WrTextStyles.body,
          ),
        ],
        const SizedBox(height: 12),
        ...phase.tasks.map((task) {
          final completed = progress[task.id] ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                ref
                    .read(actionProgressNotifierProvider(reportId).notifier)
                    .toggle(task.id, !completed);
              },
              child: Row(
                children: [
                  Icon(
                    completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: completed ? WrColors.teal : WrColors.muted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.label,
                      style: WrTextStyles.body.copyWith(
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: completed
                            ? WrColors.muted
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
