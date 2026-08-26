import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/wr_career_profile.dart';
import '../logic/wr_display_name.dart';
import '../logic/wr_pricing.dart';
import '../models/checkin.dart';
import '../models/development_theme.dart';
import '../models/insight.dart';
import '../models/mobile_profile.dart';
import '../models/practice.dart';
import '../models/recurring_situation.dart';
import '../models/sca_report.dart';
import '../models/timeline_event.dart';
import '../models/workshop.dart';

/// Những đuôi file người dùng được chọn cho tài liệu bối cảnh.
///
/// JD và CV người Việt gửi nhau phần lớn là file Word, sau đó mới tới PDF và
/// ảnh chụp. `.docx` đọc được từ 04/08 — máy chủ tự bóc chữ trong file, không
/// qua model (`wr-doc-analyze/docx.ts`).
///
/// `.doc` bản cũ thì KHÔNG: nó là định dạng nhị phân đời khác, không phải ZIP,
/// bóc được nó là một việc riêng. Cho chọn rồi báo hỏng còn tệ hơn không cho
/// chọn.
const List<String> kContextDocExtensions = [
  'pdf',
  'docx',
  'png',
  'jpg',
  'jpeg',
  'webp',
];

/// Kiểu MIME theo đuôi file, dùng lúc đẩy lên Storage.
String contextDocMimeType(String ext) => switch (ext.toLowerCase()) {
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class WrRepository {
  // --- Check-ins ---
  Future<Checkin?> getTodayCheckin();
  Future<void> upsertCheckin(
    Mood mood, {
    CheckinEnergy? energy,
    CheckinDirection? direction,
  });
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

  /// Ghi Career Snapshot (vai trò · mục tiêu · trăn trở) vào
  /// `wr_mobile_profiles`. Bước bị bỏ qua được ghi null.
  Future<void> saveCareerSnapshot(CareerSnapshot snapshot);

  /// Ghi lịch sử tình huống đã xem (Hai Lớp v1.6 §4.1).
  ///
  /// Lưu theo Person chứ không theo phiên (§XII.2) — xoay vòng chống lặp chỉ có
  /// nghĩa khi nhớ được qua nhiều ngày. Danh sách đã được cắt còn tối đa 30 mục
  /// ở tầng logic trước khi tới đây.
  Future<void> saveRecentSituationIds(List<String> codes);

  /// Ghi mô tả tự do về vai trò hiện tại (§11.3). Tùy chọn, có thể để trống.
  Future<void> saveRoleText(String? roleText);

  /// Ghi ba trường riêng của app ở màn "Thông tin của bạn".
  ///
  /// Chỉ những khoá có mặt trong [fields] mới bị ghi đè — màn kia sửa mỗi lần
  /// một trường, nên gửi cả ba sẽ xoá mất hai trường người dùng không đụng tới.
  /// Khoá hợp lệ: `city`, `org_industry`, `org_company_type`.
  ///
  /// Bốn trường còn lại của màn đó đi qua [updateCcProfile] vì chúng dùng chung
  /// cột với web.
  Future<void> saveMyInfo(Map<String, String?> fields);

  // --- CC tables (web-app shared) ---
  Future<ScaReport?> getLatestScaReport();
  Future<Workshop?> getUpcomingWorkshop();
  Future<Map<String, dynamic>> getCcProfile();
  Future<void> updateCcProfile(Map<String, dynamic> fields);
  Future<void> updateDisplayName(String displayName);

  /// Các gói Premium **của app**, đọc từ `cc_products` — cùng bảng mà trang
  /// quản trị Gói dịch vụ của web ghi vào, nhưng lấy nhóm
  /// [kPremiumMobileProductType] chứ không lấy dòng `premium` của web: khách
  /// chốt 2026-08-04 hai bên bán hai gói khác giá.
  ///
  /// Trả về theo `display_order` — phần tử đầu là gói chọn sẵn trên Paywall.
  /// Danh sách rỗng nghĩa là không có gói nào đang bật; tầng trên tự quyết định
  /// hiện giá tham khảo hay chặn mua.
  Future<List<WrPremiumPricing>> getPremiumPlans();

  // --- Avatar ---
  /// Upload [bytes] to `avatars/{userId}/avatar.{ext}` with upsert, then
  /// update cc_profiles.avatar_url with the public URL (cache-busted).
  Future<String> uploadAvatar(List<int> bytes, String ext);

  // --- Context documents (JD / CV) ---
  /// Upload [bytes] vào `context-docs/{userId}/{docType}-{timestamp}.{ext}`
  /// và trả về đường dẫn trong bucket để lưu vào
  /// `wr_context_documents.file_path`.
  ///
  /// [ext] quyết định kiểu file lưu trong Storage. Bản trước ghi cứng
  /// `image/$ext` cho mọi thứ, nên một file PDF nằm trong bucket dưới nhãn
  /// `image/pdf` — Edge Function đọc tài liệu phải bỏ qua nhãn đó và tự suy từ
  /// đuôi file.
  Future<String> uploadContextDocument(
    List<int> bytes,
    String ext,
    String docType,
  );

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
  Future<void> upsertCheckin(
    Mood mood, {
    CheckinEnergy? energy,
    CheckinDirection? direction,
  }) async {
    await _client.from('wr_checkins').upsert(
      {
        'user_id': _uid,
        'checkin_date': _todayVn,
        'mood': mood.dbValue,
        if (energy != null) 'energy': energy.dbValue,
        if (direction != null) 'direction': direction.dbValue,
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

  @override
  Future<void> saveCareerSnapshot(CareerSnapshot snapshot) async {
    await _client
        .from('wr_mobile_profiles')
        .update({
          ...snapshot.toUpdate(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', _uid);
  }

  @override
  Future<void> saveRecentSituationIds(List<String> codes) async {
    await _client
        .from('wr_mobile_profiles')
        .update({
          'recent_situation_ids': codes,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', _uid);
  }

  @override
  Future<void> saveRoleText(String? roleText) async {
    final trimmed = roleText?.trim();
    await _client
        .from('wr_mobile_profiles')
        .update({
          // Chuỗi rỗng ghi thành null: "chưa điền" và "điền rồi xoá hết" là
          // cùng một trạng thái, không nên phân biệt ở tầng dữ liệu.
          'role_text': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', _uid);
  }

  /// Ba cột riêng của app. Chỉ khoá nào được truyền vào mới đi vào câu UPDATE —
  /// xem ghi chú ở khai báo trong [WrRepository].
  static const _myInfoColumns = {'city', 'org_industry', 'org_company_type'};

  @override
  Future<void> saveMyInfo(Map<String, String?> fields) async {
    final patch = <String, dynamic>{
      for (final e in fields.entries)
        if (_myInfoColumns.contains(e.key))
          e.key: (e.value == null || e.value!.trim().isEmpty)
              ? null
              : e.value!.trim(),
    };
    // Không có khoá hợp lệ nào thì đừng gửi một UPDATE chỉ đụng `updated_at`:
    // nó làm hàng "vừa được sửa" trong khi thật ra không có gì đổi.
    if (patch.isEmpty) return;
    patch['updated_at'] = DateTime.now().toIso8601String();
    await _client
        .from('wr_mobile_profiles')
        .update(patch)
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
          // `role` quyết định Premium: khách chốt 2026-08-01 rằng Premium web
          // và app là một, và trang quản trị của web cấp Premium bằng cột này.
          'full_name, email, role, subscription_expires_at, '
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
  Future<List<WrPremiumPricing>> getPremiumPlans() async {
    // Cùng dạng truy vấn với web (`useProductPrice`) — gói đang bật, xếp theo
    // display_order, không lọc theo user vì bảng giá là chung. Khác web ở hai
    // chỗ: product_type riêng của app, và KHÔNG `.limit(1)` vì app bán nhiều
    // gói (năm / tháng) cùng lúc.
    final rows = await _client
        .from('cc_products')
        .select(
          'id, name, description, product_type, current_price, original_price, '
          'currency, duration_days',
        )
        .eq('product_type', kPremiumMobileProductType)
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return rows
        .map((r) => WrPremiumPricing.fromJson(Map<String, dynamic>.from(r)))
        .toList();
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
  Future<String> uploadContextDocument(
    List<int> bytes,
    String ext,
    String docType,
  ) async {
    final uid = _uid;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeExt = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final filePath = '$uid/$docType-$stamp.$safeExt';
    await _client.storage.from('context-docs').uploadBinary(
          filePath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            upsert: true,
            contentType: contextDocMimeType(safeExt),
          ),
        );
    return filePath;
  }

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
      // Tên lấy từ metadata tài khoản — KHÔNG bao giờ lấy email.
      //
      // Bản trước là `userMetadata['display_name'] ?? user.email ?? ''`, tức là
      // không đọc được tên thì ghi thẳng email vào ô tên. Hai hệ quả:
      //   • Đăng nhập bằng Google rơi đúng vào nhánh đó (Google trả `name` /
      //     `full_name`, không trả `display_name`), nên người dùng Google bị
      //     app chào bằng email — chính điều khách báo ở họp 26_1.
      //   • Email nằm trong DB rồi thì mọi màn đọc ô tên đều sai theo, và không
      //     màn nào có cách nào biết đó không phải tên thật.
      //
      // Nay: không có tên thì để trống, và màn hình nói "bạn". Đọc cả ba khoá
      // vì ba nguồn đăng nhập ghi ba khoá khác nhau.
      final displayName = wrGreetingName(userMetadata: user.userMetadata);
      await _client.from('wr_mobile_profiles').insert({
        'user_id': _uid,
        if (displayName != null) 'display_name': displayName,
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

    // KHÔNG gọi `seed_wr_sample_data` nữa.
    //
    // Changelog 24/08/2026 §7, ghi chú cho dev: "Dữ liệu demo … hiện đang được
    // seed sẵn để xem trước màn hình — cần loại bỏ seed này khi triển khai
    // thật, để mỗi user bắt đầu từ trạng thái rỗng."
    //
    // Hàm RPC đó chèn chủ đề phát triển, bước thực hành, tình huống lặp lại và
    // insight BỊA cho mọi tài khoản thật ngay lần đầu đăng nhập. Hệ quả nặng
    // hơn một màn xem trước sai: từ hôm nay màn Diễn giải sâu (§7) đối chiếu
    // điểm Self-Check với tần suất Reflection, và Career Memory (§8) sinh Cột
    // mốc · Chủ đề · Insight từ chính lịch sử đó — dữ liệu bịa sẽ chảy thẳng
    // vào những kết luận app nói với người dùng về đời họ.
    //
    // Chỉ gỡ ở phía app, không đụng vào hàm trong DB: backend này dùng chung
    // với bản web, và việc bên đó còn cần hàm hay không không phải chuyện của
    // app di động.
  }

  @override
  Future<void> saveOnboardingSituation(String situation) async {
    await _client.from('wr_mobile_profiles').update({
      'onboarding_situation': situation,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', _uid);
  }
}
