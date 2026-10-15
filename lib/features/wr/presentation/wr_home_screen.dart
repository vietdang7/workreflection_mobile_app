// Hôm nay — BỐ CỤC theo mockup Sprint 2 (`WorkReflection_Sprint2_Mockup (1).html`
// §screenHome), HỆ MÀU theo `giao-dien-chinh.html`.
//
// Hai bản thiết kế này xung đột về màu và khách đã chốt (2026-07-30) lấy mỗi bản
// một nửa:
//   · bố cục, câu chữ, thứ tự khối, pill, chữ serif  → Sprint 2
//   · nền màn TRẮNG, thẻ KEM #FFF3E6 (`.card-minimal`, bo 20, đệm 20),
//     ô check-in kem, ô đang chọn tô ĐẶC coral        → giao-dien-chinh
//
// Lý do: Sprint 2 đổi nền màn sang #FBF9F5 và thẻ sang trắng-viền-navy, nhưng
// Home là màn DUY NHẤT trong app từng đổi theo — ba tab còn lại (Hiểu mình, Phát
// triển, Hành trình) vẫn nền trắng + thẻ kem. Khách nhìn thấy ngay: "không giống
// ban đầu là nền kem và màu cam nữa". Một màn lệch cả app thì lỗi ở màn đó.
//
// Từ 2026-07-30 hệ màu của màn này là hệ màu CHUNG: ba tab kia đã kéo về đúng
// bốn quy ước ở `wr_card.dart` (nền trắng · thẻ kem · thẻ đọc-chậm navy · ô lồng
// trắng). Sửa màu ở đây là sửa cả bốn tab — đọc ghi chú ở `wr_card.dart` trước.
//
// Các khối, đúng thứ tự của bản thiết kế:
//   0. minh hoạ theo khung giờ — "một chiếc ghế đang chờ bạn" (§5, 24/08)
//   1. lời chào + ngày
//   2. "Bạn đang trải qua điều gì?" + lưới check-in 3×2
//   3. thẻ navy "Hệ thống nhận ra"  → dẫn sang màn chi tiết điều lặp lại
//   4. "Gợi ý khi …" + thẻ Thư viện Nội dung Cảm xúc → dẫn sang màn đọc/nghe
//   5. "Insight gần nhất"
//   6. "Tiếp tục hôm nay" — bước thực hành đang dở
//
// ⚠ Khối 3 và 4 CHỈ hiện sau khi đã check-in hôm nay — đúng nhánh
//   `state.checkedInToday ? … : ''` của mockup, và đúng lời khách 2026-07-29:
//   "màn hình ban đầu nó chỉ hiển thị ngày hôm nay của bạn thế nào, insight gần
//   nhất, và tiếp tục một cái thực hành bạn đang làm dở. Hệ thống nhận ra và
//   gợi ý hôm nay là hai cái hiển thị ra SAU khi họ check in xong."
//
//   Lý do của khách, không phải thẩm mỹ: "hệ thống nhận ra" chỉ có nghĩa khi nó
//   đọc ra từ chính lần check-in vừa rồi. Bày sẵn từ đầu thì nó thành một lời
//   phán chung chung, và gợi ý thì không biết gợi theo cảm xúc nào.
//
// Bốn khối này khớp đúng danh sách nội dung tab Home ở Kiến trúc Dữ liệu v1.6
// §9.1. Thẻ ở khối 4 trước đây gợi ý một Story; từ v1.6 nó là Thư viện Nội dung
// Cảm xúc (§VIII) — hai mạch khác nhau: Story giờ là nguồn nội dung cho tình
// huống trong luồng phản tư, còn thư viện này là nội dung chăm sóc cảm xúc.
//
// Toàn bộ nội dung ba khối dưới đến từ dữ liệu thật của người dùng
// (`lib/core/logic/wr_home_surface.dart`). Chưa đủ dữ liệu thì khối biến mất
// hẳn — WXS Orch. Inv.5: im lặng là lựa chọn hợp lệ, không bịa nội dung mẫu.
//
// Chọn một ô check-in là đã trả lời: luồng đi thẳng sang màn khoảnh khắc rồi
// tới các câu hỏi dẫn dắt của khoảnh khắc đó (HXA §2.5, §3.6). Không có nút
// "Bắt đầu" trung gian.
//
// Ngoại lệ: còn phiên đang dở thì Journey Continuity được ưu tiên hơn novelty
// (WXS Orch. Inv.3) — Home mời tiếp tục trước.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/logic/wr_display_name.dart';
import '../../../core/logic/wr_home_surface.dart';
import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/models/checkin.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_app_background.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../profile/profile_providers.dart';
import '../episode_flow_controller.dart';
import '../growth_providers.dart';
import '../mood_content_providers.dart';
import '../../../core/models/wr_mood_content.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../../../core/widgets/wr_title_text.dart';

// Hồ sơ đọc qua `mobileProfileProvider` dùng chung ở `profile_providers.dart`.
// Trước 2026-08-22 màn này khai một FutureProvider riêng cùng nội dung, nên
// avatar trên Home và avatar do widget tự đọc ở ba màn tab còn lại nằm trên hai
// provider khác nhau — hai lần gọi repository cho cùng một hồ sơ, và hai lần
// đó có thể lệch nhau một nhịp sau khi người dùng đổi tên.

// ---------------------------------------------------------------------------
// Lưới check-in — sáu ô như bản thiết kế mới nhất, mỗi ô là một cách nói về
// ngày hôm nay.
//
// Khách yêu cầu bỏ bước "trạng thái" tách rời khỏi "năng lượng"; ở đây chỉ còn
// MỘT câu hỏi. Bốn ô đầu tiên (2026-07) là bốn mức của cùng một thang năng
// lượng; hai ô thêm 24/08 (§3) nói về sự rõ ràng và sự ăn khớp, không phải về
// năng lượng — xem ghi chú `energy` ở từng ô.
// ---------------------------------------------------------------------------

typedef CheckinOption = ({
  String id,
  String label,
  CheckinEnergy energy,
  Mood mood,
});

