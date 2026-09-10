// Đổi ngôn ngữ GIỮA CHỪNG, không phải mở app sẵn ở một ngôn ngữ.
//
// `wr_tr_test.dart` và `wr_tr_db_test.dart` khoá phép chọn câu — cho một giá
// trị `wrEnglish`, câu nào được trả về. Đó là trạng thái tĩnh. File này khoá
// chuyện khác hẳn: người dùng đang dùng app thì bấm đổi ngôn ngữ, và những gì
// ĐÃ được tính ra bằng ngôn ngữ cũ phải đổi theo.
//
// Ba nhóm lỗi tách ra từ ảnh chụp màn hình của khách 10/09:
//   1. chữ dựng sẵn thành hằng — đóng băng ở ngôn ngữ lần đọc đầu tiên;
//   2. chữ đã ghi xuống DB — `draft_meaning` gộp chữ người dùng với chữ app;
//   3. cache Riverpod — không ai bảo màn hình dựng lại thì nó không dựng lại.
//
// Run: flutter test test/core/l10n/wr_locale_switch_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/user_session_scope.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_home_surface.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_flow.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

WrSituation _sit(String code, String text, String? textEn) => WrSituation(
      code: code,
      text: text,
      textEn: textEn,
      scaDimension: ScaDimension.a3,
      wave: 1,
    );

