import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/development_theme.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/practice.dart';
import 'package:workreflection_mobile/core/models/recurring_situation.dart';
import 'package:workreflection_mobile/core/models/sca_report.dart';
import 'package:workreflection_mobile/core/models/timeline_event.dart';
import 'package:workreflection_mobile/core/models/workshop.dart';

/// In-memory fake repository for use in widget/unit tests.
///
/// Pre-populate via the `seed*` methods before pumping widgets.
/// Inspect recorded calls via the `*Calls` fields.
class FakeWrRepository implements WrRepository {
  // --- Internal state ---
  Checkin? _todayCheckin;
  final List<DateTime> _checkinDates = [];
  final List<Insight> _insights = [];
  final List<RecurringSituation> _situations = [];
  final List<Practice> _practices = [];
  final List<TimelineEvent> _timelineEvents = [];
  DevelopmentTheme? _activeTheme;
  MobileProfile? _profile;
  ScaReport? _scaReport;
  Workshop? _workshop;
  Map<String, dynamic> _ccProfile = {};

  // --- Call recorders ---
  final List<Mood> upsertCheckinCalls = [];
  final List<(String, PracticeStatus)> updatePracticeStatusCalls = [];
  final List<bool> updateReminderCalls = [];
  final List<String> updateLanguageCalls = [];
  final List<String?> ensureSeededCalls = [];
  final List<String> saveOnboardingSituationCalls = [];
  final List<Map<String, dynamic>> updateCcProfileCalls = [];
  final List<String> updateDisplayNameCalls = [];

  // --- Seed helpers ---

  void seedCheckinDates(List<DateTime> dates) {
    _checkinDates
      ..clear()
      ..addAll(dates);
  }

  void seedInsights(List<Insight> insights) {
    _insights
      ..clear()
      ..addAll(insights);
    // Sort descending by savedAt so getLatestInsight works correctly.
    _insights.sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  void seedPractices(List<Practice> practices) {
    _practices
      ..clear()
      ..addAll(practices);
  }

  void seedSituations(List<RecurringSituation> situations) {
    _situations
      ..clear()
      ..addAll(situations);
  }

  void seedTimelineEvents(List<TimelineEvent> events) {
    _timelineEvents
      ..clear()
      ..addAll(events);
  }

  void seedActiveTheme(DevelopmentTheme theme) {
    _activeTheme = theme;
  }

  void seedProfile(MobileProfile profile) {
    _profile = profile;
  }

  void seedScaReport(ScaReport report) {
    _scaReport = report;
  }

  void seedWorkshop(Workshop workshop) {
    _workshop = workshop;
  }

  void seedCcProfile(Map<String, dynamic> data) {
    _ccProfile = data;
  }

  // --- WrRepository impl ---

  @override
  Future<Checkin?> getTodayCheckin() async => _todayCheckin;

  @override
  Future<void> upsertCheckin(Mood mood) async {
    upsertCheckinCalls.add(mood);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _todayCheckin = Checkin(
      id: 'fake-checkin',
      userId: 'fake-user',
      mood: mood,
      checkinDate: today,
      createdAt: now,
    );
    // Add to dates if not already present for today.
    if (!_checkinDates.any(
      (d) => d.year == today.year && d.month == today.month && d.day == today.day,
    )) {
      _checkinDates.add(today);
    }
  }

  @override
  Future<List<DateTime>> getCheckinDates({int limit = 60}) async {
    return _checkinDates.take(limit).toList();
  }

  @override
  Future<int> countCheckins() async => _checkinDates.length;

  @override
  Future<Insight?> getLatestInsight() async {
    if (_insights.isEmpty) return null;
    return _insights.first; // already sorted desc
  }

  @override
  Future<List<Insight>> getInsights() async => List.unmodifiable(_insights);

  @override
  Future<int> countInsights() async => _insights.length;

  @override
  Future<List<RecurringSituation>> getRecurringSituations() async =>
      List.unmodifiable(_situations);

  @override
  Future<DevelopmentTheme?> getActiveTheme() async => _activeTheme;

  @override
  Future<List<Practice>> getTodayPractices() async {
    if (_practices.isEmpty) return const [];
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    // Filter for today's practices first.
    final todayPractices = _practices.where((p) {
      final d = p.practiceDate;
      return DateTime(d.year, d.month, d.day) == todayDate;
    }).toList();
    if (todayPractices.isNotEmpty) return List.unmodifiable(todayPractices);
    // Fallback: return practices from the most recent practice_date.
    final latestDate = _practices
        .map((p) => DateTime(p.practiceDate.year, p.practiceDate.month, p.practiceDate.day))
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return List.unmodifiable(_practices.where((p) {
      final d = p.practiceDate;
      return DateTime(d.year, d.month, d.day) == latestDate;
    }).toList());
  }

  @override
  Future<void> updatePracticeStatus(String id, PracticeStatus status) async {
    updatePracticeStatusCalls.add((id, status));
    final idx = _practices.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _practices[idx] = _practices[idx].copyWith(
        status: status,
        completedAt: status == PracticeStatus.done ? DateTime.now() : null,
      );
    }
  }

  @override
  Future<List<TimelineEvent>> getTimelineEvents() async =>
      List.unmodifiable(_timelineEvents);

  @override
  Future<int> countMilestones() async =>
      _timelineEvents.where((e) => e.eventType == TimelineEventType.milestone).length;

  @override
  Future<MobileProfile?> getMobileProfile() async => _profile;

  @override
  Future<void> updateReminder(bool enabled) async {
    updateReminderCalls.add(enabled);
    if (_profile != null) {
      _profile = _profile!.copyWith(reminderEnabled: enabled);
    }
  }

  @override
  Future<void> updateLanguage(String lang) async {
    updateLanguageCalls.add(lang);
    if (_profile != null) {
      _profile = _profile!.copyWith(language: lang);
    }
  }

  @override
  Future<ScaReport?> getLatestScaReport() async => _scaReport;

  @override
  Future<Workshop?> getUpcomingWorkshop() async => _workshop;

  @override
  Future<Map<String, dynamic>> getCcProfile() async =>
      Map<String, dynamic>.from(_ccProfile);

  @override
  Future<Map<String, dynamic>> exportUserData() async {
    return {
      'checkins': _checkinDates.map((d) => d.toIso8601String()).toList(),
      'insights': _insights.map((i) => i.content).toList(),
      'recurring_situations': _situations.map((s) => s.label).toList(),
      'development_themes': _activeTheme != null ? [_activeTheme!.code] : [],
      'practices': _practices.map((p) => p.title).toList(),
      'timeline_events': _timelineEvents.map((e) => e.title).toList(),
      'mobile_profile': _profile != null ? {'user_id': _profile!.userId} : null,
    };
  }

  @override
  Future<void> ensureSeeded({String? onboardingSituation}) async {
    ensureSeededCalls.add(onboardingSituation);
    // Mirror the production contract: only set display_name on first insert
    // (when profile is absent). Never clobber user-edited display_name.
    if (_profile == null) {
      _profile = MobileProfile(
        userId: 'fake-user',
        displayName: 'seeded-name',
        onboardingSituation: onboardingSituation,
        reminderEnabled: true,
        language: 'vi',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else if (onboardingSituation != null) {
      _profile = _profile!.copyWith(onboardingSituation: onboardingSituation);
    }
  }

  @override
  Future<void> saveOnboardingSituation(String situation) async {
    saveOnboardingSituationCalls.add(situation);
  }

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
}
