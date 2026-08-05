// Roadmap Tracker screen — Phase 5 Task 5.
//
// Route: /roadmap (fullscreen, outside shell).
// Entry points:
//   1. ProfileScreen settings row "Lộ trình hành động"
//   2. ReportScreen CTA "Lộ trình phát triển" (premium reports only)
//
// Web parity: mirrors RoadmapTracker.tsx structure:
//   - Report picker dropdown (PREMIUM reports only)
//   - Optional nickname rename dialog
//   - Overall progress bar
//   - Per-layer sections (STRUCTURE / CULTURE / ACTIVITY)
//     each with 3 day columns (7 / 14 / 30)
//     → narrative actions from cc_roadmap_actions (lowest sub-component per layer)
//     → custom tasks CRUD (add / edit / delete)
//   - Coach access section (invite from cc_coaches)
//   - Activity log (completed items)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/profile_providers.dart';
import '../roadmap_providers.dart';

// ---------------------------------------------------------------------------
// Constants — mirror LAYERS / DAYS from web
// ---------------------------------------------------------------------------

const _layers = ['STRUCTURE', 'CULTURE', 'ACTIVITY'];
const _days = [7, 14, 30];

// ---------------------------------------------------------------------------
// Sub-component score helpers (mirror web getMaxActionLevel / getSubComponentLabel)
// ---------------------------------------------------------------------------

/// Identify the lowest-scoring sub-component per layer from report.subScores.
Map<String, _LayerFocus> _buildLayerFocusMap(
    Map<String, dynamic>? subScores, AppLocalizations l10n) {
  if (subScores == null || subScores.isEmpty) return {};
  final result = <String, _LayerFocus>{};
  for (final layer in _layers) {
    final entries = <MapEntry<String, double>>[];
    for (final entry in subScores.entries) {
      final val = entry.value;
      if (val is! Map) continue;
      final valLayer = (val['layer'] as String?)?.toUpperCase();
      final score = (val['score'] as num?)?.toDouble();
      if (valLayer == layer && score != null) {
        entries.add(MapEntry(entry.key, score));
      }
    }
    if (entries.isEmpty) continue;
    entries.sort((a, b) {
      final cmp = a.value.compareTo(b.value);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });
    final lowest = entries.first;
    result[layer] = _LayerFocus(
      subComponent: lowest.key,
      score: lowest.value,
      label: _subCompLabel(lowest.key, l10n),
    );
  }
  return result;
}

String _subCompLabel(String sc, AppLocalizations l10n) {
  return switch (sc) {
    'role_expectations' => l10n.subCompRoleExpect,
    'collab_rules' => l10n.subCompCollabRules,
    'comm_channels' => l10n.subCompCommChannels,
    'trust' => l10n.subCompTrust,
    'psych_safety' => l10n.subCompPsychSafety,
    'feedback_dialogue' => l10n.subCompFeedbackDialogue,
    'goal_alignment' => l10n.subCompGoalAlignment,
    'execution_rhythm' => l10n.subCompExecutionRhythm,
    'retrospective' => l10n.subCompRetrospective,
    'continuous_improve' => l10n.subCompContinuousImprove,
    _ => sc,
  };
}

String _scoreLabel(double score, AppLocalizations l10n) {
  if (score >= 4.2) return l10n.roadmapScoreHigh;
  if (score >= 3.5) return l10n.roadmapScoreGood;
  if (score >= 2.8) return l10n.roadmapScoreWarning;
  return l10n.roadmapScoreCritical;
}

Color _scoreColor(double score) {
  if (score >= 4.2) return WrColors.teal;
  if (score >= 3.5) return WrColors.navy;
  if (score >= 2.8) return WrColors.coral;
  return WrColors.destructive;
}

class _LayerFocus {
  const _LayerFocus({
    required this.subComponent,
    required this.score,
    required this.label,
  });
  final String subComponent;
  final double score;
  final String label;
}

