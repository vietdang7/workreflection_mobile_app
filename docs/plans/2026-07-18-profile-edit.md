# Profile Edit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `/profile/edit` screen that lets users edit `display_name` (wr_mobile_profiles) and the 8 cc_profiles fields that the web app manages (full_name, phone, company_name, position, company_size, total_work_experience, company_tenure, department), with avatar deferred (see below).

**Architecture:** A new `ProfileEditScreen` (ConsumerStatefulWidget) navigated to from the existing `ProfileScreen` settings row. Two repository methods are added to `WrRepository`: `updateDisplayName` (wr_mobile_profiles) and `updateCcProfile` (cc_profiles). A single `profileEditProvider` (AsyncNotifier) holds the save state and invalidates `ccProfileProvider` + `mobileProfileProvider` on success. No new model class is needed — cc_profiles data stays as `Map<String, dynamic>` matching the existing pattern.

**Tech Stack:** Flutter + Riverpod (AsyncNotifier) + Supabase Flutter SDK + go_router (`context.push('/profile/edit')`) + flutter_gen l10n (app_vi.arb / app_en.arb)

**Avatar scope decision:** The web app uses a dedicated crop dialog (`react-easy-crop`), a Supabase Storage bucket (`"avatars"`), and path pattern `{userId}/avatar.{ext}`. The Flutter project has no `image_picker` dependency. Avatar editing is **deferred** — the edit screen will show the initials avatar as read-only with a "Thay ảnh — thực hiện trên web" note (no interactive upload).

---

## Background for the implementer

### Schema confirmed from web codebase

**cc_profiles** columns written by the web Profile.tsx `handleSave`:
- `full_name` — free text
- `phone` — free text
- `company_name` — free text
- `position` — select; values: `"staff"`, `"team_lead"`, `"manager"`, `"director"`, `"c_level"`, `"intern"`, `"freelancer"`, `"other"`
- `company_size` — select; values: `"1_10"`, `"11_50"`, `"51_200"`, `"201_500"`, `"501_1000"`, `"1000_plus"`
- `total_work_experience` — select; values: `"less_1"`, `"1_3"`, `"3_5"`, `"5_10"`, `"10_plus"`
- `company_tenure` — select; values: `"less_6m"`, `"6m_1y"`, `"1_2"`, `"2_5"`, `"5_plus"`
- `department` — select; values: `"marketing"`, `"accounting"`, `"sales"`, `"purchasing"`, `"hr"`, `"it"`, `"production"`, `"admin"`, `"other"`

**wr_mobile_profiles** column written on edit:
- `display_name` (String?) + `updated_at`

The cc_profiles **read** in `getCcProfile()` currently only selects `full_name, email, subscription_expires_at`. The edit screen needs the 7 additional fields. The existing `getCcProfile()` must be **extended** — do not add a new method, just widen the select.

### Existing patterns to follow

- Repository: `lib/core/data/wr_repository.dart` — abstract `WrRepository` interface + `SupabaseWrRepository` implementation
- Providers: `lib/features/profile/profile_providers.dart` — `FutureProvider`, `AsyncNotifierProvider`
- Screen: `lib/features/profile/presentation/profile_screen.dart` — `ConsumerStatefulWidget`, `WrColors`, `WrTextStyles`
- Test pattern: `test/features/profile_test.dart` + `test/support/fake_repository.dart` — `FakeWrRepository`, `_wrap()`, `_pumpLarge()`, `ProviderScope.overrides`
- l10n: `lib/l10n/app_vi.arb` + `lib/l10n/app_en.arb` — all user-facing strings go in both files; run `flutter gen-l10n` (or `flutter pub get`) to regenerate `app_localizations*.dart`
- Router: `lib/core/router/app_router.dart` — add a new `GoRoute` for `/profile/edit` **outside** the `StatefulShellRoute` (same pattern as `/my-workshops`)

