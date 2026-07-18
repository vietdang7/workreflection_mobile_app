import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/profile_options.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../l10n/app_localizations.dart';
import '../avatar_providers.dart';
import '../profile_providers.dart';

/// Navigated to via context.push('/profile/edit').
/// Loads current cc_profiles + mobileProfile, lets user edit,
/// and calls ProfileEditNotifier.save() on submit.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, this.setupMode = false});
  final bool setupMode;

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

  Future<void> _pickAvatar(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final url = await ref
        .read(avatarUploadProvider.notifier)
        .pickAndUpload();
    if (!context.mounted) return;
    if (url != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.avatarUploadSuccess)),
      );
    } else if (ref.read(avatarUploadProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.avatarUploadError)),
      );
    }
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
        if (widget.setupMode) {
          context.go('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.profileEditSaveSuccess)),
          );
        }
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
    final avatarUrl = ccData['avatar_url'] as String?;

    final avatarState = ref.watch(avatarUploadProvider);
    final isUploadingAvatar = avatarState.isLoading;

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.setupMode ? null : const BackButton(color: WrColors.navy),
        title: Text(
          widget.setupMode ? l10n.profileSetupTitle : l10n.profileEditTitle,
          style: WrTextStyles.hMedium,
        ),
        centerTitle: false,
        actions: [
          if (widget.setupMode)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton(
                key: const Key('profile_setup_skip_btn'),
                onPressed: () => context.go('/home'),
                child: Text(
                  l10n.profileSetupSkip,
                  style: const TextStyle(color: WrColors.muted),
                ),
              ),
            ),
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
                      widget.setupMode ? l10n.profileSetupComplete : l10n.profileEditSave,
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

                    // Avatar (tappable — pick from gallery)
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            key: const Key('profile_edit_avatar_tap'),
                            onTap: isUploadingAvatar
                                ? null
                                : () => _pickAvatar(context),
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: WrColors.navy.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: avatarUrl != null && avatarUrl.isNotEmpty
                                      ? Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _InitialsCircle(initials: initials),
                                        )
                                      : _InitialsCircle(initials: initials),
                                ),
                                // Camera overlay
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: WrColors.coral,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: WrColors.white, width: 2),
                                    ),
                                    child: isUploadingAvatar
                                        ? const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: WrColors.white,
                                            ),
                                          )
                                        : const Icon(Icons.camera_alt,
                                            size: 14, color: WrColors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isUploadingAvatar
                                ? l10n.avatarUploading
                                : l10n.avatarChangeBtn,
                            style: WrTextStyles.body.copyWith(
                              fontSize: 12,
                              color: WrColors.coral,
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
                        ...positionOptions(l10n).map((o) => _opt(o.value, o.label)),
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
                        ...companySizeOptions(l10n).map((o) => _opt(o.value, o.label)),
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
                        ...workExperienceOptions(l10n).map((o) => _opt(o.value, o.label)),
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
                        ...companyTenureOptions(l10n).map((o) => _opt(o.value, o.label)),
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
                        ...departmentOptions(l10n).map((o) => _opt(o.value, o.label)),
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

// ---------------------------------------------------------------------------
// Helper widget — initials fallback inside avatar circle
// ---------------------------------------------------------------------------

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WrColors.navy.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: WrColors.navy,
        ),
      ),
    );
  }
}
