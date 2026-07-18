import 'dart:typed_data';

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
  Future<int> countCheckins();

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
  Future<void> updateCcProfile(Map<String, dynamic> fields);
  Future<void> updateDisplayName(String displayName);

  // --- Avatar ---
  /// Upload [bytes] to `avatars/{userId}/avatar.{ext}` with upsert, then
  /// update cc_profiles.avatar_url with the public URL (cache-busted).
  Future<String> uploadAvatar(List<int> bytes, String ext);

  // --- Vouchers ---
  /// Returns active vouchers visible to the current user.
  Future<List<Map<String, dynamic>>> getVouchers();

  // --- Org invitations ---
  /// Returns all invitations matching the user's email, ordered newest first.
  Future<List<Map<String, dynamic>>> getInvitations();

  /// Accept an invitation via the `accept_org_invitation` RPC.
  /// Returns the org_name from the RPC result.
  Future<String> acceptInvitation(String token);

  /// Decline an invitation (set status = 'declined').
  Future<void> declineInvitation(String invitationId);

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

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

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

  @override
  Future<int> countCheckins() async {
    final res = await _client
        .from('wr_checkins')
        .count(CountOption.exact)
        .eq('user_id', _uid);
    return res;
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
    // Try today's VN date first.
    final todayRows = await _client
        .from('wr_practices')
        .select()
        .eq('user_id', _uid)
        .eq('practice_date', _todayVn)
        .order('created_at');
    if (todayRows.isNotEmpty) {
      return todayRows.map(Practice.fromJson).toList();
    }

    // Fallback: find the most recent practice_date and return those rows.
    // This prevents the list from going empty just because a new day started.
    final latestRows = await _client
        .from('wr_practices')
        .select()
        .eq('user_id', _uid)
        .order('practice_date', ascending: false)
        .order('created_at')
        .limit(1);
    if (latestRows.isEmpty) return [];

    final latestDate = latestRows.first['practice_date'] as String;
    final fallbackRows = await _client
        .from('wr_practices')
        .select()
        .eq('user_id', _uid)
        .eq('practice_date', latestDate)
        .order('created_at');
    return fallbackRows.map(Practice.fromJson).toList();
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
        .select(
          'full_name, email, subscription_expires_at, '
          'phone, company_name, position, company_size, '
          'total_work_experience, company_tenure, department, avatar_url',
        )
        .eq('id', _uid)
        .limit(1);
    if (rows.isEmpty) return {};
    return Map<String, dynamic>.from(rows.first);
  }

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

  // --- Avatar ---

  @override
  Future<String> uploadAvatar(List<int> bytes, String ext) async {
    final uid = _uid;
    final filePath = '$uid/avatar.$ext';

    // Remove old files in user's folder first (mirrors web behaviour).
    final existing =
        await _client.storage.from('avatars').list(path: uid);
    if (existing.isNotEmpty) {
      final toRemove = existing.map((f) => '$uid/${f.name}').toList();
      await _client.storage.from('avatars').remove(toRemove);
    }

    // Upload with upsert.
    await _client.storage.from('avatars').uploadBinary(
          filePath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
        );

    // Public URL with cache-bust (mirrors web ?t=Date.now()).
    final urlData =
        _client.storage.from('avatars').getPublicUrl(filePath);
    final publicUrl = '$urlData?t=${DateTime.now().millisecondsSinceEpoch}';

    // Persist to cc_profiles.
    await _client
        .from('cc_profiles')
        .update({'avatar_url': publicUrl}).eq('id', uid);

    return publicUrl;
  }

  // --- Vouchers ---

  @override
  Future<List<Map<String, dynamic>>> getVouchers() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from('cc_vouchers')
        .select('*')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    // Fetch user's org membership to determine if enterprise.
    final orgRows = await _client
        .from('cc_org_members')
        .select('id')
        .eq('user_id', _uid)
        .limit(1);
    final isEnterprise = orgRows.isNotEmpty;

    // Fetch user's role from cc_profiles.
    final profileRows = await _client
        .from('cc_profiles')
        .select('role')
        .eq('id', _uid)
        .limit(1);
    final role = (profileRows.isNotEmpty
            ? profileRows.first['role'] as String?
            : null) ??
        'free';

    final filtered = (rows as List).where((v) {
      final targetType = (v['target_type'] as String?) ?? 'all';
      switch (targetType) {
        case 'all':
          return true;
        case 'individual_free':
          return role == 'free';
        case 'individual_premium':
          return role == 'premium';
        case 'enterprise':
          return role == 'enterprise' || isEnterprise;
        case 'specific_users':
          final assigned = (v['assigned_users'] as List?) ?? [];
          return assigned.contains(user.id);
        default:
          return true;
      }
    }).toList();

    return filtered.map((v) => Map<String, dynamic>.from(v as Map)).toList();
  }

  // --- Org invitations ---

  @override
  Future<List<Map<String, dynamic>>> getInvitations() async {
    final user = _client.auth.currentUser;
    if (user?.email == null) return [];

    final rows = await _client.from('cc_org_invitations').select('''
        id,
        org_id,
        email,
        role,
        department,
        status,
        expires_at,
        created_at,
        token,
        cc_organizations!inner(name)
      ''').eq('email', user!.email!.toLowerCase()).order('created_at',
        ascending: false);

    return (rows as List).map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final org = r['cc_organizations'];
      map['org_name'] =
          (org is Map ? org['name'] : null) as String? ?? '';
      map.remove('cc_organizations');
      return map;
    }).toList();
  }

  @override
  Future<String> acceptInvitation(String token) async {
    final result = await _client
        .rpc('accept_org_invitation', params: {'invitation_token': token});
    final data = result as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to accept invitation');
    }
    return (data['org_name'] as String?) ?? '';
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _client
        .from('cc_org_invitations')
        .update({'status': 'declined'}).eq('id', invitationId);
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

    // Check if a profile row already exists for this user.
    final existing = await _client
        .from('wr_mobile_profiles')
        .select('user_id')
        .eq('user_id', _uid)
        .limit(1);

    if (existing.isEmpty) {
      // First-time insert: populate display_name from Google metadata or email.
      final displayName =
          (user.userMetadata?['display_name'] as String?) ?? user.email ?? '';
      await _client.from('wr_mobile_profiles').insert({
        'user_id': _uid,
        'display_name': displayName,
        if (onboardingSituation != null)
          'onboarding_situation': onboardingSituation,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else if (onboardingSituation != null) {
      // Profile exists — only update fields that don't overwrite user edits.
      await _client.from('wr_mobile_profiles').update({
        'onboarding_situation': onboardingSituation,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', _uid);
    }

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