### Test command
```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/profile_edit_test.dart -v
```
All tests command:
```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test -v
```
Analyze:
```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter analyze
```

---

## Task 1: Widen `getCcProfile()` + add write methods to WrRepository

**Files:**
- Modify: `lib/core/data/wr_repository.dart:331-339` (getCcProfile select list), `lib/core/data/wr_repository.dart:19-63` (abstract interface), `lib/core/data/wr_repository.dart:77+` (SupabaseWrRepository)
- Modify: `test/support/fake_repository.dart` (add stubs for new methods + extend seedCcProfile support)

### Step 1: Write the failing test (in a new file, run it first to confirm FAIL)

Create `test/features/profile_edit_test.dart` with just a smoke compile check at first:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';

import '../support/fake_repository.dart';

void main() {
  group('WrRepository profile-edit contract', () {
    test('getCcProfile returns extended fields', () async {
      final repo = FakeWrRepository();
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'y@y.com',
        'subscription_expires_at': null,
        'phone': '0901234567',
        'company_name': 'Acme',
        'position': 'manager',
        'company_size': '51_200',
        'total_work_experience': '5_10',
        'company_tenure': '2_5',
        'department': 'hr',
      });
      final data = await repo.getCcProfile();
      expect(data['phone'], '0901234567');
      expect(data['company_name'], 'Acme');
      expect(data['position'], 'manager');
    });

    test('updateCcProfile records call', () async {
      final repo = FakeWrRepository();
      await repo.updateCcProfile({
        'full_name': 'New Name',
        'phone': '0900000000',
        'company_name': 'Corp',
        'position': 'staff',
        'company_size': '1_10',
        'total_work_experience': 'less_1',
        'company_tenure': 'less_6m',
        'department': 'it',
      });
      expect(repo.updateCcProfileCalls, hasLength(1));
      expect(repo.updateCcProfileCalls.first['position'], 'staff');
    });

    test('updateDisplayName records call', () async {
      final repo = FakeWrRepository();
      await repo.updateDisplayName('New Display');
      expect(repo.updateDisplayNameCalls, contains('New Display'));
    });
  });
}
```

### Step 2: Run — expect compile FAIL (methods not declared yet)

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/profile_edit_test.dart -v 2>&1 | tail -20
```
Expected: compile error mentioning `updateCcProfile` / `updateDisplayName` not found.

### Step 3: Add abstract declarations to WrRepository interface

In `lib/core/data/wr_repository.dart`, inside the `abstract class WrRepository` block (after line 53 `Future<Map<String, dynamic>> getCcProfile();`), add:

```dart
  Future<void> updateCcProfile(Map<String, dynamic> fields);
  Future<void> updateDisplayName(String displayName);
```

Widen the select in `SupabaseWrRepository.getCcProfile()` (around line 333):

```dart
  @override
  Future<Map<String, dynamic>> getCcProfile() async {
    final rows = await _client
        .from('cc_profiles')
        .select(
          'full_name, email, subscription_expires_at, '
          'phone, company_name, position, company_size, '
          'total_work_experience, company_tenure, department',
        )
        .eq('id', _uid)
        .limit(1);
    if (rows.isEmpty) return {};
    return Map<String, dynamic>.from(rows.first);
  }
```

Add implementations at end of `SupabaseWrRepository` (before the closing `}`):

```dart
  @override
  Future<void> updateCcProfile(Map<String, dynamic> fields) async {
    await _client.from('cc_profiles').update(fields).eq('id', _uid);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    await _client.from('wr_mobile_profiles').update({
      'display_name': displayName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', _uid);
  }
```

### Step 4: Add stubs to FakeWrRepository

In `test/support/fake_repository.dart`, add call recorders and implementations:

After `final List<String> saveOnboardingSituationCalls = [];` (line 36), add:
```dart
  final List<Map<String, dynamic>> updateCcProfileCalls = [];
  final List<String> updateDisplayNameCalls = [];
```