/// Sáu ô check-in. [mood] KHÔNG suy được từ [energy]: bốn cảm xúc đầu dùng
/// chung `CheckinEnergy.low`, nhưng Kiến trúc Dữ liệu v1.6 §III lọc tình huống
/// theo những cụm chiều khác nhau cho từng cảm xúc. Giữ cả hai trường.
///
/// THỨ TỰ LÀ DỮ LIỆU, không phải chuyện trình bày. Changelog mockup 24/08/2026
/// §3: hai ô mới chèn NGAY SAU "Mệt mỏi", TRƯỚC "Khá ổn" — nhóm cảm xúc khó
/// khăn đứng trước, nhóm tích cực đứng sau. Đảo lại thì người đang mệt phải đọc
/// qua hai ô vui vẻ mới tới ô của mình.
///
/// Lưới ở `_CheckinQuestion` cắt hai ô một hàng nên sáu ô tự thành 3×2, không
/// cần đổi gì ở đó.
/// KHÔNG còn `const`: nhãn đi qua `tr()`, mà `tr()` đọc ngôn ngữ hiện tại nên
/// không phải hằng biên dịch. Đổi thành getter chứ không thành biến `final` ở
/// tầng file: biến `final` chốt ngôn ngữ tại lần đọc ĐẦU TIÊN, nên người đổi
/// ngôn ngữ trong Tài khoản sẽ thấy sáu ô check-in vẫn nguyên tiếng cũ.
List<CheckinOption> get kCheckinOptions => [
  (
    id: 'stress',
    label: tr('Tôi đang\ncăng thẳng', 'I feel\ntense'),
    energy: CheckinEnergy.low,
    mood: Mood.stressed,
  ),
  (
    id: 'tired',
    label: tr('Tôi mệt mỏi\ncần nghỉ ngơi', 'I am tired,\nneed rest'),
    energy: CheckinEnergy.low,
    mood: Mood.tired,
  ),
  (
    id: 'foggy',
    label: tr('Tôi thấy\nmơ hồ', 'I feel\nunclear'),
    // Mơ hồ không phải mệt: người không rõ việc mình đang làm vẫn có thể còn
    // đủ sức. Ghi `ok` để thẻ năng lượng không tụt oan mỗi lần họ nói ra điều
    // này.
    energy: CheckinEnergy.ok,
    mood: Mood.foggy,
  ),
  (
    id: 'outofsync',
    label: tr('Tôi thấy\nmọi thứ lệch nhau', 'Things feel\nout of sync'),
    energy: CheckinEnergy.ok,
    mood: Mood.outofsync,
  ),
  (
    id: 'ok',
    label: tr('Tôi\nkhá ổn', 'I am\ndoing okay'),
    energy: CheckinEnergy.ok,
    mood: Mood.okay,
  ),
  (
    id: 'happy',
    label: tr('Tôi\nđang vui', 'I am\nfeeling good'),
    energy: CheckinEnergy.good,
    mood: Mood.happy,
  ),
];

class WrHomeScreen extends ConsumerWidget {
  const WrHomeScreen({super.key});

  static List<String> get _weekdays => [
    tr('Thứ Hai', 'Monday'),
    tr('Thứ Ba', 'Tuesday'),
    tr('Thứ Tư', 'Wednesday'),
    tr('Thứ Năm', 'Thursday'),
    tr('Thứ Sáu', 'Friday'),
    tr('Thứ Bảy', 'Saturday'),
    tr('Chủ Nhật', 'Sunday'),
  ];

