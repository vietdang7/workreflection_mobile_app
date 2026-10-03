// Video hướng dẫn: cờ "đã tự bật" theo thiết bị và nguồn file thời lượng.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Khoá SharedPreferences của cờ đã tự bật video.
const String kIntroVideoShownKey = 'wr_intro_video_shown';

/// Video đã từng TỰ bật trên máy này chưa.
///
/// `null` = đang đọc bộ nhớ máy, chưa biết. Màn chào phải chờ tới khi có
/// `false` rồi mới tự bật, không thì máy đã xem rồi vẫn bị bật lại trong khung
/// hình đầu tiên.
///
/// Theo MÁY chứ không theo tài khoản, viết theo mẫu
/// `ProfileNudgeDismissedNotifier`: màn chào hiện trước khi đăng nhập, lúc đó
/// chưa có tài khoản nào để ghi.
class IntroVideoShownNotifier extends StateNotifier<bool?> {
  IntroVideoShownNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(kIntroVideoShownKey) ?? false;
      // markShown() có thể chạy trước khi đọc xong; đừng ghi đè true bằng false.
      if (mounted && state != true) state = v;
    } catch (_) {
      // Không đọc được bộ nhớ máy thì coi như đã xem: thà không tự bật còn hơn
      // bật lại mỗi lần mở app. Video vẫn mở được từ thẻ và từ Hướng dẫn.
      if (mounted && state == null) state = true;
    }
  }

  /// Đánh dấu NGAY lúc mở video, không đợi xem hết: người dùng tắt app giữa
  /// chừng thì lần sau cũng không bị bật lại.
  Future<void> markShown() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kIntroVideoShownKey, true);
    } catch (_) {
      /* best-effort: trong phiên này vẫn không bật lại */
    }
  }
}

final introVideoShownProvider =
    StateNotifierProvider<IntroVideoShownNotifier, bool?>(
      (ref) => IntroVideoShownNotifier(),
    );

/// Đọc nội dung file `assets/intro/intro_<lang>.json`; null khi chưa có (chưa
/// sinh được giọng đọc). Tách thành provider để test thay bằng chuỗi giả.
typedef IntroTimingSource = Future<String?> Function(String lang);

final introTimingSourceProvider = Provider<IntroTimingSource>(
  (ref) => (lang) async {
    try {
      return await rootBundle.loadString('assets/intro/intro_$lang.json');
    } catch (_) {
      return null;
    }
  },
);
