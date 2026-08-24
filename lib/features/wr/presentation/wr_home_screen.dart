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
//   1. lời chào + ngày
//   2. "Bạn đang trải qua điều gì?" + lưới check-in 2×2
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

import '../../../core/logic/vn_date.dart';
import '../../../core/logic/wr_home_surface.dart';
import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../profile/profile_providers.dart';
import '../episode_flow_controller.dart';
import '../growth_providers.dart';
import '../mood_content_providers.dart';
import '../wr_providers.dart';
import 'wr_mood_library_screen.dart' show WrDraftBadge;
import 'wr_practice_step_completion.dart' show practiceStageLabel;
import '../../../core/widgets/wr_paragraph.dart';

// Hồ sơ đọc qua `mobileProfileProvider` dùng chung ở `profile_providers.dart`.
// Trước 2026-08-22 màn này khai một FutureProvider riêng cùng nội dung, nên
// avatar trên Home và avatar do widget tự đọc ở ba màn tab còn lại nằm trên hai
// provider khác nhau — hai lần gọi repository cho cùng một hồ sơ, và hai lần
// đó có thể lệch nhau một nhịp sau khi người dùng đổi tên.

// ---------------------------------------------------------------------------
// Lưới check-in — bốn ô như bản thiết kế, mỗi ô là một mức năng lượng.
//
// Khách yêu cầu bỏ bước "trạng thái" tách rời khỏi "năng lượng"; ở đây chỉ còn
// MỘT câu hỏi, bốn cách nói của cùng một thang năng lượng.
// ---------------------------------------------------------------------------

typedef CheckinOption = ({
  String id,
  String label,
  CheckinEnergy energy,
  Mood mood,
});

/// Bốn ô check-in. [mood] KHÔNG suy được từ [energy]: "căng thẳng" và "mệt mỏi"
/// dùng chung `CheckinEnergy.low`, nhưng Kiến trúc Dữ liệu v1.6 §III lọc tình
/// huống theo hai cụm chiều khác nhau cho hai cảm xúc đó. Giữ cả hai trường.
const List<CheckinOption> kCheckinOptions = [
  (
    id: 'stress',
    label: 'Tôi đang\ncăng thẳng',
    energy: CheckinEnergy.low,
    mood: Mood.stressed,
  ),
  (
    id: 'tired',
    label: 'Tôi mệt mỏi\ncần nghỉ ngơi',
    energy: CheckinEnergy.low,
    mood: Mood.tired,
  ),
  (id: 'ok', label: 'Tôi\nkhá ổn', energy: CheckinEnergy.ok, mood: Mood.okay),
  (
    id: 'happy',
    label: 'Tôi\nđang vui',
    energy: CheckinEnergy.good,
    mood: Mood.happy,
  ),
];

class WrHomeScreen extends ConsumerWidget {
  const WrHomeScreen({super.key});

  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  /// `Thứ Ba, 24 tháng 6` — nguyên văn khuôn ngày của mockup.
  ///
  /// Không dùng `24/06`: dòng này là lời chào, đọc thành câu. Dạng gạch chéo là
  /// ngôn ngữ của bảng dữ liệu, để dành cho "Lưu ngày 20/06" ở thẻ Insight.
  String _dateLabel() {
    final now = todayVn();
    return '${_weekdays[now.weekday - 1]}, ${now.day} tháng ${now.month}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName =
        ref.watch(mobileProfileProvider).valueOrNull?.displayName ?? '';

    return Scaffold(
      // `giao-dien-chinh.html` §.screen: nền màn TRẮNG, thẻ mới là màu kem. Sắc
      // kem nằm ở thẻ chứ không ở nền — đảo lại thì màn vàng cả mảng và thẻ
      // chìm mất.
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── .topbar { padding: 8px 22px 14px } ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mockup: ngày là dòng `.tiny` ở TRÊN, lời chào là
                        // `.h1` ở dưới. Trước đây app làm ngược — ngày to 32px
                        // choán đầu màn, tên người dùng thành chú thích.
                        Text(
                          _dateLabel(),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: WrColors.text3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          displayName.isNotEmpty
                              ? 'Chào $displayName'
                              : 'Chào bạn',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: WrColors.navy,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  WrProfileAvatar(
                    key: const Key('wr_home_profile_button'),
                    displayName: displayName,
                  ),
                ],
              ),
            ),

