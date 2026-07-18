import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/data/wr_repository.dart';
import '../../core/logic/streak.dart';
import '../../core/logic/vn_date.dart';
import '../../core/models/mobile_profile.dart';

// ---------------------------------------------------------------------------
// App locale provider — drives WrApp locale live
// ---------------------------------------------------------------------------

const _kAppLanguage = 'app_language';
const _kSupportedLocales = {'vi', 'en'};

/// Reads the persisted locale from SharedPreferences.
/// Falls back to 'vi' when no value is stored or the value is unsupported.
Future<String> readPersistedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kAppLanguage);
  if (saved != null && _kSupportedLocales.contains(saved)) return saved;
  return 'vi';
}

/// Initialized in main.dart via ProviderScope override with the persisted
/// locale so the correct locale is applied before the first frame.
final appLocaleProvider = StateProvider<String>((ref) => 'vi');

// ---------------------------------------------------------------------------
// Profile data
// ---------------------------------------------------------------------------

final mobileProfileProvider = FutureProvider<MobileProfile?>((ref) async {
  return ref.watch(wrRepositoryProvider).getMobileProfile();
});

final ccProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(wrRepositoryProvider).getCcProfile();
});

final insightCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(wrRepositoryProvider).countInsights();
});

final milestoneCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(wrRepositoryProvider).countMilestones();
});

final streakProvider = FutureProvider<int>((ref) async {
  final dates = await ref.watch(wrRepositoryProvider).getCheckinDates();
  return computeStreak(dates, todayVn());
});

// ---------------------------------------------------------------------------
// Reminder toggle notifier
// ---------------------------------------------------------------------------

class ReminderNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final profile = await ref.watch(mobileProfileProvider.future);
    return profile?.reminderEnabled ?? true;
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? true;
    state = AsyncData(!current);
    try {
      await ref.read(wrRepositoryProvider).updateReminder(!current);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final reminderProvider =
    AsyncNotifierProvider<ReminderNotifier, bool>(ReminderNotifier.new);

// ---------------------------------------------------------------------------
// Profile edit save notifier
// ---------------------------------------------------------------------------

/// Holds the async save state for the edit screen.
/// Call [save] with the new field values; it writes to both tables and
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
