import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/data/wr_episode_repository.dart';
import '../../core/data/wr_repository.dart';
import '../../core/logic/checkin_history.dart';
import '../../core/logic/streak.dart';
import '../../core/logic/vn_date.dart';
import '../../core/logic/wr_my_info.dart';
import '../../core/models/mobile_profile.dart';
import '../../l10n/app_localizations.dart';
import '../wr/wr_providers.dart';

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

/// Số ngày người dùng đã nhìn lại — con số ở màn Hồ sơ (yêu cầu 05/08).
///
/// Đọc TOÀN BỘ Episode, không đặt `limit`: đây là một phép đếm tích luỹ, cắt
/// bớt là báo một con số thấp hơn sự thật cho đúng những người dùng lâu năm
/// nhất. [wrEpisodeHistoryProvider] có giới hạn 50 nên không dùng lại được.
final reflectionDayCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  try {
    final episodes = await ref.watch(wrEpisodeRepositoryProvider).fetchEpisodes(
          userId,
        );
    return reflectionDayCount(episodes);
  } catch (_) {
    return 0;
  }
});

/// 30-element list: index 0 = today−29, index 29 = today.
/// true = checked in that day.
final checkinHistoryProvider = FutureProvider<List<bool>>((ref) async {
  final dates =
      await ref.watch(wrRepositoryProvider).getCheckinDates(limit: 30);
  return buildCheckinHistory(checkinDates: dates, today: DateTime.now());
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

// ---------------------------------------------------------------------------
// "Thông tin của bạn" — mockup Sprint 2 bản (4)
// ---------------------------------------------------------------------------

/// Ghi MỘT trường của màn "Thông tin của bạn".
///
/// Trường đi về đúng bảng nó vốn thuộc về ([MyInfoField.store]) chứ không gom
/// hết vào một chỗ — xem ghi chú ở `wr_my_info.dart`.
class MyInfoSaveNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save(MyInfoField field, String value) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(wrRepositoryProvider);
      switch (field.store) {
        case MyInfoStore.ccProfile:
          await repo.updateCcProfile({field.column: value});
          ref.invalidate(ccProfileProvider);
        case MyInfoStore.mobileProfile:
          // Chỉ gửi đúng một khoá: `saveMyInfo` ghi đè mọi khoá nó nhận được,
          // nên gửi cả ba sẽ xoá hai trường người dùng không đụng tới.
          await repo.saveMyInfo({field.column: value});
          ref.invalidate(mobileProfileProvider);
      }
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final myInfoSaveProvider =
    AsyncNotifierProvider<MyInfoSaveNotifier, void>(MyInfoSaveNotifier.new);

/// Người dùng đã bấm "Bỏ qua" ở thẻ nhắc điền hồ sơ trên màn Hôm nay.
///
/// Nhớ ở MÁY chứ không ghi lên máy chủ: đây là một cử chỉ giao diện ("đừng hỏi
/// nữa"), không phải một sự thật về người dùng. Ghi lên bảng hồ sơ thì nó thành
/// một cột dữ liệu vô nghĩa mà web cũng phải hiểu.
class ProfileNudgeDismissedNotifier extends StateNotifier<bool> {
  ProfileNudgeDismissedNotifier() : super(false) {
    _load();
  }

  static const String _key = 'wr_profile_nudge_dismissed';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (_) {
      /* đọc không được thì cứ hiện — thà hỏi thừa còn hơn giấu mất lối vào */
    }
  }

  Future<void> dismiss() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      /* best-effort: ẩn được trong phiên này, mở lại app thì hiện lại */
    }
  }
}

final profileNudgeDismissedProvider =
    StateNotifierProvider<ProfileNudgeDismissedNotifier, bool>(
  (ref) => ProfileNudgeDismissedNotifier(),
);

/// Số trường đã điền / tổng số, cho dòng "n/7" ở màn Hồ sơ.
///
/// Đọc từ CẢ hai bảng, vì bảy trường đó nằm ở hai nơi. Đây cũng là con số quyết
/// định thẻ nhắc ở màn Hôm nay có hiện hay không.
final myInfoStatusProvider =
    Provider.family<({int filled, int total}), AppLocalizations>((ref, l10n) {
  final fields = myInfoFields(l10n);
  final cc = ref.watch(ccProfileProvider).valueOrNull ?? const {};
  final profile = ref.watch(mobileProfileProvider).valueOrNull;

  String? read(MyInfoField f) => switch (f.store) {
    MyInfoStore.ccProfile => cc[f.column] as String?,
    MyInfoStore.mobileProfile => switch (f.column) {
      'city' => profile?.city,
      'org_industry' => profile?.orgIndustry,
      'org_company_type' => profile?.orgCompanyType,
      _ => null,
    },
  };

  return (filled: myInfoFilledCount(fields, read), total: fields.length);
});
