import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/checkin.dart';
import '../models/development_theme.dart';
import '../models/insight.dart';
import '../models/mobile_profile.dart';
import '../models/practice.dart';
import '../models/recurring_situation.dart';
import '../models/sca_report.dart';
import '../models/timeline_event.dart';
import '../models/workshop.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class WrRepository {
  // --- Check-ins ---
  Future<Checkin?> getTodayCheckin();
  Future<void> upsertCheckin(Mood mood);
  Future<List<DateTime>> getCheckinDates({int limit = 60});

  // --- Insights ---
  Future<Insight?> getLatestInsight();
  Future<List<Insight>> getInsights();
  Future<int> countInsights();

  // --- Recurring situations ---
  Future<List<RecurringSituation>> getRecurringSituations();

  // --- Development themes ---
  Future<DevelopmentTheme?> getActiveTheme();

  // --- Practices ---
  Future<List<Practice>> getTodayPractices();
  Future<void> updatePracticeStatus(String id, PracticeStatus status);

  // --- Timeline ---
  Future<List<TimelineEvent>> getTimelineEvents();
  Future<int> countMilestones();

  // --- Mobile profile ---
  Future<MobileProfile?> getMobileProfile();
  Future<void> updateReminder(bool enabled);
  Future<void> updateLanguage(String lang);

  // --- CC tables (web-app shared) ---
  Future<ScaReport?> getLatestScaReport();
  Future<Workshop?> getUpcomingWorkshop();
  Future<Map<String, dynamic>> getCcProfile();

  // --- Export ---
  Future<Map<String, dynamic>> exportUserData();

  // --- Seed / onboarding ---
  /// Ensures the user's wr_mobile_profiles row exists and seeds sample data
  /// the first time. [onboardingSituation] is persisted to the profile.
  Future<void> ensureSeeded({String? onboardingSituation});
  Future<void> saveOnboardingSituation(String situation);
}

// ---------------------------------------------------------------------------
// Riverpod provider (overridable in tests)
// ---------------------------------------------------------------------------