After the `seedCcProfile` method (around line 91), the existing `_ccProfile = data` already stores whatever map is seeded — no change needed.

After the `getCcProfile` implementation (around line 211), add:
```dart
  @override
  Future<void> updateCcProfile(Map<String, dynamic> fields) async {
    updateCcProfileCalls.add(Map<String, dynamic>.from(fields));
    _ccProfile = {..._ccProfile, ...fields};
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    updateDisplayNameCalls.add(displayName);
    if (_profile != null) {
      _profile = _profile!.copyWith(displayName: displayName);
    }
  }
```

### Step 5: Run test — expect PASS

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/profile_edit_test.dart -v 2>&1 | tail -20
```
Expected: `+3: All tests passed!`

### Step 6: Run analyze — must be clean

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter analyze 2>&1 | tail -10
```
Expected: `No issues found!`

### Step 7: Commit

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && git add lib/core/data/wr_repository.dart test/support/fake_repository.dart test/features/profile_edit_test.dart && git commit -m "feat(profile-edit): widen getCcProfile select + add updateCcProfile/updateDisplayName to WrRepository"
```

---

## Task 2: l10n strings for profile edit screen

**Files:**
- Modify: `lib/l10n/app_vi.arb`
- Modify: `lib/l10n/app_en.arb`

### Step 1: Add keys to app_vi.arb

Open `lib/l10n/app_vi.arb`. Locate the last line of the profile section (line 369: `"changePasswordErrorSessionExpired": ...`). Insert the following **before** the closing `}` of the file:

```json
  "profileEditTitle": "Chỉnh sửa hồ sơ",
  "profileEditEyebrow": "Thông tin cá nhân",
  "profileEditFieldDisplayName": "Tên hiển thị",
  "profileEditFieldFullName": "Họ và tên",
  "profileEditFieldPhone": "Số điện thoại",
  "profileEditFieldCompanyName": "Tên công ty",
  "profileEditFieldPosition": "Chức danh",
  "profileEditFieldCompanySize": "Quy mô công ty",
  "profileEditFieldExperience": "Thâm niên làm việc",
  "profileEditFieldTenure": "Thời gian tại công ty",
  "profileEditFieldDepartment": "Phòng ban",
  "profileEditSave": "Lưu thay đổi",
  "profileEditSaveSuccess": "Đã cập nhật hồ sơ.",
  "profileEditSaveError": "Không thể lưu. Vui lòng thử lại.",
  "profileEditAvatarNote": "Thay ảnh đại diện trên web tại workreflection.app",
  "profileEditPositionStaff": "Nhân viên",
  "profileEditPositionTeamLead": "Trưởng nhóm",
  "profileEditPositionManager": "Quản lý",
  "profileEditPositionDirector": "Giám đốc",
  "profileEditPositionCLevel": "C-Level",
  "profileEditPositionIntern": "Thực tập sinh",
  "profileEditPositionFreelancer": "Freelancer",
  "profileEditPositionOther": "Khác",
  "profileEditCompanySize1to10": "1–10 người",
  "profileEditCompanySize11to50": "11–50 người",
  "profileEditCompanySize51to200": "51–200 người",
  "profileEditCompanySize201to500": "201–500 người",
  "profileEditCompanySize501to1000": "501–1000 người",
  "profileEditCompanySize1000Plus": "Trên 1000 người",
  "profileEditExpLess1": "Dưới 1 năm",
  "profileEditExp1to3": "1–3 năm",
  "profileEditExp3to5": "3–5 năm",
  "profileEditExp5to10": "5–10 năm",
  "profileEditExp10Plus": "Trên 10 năm",
  "profileEditTenureLess6m": "Dưới 6 tháng",
  "profileEditTenure6mto1y": "6 tháng–1 năm",
  "profileEditTenure1to2": "1–2 năm",
  "profileEditTenure2to5": "2–5 năm",
  "profileEditTenure5Plus": "Trên 5 năm",
  "profileEditDeptMarketing": "Marketing",
  "profileEditDeptAccounting": "Kế toán",
  "profileEditDeptSales": "Kinh doanh",
  "profileEditDeptPurchasing": "Mua hàng",
  "profileEditDeptHr": "Nhân sự",
  "profileEditDeptIt": "IT",
  "profileEditDeptProduction": "Sản xuất",
  "profileEditDeptAdmin": "Hành chính",
  "profileEditDeptOther": "Khác",
  "profileEditSelectHint": "Chọn...",
  "profileEditRowLabel": "Chỉnh sửa hồ sơ"