            // ── .scr-body ───────────────────────────────────────────────
            // `.section-gap { margin: 0 22px 14px }` → lề ngang 22, các thẻ
            // cách nhau 14. Không có đường kẻ ngang nào trong mockup.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 34),
                children: [
                  // Lưới check-in là khối CỐ ĐỊNH của mockup: luôn ở đây, luôn
                  // bày sẵn bốn câu trả lời. Trước đây phiên đang dở thay chỗ
                  // nó bằng một nút "Tiếp tục", nghĩa là muốn nói hôm nay mình
                  // thế nào thì phải bấm thêm một nút nữa — hỏi xong rồi giấu
                  // mất chỗ trả lời.
                  const _CheckinQuestion(),
                  // Thẻ nhắc điền hồ sơ nằm NGAY dưới lưới check-in, trên các
                  // khối nội dung — mockup bản (4) đặt nó ở đó vì nó là lời mời
                  // duy nhất trong màn có thời hạn: hỏi muộn hơn thì mấy chục
                  // Insight đầu đã sinh ra trong lúc app còn đoán mò bối cảnh.
                  const _ProfileNudgeCard(),
                  // Lời nhắc "còn dở" đứng ngay dưới lưới check-in: nó nói về
                  // chính việc người dùng vừa làm ở lưới đó, và phải đọc được
                  // trước khi mắt trôi xuống các khối nội dung.
                  const _UnfinishedReflectionCard(),
                  // Thứ tự lấy nguyên từ `screenHome()`: check-in (cố định) →
                  // Hệ thống nhận ra → Gợi ý → Insight gần nhất → Tiếp tục hôm
                  // nay. Hai khối giữa nằm trong nhánh `state.checkedInToday`
                  // của mockup, nên chúng vắng mặt trước check-in mà KHÔNG đổi
                  // chỗ ba khối còn lại.
                  const _SystemNoticeCard(),
                  const _MoodContentSection(),
                  const _LatestInsightSection(),
                  const _ContinueTodaySection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 · "Bạn đang trải qua điều gì?" + lưới 2×2
// ---------------------------------------------------------------------------

class _CheckinQuestion extends ConsumerWidget {
  const _CheckinQuestion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        const Text(
          // Nguyên văn mockup Sprint 2 §screenHome, cỡ chữ `.h2` = 15.5px.
          'Ngày hôm nay của bạn như thế nào?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < kCheckinOptions.length
                      ? _CheckinTile(
                          option: kCheckinOptions[i + 1],
                          selected: kCheckinOptions[i + 1].id == selectedId,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const SizedBox(
          width: double.infinity,
          child: Text(
            'Chạm để bắt đầu một Reflection, dựa trên đúng cảm giác lúc này.',
            textAlign: TextAlign.center,
            style: TextStyle(
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

class _CheckinTile extends ConsumerWidget {
  const _CheckinTile({required this.option, required this.selected});

  final CheckinOption option;
  final bool selected;

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
        // Phiên cũ không mất gì: nó vẫn mở trong DB, và thẻ "Còn dở" ngay dưới
        // lưới này vẫn mời quay lại — đường đó gọi `resume()` với Episode đọc
        // thẳng từ `wrOpenEpisodeProvider`, không phụ thuộc state ở đây. Khác
        // biệt duy nhất: người dùng chọn quay lại phiên cũ, thay vì bị đưa vào
        // một phiên họ không nhớ mình đang dở.
        ref.read(episodeFlowProvider.notifier).leave();

        ref.read(episodeFlowProvider.notifier).saveCheckin(
              energy: option.energy,
              mood: option.mood,
            );
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
            width: 1.5,
          ),
        ),
        child: WrParagraph(
          option.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: WrColors.navy,
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

class _ProfileNudgeCard extends ConsumerWidget {
  const _ProfileNudgeCard();

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
              'Cho mình biết bạn đi làm được bao lâu để những gợi ý sát hơn nhé',
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
                  child: const Text(
                    'Điền ngay',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('wr_home_profile_nudge_dismiss'),
                  onPressed: () =>
                      ref.read(profileNudgeDismissedProvider.notifier).dismiss(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WrColors.muted,
                    side: const BorderSide(color: WrColors.line),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Bỏ qua',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
      child: Container(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
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
// 2c · "Còn dở" — check-in rồi mà chưa chọn điều muốn nhìn lại.
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
//   • có phiên chưa khép (kể cả từ hôm trước)             → mời quay lại
// Không rơi vào hai trường hợp trên thì khối biến mất hẳn — WXS Orch. Inv.5.
// ---------------------------------------------------------------------------

class _UnfinishedReflectionCard extends ConsumerWidget {
  const _UnfinishedReflectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkedIn = ref.watch(todayCheckinProvider).valueOrNull != null;
    if (!checkedIn) return const SizedBox.shrink();

    final open = ref.watch(wrOpenEpisodeProvider).valueOrNull;
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];

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
    final line = open != null
        ? 'Bạn còn một lần nhìn lại đang dở. Đi tiếp từ chỗ đang đứng.'
        : 'Bạn đã ghi cảm xúc hôm nay, nhưng chưa chọn điều muốn nhìn lại.';

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
              const WrEyebrow('CÒN DỞ'),
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

class _SystemNoticeCard extends ConsumerWidget {
  const _SystemNoticeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cùng một điều kiện với khối "Gợi ý khi …" ngay dưới: hai khối này là một
    // cặp, cùng xuất hiện sau check-in.
    final checkin = ref.watch(todayCheckinProvider).valueOrNull;
    if (checkin == null) return const SizedBox.shrink();

    // recentSituationIds, không phải `wr_pattern_counts` (v2.0 §4.3). Trước bản
    // 2026-07-31 thẻ này nói "Đây là lần thứ 4 bạn gặp tình huống X" trong khi
    // luồng hiện hành mới ghi đúng MỘT lần — ba lần kia là số tích luỹ cũ.
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
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
                'HỆ THỐNG NHẬN RA',
                color: WrColors.cream.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 6),
              Text(
                '"${notice.sentence}"',
                // `.muted.serif` + italic — câu này là hệ thống đang trích lại
                // điều lặp lại của chính người dùng, không phải chữ giao diện.
                style: WrText.serifQuote(
                  fontSize: 15.5,
                  color: WrColors.cream,
                ),
              ),
              const SizedBox(height: 10),
              // `.pill` của mockup: nói rõ đây là lớp Pattern cơ bản và nó miễn
              // phí — để người dùng không tưởng mình đang xem thử một tính năng
              // trả tiền rồi mất hứng.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: WrColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Pattern cơ bản · miễn phí',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.27,
                    color: WrColors.cream,
                  ),
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

    final item = items.first;

    return Padding(
      key: const Key('wr_home_mood_content'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: const Key('wr_home_mood_content_card'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/wr/mood-content/${item.id}'),
            // Mockup: eyebrow nằm TRONG thẻ, không đứng ngoài làm tiêu đề mục.
            child: WrCardMinimal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrEyebrow(moodSuggestionTitle(mood)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          // Navy 6%, đúng mockup. Bản trước tô trắng vì thẻ chứa
                          // nó còn là kem; từ khi thẻ thành TRẮNG (brand identity
                          // 04/8) thì ô trắng trên thẻ trắng biến mất, icon nằm
                          // trơ không ra hình một ô.
                          color: WrColors.navy.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.type == MoodContentType.audio
                              ? Icons.mic_none_outlined
                              : Icons.menu_book_outlined,
                          size: 22,
                          color: WrColors.navy,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: WrParagraph(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: WrColors.navy,
                                      height: 1.35,
                                    ),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                if (item.placeholder) ...[
                                  const SizedBox(width: 6),
                                  const WrDraftBadge(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.kind} · ${item.duration}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: WrColors.text3,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: WrColors.text3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              key: const Key('wr_home_mood_library_link'),
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/wr/mood-library'),
              // Mũi tên dùng Icon chứ không dùng ký tự "→": font chữ của app
              // không chắc có glyph U+2192, thiếu là ra ô vuông rỗng.
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem thêm gợi ý trong thư viện',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 12, color: WrColors.navy),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5 · "Insight gần nhất" — câu chính người dùng đã xác nhận.
// ---------------------------------------------------------------------------

class _LatestInsightSection extends ConsumerWidget {
  const _LatestInsightSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(wrLatestInsightProvider).valueOrNull;

    // Chưa có Insight nào thì thẻ VẪN đứng đây, chỉ đổi lời — mockup bản (4)
    // thay nhánh ẩn cũ bằng một câu mời.
    //
    // Lý do giống hệt khối "Tiếp tục hôm nay" ngay dưới: người dùng mới nhất là
    // người cần thấy nhất rằng Home sẽ có gì. Ẩn đi thì màn của họ chỉ còn lưới
    // check-in, và chỗ này im lặng cho tới tận lần phản tư đầu tiên.
    if (insight == null) {
      return const Padding(
        key: Key('wr_home_latest_insight_empty'),
        padding: EdgeInsets.only(top: 14),
        child: WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WrEyebrow('INSIGHT GẦN NHẤT'),
              SizedBox(height: 6),
              WrParagraph(
                'Chưa có Insight nào. Bắt đầu một lần nhìn lại để lưu Insight '
                'đầu tiên.',
                style: TextStyle(
                  fontSize: 14,
                  color: WrColors.text2,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final at = insight.createdAt;
    final saved = at == null
        ? null
        : 'Lưu ngày ${at.day.toString().padLeft(2, '0')}/'
              '${at.month.toString().padLeft(2, '0')}';

    return Padding(
      key: const Key('wr_home_latest_insight'),
      padding: const EdgeInsets.only(top: 14),
      // Navy đậm như thẻ "Hệ thống nhận ra" (khách 2026-07-30). Hai thẻ này là
      // một cặp về nội dung — đều là câu TRÍCH về chính người dùng, một câu do hệ
      // thống đọc ra, một câu do người dùng tự đặt tên. Cùng giọng nói thì cùng
      // màu áo. Các thẻ kem còn lại là thứ để làm, không phải thứ để đọc chậm.
      child: WrCardNavy(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WrEyebrow(
              'INSIGHT GẦN NHẤT',
              color: WrColors.cream.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 6),
            Text(
              '"${insight.content}"',
              // `.muted.serif` italic 13.5px của mockup — cùng giọng với thẻ
              // "Hệ thống nhận ra", vì cả hai đều là câu trích về người dùng.
              style: WrText.serifQuote(
                fontSize: 15,
                color: WrColors.cream,
              ),
            ),
            if (saved != null) ...[
              const SizedBox(height: 8),
              Text(
                saved,
                style: TextStyle(
                  fontSize: 12.5,
                  color: WrColors.cream.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6 · "Tiếp tục hôm nay" — bước thực hành đang dở.
//
// Vị trí lấy từ mockup: nằm CUỐI màn, ngay dưới "Insight gần nhất", và có mặt
// kể cả trước khi check-in. Nó là sợi dây nối tab Home với tab Phát triển:
// người dùng mở app ra thấy ngay việc mình đang làm dở, khỏi phải nhớ mà bấm
// sang tab.
//
// Khối này LUÔN có mặt, đúng như mockup (khách 2026-07-30: "section Tiếp tục
// hôm nay đâu sao tôi không thấy").
//
// Trước đây nó biến mất khi chưa ghi danh chủ đề nào, viện WXS Orch. Inv.5. Chỗ
// sai của lập luận đó: ghi danh chỉ xảy ra khi người dùng tự vào tab Phát triển
// chọn một chủ đề — không có bước nào trong luồng phản tư tự ghi danh. Nên với
// gần như mọi người dùng thật, khối này im lặng VĨNH VIỄN, và Home mất hẳn sợi
// dây nối sang Phát triển. Im lặng chỉ hợp lệ khi nó tạm thời.
//
// Vì thế: chưa có chủ đề nào đang theo thì khối vẫn đứng đây, nhưng đổi lời —
// mời chọn một chủ đề, dẫn sang danh sách chủ đề ở tab Phát triển. Vẫn là một
// dòng có việc để làm, không phải thẻ rỗng.
// ---------------------------------------------------------------------------

/// Dòng mời tiếp tục, đúng khuôn câu của mockup.
String _continueLabel(PendingPracticeStep pending) {
  final stage = practiceStageLabel(pending.step.stepOrder);
  final tail = stage == null ? pending.step.title : 'bước $stage đang chờ';
  return '"${pending.theme.title}": $tail';
}

class _ContinueTodaySection extends ConsumerWidget {
  const _ContinueTodaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(wrPendingPracticeStepProvider).valueOrNull;

    // Chưa theo chủ đề nào: cùng một khối, cùng một chỗ, đổi lời và đổi điểm
    // đến sang danh sách chủ đề.
    final label = pending == null
        ? 'Chưa có chủ đề nào đang theo. Chọn một chủ đề để bắt đầu.'
        : _continueLabel(pending);
    final route = pending == null
        ? '/wr/growth/themes'
        : '/wr/growth/theme/${pending.theme.themeId}';

    return Padding(
      key: const Key('wr_home_continue_today'),
      // `.card + .card { margin-top: 12px }` — Insight và Tiếp tục hôm nay là
      // hai thẻ cùng một nhóm trong mockup, nên khoảng cách 12 chứ không 14.
      padding: const EdgeInsets.only(top: 12),
      child: WrCardMinimal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WrEyebrow('TIẾP TỤC HÔM NAY'),
            const SizedBox(height: 6),
            GestureDetector(
              key: const Key('wr_home_continue_today_card'),
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(route),
              // Ô lồng tô navy 3%, đúng mockup `rgba(9,55,116,0.03)`. Bản trước
              // tô trắng vì thẻ chứa nó là kem; thẻ giờ đã TRẮNG nên ô trắng
              // trong thẻ trắng không còn ranh giới nào, dòng chữ nằm trơ không
              // ra hình một ô bấm được.
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: WrColors.navy.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_outlined,
                      size: 20,
                      color: WrColors.coral,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        // Mockup: `"Dám lên tiếng": bước Thử nghiệm đang chờ`.
                        // Home nói TÊN GIAI ĐOẠN chứ không nói tên việc cụ thể —
                        // tên việc thuộc màn chủ đềtên việc thuộc màn chủ đề, nơi người dùng thật sự làm
                        // nó. Ở đây chỉ cần đủ để nhớ mình đang dở tới đâu.
                        //
                        // Bước thứ tư trở đi không có tên giai đoạn thì lùi về
                        // tên việc, thà dài còn hơn để trống một nửa câu.
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: WrColors.navy,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: WrColors.text3,
                    ),
                  ],
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
