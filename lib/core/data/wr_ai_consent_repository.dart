// Đọc và ghi sự đồng ý cho phép gửi dữ liệu sang dịch vụ AI bên thứ ba.
//
// Bảng `wr_ai_consent` (migration `20260907010000_wr_ai_consent.sql`). Đây là
// một trong số ít bảng mà client ĐƯỢC ghi: nó lưu lựa chọn của chính người dùng
// về chính dữ liệu của họ, không phải một thứ quyền lợi có thể tự cấp.
//
// Máy chủ cũng kiểm lại trước khi gọi OpenRouter — xem `wr-chat`,
// `wr-doc-analyze`, `wr-narrative`. Repository này chỉ để app biết có cần hỏi
// hay không, chứ không phải chốt chặn duy nhất.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/wr_ai_disclosure.dart';

/// Lựa chọn của người dùng về việc gửi dữ liệu sang AI.
class WrAiConsent {
  const WrAiConsent({
    required this.version,
    this.grantedAt,
    this.revokedAt,
  });

  /// Phiên bản bản công bố người dùng đã đọc lúc bấm đồng ý.
  final int version;

  final DateTime? grantedAt;
  final DateTime? revokedAt;

  /// Chưa từng trả lời — app phải hỏi.
  static const WrAiConsent unknown = WrAiConsent(version: 0);

  /// True khi đang cho phép, xét theo ĐÚNG bản công bố hiện hành.
  ///
  /// Ba điều kiện, thiếu điều nào cũng là chưa cho phép:
  ///   • Đã từng bấm đồng ý.
  ///   • Chưa rút lại sau lần đồng ý đó. So mốc chứ không chỉ xem `revokedAt`
  ///     có giá trị hay không — người dùng tắt rồi bật lại thì cả hai mốc đều
  ///     có, và mốc đồng ý mới hơn.
  ///   • Bản công bố đã đọc không cũ hơn bản hiện hành. Thêm một bên nhận dữ
  ///     liệu mà vẫn dùng lời đồng ý cũ là xin phép cho việc A rồi làm việc B.
  bool get isGranted {
    final granted = grantedAt;
    if (granted == null) return false;
    if (version < kWrAiDisclosureVersion) return false;
    final revoked = revokedAt;
    if (revoked != null && !revoked.isBefore(granted)) return false;
    return true;
  }

  /// Đã từng trả lời (dù đồng ý hay từ chối).
  ///
  /// Khác [isGranted]: người đã chủ động TỪ CHỐI thì không được hỏi lại mỗi lần
  /// mở màn — hỏi tới hỏi lui cho tới khi người ta bấm bừa là ép buộc, không
  /// phải xin phép.
  bool get hasAnswered => grantedAt != null || revokedAt != null;

  factory WrAiConsent.fromJson(Map<String, dynamic> json) {
    return WrAiConsent(
      version: (json['version'] as num?)?.toInt() ?? 0,
      grantedAt: json['granted_at'] == null
          ? null
          : DateTime.tryParse(json['granted_at'].toString()),
      revokedAt: json['revoked_at'] == null
          ? null
          : DateTime.tryParse(json['revoked_at'].toString()),
    );
  }
}

abstract class WrAiConsentRepository {
  /// Lựa chọn hiện tại. Trả [WrAiConsent.unknown] khi chưa có hàng nào.
  Future<WrAiConsent> fetch();

  /// Ghi nhận đồng ý cho bản công bố [kWrAiDisclosureVersion].
  Future<void> grant();

  /// Rút lại.
  Future<void> revoke();
}

class SupabaseAiConsentRepository implements WrAiConsentRepository {
  SupabaseAiConsentRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<WrAiConsent> fetch() async {
    final uid = _uid;
    if (uid == null) return WrAiConsent.unknown;
    final row = await _client
        .from('wr_ai_consent')
        .select('version, granted_at, revoked_at')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return WrAiConsent.unknown;
    return WrAiConsent.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> grant() async {
    final uid = _uid;
    if (uid == null) throw StateError('not authenticated');
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('wr_ai_consent').upsert({
      'user_id': uid,
      'version': kWrAiDisclosureVersion,
      'granted_at': now,
      // Xoá mốc rút lại của lần trước. Để nguyên thì [WrAiConsent.isGranted] so
      // hai mốc vẫn ra đúng, nhưng một hàng mang cả hai mốc cùng lúc đọc rất
      // khó hiểu khi tra cứu về sau.
      'revoked_at': null,
      'updated_at': now,
    }, onConflict: 'user_id');
  }

  @override
  Future<void> revoke() async {
    final uid = _uid;
    if (uid == null) throw StateError('not authenticated');
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('wr_ai_consent').upsert({
      'user_id': uid,
      'version': kWrAiDisclosureVersion,
      'revoked_at': now,
      'updated_at': now,
    }, onConflict: 'user_id');
  }
}

final wrAiConsentRepositoryProvider = Provider<WrAiConsentRepository>((ref) {
  return SupabaseAiConsentRepository(Supabase.instance.client);
});
