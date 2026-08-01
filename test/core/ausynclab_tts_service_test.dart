// AusyncLab TTS — hợp đồng bất đồng bộ POST → poll.
//
// Test bằng http.Client giả, không chạm mạng. Điều đang được giữ ở đây là ba
// chỗ dễ làm sai nhất khi nối một API kiểu này:
//   • đường dẫn audio KHÔNG có trong phản hồi POST, phải poll mới ra
//   • trạng thái thất bại phải dừng vòng lặp ngay, không chờ hết timeout
//   • lỗi của dịch vụ phải lên tới người dùng nguyên văn, không bị nuốt

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:workreflection_mobile/core/data/ausynclab_tts_service.dart';

/// Client giả: trả lần lượt các phản hồi đã dựng sẵn theo phương thức.
class _FakeClient extends http.BaseClient {
  _FakeClient({required this.postResponse, required this.getResponses});

  final http.Response postResponse;
  final List<http.Response> getResponses;

  final List<String> calls = [];
  int _getIndex = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls.add('${request.method} ${request.url.path}');
    final res = request.method == 'POST'
        ? postResponse
        : getResponses[_getIndex++ < getResponses.length
            ? _getIndex - 1
            : getResponses.length - 1];
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}

http.Response _json(Object body, {int status = 200}) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

AusynclabTtsService _service(_FakeClient client) => AusynclabTtsService(
      client: client,
      apiKey: 'k',
      // Poll nhanh để test không phải chờ thật.
      pollInterval: Duration.zero,
      timeout: const Duration(milliseconds: 300),
    );

void main() {
  test('POST rồi poll tới khi có audio_url', () async {
    final client = _FakeClient(
      postResponse: _json({
        'status': 200,
        'result': {'audio_id': 42},
      }),
      getResponses: [
        // Lần đầu chưa xong: chưa có audio_url, state còn đang chạy.
        _json({
          'status': 200,
          'result': {'id': 42, 'state': 'IN_PROGRESS'},
        }),
        _json({
          'status': 200,
          'result': {
            'id': 42,
            'state': 'SUCCEED',
            'audio_url': 'https://cdn.test/a.wav',
          },
        }),
      ],
    );

    final url = await _service(client).synthesize(text: 'xin chào', name: 'a');

    expect(url, 'https://cdn.test/a.wav');
    expect(client.calls.first, 'POST /api/v1/speech/text-to-speech');
    expect(client.calls.where((c) => c.startsWith('GET')), hasLength(2));
  });

  test('lỗi gói dịch vụ lên tới người dùng nguyên văn', () async {
    // Đây đúng là phản hồi thật của khoá khách gửi ngày 2026-07-29. Giấu nó sau
    // một câu chung chung là bắt người khác đi dò lại từ đầu.
    final client = _FakeClient(
      postResponse: _json(
        {'detail': 'A paid plan is required to use the AusyncLab API.'},
        status: 403,
      ),
      getResponses: const [],
    );

    expect(
      () => _service(client).synthesize(text: 't', name: 'n'),
      throwsA(isA<TtsException>().having(
        (e) => e.message,
        'message',
        contains('A paid plan is required'),
      )),
    );
  });

  test('trạng thái hỏng dừng ngay, không chờ hết timeout', () async {
    final client = _FakeClient(
      postResponse: _json({
        'status': 200,
        'result': {'audio_id': 7},
      }),
      getResponses: [
        _json({
          'status': 200,
          'result': {'id': 7, 'state': 'FAILED'},
        }),
      ],
    );

    await expectLater(
      _service(client).synthesize(text: 't', name: 'n'),
      throwsA(isA<TtsException>()),
    );
    // Đúng một lần hỏi: thấy FAILED là thôi.
    expect(client.calls.where((c) => c.startsWith('GET')), hasLength(1));
  });

  test('phản hồi POST thiếu audio_id thì báo lỗi thay vì poll bừa', () async {
    final client = _FakeClient(
      postResponse: _json({'status': 200, 'result': {}}),
      getResponses: const [],
    );

    expect(
      () => _service(client).synthesize(text: 't', name: 'n'),
      throwsA(isA<TtsException>()),
    );
  });
}