  /// Tên tháng cho bản tiếng Anh.
  ///
  /// Dòng này là LỜI CHÀO, đọc thành câu — nên bản tiếng Anh cũng phải là
  /// "Tuesday, June 24", không phải "Tuesday, 24/6". Dạng gạch chéo là ngôn
  /// ngữ của bảng dữ liệu, để dành cho "Saved 20/06" ở thẻ Insight.
  static const _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// `Thứ Ba, 24 tháng 6` — nguyên văn khuôn ngày của mockup.
  ///
  /// Không dùng `24/06`: dòng này là lời chào, đọc thành câu. Dạng gạch chéo là
  /// ngôn ngữ của bảng dữ liệu, để dành cho "Lưu ngày 20/06" ở thẻ Insight.
  String _dateLabel() {
    final now = todayVn();
    final day = _weekdays[now.weekday - 1];
    return tr(
      '$day, ${now.day} tháng ${now.month}',
      '$day, ${_monthsEn[now.month - 1]} ${now.day}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tên đọc qua `greetingNameProvider`, không đọc thẳng `display_name`:
    // hàng hồ sơ cũ có thể đang chứa EMAIL ở ô tên (khách báo họp 26_1, xem
    // `wr_display_name.dart`), và tài khoản đăng ký từ web thì tên nằm ở
    // `cc_profiles.full_name` chứ không ở bảng của app di động.
    final greetingName = ref.watch(greetingNameProvider);
    final displayName = greetingName ?? '';

    final todayMood = ref.watch(todayCheckinProvider).valueOrNull?.mood;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Không bọc SafeArea: ảnh hero tràn lên dưới thanh trạng thái như mockup
      // v55 (`.hero2.home2`), phần chữ tự né thanh đó trong `WrHeroHeader`.
      body: ListView(
        // Padding tường minh: `ListView` không có padding sẽ xoá phần thanh
        // trạng thái khỏi `MediaQuery` của con, ảnh hero hết tràn lên.
        // `<div style="height:104px">` cuối màn: đủ chỗ để bong bóng trò
        // chuyện (đè 34px lên vùng nội dung) không che nút cuối cùng.
        padding: const EdgeInsets.only(bottom: 104),
        children: [
          // Hero ảnh màu nước (mockup v55 `heroPhoto('home')`). Một khối tĩnh,
          // cả ngày một ảnh, không theo dữ liệu người dùng — nên nó ở đây kể
          // cả trước lần check-in đầu tiên.
          WrHeroHeader.home(
            key: const Key('wr_home_hero'),
            overline: _dateLabel(),
            title: wrGreeting(greetingName),
            subtitle: tr(
              // Ngắt sẵn thành hai dòng (họp khách 14/10).
              'Dừng lại một chút.\nHôm nay của bạn đang như thế nào?',
              'Pause for a moment.\nHow is your day going?',
            ),
            trailing: WrProfileAvatar(
              key: const Key('wr_home_profile_button'),
              displayName: displayName,
            ),
          ),
          const SizedBox(height: WrHeroHeader.kContentGap),
          // `.section-gap { margin: 0 22px 14px }` → lề ngang 22, các thẻ
          // cách nhau 14.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Lưới check-in: khi chưa check-in thì chỉ hiển thị đúng khung này.
                const _CheckinQuestion(),
                // Khi đã check-in: 1. Thư viện cảm xúc, 2. Lần gần nhất bạn thấy như vậy
                if (todayMood != null) ...[
                  const _MoodContentSection(),
                  const _LatestInsightSection(),
                ],
                // 3. Tiếp tục hôm nay: chỉ khi có chủ đề đang dở.
                const _ContinueTodaySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 · "Bạn đang trải qua điều gì?" + lưới 3×2
// ---------------------------------------------------------------------------

/// Phần đứng sau "Hôm nay bạn" ở dòng cảm xúc đã chọn (mockup v47
/// `.mood-row`): nhãn ô check-in bỏ chữ "Tôi"/"Tôi đang" ở đầu, đúng regex
/// `/^Tôi (đang )?/` của mockup, nên "Tôi đang vui" còn lại "vui".
String checkinTodayPhrase(String id) => switch (id) {
  'stress' => tr('căng thẳng', 'feel tense'),
  'tired' => tr('mệt mỏi cần nghỉ ngơi', 'are tired and need rest'),
  'foggy' => tr('thấy mơ hồ', 'feel unclear'),
  'outofsync' => tr('thấy mọi thứ lệch nhau', 'feel things are out of sync'),
  'ok' => tr('khá ổn', 'are doing okay'),
  'happy' => tr('vui', 'are feeling good'),
  _ => '',
};

class _CheckinQuestion extends ConsumerStatefulWidget {
  const _CheckinQuestion();

  @override
  ConsumerState<_CheckinQuestion> createState() => _CheckinQuestionState();
}

class _CheckinQuestionState extends ConsumerState<_CheckinQuestion> {
  /// Đã check-in hôm nay mà bấm "Đổi" thì mở lại lưới.
  bool _editing = false;

  /// Chọn lại xong thì quay về dòng gọn khi trở lại Home.
  void _closeEditor() {
    if (_editing) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    // Tô theo cảm xúc đã ghi, không theo năng lượng: "căng thẳng" và "mệt mỏi"
    // cùng là năng lượng thấp, nên khớp bằng energy sẽ luôn sáng ô đầu tiên dù
    // người dùng chạm ô thứ hai.
    final todayMood = ref.watch(todayCheckinProvider).valueOrNull?.mood;
    final selectedId = todayMood == null
        ? null
        : kCheckinOptions
              .where((o) => o.mood == todayMood)
              .map((o) => o.id)
              .firstOrNull;

    // Mockup v47: check-in xong thì lưới thu thành một dòng. Lưới sáu ô đã làm
    // xong việc của nó trong ngày; để nguyên thì nó choán nửa màn và đẩy các
    // khối nói về chính lần check-in đó xuống dưới.
    if (selectedId != null && !_editing) {
      return _TodayMoodRow(
        id: selectedId,
        onChange: () => setState(() => _editing = true),
      );
    }

    // Cả khối nằm TRONG một thẻ trắng — `<div class="card card-pad">` của
    // mockup bản (4). Trước đây lưới đứng trần trên nền màn: hồi nền màn còn
    // TRẮNG và ô check-in màu kem thì cách đó đúng, nhưng từ khi nền màn thành
    // xám và ô check-in thành trắng (brand identity 04/8) thì khối quan trọng
    // nhất của Home lại là khối duy nhất không có mặt phẳng riêng — nó trôi
    // giữa nền xám trong khi ba khối dưới đều là thẻ.
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrTitleText(
            // Nguyên văn mockup Sprint 2 §screenHome, cỡ chữ `.h2` = 15.5px.
            tr('Ngày hôm nay của bạn như thế nào?', 'How has your day been?'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          // Một tỉ lệ chữ CHUNG cho cả sáu ô, vừa đủ để dòng dài nhất nằm gọn
          // trong lòng ô: nhãn luôn đúng hai dòng như script, sáu ô vẫn cùng
          // cỡ chữ. Không có bước này thì cỡ chữ hệ thống lớn (máy thật 1.15,
          // 13/10) bẻ "Tôi mệt mỏi cần nghỉ ngơi" thành bốn dòng.
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = _checkinLabelScale(context, constraints.maxWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < kCheckinOptions.length; i += 2) ...[
                    if (i > 0) const SizedBox(height: 12),
                    // IntrinsicHeight để hai ô cùng hàng cao bằng nhau như lưới CSS —
                    // "Tôi khá ổn" một dòng và "Tôi mệt mỏi cần nghỉ ngơi" hai dòng mà
                    // để tự do thì hai ô lệch nhau.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _CheckinTile(
                              option: kCheckinOptions[i],
                              selected: kCheckinOptions[i].id == selectedId,
                              onPicked: _closeEditor,
                              labelScale: scale,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: i + 1 < kCheckinOptions.length
                                ? _CheckinTile(
                                    option: kCheckinOptions[i + 1],
                                    selected:
                                        kCheckinOptions[i + 1].id == selectedId,
                                    onPicked: _closeEditor,
                                    labelScale: scale,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Text(
              wrKeepCompounds(tr(
                'Chạm để bắt đầu một lần nhìn lại, dựa trên đúng cảm giác lúc '
                    'này.',
                'Tap to start a look-back, based on exactly how you feel right '
                    'now.',
              )),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: WrColors.text3,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.mood-row` — "Hôm nay bạn **căng thẳng** · Đổi".
class _TodayMoodRow extends StatelessWidget {
  const _TodayMoodRow({required this.id, required this.onChange});

  final String id;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_home_mood_row'),
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        color: WrColors.white,
        image: WrBackgroundScope.of(context)
            ? const DecorationImage(
                image: AssetImage('assets/images/paper_card.webp'),
                repeat: ImageRepeat.repeat,
                scale: 2.0,
                alignment: Alignment.topLeft,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WrColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: WrMoodPalette.dot(id),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: tr('Hôm nay bạn ', 'Today you '),
                    style: const TextStyle(color: WrColors.text2),
                  ),
                  TextSpan(
                    text: checkinTodayPhrase(id),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 14,
                color: WrColors.navy,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            key: const Key('wr_home_mood_change'),
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: WrColors.link,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(wrKeepCompounds(tr('Đổi', 'Change'))),
          ),
        ],
      ),
    );
  }
}

/// Chạm một ô cảm xúc: ghi check-in và mở một lần nhìn lại MỚI.
///
/// Dùng chung cho lưới Home và bước cuối của Onboarding (mockup v47: chọn cảm
/// xúc là vào thẳng lần nhìn lại đầu tiên). Người gọi tự điều hướng sang
/// `/wr/flow/step`.
void startReflectionFromCheckin(WidgetRef ref, CheckinOption option) {
  ref.read(pendingEnergyProvider.notifier).state = option.energy;
  ref.read(pendingMoodProvider.notifier).state = option.mood;

  // Chạm ô cảm xúc là BẮT ĐẦU MỘT LẦN NHÌN LẠI MỚI — buông phiên mà
  // controller còn đang giữ, trước khi đi tiếp.
  //
  // Khách báo 2026-08-24: "các check in lặp lại 2 lần không được count".
  // Đúng, và đây là chỗ sinh ra nó. Bỏ dở một phiên bằng thanh tab hay
  // nút Back của hệ thống thì phiên ấy vẫn nằm nguyên trong
  // `episodeFlowProvider` — chỉ nút "Xong" mới gọi `leave()`. Lần check-in
  // kế tiếp bị `wr_step_screen` kéo thẳng về bước còn dở của phiên cũ:
  // không Episode mới, bộ đếm Career Health đứng yên.
  //
  // Tệ hơn cả việc đếm thiếu là việc nó KHÔNG NHẤT QUÁN: đóng app rồi mở
  // lại thì state rỗng và đúng thao tác ấy lại được đếm. Cùng một hành vi,
  // hai kết quả, không ai đối chiếu được.
  //
  // Phiên cũ không mất gì: nó vẫn mở trong DB, và thẻ "Đang bỏ ngỏ" dưới
  // lưới này vẫn mời quay lại — đường đó gọi `resume()` với Episode đọc
  // thẳng từ `wrOpenEpisodeProvider`, không phụ thuộc state ở đây. Khác
  // biệt duy nhất: người dùng chọn quay lại phiên cũ, thay vì bị đưa vào
  // một phiên họ không nhớ mình đang dở.
  ref.read(episodeFlowProvider.notifier).leave();

  ref
      .read(episodeFlowProvider.notifier)
      .saveCheckin(energy: option.energy, mood: option.mood);
}

/// Cỡ chữ nhãn ô check-in (12px của script + 1.5 theo brand identity 04/8).
const double kCheckinLabelFontSize = 13.5;

/// Đệm ngang và viền của ô check-in — phải khớp [_CheckinTile].
const double _kCheckinTilePadH = 10;
const double _kCheckinTileBorder = 1.5;
const double _kCheckinGridGap = 12;

/// Hệ số (≤ 1) thu cỡ chữ để dòng dài nhất trong sáu nhãn vừa lòng ô, đo
/// đúng cỡ chữ hệ thống đang bật. Một hệ số cho cả lưới để sáu ô đều nhau.
double _checkinLabelScale(BuildContext context, double gridWidth) {
  if (!gridWidth.isFinite || gridWidth <= 0) return 1.0;
  final inner =
      (gridWidth - _kCheckinGridGap) / 2 -
      2 * _kCheckinTilePadH -
      2 * _kCheckinTileBorder;
  if (inner <= 0) return 1.0;
  final scaler = MediaQuery.textScalerOf(context);
  final style = DefaultTextStyle.of(context).style.merge(
    const TextStyle(
      fontSize: kCheckinLabelFontSize,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
  );
  var widest = 0.0;
  for (final option in kCheckinOptions) {
    for (final line in wrKeepCompounds(option.label).split('\n')) {
      final painter = TextPainter(
        text: TextSpan(text: line, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
  }
  if (widest <= inner) return 1.0;
  // Chừa 2% cho sai số làm tròn giữa lúc đo và lúc vẽ.
  return (inner / widest) * 0.98;
}

class _CheckinTile extends ConsumerWidget {
  const _CheckinTile({
    required this.option,
    required this.selected,
    required this.onPicked,
    this.labelScale = 1.0,
  });

  final CheckinOption option;
  final bool selected;
  final VoidCallback onPicked;

  /// Hệ số thu cỡ chữ nhãn, chung cho cả lưới — xem [_checkinLabelScale].
  final double labelScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      key: Key('wr_home_checkin_${option.id}'),
      behavior: HitTestBehavior.opaque,
      // v2.0 §9.1: "Home dẫn thẳng vào luồng 5 bước ngay sau khi người dùng
      // chạm chọn cảm xúc check-in". Không còn màn "Chọn khoảnh khắc" chen vào
      // giữa — sáu Human Moment Archetype giờ suy ra từ chính cảm xúc này
      // (`momentForMood`), đúng tinh thần HXA §2.5 xem archetype là bộ TỪ VỰNG
      // chứ không phải một câu hỏi đặt ra cho người dùng.
      //
      // Check-in ghi ngay tại đây, còn Episode chỉ mở khi người dùng thật sự
      // chạm một tình huống ở màn sau — lý do ở `wr_step_screen.dart`.
      onTap: () {
        onPicked();
        startReflectionFromCheckin(ref, option);
        context.push('/wr/flow/step');
      },
      // Mockup bản (4) §screenHome: ô là VIỀN 1.5px, bo 13, chữ luôn navy. Ô
      // đang chọn đổi viền sang coral và tô nền coral 7% — không tô đặc.
      //
      // Bản trước tô đặc coral, lấy từ `giao-dien-chinh.html`. Cách đó hợp lý
      // khi ô nằm trần trên nền màn; giờ ô nằm TRONG một thẻ trắng, một mảng
      // coral đặc trong thẻ đọc ra như nút bấm chính của màn — mà nút chính thì
      // spec §01 dành riêng cho một chỗ duy nhất, và đây không phải chỗ đó.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: _kCheckinTilePadH,
          vertical: 12,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? WrColors.coral.withValues(alpha: 0.07)
              : WrColors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? WrColors.coral
                : WrColors.navy.withValues(alpha: 0.14),
            width: _kCheckinTileBorder,
          ),
        ),
        // `Text` chứ KHÔNG phải `WrParagraph`. Nhãn ô check-in là dòng chữ ngắn
        // trong thẻ — đúng thứ mà chính doc của `WrParagraph` dặn đừng dùng nó.
        //
        // Không chỉ là chuyện hình thức: `WrParagraph` nối hai tiếng cuối bằng
        // U+00A0 để dòng chót không rớt một tiếng cụt. Ở một đoạn văn thì hay,
        // nhưng ở đây nó biến "feeling good" thành MỘT khối không ngắt được,
        // rộng hơn lòng ô, và Flutter cắt ngang giữa từ: người dùng bản tiếng
        // Anh đọc thấy "I am / feeling goo" (ảnh khách gửi 11/09).
        //
        // Bản tiếng Việt không lộ vì "đang vui" đủ ngắn, và bộ test cũng không
        // lộ vì `flutter_test_config.dart` tắt `wrParagraphKeepsTail`.
        //
        // Trên Flutter web (canvaskit) đã thấy chữ VẼ rộng hơn đoạn văn đã layout
        // (02/10, khổ 320px): dòng cuối rớt xuống và bị cắt dù RenderParagraph
        // báo đúng số dòng. Layout ở đây đúng; hãy thử trên máy thật trước khi
        // đổi bố cục.
        //
        // Chỉ khoá từ ghép ("nghỉ ngơi", họp khách 08/10) — bật ở tiếng Việt,
        // không đụng tới lỗi "feeling goo" ở trên.
        //
        // Không tự xuống dòng: hai dòng là hai dòng của script (`\n` trong
        // nhãn). [labelScale] đã thu chữ cho vừa; FittedBox chỉ đỡ phần lệch
        // rất nhỏ giữa lúc đo và lúc vẽ, để không bao giờ rớt thành dòng ba.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            wrKeepCompounds(option.label),
            textAlign: TextAlign.center,
            softWrap: false,
            style: TextStyle(
              fontSize: kCheckinLabelFontSize * labelScale,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: WrColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2b · Thẻ nhắc điền hồ sơ — mockup Sprint 2 bản (4), `showProfileNudge`.
//
// Ba điều kiện, đúng mockup: đã lưu ít nhất 3 Insight, chưa khai số năm kinh
// nghiệm, và chưa bấm "Bỏ qua".
//
// Ngưỡng 3 Insight là phần quan trọng nhất và cũng dễ bỏ sót nhất: KHÔNG hỏi
// người mới. Người vừa cài app chưa có lý do gì để tin app, và một biểu mẫu
// dựng ngay trước mặt ở lần mở thứ hai chỉ đọc ra là "app này muốn lấy dữ liệu".
// Sau ba lần nhìn lại thì họ đã thấy app làm được gì, và câu hỏi lúc đó đọc ra
// đúng nghĩa của nó: để gợi ý bám sát hơn.
//
// Chỉ hỏi MỘT trường (số năm kinh nghiệm) chứ không hỏi cả bảy — đây là lời
// nhắc, không phải biểu mẫu. Sáu trường còn lại nằm ở màn "Thông tin của bạn",
// nơi người dùng tự đến khi muốn.
// ---------------------------------------------------------------------------

/// Số Insight tối thiểu trước khi app được phép hỏi thêm về người dùng.
const int kProfileNudgeInsightThreshold = 3;

class WrProfileNudgeCard extends ConsumerWidget {
  const WrProfileNudgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(profileNudgeDismissedProvider)) {
      return const SizedBox.shrink();
    }

    // Cả hai nguồn chưa về thì im lặng: hiện thẻ rồi rút lại khi dữ liệu tới
    // là màn nhảy ngay dưới tay người dùng.
    final insights = ref.watch(insightCountProvider).valueOrNull;
    final cc = ref.watch(ccProfileProvider).valueOrNull;
    if (insights == null || cc == null) return const SizedBox.shrink();

    if (insights < kProfileNudgeInsightThreshold) {
      return const SizedBox.shrink();
    }
    final experience = cc['total_work_experience'] as String?;
    if (experience != null && experience.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: const Key('wr_home_profile_nudge'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Viền ĐỨT, đúng mockup: thẻ này khác mọi thẻ khác trên màn ở chỗ nó
          // sẽ biến mất sau khi được trả lời. Viền đứt là cách nói "chỗ này còn
          // trống" mà không cần thêm chữ nào.
          DottedBorderBox(
            child: Text(
              wrKeepCompounds(tr(
                'Cho mình biết bạn đi làm được bao lâu để những gợi ý sát hơn nhé',
                'Tell us how long you have been working so the prompts fit you better',
              )),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
                height: 1.5,
              ),
            ),
          ),
          // Mockup kéo hàng nút lên sát thẻ (`margin-top:-8px`) — hai nút là
          // phần trả lời của chính câu hỏi trong thẻ, không phải một khối rời.
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  key: const Key('wr_home_profile_nudge_fill'),
                  onPressed: () => context.push('/profile/my-info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrColors.navy,
                    foregroundColor: WrColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    wrKeepCompounds(tr('Điền ngay', 'Fill in now')),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('wr_home_profile_nudge_dismiss'),
                  onPressed: () => ref
                      .read(profileNudgeDismissedProvider.notifier)
                      .dismiss(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WrColors.muted,
                    side: const BorderSide(color: WrColors.line),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    wrKeepCompounds(tr('Bỏ qua', 'Skip')),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thẻ trắng viền ĐỨT — `border-style:dashed` của mockup.
///
/// Flutter không có kiểu viền đứt sẵn, nên vẽ bằng [CustomPaint]. Giữ riêng ở
/// đây thay vì cho vào `wr_card.dart`: hệ thẻ chung cố ý chỉ có ba mặt phẳng,
/// và đây là ngoại lệ của đúng một thẻ.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(),
      child: Container(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  static const double _radius = 20;
  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final paint = Paint()
      ..color = WrColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// 2c · "Đang bỏ ngỏ" — check-in rồi mà chưa chọn điều muốn nhìn lại.
//
// Khách báo 2026-08-22: chị check-in "đang căng thẳng" ngày 21/08 rồi rời màn
// chọn tình huống, và tin rằng mình đã ghi lại xong. Trên DB ngày đó có đúng
// một dòng `wr_checkins` và KHÔNG có Episode nào — nên mọi khối đọc tình huống
// im lặng, còn app thì không hề nói gì về việc còn dở.
//
// Episode chỉ sinh ra khi người dùng chạm một tình huống (`wr_step_screen.dart`)
// và đó là chủ ý — không để lại phiên rỗng. Nhưng "không tạo phiên" không có
// nghĩa là "không có gì để nhắc": chính lần check-in là dấu vết cho thấy người
// dùng đã bắt đầu.
//
// Khối này bù đúng khoảng trống đó, và chỉ khoảng trống đó:
//   • đã check-in hôm nay VÀ chưa mở phiên nào trong ngày → mời đi tiếp
//   • có phiên chưa khép, mới rời trong vòng một ngày     → mời quay lại
// Không rơi vào hai trường hợp trên thì khối biến mất hẳn — WXS Orch. Inv.5.
//
// VÌ SAO CÓ HẠN NGÀY (khách 2026-08-25: "tự nhiên còn dở là sao"). Trên DB thật
// tài khoản của khách có TÁM Episode chưa khép, cái mới nhất từ 04/08 — hai
// mươi mốt ngày trước hôm khách chụp màn hình. `fetchOpenEpisode` không có mốc
// thời gian nào, nên nó cứ trả về phiên cũ nhất-còn-mở ấy mãi mãi: mỗi lần
// check-in, Home lại nhắc về một phiên người dùng không còn nhớ, và chạm vào là
// bị kéo ngược vào giữa chừng nó.
//
// Phiên cũ KHÔNG mất: nó vẫn mở trong DB và vẫn quay lại được từ tab Hành trình
// → chi tiết Episode → "Hiểu lại chuyện này" (WPA Inv.4). Chỉ có lời nhắc trên
// Home là im — vì lời nhắc chỉ đúng khi người ta còn nhớ mình đang dở dở dang.
// ---------------------------------------------------------------------------

/// Phiên bỏ dở cách đây quá bao nhiêu ngày thì Home thôi nhắc. 1 = hôm nay và
/// hôm qua còn nhắc, từ hôm kia trở đi thì không.
const int kUnfinishedReflectionMaxDaysAgo = 1;

class WrUnfinishedReflectionCard extends ConsumerWidget {
  const WrUnfinishedReflectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkedIn = ref.watch(todayCheckinProvider).valueOrNull != null;
    if (!checkedIn) return const SizedBox.shrink();

    // `updatedAt` chứ không phải `openedAt`: câu hỏi ở đây là "rời khỏi nó bao
    // lâu rồi", không phải "bắt đầu nó bao lâu rồi". Phiên mở tuần trước nhưng
    // hôm qua vừa viết thêm thì vẫn còn trong trí nhớ người dùng.
    final openRaw = ref.watch(wrOpenEpisodeProvider).valueOrNull;
    final touchedAt = openRaw?.updatedAt ?? openRaw?.openedAt;
    final open =
        openRaw == null ||
            (touchedAt != null &&
                daysAgoVn(touchedAt) > kUnfinishedReflectionMaxDaysAgo)
        ? null
        : openRaw;

    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];

    final today = todayVn();
    bool isToday(DateTime? at) {
      if (at == null) return false;
      final vn = at.toUtc().add(const Duration(hours: 7));
      return vn.year == today.year &&
          vn.month == today.month &&
          vn.day == today.day;
    }

    final startedToday = episodes.any((e) => isToday(e.openedAt));
    if (open == null && startedToday) return const SizedBox.shrink();

    // Phiên dở được ưu tiên nói tới: nó đã có nội dung người dùng viết, còn lần
    // check-in trống thì chưa.
    //
    // Nhãn cũ là "CÒN DỞ" — khách bác 2026-08-25 vì "dùng từ chưa phù hợp".
    // Đúng: trong tiếng Việt "dở" tự nó là DỞ/TỆ, phải đi cặp thành "dở dang"
    // mới mang nghĩa chưa xong. Đặt một mình trên thẻ nói về chính lần nhìn lại
    // của người dùng, nó đọc thành lời chê. Giọng của app là mời, không chấm.
    final (eyebrow, line) = open != null
        ? (
            tr('ĐANG BỎ NGỎ', 'STILL OPEN'),
            tr(
              'Bạn đang có một câu chuyện chưa hoàn thành. Tiếp tục viết tiếp '
                  'từ chỗ dừng lại nhé!',
              'You have a story you never finished. Pick it up from where you '
                  'left off.',
            ),
          )
        : (
            tr('CÒN MỘT BƯỚC NỮA', 'ONE STEP LEFT'),
            tr(
              'Bạn đã ghi cảm xúc hôm nay, nhưng chưa chọn điều muốn nhìn lại.',
              'You logged how you feel today, but have not chosen what to look back on.',
            ),
          );

    return Padding(
      key: const Key('wr_home_unfinished_reflection'),
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        key: const Key('wr_home_unfinished_link'),
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (open != null) {
            await ref.read(episodeFlowProvider.notifier).resume(open);
          }
          if (context.mounted) context.push('/wr/flow/step');
        },
        child: WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WrEyebrow(eyebrow),
              const SizedBox(height: 6),
              WrParagraph(
                line,
                style: const TextStyle(
                  fontSize: 15.5,
                  color: WrColors.navy,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · Thẻ navy "Hệ thống nhận ra" — đọc lại chính con số của người dùng.
//
// Chỉ hiện SAU khi đã check-in hôm nay (họp khách 2026-07-29). Trước đó màn
// Home rút về đúng ba việc: hỏi hôm nay thế nào, Insight gần nhất, và thực hành
// đang dở.
// ---------------------------------------------------------------------------

class WrSystemNoticeCard extends ConsumerWidget {
  const WrSystemNoticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cùng một điều kiện với khối "Gợi ý khi …" ngay dưới: hai khối này là một
    // cặp, cùng xuất hiện sau check-in.
    final checkin = ref.watch(todayCheckinProvider).valueOrNull;
    if (checkin == null) return const SizedBox.shrink();

    // recentSituationIds, không phải `wr_pattern_counts` (v2.0 §4.3). Trước bản
    // 2026-07-31 thẻ này nói "Đây là lần thứ 4 bạn gặp tình huống X" trong khi
    // luồng hiện hành mới ghi đúng MỘT lần — ba lần kia là số tích luỹ cũ.
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final notice = systemNotice(
      recent: recentSituationIds(episodes),
      situations: situations,
      // Cảm xúc vừa check-in là bộ lọc, không phải thông tin phụ: khách
      // 2026-08-22 nói rõ "hệ thống nhận ra là nhận diện tình huống vừa
      // check-in". Bỏ tham số này là thẻ quay về đọc chuyện tuần trước.
      mood: checkin.mood,
    );

    // Chưa lặp lại lần nào thì hệ thống chưa có gì để nhận ra — im lặng.
    if (notice == null) return const SizedBox.shrink();

    return Padding(
      key: const Key('wr_home_system_notice'),
      padding: const EdgeInsets.only(top: 14),
      // Mockup không cho thẻ này bấm được, nhưng app có màn chi tiết điều lặp
      // lại nên giữ cú chạm ở CẢ thẻ thay vì thêm một dòng link không có trong
      // bản thiết kế. Cùng một điểm đến, ít hơn một phần tử lạ.
      child: GestureDetector(
        key: const Key('wr_home_notice_link'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/wr/pattern/${notice.situationCode}'),
        child: WrCardNavy(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WrEyebrow(
                tr('HỆ THỐNG NHẬN RA', 'WHAT THE APP NOTICED'),
                color: WrColors.cream.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 6),
              Text(
                wrKeepCompounds(// KHÔNG bọc thêm một cặp ngoặc kép nữa. [SystemNotice.sentence]
                // đã tự đóng ngoặc quanh tên tình huống, nên bọc lần hai cho ra
                // `"Bạn đã gặp tình huống "…" 2 lần"` — bốn dấu ngoặc trong một
                // dòng, và người đọc mất một nhịp để biết cái nào đóng cái nào.
                // Chữ nghiêng serif đã đủ nói đây là câu trích.
                notice.sentence),
                // `.muted.serif` + italic — câu này là hệ thống đang trích lại
                // điều lặp lại của chính người dùng, không phải chữ giao diện.
                style: WrText.serifQuote(fontSize: 15.5, color: WrColors.cream),
              ),
              // ĐÃ BỎ nhãn "Pattern cơ bản · miễn phí" (họp 26_1).
              //
              // Nó có trong mockup để trấn an rằng khối này không phải hàng
              // trả tiền. Nhưng người dùng thật đọc xong không biết "Pattern cơ
              // bản" là gì — chữ sinh ra để giải toả lo lắng lại tạo thêm một
              // câu hỏi. Khối này vốn miễn phí cho mọi người, im lặng là đủ.
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · "Gợi ý khi …" — Thư viện Nội dung Cảm xúc.
//
// Kiến trúc Dữ liệu v1.6 §8.3: Home hiện đúng MỘT mục, là mục đầu tiên của
// nhóm theo cảm xúc vừa check-in. Không xoay vòng ở đây — xoay vòng làm thẻ
// đổi nội dung mỗi lần mở app, người dùng không quay lại được bài đang đọc dở.
//
// §8.3: miễn phí cho mọi người dùng, không phân lớp Free/Paid, vì đây là nội
// dung chăm sóc cảm xúc chứ không phải trí tuệ rút từ dữ liệu cá nhân.
// ---------------------------------------------------------------------------

class _MoodContentSection extends ConsumerWidget {
  const _MoodContentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(todayCheckinProvider).valueOrNull?.mood;
    final items = ref.watch(wrTodayMoodContentProvider).valueOrNull ?? const [];

    // Chưa check-in hoặc chưa có nội dung thì khối biến mất hẳn —
    // WXS Orch. Inv.5: im lặng là lựa chọn hợp lệ, không bịa nội dung mẫu.
    if (mood == null || items.isEmpty) return const SizedBox.shrink();

    // Bài nghe trước (họp khách 14/10), chưa có bài nghe thì lấy bài đọc.
    final item = audioFirst(items).first;
    final isAudio = item.type == MoodContentType.audio && item.hasAudio;
    final paper = WrBackgroundScope.of(context);

    // `.card.tlcard` của mockup Sprint 2: mặt giấy trắng bo 18, viền `--line`,
    // không đổ bóng. Ảnh `.tlcard-img` cao 88, mép dưới tan dần vào thân thẻ.
    // Không có huy hiệu thời lượng trên ảnh: thời lượng đã nằm ở dòng meta.
    return Padding(
      key: const Key('wr_home_mood_content'),
      padding: const EdgeInsets.only(top: 14),
      child: GestureDetector(
        key: const Key('wr_home_mood_content_card'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/wr/mood-content/${item.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: WrColors.white,
            image: paper
                ? const DecorationImage(
                    image: AssetImage('assets/images/paper_card.webp'),
                    repeat: ImageRepeat.repeat,
                    scale: 2.0,
                    alignment: Alignment.topLeft,
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: WrColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const Key('wr_home_mood_content_image'),
                height: 88,
                // `mask-image: linear-gradient(to bottom, #000 66%,
                // transparent 100%)`.
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.black, Colors.transparent],
                    stops: [0, 0.66, 1],
                  ).createShader(rect),
                  child: Image.asset(
                    'assets/images/card_library.webp',
                    fit: BoxFit.cover,
                    // `background-position: 50% 52%`.
                    alignment: const Alignment(0, 0.04),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // Script `.tiny` 700 tracking .12em, một dòng. Cỡ chữ
                        // hệ thống lớn (máy thật 13/10) thì thu cho vừa,
                        // không gãy thành "THƯ VIỆN CẢM / XÚC".
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              wrKeepCompounds(tr('THƯ VIỆN CẢM XÚC', 'EMOTION LIBRARY')),
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: WrColors.text3,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          key: const Key('wr_home_mood_library_link'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.push('/wr/mood-library'),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                            child: Text(
                              wrKeepCompounds(tr('Xem tất cả →', 'See all →')),
                              maxLines: 1,
                              softWrap: false,
                              // Script: 11px.
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: WrColors.link,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      wrKeepCompounds(item.title),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // `.muted`: "Gợi ý khi căng thẳng · BÀI ĐỌC · 2 phút đọc".
                    Text(
                      wrKeepCompounds('${moodSuggestionTitle(mood)} · ${item.kindLabel} · '
                      '${item.durationLabel}'),
                      key: const Key('wr_home_mood_content_meta'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WrColors.text2,
                        height: 1.65,
                      ),
                    ),
                    // Nút "Nghe" nổi bật (họp khách 14/10): người dùng phải
                    // thấy ngay đây là bài nghe, không tưởng là bài đọc chữ.
                    // Bấm vào mở màn bài nghe, nơi có trình phát.
                    if (isAudio) ...[
                      const SizedBox(height: 10),
                      Container(
                        key: const Key('wr_home_mood_listen'),
                        padding: const EdgeInsets.fromLTRB(12, 7, 16, 7),
                        decoration: BoxDecoration(
                          color: WrColors.coral,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                              color: WrColors.navy,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              wrKeepCompounds(tr('Nghe ngay', 'Listen now')),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: WrColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5 · "Lần gần nhất bạn thấy như vậy" — dòng chính người dùng đã viết.
//
// Mockup Sprint 2 `lastEntryForMood`: không phải số liệu hệ thống đếm được mà
// là chữ của chính họ, ở lần nhìn lại gần nhất mà hôm đó họ chọn CÙNG cảm xúc
// với hôm nay. Mockup bày sáu câu mẫu (`MOOD_LAST_ENTRY`) để minh hoạ; app
// không bao giờ hiện câu mẫu cho người dùng thật. Chưa có thì khối biến mất.
// ---------------------------------------------------------------------------

class _LatestInsightSection extends ConsumerWidget {
  const _LatestInsightSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayMood = ref.watch(todayCheckinProvider).valueOrNull?.mood;
    if (todayMood == null) return const SizedBox.shrink();

    final line = lastWrittenForMood(
      episodes: ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [],
      checkins: ref.watch(wrRecentCheckinsProvider).valueOrNull ?? const [],
      mood: todayMood,
      todayVn: todayVn(),
    );
    if (line == null) return const SizedBox.shrink();

    final date =
        '${line.date.day.toString().padLeft(2, '0')}/'
        '${line.date.month.toString().padLeft(2, '0')}';

    return Padding(
      key: const Key('wr_home_latest_insight'),
      padding: const EdgeInsets.only(top: 20),
      child: WrCardMinimal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Script `.tiny` 700, một dòng; chữ lớn thì thu cho vừa.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                wrKeepCompounds(tr(
                  'LẦN GẦN NHẤT BẠN THẤY NHƯ VẬY',
                  'THE LAST TIME YOU FELT THIS WAY',
                )),
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: WrColors.text3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Chữ của người dùng: in nguyên văn, không dịch.
            Text(
              wrKeepCompounds('“${line.text}”'),
              key: const Key('wr_home_latest_insight_text'),
              style: WrText.serifQuote(
                fontSize: 16,
                color: WrColors.navy,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              wrKeepCompounds(date),
              key: const Key('wr_home_latest_insight_date'),
              style: const TextStyle(fontSize: 12.5, color: WrColors.text3),
            ),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: WrColors.lineSoft)),
              ),
              child: Text(
                wrKeepCompounds(tr(
                  'Không cần làm gì với điều này. Chỉ là một dòng bạn từng '
                      'viết, trong một ngày giống hôm nay.',
                  'No need to do anything with this. Just a line you once '
                      'wrote, on a day like today.',
                )),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: WrColors.text3,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6 · "Tiếp tục hôm nay" — bước thực hành đang dở.
//
// Mockup Sprint 2 `resumeTheme()`: chỉ hiện khi có một chủ đề ĐANG DỞ (đã xong
// ít nhất một bước, còn bước chưa xong). Không có thì khối biến mất hẳn, không
// còn thẻ mời "Chưa có chủ đề nào đang theo": mockup không có thẻ đó, và lối
// sang chủ đề thực hành đã có ở tab Phát triển.
//
// Đây là thẻ duy nhất trên màn có nút chính (`btn btn-primary btn-sm`): nền
// coral, chữ navy, cỡ nhỏ, không kéo hết bề ngang, căn trái.
// ---------------------------------------------------------------------------

class _ContinueTodaySection extends ConsumerWidget {
  const _ContinueTodaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(wrPendingPracticeStepProvider).valueOrNull;
    if (pending == null) return const SizedBox.shrink();

    final total = pending.totalSteps > 0 ? pending.totalSteps : 4;
    final d = pending.completedCount.clamp(0, total);
    // Số bước theo đúng bước đang hiện câu hỏi bên dưới (xem `stepNumber`).
    final n = pending.stepNumber > 0 ? pending.stepNumber : d + 1;
    final desc = pending.step.content ?? pending.step.title;

    return Padding(
      key: const Key('wr_home_continue_today'),
      padding: const EdgeInsets.only(top: 20),
      child: WrCardMinimal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      wrKeepCompounds(tr('TIẾP TỤC HÔM NAY', 'CONTINUE TODAY')),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: WrColors.text3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  wrKeepCompounds(tr('Bước $n / $total', 'Step $n / $total')),
                  key: const Key('wr_home_continue_today_step'),
                  style: const TextStyle(fontSize: 12.5, color: WrColors.text3),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              wrKeepCompounds(pending.theme.title),
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            // `.sb`: vạch tiến độ, bước đã xong tô teal.
            Row(
              children: [
                for (var k = 0; k < total; k++) ...[
                  if (k > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: k < d
                            ? WrColors.teal
                            : WrColors.navy.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                wrKeepCompounds(desc),
                style: const TextStyle(
                  fontFamily: WrText.serifFamily,
                  fontSize: 14.5,
                  color: WrColors.navy,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 13),
            // `.btn.btn-primary.btn-sm`: đệm 9×14, bo 10, rộng theo chữ.
            FilledButton(
              key: const Key('wr_home_continue_today_card'),
              style: FilledButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () =>
                  context.push('/wr/growth/theme/${pending.theme.themeId}'),
              child: Text(
                wrKeepCompounds(tr('Mở bước này', 'Open this step')),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Thẻ "ĐANG CHỜ BẠN" (mời tiếp tục phiên phản tư đang dở) đã bỏ khỏi Home theo
// yêu cầu khách 2026-07-30: mockup Sprint 2 không có nó, và Home phải đúng bằng
// bản thiết kế.
//
// Phiên dở KHÔNG mất đường quay lại: nó vẫn nằm trong tab Hành trình, mở ra màn
// chi tiết Episode và tiếp tục bằng nút `wr_episode_reopen`. Chạm một ô check-in
// ở đây thì mở phiên MỚI (`EpisodeFlow.start`), không đụng gì phiên cũ.
