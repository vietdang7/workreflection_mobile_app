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

class SurveyIntroScreen extends ConsumerStatefulWidget {
  const SurveyIntroScreen({super.key});

  @override
  ConsumerState<SurveyIntroScreen> createState() => _SurveyIntroScreenState();
}

class _SurveyIntroScreenState extends ConsumerState<SurveyIntroScreen> {
  final _positionCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _companySizeCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();

  @override
  void dispose() {
    _positionCtrl.dispose();
    _experienceCtrl.dispose();
    _tenureCtrl.dispose();
    _companySizeCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typeAsync = ref.watch(surveyTypeProvider);

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              WrEyebrow(l10n.surveyIntroEyebrow),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.surveyIntroTitle,
                        style: WrTextStyles.hLarge),
                  ),
                  typeAsync.when(
                    data: (type) => _BadgeChip(
                      label: type == SurveyType.premium
                          ? l10n.surveyIntroBadgePremium
                          : l10n.surveyIntroBadgeFree,
                      isPremium: type == SurveyType.premium,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.surveyIntroBody, style: WrTextStyles.body),
              const SizedBox(height: 28),

              // Optional info fields
              _InfoField(
                  controller: _positionCtrl,
                  label: l10n.surveyIntroFieldPosition),
              const SizedBox(height: 12),
              _InfoField(
                  controller: _experienceCtrl,
                  label: l10n.surveyIntroFieldExperience),
              const SizedBox(height: 12),
              _InfoField(
                  controller: _tenureCtrl,
                  label: l10n.surveyIntroFieldCompanyTenure),
              const SizedBox(height: 12),
              _InfoField(
                  controller: _companySizeCtrl,
                  label: l10n.surveyIntroFieldCompanySize),
              const SizedBox(height: 12),
              _InfoField(
                  controller: _departmentCtrl,
                  label: l10n.surveyIntroFieldDepartment),
              const SizedBox(height: 32),

              WrPillButton(
                label: l10n.surveyIntroCta,
                onPressed: () {
                  // Store intro fields
                  ref.read(surveyIntroInfoProvider.notifier).state = SurveyIntroInfo(
                    userPosition: _positionCtrl.text.trim().isEmpty ? null : _positionCtrl.text.trim(),
                    userWorkExperience: _experienceCtrl.text.trim().isEmpty ? null : _experienceCtrl.text.trim(),
                    userCompanyTenure: _tenureCtrl.text.trim().isEmpty ? null : _tenureCtrl.text.trim(),
                    userCompanySize: _companySizeCtrl.text.trim().isEmpty ? null : _companySizeCtrl.text.trim(),
                    userDepartment: _departmentCtrl.text.trim().isEmpty ? null : _departmentCtrl.text.trim(),
                  );
                  // Reset answers + index + in-progress surveyId for fresh survey
                  ref.read(surveyAnswersProvider.notifier).reset();
                  ref.read(currentQuestionIndexProvider.notifier).state = 0;
                  ref.read(surveyIdInProgressProvider.notifier).state = null;
                  context.push('/survey/questions');
                },
                variant: WrPillVariant.coral,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.isPremium});
  final String label;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPremium
            ? WrColors.teal.withValues(alpha: 0.12)
            : WrColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPremium ? WrColors.teal : WrColors.navy,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: WrTextStyles.body,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WrColors.navy.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WrColors.navy.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WrColors.coral),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
