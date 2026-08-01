// Giọng đọc AI cho Thư viện Nội dung Cảm xúc — AusyncLab TTS.
//
// Họp khách 2026-07-29: "vậy thì chọn AI trước đi chị" — giọng đọc AI dựng
// trước, thu giọng thật để sau. Khóa API do khách cung cấp.
//
// ⚠ Quy trình của AusyncLab là BẤT ĐỒNG BỘ. POST chỉ trả về `audio_id`; đường
//   dẫn file đến sau, qua webhook hoặc qua polling. App không có máy chủ để
//   nhận webhook nên ở đây dùng polling — xem [_pollForUrl].
//
// ⚠ Kết quả PHẢI được lưu vào `wr_mood_content.audio_url` sau lần dựng đầu
//   tiên. Gọi TTS mỗi lần có người mở bài là đốt credit của khách và bắt người
//   dùng chờ lại từ đầu, cho cùng một đoạn chữ không đổi.
//
// Tình trạng 2026-07-29: khoá đang ở gói miễn phí, API trả
// "A paid plan is required to use the AusyncLab API". Toàn bộ mã dưới đã dựng
// đúng hợp đồng của API và sẽ chạy ngay khi khách nâng gói — lỗi hiện tại được
// truyền nguyên văn lên UI chứ không nuốt, để không ai phải đoán vì sao im.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Cấu hình — đổi được lúc build, không phải sửa mã
// ---------------------------------------------------------------------------

/// Khoá API AusyncLab.
///
/// Mặc định là khoá khách gửi 2026-07-29 để bản dựng nội bộ chạy được ngay.
/// Bản phát hành nên truyền khoá riêng:
/// `flutter build apk --dart-define=AUSYNCLAB_API_KEY=...`
const String kAusynclabApiKey = String.fromEnvironment(
  'AUSYNCLAB_API_KEY',
  defaultValue:
      'oag4F0Ky3FmjMo7u1LAK5Q_lHY5DpL5IVq2GzkrbPWXM5DXhKc8XoV1tNDn7MVtttmBLWhcZFyytS-s3rfPr-g',
);

/// Giọng đọc dùng cho toàn bộ thư viện.
///
/// Một giọng duy nhất là chủ đích: thư viện chỉ có vài chục bài ngắn, đổi giọng
/// giữa các bài làm người nghe mất cảm giác đang nghe cùng một người.
const int kAusynclabVoiceId =
    int.fromEnvironment('AUSYNCLAB_VOICE_ID', defaultValue: 1000);

const String kAusynclabModel = String.fromEnvironment(
  'AUSYNCLAB_MODEL',
  defaultValue: 'myna-2',
);

const String _base = 'https://api.ausynclab.io/api/v1';

/// Tổng thời gian chờ dựng xong một bản thu trước khi bỏ cuộc.
const Duration kTtsTimeout = Duration(seconds: 90);

/// Khoảng cách giữa hai lần hỏi trạng thái.
const Duration kTtsPollInterval = Duration(seconds: 3);

// ---------------------------------------------------------------------------

/// Lỗi dựng giọng đọc, kèm câu để hiển thị thẳng cho người dùng.
class TtsException implements Exception {
  const TtsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Hợp đồng tối thiểu — test bơm bản giả, không chạm mạng.
abstract class TtsService {
  /// Dựng bản thu cho [text] và trả về đường dẫn file audio.
  ///
  /// Ném [TtsException] khi không dựng được, với câu đã viết sẵn cho người dùng.
  Future<String> synthesize({required String text, required String name});
}

// ---------------------------------------------------------------------------

class AusynclabTtsService implements TtsService {
  AusynclabTtsService({
    http.Client? client,
    this.apiKey = kAusynclabApiKey,
    this.voiceId = kAusynclabVoiceId,
    this.model = kAusynclabModel,
    this.timeout = kTtsTimeout,
    this.pollInterval = kTtsPollInterval,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String apiKey;
  final int voiceId;
  final String model;
  final Duration timeout;
  final Duration pollInterval;

  Map<String, String> get _headers => {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };

  @override
  Future<String> synthesize({
    required String text,
    required String name,
  }) async {
    final audioId = await _requestSynthesis(text: text, name: name);
    return _pollForUrl(audioId);
  }

  /// Đặt hàng dựng bản thu, trả về `audio_id`.
  Future<int> _requestSynthesis({
    required String text,
    required String name,
  }) async {
    late final http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_base/speech/text-to-speech'),
        headers: _headers,
        body: jsonEncode({
          'audio_name': name,
          'text': text,
          'voice_id': voiceId,
          'speed': 1.0,
          'model_name': model,
          'language': 'vi',
        }),
      );
    } catch (_) {
      throw const TtsException('Không kết nối được dịch vụ giọng đọc.');
    }

    if (res.statusCode != 200) {
      throw TtsException(_readableError(res));
    }

    final body = _decode(res);
    final id = (body['result'] as Map?)?['audio_id'];
    if (id is! int) {
      throw const TtsException('Dịch vụ giọng đọc trả về dữ liệu không hợp lệ.');
    }
    return id;
  }

  /// Hỏi trạng thái tới khi có đường dẫn, hoặc tới khi hết [timeout].
  ///
  /// Trạng thái thất bại được nhận ra ngay và dừng vòng lặp: chờ hết 90 giây
  /// cho một bản thu đã hỏng là bắt người dùng nhìn màn hình quay vô ích.
  Future<String> _pollForUrl(int audioId) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      late final http.Response res;
      try {
        res = await _client.get(
          Uri.parse('$_base/speech/$audioId'),
          headers: _headers,
        );
      } catch (_) {
        throw const TtsException('Mất kết nối khi đang dựng bản thu.');
      }

      if (res.statusCode != 200) throw TtsException(_readableError(res));

      final result = _decode(res)['result'];
      if (result is Map) {
        final url = result['audio_url'];
        if (url is String && url.isNotEmpty) return url;

        // API dùng cả 'SUCCEED' (polling) lẫn 'SUCCEEDED' (webhook), nên chỉ
        // bắt các trạng thái hỏng thay vì so bằng trạng thái thành công.
        final state = (result['state'] ?? result['status'])?.toString();
        if (state != null &&
            (state.startsWith('FAIL') || state.startsWith('ERROR'))) {
          throw const TtsException('Dựng bản thu không thành công.');
        }
      }

      await Future<void>.delayed(pollInterval);
    }

    throw const TtsException(
      'Bản thu đang được dựng lâu hơn bình thường. Thử lại sau ít phút.',
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Câu lỗi cho người dùng, ưu tiên `detail` mà AusyncLab trả về.
  ///
  /// Chuyển nguyên văn `detail` lên là có chủ đích: lỗi thật hiện nay là
  /// "A paid plan is required…", và giấu nó sau một câu chung chung sẽ khiến
  /// đội vận hành mất hàng giờ đoán xem hỏng ở đâu.
  String _readableError(http.Response res) {
    final detail = _decode(res)['detail'];
    if (detail is String && detail.isNotEmpty) {
      return 'Giọng đọc AI chưa dùng được: $detail';
    }
    return 'Giọng đọc AI chưa dùng được (mã ${res.statusCode}).';
  }
}

/// Bản dùng thật. Test override bằng một [TtsService] giả.
final ttsServiceProvider = Provider<TtsService>((ref) {
  return AusynclabTtsService();
});