void main() {
  // Quên trả về là hàng trăm bài chạy sau đó đỏ ở file khác hẳn file gây ra.
  tearDown(() => wrEnglish = false);

  group('midSentence — nhúng một câu vào giữa câu khác', () {
    test('tiếng Việt hạ chữ đầu, vì tiếng Việt không viết hoa giữa câu', () {
      expect(midSentence('Tôi cứ ra quyết định theo cảm xúc'),
          'tôi cứ ra quyết định theo cảm xúc');
    });

    test('tiếng Anh GIỮ NGUYÊN — "I" viết hoa ở mọi vị trí', () {
      // Đây là lỗi khách chụp lại: thẻ navy đọc `"i keep making decisions…"`.
      // Hạ chữ đầu là luật của tiếng Việt, đem sang tiếng Anh thì nó biến đại
      // từ ngôi thứ nhất thành lỗi chính tả.
      wrSetLocale('en');
      expect(midSentence('I keep making decisions on how I feel'),
          'I keep making decisions on how I feel');
    });
  });

  group('Hệ thống nhận ra — đúng MỘT cặp ngoặc kép', () {
    final situations = [
      _sit('A3-05', 'Tôi cứ ra quyết định theo cảm xúc',
          'I keep making decisions on how I feel'),
    ];

    test('tiếng Việt: ngoặc chỉ ôm tên tình huống', () {
      final notice = systemNotice(
        recent: const ['A3-05', 'A3-05'],
        situations: situations,
      );

      expect(notice, isNotNull);
      expect(notice!.sentence,
          'Bạn đã gặp tình huống "tôi cứ ra quyết định theo cảm xúc" 2 lần');
      // Hai dấu, không phải bốn. Bản trước màn Hôm nay bọc thêm một cặp nữa
      // quanh cả câu, nên người đọc mất một nhịp để biết dấu nào đóng dấu nào.
      expect('"'.allMatches(notice.sentence).length, 2);
    });

    test('tiếng Anh: dịch cả câu bao và giữ nguyên chữ hoa bên trong', () {
      wrSetLocale('en');
      final notice = systemNotice(
        recent: const ['A3-05', 'A3-05'],
        situations: situations,
      );

      expect(notice!.sentence,
          'You have met "I keep making decisions on how I feel" 2 times');
      expect('"'.allMatches(notice.sentence).length, 2);
    });
  });

  group('stemFromNote — bóc vế mở dở của CẢ HAI ngôn ngữ', () {
    // Một tài khoản dùng lâu sẽ có ghi chú của cả hai ngôn ngữ nằm lẫn nhau:
    // đổi ngôn ngữ không viết lại những dòng đã ghi. Chỉ nhận ra vế của ngôn
    // ngữ đang bật là mở lại phiên cũ thì thấy vế mở dở lặp hai lần.
    test('đang tiếng Anh vẫn bóc được ghi chú viết bằng tiếng Việt', () {
      wrSetLocale('en');
      expect(
        stemFromNote('Với tôi, điều này xảy ra vì tôi chưa nói ra'),
        'tôi chưa nói ra',
      );
    });

    test('đang tiếng Việt vẫn bóc được ghi chú viết bằng tiếng Anh', () {
      expect(
        stemFromNote('To me, this happens because I never said it'),
        'I never said it',
      );
    });

    test('không có vế mở dở nào thì trả nguyên văn', () {
      expect(stemFromNote('Chỉ là một câu rời'), 'Chỉ là một câu rời');
      expect(stemFromNote(null), '');
    });
  });

  group('liveMeaning — dựng lại thay vì đọc draft_meaning đóng băng', () {
    test('chữ người dùng GIỮ NGUYÊN, câu aha đổi theo ngôn ngữ', () {
      wrSetLocale('en');

      final built = liveMeaning(
        notes: const {
          'reframe': 'Với tôi, điều này xảy ra vì mình chưa rõ mình mong gì',
        },
        storyAha: 'Weak coordination often creates invisible waste.',
      );

      // Vế mở dở đã đổi sang tiếng Anh…
      expect(built, startsWith('To me, this happens because '));
      // …chữ của chính người dùng thì không. Dịch chữ họ viết mới là sai.
      expect(built, contains('mình chưa rõ mình mong gì'));
      // …và câu của app thì theo ngôn ngữ đang bật.
      expect(built, endsWith('Weak coordination often creates invisible waste.'));
    });

    test('người dùng bỏ qua Lớp 1 thì còn đúng câu aha, không có vế mở dở', () {
      wrSetLocale('en');

      final built = liveMeaning(
        notes: const {},
        storyAha: 'Weak coordination often creates invisible waste.',
      );

      expect(built, 'Weak coordination often creates invisible waste.');
      expect(built, isNot(contains('To me, this happens because')));
    });

    test('story không có câu aha thì rơi về câu mặc định, đúng ngôn ngữ', () {
      wrSetLocale('en');
      expect(liveMeaning(notes: const {}, storyAha: null), kDefaultAha);
      expect(kDefaultAha, startsWith('Stopping to name'));
    });
  });

  group('xoá cache khi đổi ngôn ngữ', () {
    test('xoá đúng danh sách repository, không đụng định danh hay phiên', () {
      final invalidated = <Object>[];
      resetLocaleScopedProviders(invalidated.add);

      // Repository là gốc: mọi provider dữ liệu đều watch một cái trong đó, nên
      // xoá gốc là cả cây tự dựng lại. Đây cũng là thứ buộc màn hình `const`
      // trong bảng route phải chạy lại `build` — không có bước này thì `tr()`
      // không bao giờ được đọc lại và app "đổi ngôn ngữ rất chậm, cứ xen kẽ".
      expect(invalidated, containsAll(userDataProviders));

      // Người dùng vẫn là người đó — xoá định danh chỉ tạo ra một vòng tải lại
      // vô cớ.
      for (final p in userIdentityProviders) {
        expect(invalidated, isNot(contains(p)));
      }

      // Và một buổi nhìn lại đang viết dở không được biến mất chỉ vì người dùng
      // bấm đổi ngôn ngữ giữa chừng.
      for (final p in userSessionStateProviders) {
        expect(invalidated, isNot(contains(p)));
      }
    });
  });

  group('ReflectionEpisode — dữ liệu thật đi qua liveMeaning', () {
    test('Episode có ghi chú reframe thì dựng lại được', () {
      final e = ReflectionEpisode(
        id: 'e1',
        userId: 'u1',
        humanMoment: HumanMoment.confusion,
        state: ExperienceState.integrated,
        situationCode: 'S2-03',
        openedAt: DateTime(2026, 9, 1),
        draftMeaning: 'Với tôi, điều này xảy ra vì A. Câu aha tiếng Việt.',
        notes: const {'reframe': 'Với tôi, điều này xảy ra vì A'},
      );

      wrSetLocale('en');
      final built = liveMeaning(
        notes: e.notes,
        storyAha: 'The English aha.',
      );

      expect(built, 'To me, this happens because A. The English aha.');
      // Bản đóng băng vẫn nằm nguyên trong DB — không sửa dữ liệu cũ, chỉ thôi
      // đọc nó.
      expect(e.draftMeaning, contains('Câu aha tiếng Việt.'));
    });
  });
}