// ---------------------------------------------------------------------------
// Layer colours (mirror web LAYER_CONFIG)
// ---------------------------------------------------------------------------

Color _layerColor(String layer) => switch (layer) {
      'STRUCTURE' => const Color(0xFF5b6d8f),
      'CULTURE' => WrColors.coral,
      'ACTIVITY' => WrColors.teal,
      _ => WrColors.muted,
    };

String _layerLabel(String layer, AppLocalizations l10n) => switch (layer) {
      'STRUCTURE' => l10n.roadmapLayerStructure,
      'CULTURE' => l10n.roadmapLayerCulture,
      'ACTIVITY' => l10n.roadmapLayerActivity,
      _ => layer,
    };

String _dayHeader(int day, AppLocalizations l10n) => switch (day) {
      7 => l10n.roadmapDayHeader7,
      14 => l10n.roadmapDayHeader14,
      _ => l10n.roadmapDayHeader30,
    };

// ---------------------------------------------------------------------------
// Report display label (mirror web reportDisplayLabel)
// ---------------------------------------------------------------------------

String _reportLabel(PremiumReport r) {
  if (r.nickname != null && r.nickname!.isNotEmpty) return r.nickname!;
  final d = r.createdAt;
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '${d.scoreTotal(r)} · $day/$month/${d.year}';
}

