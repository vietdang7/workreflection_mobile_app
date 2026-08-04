import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/profile_options.dart';
import '../../../core/models/survey_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/data/wr_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/profile_providers.dart';
import '../survey_providers.dart';

class SurveyIntroScreen extends ConsumerStatefulWidget {
  const SurveyIntroScreen({super.key});

  @override
  ConsumerState<SurveyIntroScreen> createState() => _SurveyIntroScreenState();
}

class _SurveyIntroScreenState extends ConsumerState<SurveyIntroScreen> {
  String? _position;
  String? _experience;
  String? _tenure;
  String? _companySize;
  String? _department;

  bool _loaded = false;

  // Mirrors web's hasSubmitted ref — prevents re-trigger after auto-skip in
  // the same widget instance. A new widget instance (after back navigation)
  // starts fresh, which is the desired behavior (same as web).
  bool _hasSkipped = false;

  void _initFromProfile(Map<String, dynamic> data) {
    if (_loaded) return;
    _loaded = true;
    _position = data['position'] as String?;
    _experience = data['total_work_experience'] as String?;
    _tenure = data['company_tenure'] as String?;
    _companySize = data['company_size'] as String?;
    _department = data['department'] as String?;
  }

  bool _isProfileComplete() => _position != null && _position!.isNotEmpty;

  void _doStateReset() {
    ref.read(surveyAnswersProvider.notifier).reset();
    ref.read(currentQuestionIndexProvider.notifier).state = 0;
    ref.read(surveyIdInProgressProvider.notifier).state = null;
  }

  Future<void> _ctaTapped({required AppLocalizations l10n}) async {
    // Store intro info to provider
    ref.read(surveyIntroInfoProvider.notifier).state = SurveyIntroInfo(
      userPosition: _position,
      userWorkExperience: _experience,
      userCompanyTenure: _tenure,
      userCompanySize: _companySize,
      userDepartment: _department,
    );

    // Update cc_profiles with any entered/changed values (mirrors web line 398)
    final updateFields = <String, dynamic>{
      if (_position != null) 'position': _position,
      if (_experience != null) 'total_work_experience': _experience,
      if (_tenure != null) 'company_tenure': _tenure,
      if (_companySize != null) 'company_size': _companySize,
      if (_department != null) 'department': _department,
    };
    if (updateFields.isNotEmpty) {
      try {
        await ref.read(wrRepositoryProvider).updateCcProfile(updateFields);
        ref.invalidate(ccProfileProvider);
      } catch (_) {
        // Non-fatal: profile update failure doesn't block survey
      }
    }

    // Reset state + navigate
    _doStateReset();
    if (mounted) context.push('/survey/guide');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typeAsync = ref.watch(surveyTypeProvider);
    final ccAsync = ref.watch(ccProfileProvider);

    // Prefill from profile once data arrives
    if (ccAsync.hasValue) {
      _initFromProfile(ccAsync.value ?? {});
    }

    // Auto-skip: if profile complete AND this widget hasn't already skipped,
    // navigate to /survey/guide without requiring manual CTA tap.
    // This mirrors web's auto-redirect when isProfileComplete is true.
    // _hasSkipped ensures the callback only fires once per widget instance.
    if (_loaded && !_hasSkipped && _isProfileComplete()) {
      _hasSkipped = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(surveyIntroInfoProvider.notifier).state = SurveyIntroInfo(
          userPosition: _position,
          userWorkExperience: _experience,
          userCompanyTenure: _tenure,
          userCompanySize: _companySize,
          userDepartment: _department,
        );
        _doStateReset();
        context.push('/survey/guide');
      });
    }

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ccAsync.isLoading
            ? const Center(child: CircularProgressIndicator(color: WrColors.coral))
            : SingleChildScrollView(
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
                          child: Text(l10n.surveyIntroTitle, style: WrTextStyles.hLarge),
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

                    // Position dropdown
                    _DropdownField<String>(
                      label: l10n.surveyIntroFieldPosition,
                      value: _position,
                      hint: l10n.profileEditSelectHint,
                      items: positionOptions(l10n)
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label, style: WrTextStyles.body)))
                          .toList(),
                      onChanged: (v) => setState(() => _position = v),
                    ),
                    const SizedBox(height: 12),

                    // Work experience dropdown
                    _DropdownField<String>(
                      label: l10n.surveyIntroFieldExperience,
                      value: _experience,
                      hint: l10n.profileEditSelectHint,
                      items: workExperienceOptions(l10n)
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label, style: WrTextStyles.body)))
                          .toList(),
                      onChanged: (v) => setState(() => _experience = v),
                    ),
                    const SizedBox(height: 12),

                    // Company tenure dropdown
                    _DropdownField<String>(
                      label: l10n.surveyIntroFieldCompanyTenure,
                      value: _tenure,
                      hint: l10n.profileEditSelectHint,
                      items: companyTenureOptions(l10n)
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label, style: WrTextStyles.body)))
                          .toList(),
                      onChanged: (v) => setState(() => _tenure = v),
                    ),
                    const SizedBox(height: 12),

                    // Company size dropdown
                    _DropdownField<String>(
                      label: l10n.surveyIntroFieldCompanySize,
                      value: _companySize,
                      hint: l10n.profileEditSelectHint,
                      items: companySizeOptions(l10n)
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label, style: WrTextStyles.body)))
                          .toList(),
                      onChanged: (v) => setState(() => _companySize = v),
                    ),
                    const SizedBox(height: 12),

                    // Department dropdown
                    _DropdownField<String>(
                      label: l10n.surveyIntroFieldDepartment,
                      value: _department,
                      hint: l10n.profileEditSelectHint,
                      items: departmentOptions(l10n)
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label, style: WrTextStyles.body)))
                          .toList(),
                      onChanged: (v) => setState(() => _department = v),
                    ),
                    const SizedBox(height: 32),

                    WrPillButton(
                      label: l10n.surveyIntroCta,
                      onPressed: () => _ctaTapped(l10n: l10n),
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

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: WrTextStyles.body.copyWith(color: WrColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: WrColors.navy.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: Text(hint, style: WrTextStyles.body.copyWith(color: WrColors.muted)),
              items: items,
              onChanged: onChanged,
              style: WrTextStyles.body,
              icon: const Icon(Icons.keyboard_arrow_down, color: WrColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}