final wrRepositoryProvider = Provider<WrRepository>((ref) {
  return SupabaseWrRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Live Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseWrRepository implements WrRepository {
  const SupabaseWrRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  /// Today's date in Asia/Ho_Chi_Minh as yyyy-MM-dd.
  String get _todayVn {
    final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateFormat('yyyy-MM-dd').format(vnNow);
  }

  // --- Check-ins ---

  @override
  Future<Checkin?> getTodayCheckin() async {
    final rows = await _client
        .from('wr_checkins')
        .select()
        .eq('user_id', _uid)
        .eq('checkin_date', _todayVn)
        .limit(1);
    if (rows.isEmpty) return null;
    return Checkin.fromJson(rows.first);
  }

  @override
  Future<void> upsertCheckin(Mood mood) async {
    await _client.from('wr_checkins').upsert(
      {
        'user_id': _uid,
        'checkin_date': _todayVn,
        'mood': mood.dbValue,
      },
      onConflict: 'user_id,checkin_date',
    );
  }

  @override
  Future<List<DateTime>> getCheckinDates({int limit = 60}) async {
    final rows = await _client
        .from('wr_checkins')
        .select('checkin_date')
        .eq('user_id', _uid)
        .order('checkin_date', ascending: false)
        .limit(limit);
    return rows.map((r) => DateTime.parse(r['checkin_date'] as String)).toList();
  }

  // --- Insights ---

  @override
  Future<Insight?> getLatestInsight() async {
    final rows = await _client
        .from('wr_insights')
        .select()
        .eq('user_id', _uid)
        .order('saved_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Insight.fromJson(rows.first);
  }

  @override
  Future<List<Insight>> getInsights() async {
    final rows = await _client
        .from('wr_insights')
        .select()
        .eq('user_id', _uid)
        .order('saved_at', ascending: false);
    return rows.map(Insight.fromJson).toList();
  }

  @override
  Future<int> countInsights() async {
    final res = await _client
        .from('wr_insights')
        .select()
        .eq('user_id', _uid)
        .count();
    return res.count;
  }

  // --- Recurring situations ---

  @override
  Future<List<RecurringSituation>> getRecurringSituations() async {
    final rows = await _client
        .from('wr_recurring_situations')
        .select()
        .eq('user_id', _uid)
        .order('occurrence_count', ascending: false);
    return rows.map(RecurringSituation.fromJson).toList();
  }

  // --- Development themes ---

  @override
  Future<DevelopmentTheme?> getActiveTheme() async {
    final rows = await _client
        .from('wr_development_themes')
        .select()
        .eq('user_id', _uid)
        .eq('is_active', true)
        .limit(1);
    if (rows.isEmpty) return null;
    return DevelopmentTheme.fromJson(rows.first);
  }

  // --- Practices ---

  @override
  Future<List<Practice>> getTodayPractices() async {
    final rows = await _client
        .from('wr_practices')
        .select()
        .eq('user_id', _uid)
        .eq('practice_date', _todayVn)
        .order('created_at');
    return rows.map(Practice.fromJson).toList();
  }

  @override
  Future<void> updatePracticeStatus(String id, PracticeStatus status) async {
    await _client.from('wr_practices').update({
      'status': status.dbValue,
      if (status == PracticeStatus.done)
        'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', _uid);
  }

  // --- Timeline ---

  @override
  Future<List<TimelineEvent>> getTimelineEvents() async {
    final rows = await _client
        .from('wr_timeline_events')
        .select()
        .eq('user_id', _uid)
        .order('occurred_at', ascending: false);
    return rows.map(TimelineEvent.fromJson).toList();
  }

  @override
  Future<int> countMilestones() async {
    final res = await _client
        .from('wr_timeline_events')
        .select()
        .eq('user_id', _uid)
        .eq('event_type', TimelineEventType.milestone.dbValue)
        .count();
    return res.count;
  }

  // --- Mobile profile ---

  @override
  Future<MobileProfile?> getMobileProfile() async {
    final rows = await _client
        .from('wr_mobile_profiles')
        .select()
        .eq('user_id', _uid)
        .limit(1);
    if (rows.isEmpty) return null;
    return MobileProfile.fromJson(rows.first);
  }

  @override
  Future<void> updateReminder(bool enabled) async {
    await _client
        .from('wr_mobile_profiles')
        .update({
          'reminder_enabled': enabled,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', _uid);
  }

  @override
  Future<void> updateLanguage(String lang) async {
    await _client
        .from('wr_mobile_profiles')
        .update({
          'language': lang,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', _uid);
  }

  // --- CC tables ---

  @override
  Future<ScaReport?> getLatestScaReport() async {
    final rows = await _client
        .from('cc_reports')
        .select('id, user_id, score_structure, score_culture, score_activity, created_at')
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return ScaReport.fromJson(rows.first);
  }

  @override
  Future<Workshop?> getUpcomingWorkshop() async {
    final rows = await _client
        .from('cc_workshops')
        .select('id, title, category, date, starts_at')
        .eq('is_active', true)
        .gte('date', _todayVn)
        .order('date')
        .limit(1);
    if (rows.isEmpty) return null;
    return Workshop.fromJson(rows.first);
  }

  @override
  Future<Map<String, dynamic>> getCcProfile() async {
    final rows = await _client
        .from('cc_profiles')
        .select('full_name, email, subscription_expires_at')
        .eq('id', _uid)
        .limit(1);
    if (rows.isEmpty) return {};
    return Map<String, dynamic>.from(rows.first);
  }

  // --- Export ---

  @override
  Future<Map<String, dynamic>> exportUserData() async {
    final results = await Future.wait([
      _client.from('wr_checkins').select().eq('user_id', _uid),
      _client.from('wr_insights').select().eq('user_id', _uid),
      _client.from('wr_recurring_situations').select().eq('user_id', _uid),
      _client.from('wr_development_themes').select().eq('user_id', _uid),
      _client.from('wr_practices').select().eq('user_id', _uid),
      _client.from('wr_timeline_events').select().eq('user_id', _uid),
      _client.from('wr_mobile_profiles').select().eq('user_id', _uid),
    ]);
    return {
      'checkins': results[0],
      'insights': results[1],
      'recurring_situations': results[2],
      'development_themes': results[3],
      'practices': results[4],
      'timeline_events': results[5],
      'mobile_profile': results[6],
    };
  }

  // --- Seed / onboarding ---

  @override
  Future<void> ensureSeeded({String? onboardingSituation}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final displayName =
        (user.userMetadata?['display_name'] as String?) ?? user.email ?? '';

    await _client.from('wr_mobile_profiles').upsert(
      {
        'user_id': _uid,
        'display_name': displayName,
        if (onboardingSituation != null)
          'onboarding_situation': onboardingSituation,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id',
    );

    // Idempotent — seed function checks internally and returns early if
    // sample data already exists for this user.
    await _client.rpc('seed_wr_sample_data');
  }

  @override
  Future<void> saveOnboardingSituation(String situation) async {
    await _client.from('wr_mobile_profiles').update({
      'onboarding_situation': situation,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', _uid);
  }
}