```

Also add the entry-point label inside the existing `profileEyebrowSettings` section — search for `"profileSettingChangePassword"` and add after it:
```json
  "profileSettingEditProfile": "Chỉnh sửa hồ sơ",
```

### Step 2: Add keys to app_en.arb (same positions)

```json
  "profileEditTitle": "Edit Profile",
  "profileEditEyebrow": "Personal Information",
  "profileEditFieldDisplayName": "Display name",
  "profileEditFieldFullName": "Full name",
  "profileEditFieldPhone": "Phone number",
  "profileEditFieldCompanyName": "Company name",
  "profileEditFieldPosition": "Job title",
  "profileEditFieldCompanySize": "Company size",
  "profileEditFieldExperience": "Work experience",
  "profileEditFieldTenure": "Time at company",
  "profileEditFieldDepartment": "Department",
  "profileEditSave": "Save changes",
  "profileEditSaveSuccess": "Profile updated.",
  "profileEditSaveError": "Could not save. Please try again.",
  "profileEditAvatarNote": "Change your avatar on the web at workreflection.app",
  "profileEditPositionStaff": "Staff",
  "profileEditPositionTeamLead": "Team Lead",
  "profileEditPositionManager": "Manager",
  "profileEditPositionDirector": "Director",
  "profileEditPositionCLevel": "C-Level",
  "profileEditPositionIntern": "Intern",
  "profileEditPositionFreelancer": "Freelancer",
  "profileEditPositionOther": "Other",
  "profileEditCompanySize1to10": "1–10 people",
  "profileEditCompanySize11to50": "11–50 people",
  "profileEditCompanySize51to200": "51–200 people",
  "profileEditCompanySize201to500": "201–500 people",
  "profileEditCompanySize501to1000": "501–1000 people",
  "profileEditCompanySize1000Plus": "1000+ people",
  "profileEditExpLess1": "Under 1 year",
  "profileEditExp1to3": "1–3 years",
  "profileEditExp3to5": "3–5 years",
  "profileEditExp5to10": "5–10 years",
  "profileEditExp10Plus": "10+ years",
  "profileEditTenureLess6m": "Under 6 months",
  "profileEditTenure6mto1y": "6 months–1 year",
  "profileEditTenure1to2": "1–2 years",
  "profileEditTenure2to5": "2–5 years",
  "profileEditTenure5Plus": "5+ years",
  "profileEditDeptMarketing": "Marketing",
  "profileEditDeptAccounting": "Accounting",
  "profileEditDeptSales": "Sales",
  "profileEditDeptPurchasing": "Purchasing",
  "profileEditDeptHr": "HR",
  "profileEditDeptIt": "IT",
  "profileEditDeptProduction": "Production",
  "profileEditDeptAdmin": "Admin",
  "profileEditDeptOther": "Other",
  "profileEditSelectHint": "Select...",
  "profileEditRowLabel": "Edit Profile"
```

After `"profileSettingChangePassword"`, add:
```json
  "profileSettingEditProfile": "Edit Profile",
```

### Step 3: Regenerate l10n

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter gen-l10n 2>&1 | tail -5
```
Expected: exits cleanly (no error). If `flutter gen-l10n` is not available, use `flutter pub get` — it triggers generation via `generate: true` in pubspec.yaml.