extension _ReportLabelExt on DateTime {
  String scoreTotal(PremiumReport r) =>
      r.scoreTotal.toStringAsFixed(1);
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key, this.initialReportId});
  final String? initialReportId;

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  String? _selectedReportId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reportsAsync = ref.watch(premiumReportsProvider);
    final localeCode = ref.watch(appLocaleProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.roadmapTitle, style: WrTextStyles.hMedium),
      ),
      body: reportsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: WrColors.coral, size: 32),
                const SizedBox(height: 12),
                Text(e.toString(), style: WrTextStyles.body,
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.invalidate(premiumReportsProvider),
                  child: Text(l10n.homeRetry),
                ),
              ],
            ),
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return _EmptyState(l10n: l10n);
          }

          // Auto-select: prefer initialReportId → first report
          if (_selectedReportId == null ||
              !reports.any((r) => r.id == _selectedReportId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedReportId = widget.initialReportId != null &&
                          reports.any((r) => r.id == widget.initialReportId)
                      ? widget.initialReportId
                      : reports.first.id;
                });
              }
            });
          }

          final selectedReport = _selectedReportId != null
              ? reports.firstWhere(
                  (r) => r.id == _selectedReportId,
                  orElse: () => reports.first,
                )
              : reports.first;

          return _RoadmapBody(
            reports: reports,
            selectedReport: selectedReport,
            localeCode: localeCode,
            onReportSelected: (id) => setState(() => _selectedReportId = id),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('roadmap_empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: WrColors.navy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.map_outlined,
                  color: WrColors.navy, size: 32),
            ),
            const SizedBox(height: 20),
            Text(l10n.roadmapNoPremiumReports,
                style: WrTextStyles.hMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l10n.roadmapNoPremiumReportsBody,
                style: WrTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  context.push('/survey/guide'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(l10n.roadmapStartSurvey),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body (report selected)
// ---------------------------------------------------------------------------

class _RoadmapBody extends ConsumerWidget {
  const _RoadmapBody({
    required this.reports,
    required this.selectedReport,
    required this.localeCode,
    required this.onReportSelected,
  });

  final List<PremiumReport> reports;
  final PremiumReport selectedReport;
  final String localeCode;
  final void Function(String id) onReportSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final progressAsync =
        ref.watch(roadmapProgressProvider(selectedReport.id));
    final actionsAsync = ref.watch(roadmapActionsProvider);

    return progressAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Text(e.toString(), style: WrTextStyles.body),
      ),
      data: (progressData) => actionsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text(e.toString(), style: WrTextStyles.body),
        ),
        data: (actions) {
          // Init optimistic notifiers once data is available
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(roadmapActionToggleNotifierProvider(selectedReport.id)
                    .notifier)
                .init(progressData.completedActionIds);
            ref
                .read(customTaskToggleNotifierProvider(selectedReport.id)
                    .notifier)
                .init(progressData.customTasks);
          });

          final layerFocus =
              _buildLayerFocusMap(selectedReport.subScores, l10n);

          // Build action grid: layer → day → [actions]
          final actionGrid = _buildActionGrid(actions, layerFocus, localeCode);

          // Custom tasks grouped by layer-day
          final customTasksByCell = <String, List<CustomTask>>{};
          for (final task in progressData.customTasks) {
            final key = '${task.layer}-${task.day}';
            customTasksByCell.putIfAbsent(key, () => []).add(task);
          }

          // Compute overall progress
          final actionToggleState = ref
              .watch(roadmapActionToggleNotifierProvider(selectedReport.id));
          final customToggleState = ref
              .watch(customTaskToggleNotifierProvider(selectedReport.id));

          int totalActions = 0;
          int completedActions = 0;
          for (final acts in actionGrid.values) {
            for (final a in acts) {
              totalActions++;
              if (actionToggleState[a.id] ?? false) completedActions++;
            }
          }
          final totalCustom = progressData.customTasks.length;
          final completedCustom = progressData.customTasks
              .where((t) => customToggleState[t.id] ?? t.isCompleted)
              .length;
          final total = totalActions + totalCustom;
          final completed = completedActions + completedCustom;
          final percent = total > 0 ? completed / total : 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
            children: [
              const SizedBox(height: 16),

              // -- Report picker + rename
              _ReportPickerRow(
                reports: reports,
                selectedReport: selectedReport,
                onSelected: onReportSelected,
                l10n: l10n,
              ),
              const SizedBox(height: 20),

              // -- Progress bar
              _ProgressBar(
                completed: completed,
                total: total,
                percent: percent,
                l10n: l10n,
              ),
              const SizedBox(height: 28),

              // -- Per-layer sections
              for (final layer in _layers) ...[
                _LayerSection(
                  layer: layer,
                  focus: layerFocus[layer],
                  actionGrid: actionGrid,
                  customTasksByCell: customTasksByCell,
                  selectedReport: selectedReport,
                  actionToggleState: actionToggleState,
                  customToggleState: customToggleState,
                  l10n: l10n,
                ),
                const SizedBox(height: 24),
              ],

              // -- Coach section
              _CoachSection(l10n: l10n),
              const SizedBox(height: 24),

              // -- Activity log
              _ActivityLog(
                progressData: progressData,
                actionGrid: actionGrid,
                actionToggleState: actionToggleState,
                customToggleState: customToggleState,
                l10n: l10n,
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<RoadmapAction>> _buildActionGrid(
    List<RoadmapAction> actions,
    Map<String, _LayerFocus> layerFocus,
    String locale,
  ) {
    final grid = <String, List<RoadmapAction>>{};
    for (final layer in _layers) {
      for (final day in _days) {
        grid['$layer-$day'] = [];
      }
    }

    for (final layer in _layers) {
      final focus = layerFocus[layer];
      if (focus == null) continue;

      // Filter to this layer's lowest sub-component (with fallbacks as on web)
      var layerActions = actions
          .where((a) => a.layer == layer && a.subComponent == focus.subComponent)
          .toList();

      // Fallback: any action in this layer
      if (layerActions.isEmpty) {
        layerActions = actions.where((a) => a.layer == layer).toList();
      }

      for (final action in layerActions) {
        final key = '$layer-${action.day}';
        grid.putIfAbsent(key, () => []).add(action);
      }
    }

    return grid;
  }
}

// ---------------------------------------------------------------------------
// Report picker row
// ---------------------------------------------------------------------------

class _ReportPickerRow extends ConsumerWidget {
  const _ReportPickerRow({
    required this.reports,
    required this.selectedReport,
    required this.onSelected,
    required this.l10n,
  });

  final List<PremiumReport> reports;
  final PremiumReport selectedReport;
  final void Function(String id) onSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            key: const Key('roadmap_report_picker'),
            onTap: () => _showPicker(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                    color: WrColors.navy.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _reportLabel(selectedReport),
                      style: WrTextStyles.hMedium.copyWith(fontSize: 15.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.unfold_more,
                      color: WrColors.muted, size: 18),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Rename button
        IconButton(
          key: const Key('roadmap_rename_btn'),
          icon: const Icon(Icons.edit_outlined,
              color: WrColors.muted, size: 20),
          onPressed: () =>
              _showRenameDialog(context, ref, selectedReport, l10n),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WrColors.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ...reports.map((r) {
                final isSelected = r.id == selectedReport.id;
                return ListTile(
                  title: Text(
                    _reportLabel(r),
                    style: WrTextStyles.hMedium.copyWith(
                      fontSize: 15.5,
                      color:
                          isSelected ? WrColors.coral : null,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: WrColors.coral)
                      : null,
                  onTap: () {
                    onSelected(r.id);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref,
      PremiumReport report, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _RenameDialog(
        report: report,
        l10n: l10n,
        onSave: (nickname) async {
          Navigator.of(ctx).pop();
          try {
            await ref
                .read(roadmapRepositoryProvider)
                .updateReportNickname(
                    reportId: report.id, nickname: nickname);
            ref.invalidate(premiumReportsProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.roadmapNicknameSaved)),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.roadmapNicknameError)),
              );
            }
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rename dialog
// ---------------------------------------------------------------------------

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({
    required this.report,
    required this.l10n,
    required this.onSave,
  });
  final PremiumReport report;
  final AppLocalizations l10n;
  final void Function(String nickname) onSave;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.report.nickname ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.roadmapRenameReport),
      content: TextField(
        key: const Key('roadmap_nickname_field'),
        controller: _ctrl,
        maxLength: 80,
        decoration: InputDecoration(
          labelText: l10n.roadmapNicknameLabel,
          hintText: l10n.roadmapNicknameHint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: const Key('roadmap_nickname_save'),
          onPressed: _ctrl.text.trim().isEmpty
              ? null
              : () => widget.onSave(_ctrl.text.trim()),
          child: Text(l10n.roadmapTaskSave,
              style: const TextStyle(color: WrColors.coral)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Progress bar
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.completed,
    required this.total,
    required this.percent,
    required this.l10n,
  });

  final int completed;
  final int total;
  final double percent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final pct = (percent * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.roadmapProgressLabel, style: WrTextStyles.hMedium),
            Text(
              '$completed/$total ($pct%)',
              style: WrTextStyles.body.copyWith(fontSize: 14.5),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            key: const Key('roadmap_progress_bar'),
            value: percent,
            minHeight: 10,
            backgroundColor: WrColors.navy.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(
              pct == 100 ? WrColors.teal : WrColors.coral,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Per-layer section
// ---------------------------------------------------------------------------

class _LayerSection extends ConsumerWidget {
  const _LayerSection({
    required this.layer,
    required this.focus,
    required this.actionGrid,
    required this.customTasksByCell,
    required this.selectedReport,
    required this.actionToggleState,
    required this.customToggleState,
    required this.l10n,
  });

  final String layer;
  final _LayerFocus? focus;
  final Map<String, List<RoadmapAction>> actionGrid;
  final Map<String, List<CustomTask>> customTasksByCell;
  final PremiumReport selectedReport;
  final Map<String, bool> actionToggleState;
  final Map<String, bool> customToggleState;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _layerColor(layer);
    final label = _layerLabel(layer, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Layer header
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: WrColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  letterSpacing: 0.04 * 13,
                ),
              ),
              if (focus != null) ...[
                const Spacer(),
                Text(
                  '${focus!.label} · ${focus!.score.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Focus sub-component badge (score + description)
        if (focus != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${focus!.score.toStringAsFixed(1)} · ${_scoreLabel(focus!.score, l10n)}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _scoreColor(focus!.score),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        // 3 day columns (horizontal scroll on mobile)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _days.map((day) {
              final key = '$layer-$day';
              final actions = actionGrid[key] ?? [];
              final tasks = customTasksByCell[key] ?? [];
              return Padding(
                padding: EdgeInsets.only(
                    right: day != _days.last ? 12 : 0),
                child: SizedBox(
                  width: 260,
                  child: _DayCell(
                    layer: layer,
                    day: day,
                    actions: actions,
                    customTasks: tasks,
                    selectedReport: selectedReport,
                    actionToggleState: actionToggleState,
                    customToggleState: customToggleState,
                    l10n: l10n,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Day cell (one cell in the roadmap grid)
// ---------------------------------------------------------------------------

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.layer,
    required this.day,
    required this.actions,
    required this.customTasks,
    required this.selectedReport,
    required this.actionToggleState,
    required this.customToggleState,
    required this.l10n,
  });

  final String layer;
  final int day;
  final List<RoadmapAction> actions;
  final List<CustomTask> customTasks;
  final PremiumReport selectedReport;
  final Map<String, bool> actionToggleState;
  final Map<String, bool> customToggleState;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _layerColor(layer);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: WrColors.navy.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: WrColors.navy.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent stripe
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Text(
            _dayHeader(day, l10n).toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: WrColors.muted,
              letterSpacing: 0.04 * 11,
            ),
          ),
          const SizedBox(height: 10),

          // Narrative actions
          for (final action in actions)
            _ActionRow(
              action: action,
              isCompleted: actionToggleState[action.id] ?? false,
              onToggle: (val) {
                ref
                    .read(roadmapActionToggleNotifierProvider(
                            selectedReport.id)
                        .notifier)
                    .toggle(action.id, val);
              },
              l10n: l10n,
            ),

          // Custom tasks
          if (customTasks.isNotEmpty) ...[
            const Divider(height: 16),
            for (final task in customTasks)
              _CustomTaskRow(
                task: task,
                isCompleted: customToggleState[task.id] ?? task.isCompleted,
                onToggle: (val) {
                  ref
                      .read(customTaskToggleNotifierProvider(
                              selectedReport.id)
                          .notifier)
                      .toggle(task.id, val);
                },
                onEdit: () =>
                    _showEditDialog(context, ref, task),
                onDelete: () =>
                    _deleteTask(context, ref, task.id),
              ),
          ],

          // Add custom task button
          const SizedBox(height: 6),
          _AddTaskButton(
            layer: layer,
            day: day,
            selectedReport: selectedReport,
            l10n: l10n,
          ),
        ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, CustomTask task) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CustomTaskDialog(
        initialTitle: task.title,
        initialDescription: task.description ?? '',
        initialDueDate: task.dueDate ?? '',
        l10n: l10n,
        isEdit: true,
        onSave: (title, desc, due) async {
          Navigator.of(ctx).pop();
          try {
            await ref
                .read(roadmapRepositoryProvider)
                .updateCustomTask(
                  taskId: task.id,
                  title: title,
                  description: desc.isEmpty ? null : desc,
                  dueDate: due.isEmpty ? null : due,
                );
            ref.invalidate(
                roadmapProgressProvider(selectedReport.id));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.roadmapTaskUpdated)),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.roadmapErrorEdit)),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteTask(
      BuildContext context, WidgetRef ref, String taskId) async {
    try {
      await ref.read(roadmapRepositoryProvider).deleteCustomTask(taskId);
      ref.invalidate(roadmapProgressProvider(selectedReport.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.roadmapTaskDeleted)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.roadmapErrorDelete)),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Action row (narrative action checkbox)
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.isCompleted,
    required this.onToggle,
    required this.l10n,
  });

  final RoadmapAction action;
  final bool isCompleted;
  final void Function(bool) onToggle;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onToggle(!isCompleted),
            child: Icon(
              isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isCompleted ? WrColors.teal : WrColors.muted,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => onToggle(!isCompleted),
                  child: Text(
                    action.titleVi,
                    style: WrTextStyles.hMedium.copyWith(
                      fontSize: 14.5,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: isCompleted ? WrColors.muted : null,
                    ),
                  ),
                ),
                if (action.descriptionVi.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    action.descriptionVi,
                    style: WrTextStyles.body.copyWith(
                      fontSize: 13.5,
                      color: WrColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom task row
// ---------------------------------------------------------------------------

class _CustomTaskRow extends StatelessWidget {
  const _CustomTaskRow({
    required this.task,
    required this.isCompleted,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomTask task;
  final bool isCompleted;
  final void Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onToggle(!isCompleted),
            child: Icon(
              isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isCompleted ? WrColors.teal : WrColors.muted,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onToggle(!isCompleted),
                        child: Text(
                          task.title,
                          style: WrTextStyles.body.copyWith(
                            fontSize: 14.5,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted ? WrColors.muted : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.dueDate != null && task.dueDate!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 10, color: WrColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        task.dueDate!,
                        style: WrTextStyles.body.copyWith(
                            fontSize: 12.5, color: WrColors.text3),
                      ),
                    ],
                  ),
                ],
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.description!,
                    style: WrTextStyles.body.copyWith(
                        fontSize: 13.5, color: WrColors.muted),
                  ),
                ],
              ],
            ),
          ),
          // Edit / delete
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: WrColors.muted),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close,
                size: 16, color: WrColors.destructive),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add task button
// ---------------------------------------------------------------------------

class _AddTaskButton extends ConsumerWidget {
  const _AddTaskButton({
    required this.layer,
    required this.day,
    required this.selectedReport,
    required this.l10n,
  });

  final String layer;
  final int day;
  final PremiumReport selectedReport;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      key: Key('roadmap_add_task_${layer}_$day'),
      onTap: () => _showAddDialog(context, ref),
      child: Row(
        children: [
          const Icon(Icons.add, size: 16, color: WrColors.muted),
          const SizedBox(width: 4),
          // Ô ngày trong lưới lộ trình hẹp cố định; ở cỡ chữ lớn nhãn này tràn
          // viền nên phải cho phép xuống dòng thay vì giữ nguyên một hàng.
          Flexible(
            child: Text(
              l10n.roadmapAddCustomTask,
              style: WrTextStyles.body.copyWith(
                  fontSize: 13.5, color: WrColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CustomTaskDialog(
        l10n: l10n,
        isEdit: false,
        onSave: (title, desc, due) async {
          Navigator.of(ctx).pop();
          try {
            await ref.read(roadmapRepositoryProvider).addCustomTask(
                  reportId: selectedReport.id,
                  title: title,
                  description: desc.isEmpty ? null : desc,
                  layer: layer,
                  day: day,
                  dueDate: due.isEmpty ? null : due,
                );
            ref.invalidate(
                roadmapProgressProvider(selectedReport.id));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.roadmapTaskAdded)),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.roadmapErrorAdd)),
              );
            }
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom task dialog (add / edit)
// ---------------------------------------------------------------------------

class _CustomTaskDialog extends StatefulWidget {
  const _CustomTaskDialog({
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialDueDate = '',
    required this.l10n,
    required this.isEdit,
    required this.onSave,
  });

  final String initialTitle;
  final String initialDescription;
  final String initialDueDate;
  final AppLocalizations l10n;
  final bool isEdit;
  final void Function(String title, String description, String dueDate) onSave;

  @override
  State<_CustomTaskDialog> createState() => _CustomTaskDialogState();
}

class _CustomTaskDialogState extends State<_CustomTaskDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _dueCtrl;
  late String _titleText;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _descCtrl = TextEditingController(text: widget.initialDescription);
    _dueCtrl = TextEditingController(text: widget.initialDueDate);
    _titleText = widget.initialTitle;
    _titleCtrl.addListener(() {
      setState(() => _titleText = _titleCtrl.text);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(
          widget.isEdit ? l10n.roadmapEditTaskTitle : l10n.roadmapAddTaskTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.roadmapTaskTitleLabel,
                style: WrTextStyles.body.copyWith(fontSize: 13.5)),
            const SizedBox(height: 4),
            TextField(
              key: const Key('roadmap_task_title_field'),
              controller: _titleCtrl,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: l10n.roadmapTaskTitleHint,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.roadmapTaskDescLabel,
                style: WrTextStyles.body.copyWith(fontSize: 13.5)),
            const SizedBox(height: 4),
            TextField(
              key: const Key('roadmap_task_desc_field'),
              controller: _descCtrl,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.roadmapTaskDescHint,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.roadmapTaskDueDateLabel,
                style: WrTextStyles.body.copyWith(fontSize: 13.5)),
            const SizedBox(height: 4),
            TextField(
              key: const Key('roadmap_task_due_field'),
              controller: _dueCtrl,
              decoration: InputDecoration(
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: Key(widget.isEdit
              ? 'roadmap_task_save_btn'
              : 'roadmap_task_add_btn'),
          onPressed: _titleText.trim().isEmpty
              ? null
              : () => widget.onSave(
                    _titleCtrl.text.trim(),
                    _descCtrl.text.trim(),
                    _dueCtrl.text.trim(),
                  ),
          child: Text(
            widget.isEdit ? l10n.roadmapTaskSave : l10n.roadmapTaskAdd,
            style: const TextStyle(color: WrColors.coral),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Coach section
// ---------------------------------------------------------------------------

class _CoachSection extends ConsumerWidget {
  const _CoachSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachAccessAsync = ref.watch(coachAccessProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.roadmapCoachSectionTitle),
        const SizedBox(height: 12),
        coachAccessAsync.when(
          loading: () =>
              const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (_, __) => const SizedBox.shrink(),
          data: (entries) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entries.isEmpty)
                  Text(l10n.roadmapNoCoachs,
                      style: WrTextStyles.body
                          .copyWith(color: WrColors.muted)),
                for (final entry in entries)
                  _CoachAccessTile(entry: entry, l10n: l10n),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('roadmap_invite_coach_btn'),
                  onPressed: () =>
                      _showInviteDialog(context, ref, entries),
                  icon: const Icon(Icons.person_add_outlined,
                      size: 18),
                  label: Text(l10n.roadmapInviteCoach),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref,
      List<CoachAccessEntry> existing) {
    final existingIds = existing.map((e) => e.coachId).toSet();
    showDialog<void>(
      context: context,
      builder: (ctx) => _InviteCoachDialog(
        existingCoachIds: existingIds,
        l10n: l10n,
        onInvite: (coachId) async {
          Navigator.of(ctx).pop();
          try {
            await ref.read(roadmapRepositoryProvider).inviteCoach(coachId);
            ref.invalidate(coachAccessProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.roadmapCoachInvited)),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.roadmapErrorInviteCoach)),
              );
            }
          }
        },
      ),
    );
  }
}

class _CoachAccessTile extends StatelessWidget {
  const _CoachAccessTile({required this.entry, required this.l10n});
  final CoachAccessEntry entry;
  final AppLocalizations l10n;

  String _statusLabel(AppLocalizations l10n) => switch (entry.status) {
        'accepted' => l10n.roadmapCoachAccepted,
        'revoked' => l10n.roadmapCoachRevoked,
        _ => l10n.roadmapCoachPending,
      };

  Color _statusColor() => switch (entry.status) {
        'accepted' => WrColors.teal,
        'revoked' => WrColors.muted,
        _ => WrColors.coral,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: WrColors.navy.withValues(alpha: 0.08),
            child: Text(
              (entry.coachName ?? 'C').characters.first.toUpperCase(),
              style: const TextStyle(
                color: WrColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.coachName ?? 'Coach',
                    style: WrTextStyles.hMedium.copyWith(fontSize: 14.5)),
                if (entry.coachTitle != null)
                  Text(entry.coachTitle!,
                      style: WrTextStyles.body
                          .copyWith(fontSize: 13.5, color: WrColors.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(l10n),
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _statusColor()),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCoachDialog extends ConsumerWidget {
  const _InviteCoachDialog({
    required this.existingCoachIds,
    required this.l10n,
    required this.onInvite,
  });

  final Set<String> existingCoachIds;
  final AppLocalizations l10n;
  final void Function(String coachId) onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachesAsync = ref.watch(availableCoachesProvider);

    return AlertDialog(
      title: Text(l10n.roadmapChooseCoach),
      content: SizedBox(
        width: double.maxFinite,
        child: coachesAsync.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (coaches) {
            final available =
                coaches.where((c) => !existingCoachIds.contains(c.id)).toList();
            if (available.isEmpty) {
              return Text(l10n.roadmapNoCoachesAvailable,
                  style: WrTextStyles.body);
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (_, i) {
                final coach = available[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        WrColors.navy.withValues(alpha: 0.08),
                    child: Text(
                      coach.fullName.characters.first.toUpperCase(),
                      style: const TextStyle(
                          color: WrColors.navy,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(coach.fullName,
                      style: WrTextStyles.hMedium.copyWith(fontSize: 15.5)),
                  subtitle: coach.title != null
                      ? Text(coach.title!,
                          style: WrTextStyles.body
                              .copyWith(fontSize: 13.5))
                      : null,
                  onTap: () => onInvite(coach.id),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Activity log
// ---------------------------------------------------------------------------

class _ActivityLog extends StatelessWidget {
  const _ActivityLog({
    required this.progressData,
    required this.actionGrid,
    required this.actionToggleState,
    required this.customToggleState,
    required this.l10n,
  });

  final RoadmapProgressData progressData;
  final Map<String, List<RoadmapAction>> actionGrid;
  final Map<String, bool> actionToggleState;
  final Map<String, bool> customToggleState;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Collect completed items
    final entries = <_ActivityEntry>[];

    // Completed system actions
    for (final acts in actionGrid.values) {
      for (final action in acts) {
        if (actionToggleState[action.id] ?? false) {
          entries.add(_ActivityEntry(
            content: action.titleVi,
            layer: action.layer,
            date: progressData.completedActionDates[action.id],
          ));
        }
      }
    }

    // Completed custom tasks
    for (final task in progressData.customTasks) {
      if (customToggleState[task.id] ?? task.isCompleted) {
        entries.add(_ActivityEntry(
          content: task.title,
          layer: task.layer,
          date: task.completedAt,
        ));
      }
    }

    entries.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.roadmapActivityLog),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text(l10n.roadmapActivityEmpty,
              style: WrTextStyles.body.copyWith(color: WrColors.muted))
        else
          for (final entry in entries) _ActivityEntryTile(entry: entry, l10n: l10n),
      ],
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry({
    required this.content,
    required this.layer,
    this.date,
  });
  final String content;
  final String layer;
  final String? date;
}

class _ActivityEntryTile extends StatelessWidget {
  const _ActivityEntryTile({required this.entry, required this.l10n});
  final _ActivityEntry entry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final color = _layerColor(entry.layer);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: WrColors.teal, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.content,
                    style: WrTextStyles.body.copyWith(fontSize: 14.5)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.layer,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ),
                    if (entry.date != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        entry.date!.substring(0, 10),
                        style: WrTextStyles.body
                            .copyWith(fontSize: 12.5, color: WrColors.text3),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
