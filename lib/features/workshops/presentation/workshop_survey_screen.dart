// Workshop post-survey screen placeholder — Phase 3 Task 10.
// Full implementation deferred to a later task.

import 'package:flutter/material.dart';

import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../l10n/app_localizations.dart';

class WorkshopSurveyScreen extends StatelessWidget {
  const WorkshopSurveyScreen({super.key, required this.workshopId});

  final String workshopId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        title: Text(l10n.wsSurveyTitle, style: WrTextStyles.hMedium),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