### Step 4: Verify generated Dart compiles

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter analyze 2>&1 | tail -10
```
Expected: `No issues found!`

### Step 5: Commit

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && git add lib/l10n/app_vi.arb lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_vi.dart lib/l10n/app_localizations_en.dart && git commit -m "feat(profile-edit): l10n strings VI/EN for profile edit screen"
```

---

## Task 3: ProfileEditNotifier provider + ProfileEditScreen widget

**Files:**
- Modify: `lib/features/profile/profile_providers.dart` (add ProfileEditNotifier)
- Create: `lib/features/profile/presentation/profile_edit_screen.dart`

### Step 1: Write failing widget tests

Add a new `group('ProfileEditScreen', ...)` block to `test/features/profile_edit_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';

// Keep the earlier group from Task 1, add this new group below:

Widget _wrapEdit(Widget child, WrRepository repo) {
  return ProviderScope(
    overrides: [wrRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: child,
    ),
  );
}

Future<void> _pumpEdit(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

FakeWrRepository _seedRepo() {
  final repo = FakeWrRepository();
  repo.seedProfile(MobileProfile(
    userId: 'u1',
    displayName: 'Yumi Trần',
    reminderEnabled: true,
    language: 'vi',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 6, 1),
  ));
  repo.seedCcProfile({
    'full_name': 'Yumi Trần',
    'email': 'yumi@workreflection.app',
    'subscription_expires_at': null,
    'phone': '0901234567',
    'company_name': 'Acme Corp',
    'position': 'manager',
    'company_size': '51_200',
    'total_work_experience': '5_10',
    'company_tenure': '2_5',
    'department': 'hr',
  });
  return repo;
}

group('ProfileEditScreen', () {
  testWidgets('renders all text fields with seeded values', (tester) async {
    final repo = _seedRepo();
    await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

    expect(find.byKey(const Key('profile_edit_display_name')), findsOneWidget);
    expect(find.byKey(const Key('profile_edit_full_name')), findsOneWidget);
    expect(find.byKey(const Key('profile_edit_phone')), findsOneWidget);
    expect(find.byKey(const Key('profile_edit_company_name')), findsOneWidget);
    // Check one pre-filled value
    expect(find.widgetWithText(TextFormField, 'Yumi Trần'), findsWidgets);
  });

  testWidgets('save button calls updateCcProfile and updateDisplayName', (tester) async {
    final repo = _seedRepo();
    await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

    // Clear and re-enter display name
    await tester.enterText(
      find.byKey(const Key('profile_edit_display_name')),
      'New Name',
    );
    // Tap save
    await tester.tap(find.byKey(const Key('profile_edit_save_btn')));
    await tester.pumpAndSettle();

    expect(repo.updateDisplayNameCalls, contains('New Name'));
    expect(repo.updateCcProfileCalls, hasLength(1));
  });

  testWidgets('shows success snackbar after save', (tester) async {
    final repo = _seedRepo();
    await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

    await tester.tap(find.byKey(const Key('profile_edit_save_btn')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đã cập nhật'), findsOneWidget);
  });

  testWidgets('position dropdown shows options', (tester) async {
    final repo = _seedRepo();
    await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

    // Tap the position dropdown
    await tester.tap(find.byKey(const Key('profile_edit_position')));
    await tester.pumpAndSettle();

    // Should see at least one option label
    expect(find.textContaining('Nhân viên'), findsOneWidget);
  });

  testWidgets('avatar section shows initials and deferred note', (tester) async {
    final repo = _seedRepo();
    await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

    expect(find.textContaining('YT'), findsOneWidget);
    expect(find.textContaining('workreflection.app'), findsOneWidget);
  });
});
```

