import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../l10n/app_localizations.dart';
import '../profile_providers.dart';

/// Navigated to via context.push('/profile/edit').
/// Loads current cc_profiles + mobileProfile, lets user edit,
/// and calls ProfileEditNotifier.save() on submit.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final _displayNameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();

  // Dropdown values — nullable until loaded
  String? _position;
  String? _companySize;
  String? _workExperience;
  String? _tenure;
  String? _department;

  bool _loaded = false;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _companyNameCtrl.dispose();
    super.dispose();
  }

  void _initFromProviders(
    Map<String, dynamic> ccData,
    String? displayName,
  ) {
    if (_loaded) return;
    _loaded = true;
    _displayNameCtrl.text = displayName ?? '';
    _fullNameCtrl.text = (ccData['full_name'] as String?) ?? '';
    _phoneCtrl.text = (ccData['phone'] as String?) ?? '';
    _companyNameCtrl.text = (ccData['company_name'] as String?) ?? '';
    _position = ccData['position'] as String?;
    _companySize = ccData['company_size'] as String?;
    _workExperience = ccData['total_work_experience'] as String?;
    _tenure = ccData['company_tenure'] as String?;
    _department = ccData['department'] as String?;
  }

  Future<void> _save(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(profileEditProvider.notifier).save(
        displayName: _displayNameCtrl.text.trim(),
        ccFields: {
          'full_name': _fullNameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'company_name': _companyNameCtrl.text.trim(),
          if (_position != null) 'position': _position,
          if (_companySize != null) 'company_size': _companySize,
          if (_workExperience != null) 'total_work_experience': _workExperience,
          if (_tenure != null) 'company_tenure': _tenure,
          if (_department != null) 'department': _department,
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileEditSaveSuccess)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileEditSaveError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ccAsync = ref.watch(ccProfileProvider);
    final profileAsync = ref.watch(mobileProfileProvider);
    final saveState = ref.watch(profileEditProvider);

    // Populate controllers once data arrives
    if (ccAsync.hasValue && profileAsync.hasValue) {
      _initFromProviders(
        ccAsync.value ?? {},
        profileAsync.value?.displayName,
      );
    }

    final ccData = ccAsync.valueOrNull ?? {};
    final name = (ccData['full_name'] as String?) ??
        profileAsync.valueOrNull?.displayName ??
        'bạn';
    final initials = _computeInitials(name);

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        leading: const BackButton(color: WrColors.navy),
        title: Text(l10n.profileEditTitle, style: WrTextStyles.hMedium),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              key: const Key('profile_edit_save_btn'),
              onPressed: saveState.isLoading ? null : () => _save(context),
              child: saveState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: WrColors.coral,
                      ),
                    )
                  : Text(
                      l10n.profileEditSave,
                      style: const TextStyle(
                        color: WrColors.coral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ccAsync.isLoading || profileAsync.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: WrColors.coral))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Avatar (read-only)
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: WrColors.navy.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: WrColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.profileEditAvatarNote,
                            style: WrTextStyles.body.copyWith(
                              fontSize: 11,
                              color: WrColors.muted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    WrEyebrow(l10n.profileEditEyebrow),
                    const SizedBox(height: 16),

                    // Display name
                    _EditField(
                      key: const Key('profile_edit_display_name'),
                      controller: _displayNameCtrl,
                      label: l10n.profileEditFieldDisplayName,
                    ),
                    const SizedBox(height: 16),

                    // Full name
                    _EditField(
                      key: const Key('profile_edit_full_name'),
                      controller: _fullNameCtrl,
                      label: l10n.profileEditFieldFullName,
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    _EditField(
                      key: const Key('profile_edit_phone'),
                      controller: _phoneCtrl,
                      label: l10n.profileEditFieldPhone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Company name
                    _EditField(
                      key: const Key('profile_edit_company_name'),
                      controller: _companyNameCtrl,
                      label: l10n.profileEditFieldCompanyName,
                    ),
                    const SizedBox(height: 16),

                    // Position dropdown
                    _SelectField<String>(
                      key: const Key('profile_edit_position'),
                      label: l10n.profileEditFieldPosition,
                      value: _position,
                      hint: l10n.profileEditSelectHint,
                      items: [
                        _opt('staff', l10n.profileEditPositionStaff),
                        _opt('team_lead', l10n.profileEditPositionTeamLead),
                        _opt('manager', l10n.profileEditPositionManager),
                        _opt('director', l10n.profileEditPositionDirector),
                        _opt('c_level', l10n.profileEditPositionCLevel),
                        _opt('intern', l10n.profileEditPositionIntern),
                        _opt('freelancer', l10n.profileEditPositionFreelancer),
                        _opt('other', l10n.profileEditPositionOther),
                      ],
                      onChanged: (v) => setState(() => _position = v),
                    ),
                    const SizedBox(height: 16),

                    // Company size dropdown
                    _SelectField<String>(
                      key: const Key('profile_edit_company_size'),
                      label: l10n.profileEditFieldCompanySize,
                      value: _companySize,
                      hint: l10n.profileEditSelectHint,
                      items: [
                        _opt('1_10', l10n.profileEditCompanySize1to10),
                        _opt('11_50', l10n.profileEditCompanySize11to50),
                        _opt('51_200', l10n.profileEditCompanySize51to200),
                        _opt('201_500', l10n.profileEditCompanySize201to500),
                        _opt('501_1000', l10n.profileEditCompanySize501to1000),
                        _opt('1000_plus', l10n.profileEditCompanySize1000Plus),
                      ],
                      onChanged: (v) => setState(() => _companySize = v),
                    ),
                    const SizedBox(height: 16),

                    // Work experience dropdown
                    _SelectField<String>(
                      key: const Key('profile_edit_work_experience'),
                      label: l10n.profileEditFieldExperience,
                      value: _workExperience,
                      hint: l10n.profileEditSelectHint,
                      items: [
                        _opt('less_1', l10n.profileEditExpLess1),
                        _opt('1_3', l10n.profileEditExp1to3),
                        _opt('3_5', l10n.profileEditExp3to5),
                        _opt('5_10', l10n.profileEditExp5to10),
                        _opt('10_plus', l10n.profileEditExp10Plus),
                      ],
                      onChanged: (v) => setState(() => _workExperience = v),
                    ),
                    const SizedBox(height: 16),

                    // Company tenure dropdown
                    _SelectField<String>(
                      key: const Key('profile_edit_tenure'),
                      label: l10n.profileEditFieldTenure,
                      value: _tenure,
                      hint: l10n.profileEditSelectHint,
                      items: [
                        _opt('less_6m', l10n.profileEditTenureLess6m),
                        _opt('6m_1y', l10n.profileEditTenure6mto1y),
                        _opt('1_2', l10n.profileEditTenure1to2),
                        _opt('2_5', l10n.profileEditTenure2to5),
                        _opt('5_plus', l10n.profileEditTenure5Plus),
                      ],
                      onChanged: (v) => setState(() => _tenure = v),
                    ),
                    const SizedBox(height: 16),

                    // Department dropdown
                    _SelectField<String>(
                      key: const Key('profile_edit_department'),
                      label: l10n.profileEditFieldDepartment,
                      value: _department,
                      hint: l10n.profileEditSelectHint,
                      items: [
                        _opt('marketing', l10n.profileEditDeptMarketing),
                        _opt('accounting', l10n.profileEditDeptAccounting),
                        _opt('sales', l10n.profileEditDeptSales),
                        _opt('purchasing', l10n.profileEditDeptPurchasing),
                        _opt('hr', l10n.profileEditDeptHr),
                        _opt('it', l10n.profileEditDeptIt),
                        _opt('production', l10n.profileEditDeptProduction),
                        _opt('admin', l10n.profileEditDeptAdmin),
                        _opt('other', l10n.profileEditDeptOther),
                      ],
                      onChanged: (v) => setState(() => _department = v),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  DropdownMenuItem<String> _opt(String value, String label) =>
      DropdownMenuItem(value: value, child: Text(label, style: WrTextStyles.body));

  static String _computeInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Reusable private widgets
// ---------------------------------------------------------------------------

class _EditField extends StatelessWidget {
  const _EditField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: WrTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: WrTextStyles.body.copyWith(color: WrColors.muted),
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

class _SelectField<T> extends StatelessWidget {
  const _SelectField({
    super.key,
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
            border: Border.all(
              color: WrColors.navy.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: Text(hint,
                  style: WrTextStyles.body.copyWith(color: WrColors.muted)),
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
