// Nối provider với màn trò chuyện: gợi ý phải là tình huống CỦA HỌ.
//
// Vì sao tách khỏi test logic thuần: `chatStarters` có thể đúng hoàn hảo mà màn
// hình vẫn hiện danh sách gán cứng, chỉ vì quên thay chỗ dùng hoặc quên watch
// provider. Đúng cái đã xảy ra: hàm dựng gợi ý và màn hình sống cạnh nhau suốt
// mà không nối vào nhau.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_chat_starters.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/features/wr/chat_providers.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

ReflectionEpisode _ep(String code, int daysAgo) => ReflectionEpisode(
      userId: 'u1',
      humanMoment: HumanMoment.confusion,
      situationCode: code,
      openedAt: DateTime.now().subtract(Duration(days: daysAgo)),
    );

final _situations = [
  const WrSituation(
    code: 'C3-01',
    text: 'Tôi biết có vấn đề nhưng không muốn nói',
    scaDimension: ScaDimension.c3,
    wave: 1,
  ),
];

/// Đọc thẳng provider, không dựng cả màn hình: phần hiển thị đã có test riêng ở
/// `wr_meeting_2026_07_29_test.dart`, còn thứ chưa ai kiểm là đường dữ liệu.
List<String> _read(ProviderContainer c) => c.read(wrChatStartersProvider);

void main() {
  test('gợi ý dựng từ tình huống người dùng hay chọn', () {
    final c = ProviderContainer(overrides: [
      wrEpisodeHistoryProvider.overrideWith(
        (ref) async => [_ep('C3-01', 1), _ep('C3-01', 5)],
      ),
      wrSituationsProvider.overrideWith((ref) async => _situations),
    ]);
    addTearDown(c.dispose);

    // Hai nguồn là FutureProvider nên phải chờ chúng xong trước khi đọc.
    c.listen(wrEpisodeHistoryProvider, (_, __) {});
    c.listen(wrSituationsProvider, (_, __) {});

    return Future(() async {
      await c.read(wrEpisodeHistoryProvider.future);
      await c.read(wrSituationsProvider.future);

      final out = _read(c);
      expect(out.first, 'Mình biết có vấn đề nhưng không muốn nói');
      expect(out.length, kChatStarterCount);
    });
  });

  test('chưa có Episode nào thì vẫn có đủ ba ô dự phòng', () async {
    final c = ProviderContainer(overrides: [
      wrEpisodeHistoryProvider.overrideWith((ref) async => const []),
      wrSituationsProvider.overrideWith((ref) async => _situations),
    ]);
    addTearDown(c.dispose);

    await c.read(wrEpisodeHistoryProvider.future);
    await c.read(wrSituationsProvider.future);

    expect(_read(c), kDefaultChatStarters);
  });

  test('nguồn dữ liệu còn đang tải thì màn chat vẫn mở được', () {
    // `valueOrNull ?? const []` chứ không `await`: màn chat không được chặn lại
    // chờ hai nguồn phụ trợ. Thiếu dữ liệu thì rơi về dự phòng, vẫn bấm được.
    final c = ProviderContainer(overrides: [
      wrEpisodeHistoryProvider.overrideWith((ref) => Completer<List<ReflectionEpisode>>().future),
      wrSituationsProvider.overrideWith((ref) => Completer<List<WrSituation>>().future),
    ]);
    addTearDown(c.dispose);

    expect(_read(c), kDefaultChatStarters);
  });
}