### Step 2: Run — expect FAIL (ProfileEditScreen not found)

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/profile_edit_test.dart --name "ProfileEditScreen" -v 2>&1 | tail -10
```
Expected: compile error — `ProfileEditScreen` not defined.

### Step 3: Add ProfileEditNotifier to profile_providers.dart

In `lib/features/profile/profile_providers.dart`, append at the end:

```dart
// ---------------------------------------------------------------------------
// Profile edit save notifier
// ---------------------------------------------------------------------------

/// Holds the async save state for the edit screen.
/// call [save] with the new field values; it writes to both tables and
/// invalidates the read providers so ProfileScreen refreshes automatically.
class ProfileEditNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save({
    required String displayName,
    required Map<String, dynamic> ccFields,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(wrRepositoryProvider).updateDisplayName(displayName);
      await ref.read(wrRepositoryProvider).updateCcProfile(ccFields);
      ref.invalidate(mobileProfileProvider);
      ref.invalidate(ccProfileProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final profileEditProvider =
    AsyncNotifierProvider<ProfileEditNotifier, void>(ProfileEditNotifier.new);
```

### Step 4: Create ProfileEditScreen

Create `lib/features/profile/presentation/profile_edit_screen.dart`:

```dart
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
          ? const Center(child: CircularProgressIndicator(color: WrColors.coral))
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
```

### Step 5: Run the widget tests — expect PASS

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/profile_edit_test.dart --name "ProfileEditScreen" -v 2>&1 | tail -20
```
Expected: `+5: All tests passed!`

### Step 6: Run full test suite — must stay green

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test -v 2>&1 | tail -20
```
Expected: all existing tests still pass.

### Step 7: Analyze

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter analyze 2>&1 | tail -10
```
Expected: `No issues found!`

### Step 8: Commit

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && git add lib/features/profile/ test/features/profile_edit_test.dart && git commit -m "feat(profile-edit): ProfileEditScreen with text + dropdown fields and save notifier"
```

---

## Task 4: Router + entry point in ProfileScreen

**Files:**
- Modify: `lib/core/router/app_router.dart` (add `/profile/edit` route)
- Modify: `lib/features/profile/presentation/profile_screen.dart` (add edit-profile row to `_SettingsSection`)

### Step 1: Write the failing router test

Add a group to `test/features/profile_edit_test.dart`:

```dart
import 'package:workreflection_mobile/core/router/app_router.dart';

// ... inside main():
group('ProfileScreen entry point', () {
  testWidgets('shows edit-profile row in settings section', (tester) async {
    final repo = FakeWrRepository();
    repo.seedProfile(MobileProfile(
      userId: 'u1',
      displayName: 'Yumi',
      reminderEnabled: true,
      language: 'vi',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 6, 1),
    ));
    repo.seedCcProfile({'full_name': 'Yumi', 'email': 'y@y.com'});

    // Re-use _wrap from profile_test.dart approach — define locally if needed:
    await _pumpEdit(tester, _wrapEdit(
      // Import ProfileScreen
      const _ProfileScreenStub(), // placeholder — see note below
      repo,
    ));
    expect(find.byKey(const Key('profile_edit_profile_btn')), findsOneWidget);
  });
});
```

> **Note:** Rather than importing `ProfileScreen` (which has GoRouter dependency), test the entry-point key directly in the existing `profile_test.dart`. Add the following test there instead:

In `test/features/profile_test.dart`, add to the existing `group('ProfileScreen widget', ...)`:

```dart
testWidgets('shows edit-profile row in settings section', (tester) async {
  final repo = FakeWrRepository();
  repo.seedProfile(_profile());
  repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
  await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

  expect(find.byKey(const Key('profile_edit_profile_btn')), findsOneWidget);
  expect(find.textContaining('Chỉnh sửa hồ sơ'), findsOneWidget);
});
```

### Step 2: Run — expect FAIL

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/profile_test.dart --name "edit-profile row" -v 2>&1 | tail -10
```
Expected: `FAIL` — key not found.

### Step 3: Add GoRoute in app_router.dart

In `lib/core/router/app_router.dart`, add the import:
```dart
import '../../features/profile/presentation/profile_edit_screen.dart';
```

Add the route after the `/my-workshops` route (around line 170):
```dart
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
```

### Step 4: Add the settings row in profile_screen.dart

In `lib/features/profile/presentation/profile_screen.dart`, in `_SettingsSection.build()`, add this row **before** the `// Change password` row (before line 318):

```dart
        // Edit profile
        _SettingRow(
          label: l10n.profileSettingEditProfile,
          trailing: GestureDetector(
            key: const Key('profile_edit_profile_btn'),
            onTap: () => context.push('/profile/edit'),
            child: const Icon(Icons.chevron_right, color: WrColors.muted, size: 16),
          ),
        ),
```

### Step 5: Run the new test — expect PASS

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/profile_test.dart --name "edit-profile row" -v 2>&1 | tail -10
```
Expected: `+1: All tests passed!`

### Step 6: Run full suite

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test -v 2>&1 | tail -20
```
Expected: all green.

### Step 7: Analyze

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter analyze 2>&1 | tail -10
```
Expected: `No issues found!`

### Step 8: Commit

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && git add lib/core/router/app_router.dart lib/features/profile/presentation/profile_screen.dart test/features/profile_test.dart && git commit -m "feat(profile-edit): wire /profile/edit route + entry row in ProfileScreen settings"
```

---

## Task 5: Final gates

### Step 1: Full analyze + full test suite

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter analyze 2>&1 && flutter test -v 2>&1 | tail -30
```
Expected: `No issues found!` and all tests green. **Paste the actual output** — do not report PASS without the real output.

### Step 2: gitnexus detect_changes

Run impact analysis for each symbol modified:
- `gitnexus_impact({target: "getCcProfile", direction: "upstream"})`
- `gitnexus_impact({target: "WrRepository", direction: "upstream"})`
- `gitnexus_detect_changes({scope: "staged"})`

Report the blast radius. If any result is HIGH or CRITICAL, stop and report to the user before continuing.

### Step 3: Debug build check

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter build apk --debug 2>&1 | tail -10
```
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

### Step 4: Re-index GitNexus

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && gitnexus analyze 2>&1 | tail -5
```

### Step 5: Final commit (if anything was left uncommitted)

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && git status
```
If clean, done. If dirty, commit with an appropriate message.

---

## Summary of all files touched

| Action | Path |
|--------|------|
| Modify | `lib/core/data/wr_repository.dart` |
| Modify | `lib/features/profile/profile_providers.dart` |
| Modify | `lib/features/profile/presentation/profile_screen.dart` |
| Create | `lib/features/profile/presentation/profile_edit_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Modify | `lib/l10n/app_vi.arb` |
| Modify | `lib/l10n/app_en.arb` |
| Auto-generated | `lib/l10n/app_localizations.dart` (via flutter gen-l10n) |
| Auto-generated | `lib/l10n/app_localizations_vi.dart` |
| Auto-generated | `lib/l10n/app_localizations_en.dart` |
| Modify | `test/support/fake_repository.dart` |
| Modify | `test/features/profile_test.dart` |
| Create | `test/features/profile_edit_test.dart` |

## Key widget keys (for tests and QA)

| Key | Widget |
|-----|--------|
| `profile_edit_profile_btn` | Entry row GestureDetector in ProfileScreen |
| `profile_edit_display_name` | TextFormField — display name |
| `profile_edit_full_name` | TextFormField — full name |
| `profile_edit_phone` | TextFormField — phone |
| `profile_edit_company_name` | TextFormField — company name |
| `profile_edit_position` | DropdownButton — position |
| `profile_edit_company_size` | DropdownButton — company size |
| `profile_edit_work_experience` | DropdownButton — work experience |
| `profile_edit_tenure` | DropdownButton — company tenure |
| `profile_edit_department` | DropdownButton — department |
| `profile_edit_save_btn` | Save TextButton in AppBar actions |
