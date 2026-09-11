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
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_home_surface.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_flow.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

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

  group('đổi ngôn ngữ không cần hỏi lại server', () {
    // Đây là điều kiện để đổi ngôn ngữ diễn ra trong MỘT khung hình. Hễ một
    // repository trả về chuỗi đã dịch sẵn thì giá trị đó nằm lì trong cache
    // bằng tiếng cũ, và cách duy nhất chữa được là xoá cache — tức là hàng chục
    // lượt mạng, mỗi lượt về một lúc, đúng cảnh "xen kẽ" khách báo 10/09.
    test('ChoicePoolLine đổi tiếng ngay trên cùng một đối tượng đã tải', () {
      const line = ChoicePoolLine(
        textVi: 'Mình sẽ hỏi lại cho rõ trước khi bắt tay vào làm',
        textEn: 'I will ask for clarity before I start',
      );

      wrSetLocale('vi');
      expect(line.text, 'Mình sẽ hỏi lại cho rõ trước khi bắt tay vào làm');

      wrSetLocale('en');
      expect(line.text, 'I will ask for clarity before I start');
    });

    test('chưa dịch thì rơi về tiếng Việt, không để ô trống', () {
      const line = ChoicePoolLine(textVi: 'Câu chưa có bản tiếng Anh');
      wrSetLocale('en');
      expect(line.text, 'Câu chưa có bản tiếng Anh');
    });
  });

  group('Diễn biến do AI viết — ngoại lệ duy nhất', () {
    PatternNarrative n(String locale, String text) => PatternNarrative(
          userId: 'u1',
          narrative: text,
          locale: locale,
        );

    test('chỉ nhận đoạn đúng tiếng đang bật, không rơi về tiếng kia', () {
      final list = [n('vi', 'Đoạn tiếng Việt')];

      wrSetLocale('vi');
      expect(currentLocaleNarrative(list)?.narrative, 'Đoạn tiếng Việt');

      // Đây là lỗi khách chụp màn 10/09: chọn tiếng Anh mà thẻ vẫn nguyên khối
      // tiếng Việt. Thà im lặng chờ model viết lại còn hơn hiện sai tiếng.
      wrSetLocale('en');
      expect(currentLocaleNarrative(list), isNull);
    });

    test('có cả hai tiếng thì lấy đúng bản của tiếng đang bật', () {
      // Danh sách xếp mới-nhất-trước, như truy vấn của repository.
      final list = [n('en', 'English version'), n('vi', 'Bản tiếng Việt')];

      wrSetLocale('vi');
      expect(currentLocaleNarrative(list)?.narrative, 'Bản tiếng Việt');

      wrSetLocale('en');
      expect(currentLocaleNarrative(list)?.narrative, 'English version');
    });

    test('dòng ghi trước migration narrative_locale được coi là tiếng Việt', () {
      // Cùng quy ước với `wr-narrative/regeneration.ts`. Coi nhầm là tiếng Anh
      // thì mọi bài cũ biến mất khỏi màn của người dùng tiếng Việt.
      final old = PatternNarrative.fromJson({
        'user_id': 'u1',
        'narrative': 'Bài cũ không có cột locale',
      });
      expect(old.locale, 'vi');

      wrSetLocale('vi');
      expect(old.matchesCurrentLocale, isTrue);
      wrSetLocale('en');
      expect(old.matchesCurrentLocale, isFalse);
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

  group('Insight đã đóng băng trong DB', () {
    // Thẻ "Insight gần nhất" ở màn Hôm nay đọc `wr_reflection_insights.content`
    // — bản GỘP lúc bấm lưu, không có đường lần ngược về Episode nên
    // `liveMeaning` không dùng được. Khách báo 10/09: cả màn Hôm nay tiếng Anh,
    // riêng thẻ này nguyên khối tiếng Việt.
    const ahaVi = 'Sự phối hợp yếu thường tạo ra lãng phí vô hình.';
    const ahaEn = 'Weak coordination often creates invisible waste.';
    const map = {ahaVi: ahaEn};

    test('đổi vế mở dở và câu aha, GIỮ NGUYÊN chữ người dùng', () {
      const frozen =
          'Với tôi, điều này xảy ra vì mình chưa rõ mình đang mong đợi gì. $ahaVi';

      wrSetLocale('en');
      final out = relocaliseInsight(frozen, ahaEnByVi: map);

      expect(out, startsWith('To me, this happens because '));
      expect(out, endsWith(ahaEn));
      // Chữ người dùng tự gõ ở nguyên ngôn ngữ họ đã viết. Dịch nó đi mới là
      // sai — thẻ nửa Anh nửa Việt ở đây là đúng.
      expect(out, contains('mình chưa rõ mình đang mong đợi gì'));
    });

    test('chiều ngược lại cũng đúng', () {
      const frozen =
          'To me, this happens because I never said what I needed. $ahaEn';

      wrSetLocale('vi');
      final out = relocaliseInsight(frozen, ahaEnByVi: map);

      expect(out, startsWith('Với tôi, điều này xảy ra vì '));
      expect(out, endsWith(ahaVi));
      expect(out, contains('I never said what I needed'));
    });

    test('câu aha mặc định đổi được mà không cần bản đồ story', () {
      wrSetLocale('en');
      expect(
        relocaliseInsight('Với tôi, điều này xảy ra vì A. $kDefaultAhaVi'),
        'To me, this happens because A. $kDefaultAhaEn',
      );
    });

    test('không nhận ra câu aha thì giữ nguyên, không cắt bừa chữ nào', () {
      // Người dùng bỏ qua Lớp 1 và tự viết trọn câu. Không mảnh nào là của app.
      const mine = 'Tôi chỉ đang mệt, không có gì sâu xa hơn.';
      wrSetLocale('en');
      expect(relocaliseInsight(mine, ahaEnByVi: map), mine);
    });

    test('bản đồ có dòng rỗng hay trùng nhau thì bỏ qua, không xoá đuôi câu', () {
      // `aha_message_en` bằng đúng bản tiếng Việt (chưa dịch, chép tạm) từng
      // làm mọi câu bị cắt đuôi rồi nối lại y nguyên — vô hại nhưng che mất
      // dòng dịch thật đứng sau nó trong vòng lặp.
      const frozen = 'Với tôi, điều này xảy ra vì B. $ahaVi';
      wrSetLocale('en');
      expect(
        relocaliseInsight(frozen, ahaEnByVi: {'': '', ahaVi: ahaVi, ...map}),
        'To me, this happens because B. $ahaEn',
      );
    });
  });
}
