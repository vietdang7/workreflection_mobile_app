// "Hướng dẫn sử dụng" — mục trong Hồ sơ, yêu cầu §4 họp 26_1.
//
// Bộ chữ nằm ở `lib/core/logic/wr_user_guide.dart`; màn này chỉ dựng. Tách như
// vậy vì chữ là thứ khách còn sửa nhiều vòng, còn bố cục thì không — và vì mọi
// con số trong hướng dẫn phải đọc từ hằng số của app, thứ dễ kiểm tra bằng test
// thuần Dart hơn là bằng widget test.
//
// ---------------------------------------------------------------------------
// Bốn quyết định về bố cục
// ---------------------------------------------------------------------------
//
// 1. GẬP/MỞ, không phải một trang chữ dài. Bản Word đọc một mạch từ trên xuống
//    được vì người đọc đang ngồi đọc tài liệu. Người mở màn này thì đang mắc ở
//    một chỗ cụ thể ("cái Career Health Check kia là gì") — tám tiêu đề nhìn
//    thấy hết trong một màn là cách nhanh nhất để họ tới đúng chỗ. Mỗi tiêu đề
//    kèm một dòng tóm tắt, nên gập lại vẫn đọc được bên trong có gì.
//
// 2. CHATBOT NẰM NGOÀI DANH SÁCH. Khách chốt hướng dẫn phải "làm nổi bật
//    Chatbot"; một mục thứ tư trong tám mục thì không nổi bật. Nó là thẻ coral
//    đặc, luôn mở, có nút mở thẳng Chatbot — và là chỗ DUY NHẤT trên màn dùng
//    coral đặc, đúng spec §01 "một CTA chính mỗi màn".
//
// 3. MỖI MỤC MỘT ICON, VÀ BỐN MỤC LẤY ĐÚNG ICON CỦA TAB TƯƠNG ỨNG. Bốn icon
//    con mắt · bóng đèn · tia chớp · nhịp sóng ở đây là bốn icon người dùng vừa
//    thấy dưới thanh tab (`shell_screen.dart`). Trùng icon là cách nối trang
//    giấy với màn hình thật mà không tốn một chữ nào — đọc mục "Hiểu mình" xong
//    ngước lên là biết bấm cái bóng đèn.
//
// 4. BA NHÃN NHÓM. Tám thẻ trắng giống hệt nhau xếp thẳng một cột không có hình
//    dạng gì để mắt bám vào; ba nhãn chia nó thành Bắt đầu · Từng tab một ·
//    Tài khoản. Nhãn đọc từ `WrGuideSection.group`, in khi nhóm đổi.
//
// Vì sao KHÔNG có ảnh minh hoạ: khách đã chốt ở Trà Chiều rằng chị "muốn nhìn
// chữ mà được làm cho nó dễ nhìn hơn là có hình vô" — thêm ảnh là phải tổ chức
// ảnh, mà ảnh co lại trên điện thoại thì còn khó đọc hơn chữ.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_user_guide.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_paragraph.dart';

// ---------------------------------------------------------------------------
// Icon của từng mục
// ---------------------------------------------------------------------------

/// Icon theo mã mục. Nằm ở đây chứ không ở bộ chữ vì `IconData` là kiểu của
/// Flutter, mà `wr_user_guide.dart` cố ý giữ thuần Dart để test được không cần
/// dựng widget.
///
/// Bốn dòng giữa TRÙNG ĐÚNG icon của bốn tab trong `shell_screen.dart`. Đổi
/// icon tab thì đổi luôn ở đây, không thì hướng dẫn chỉ vào một cái nút không
/// còn tồn tại.
const Map<String, IconData> _kSectionIcons = {
  'what': Icons.explore_outlined,
  'tabs': Icons.grid_view_rounded,
  'daily': Icons.visibility_outlined,
  'understand': Icons.lightbulb_outline,
  'growth': Icons.bolt_outlined,
  'journey': Icons.show_chart,
  'profile': Icons.person_outline_rounded,
  'faq': Icons.help_outline_rounded,
};

/// Icon của từng tab, tra theo ĐÚNG chữ ở cột trái bảng "bốn tab".
///
/// Tra bằng chữ nên nó hỏng êm: khách đổi nhãn tab trong bộ chữ thì dòng đó mất
/// icon chứ không vỡ bố cục. Bảng hai cột là khối dùng chung, không có chỗ nào
/// khai "đây là bảng tab" — mà chỉ đúng một mục dùng nó.
const Map<String, IconData> _kTabIcons = {
  'Hôm nay': Icons.visibility_outlined,
  'Hiểu mình': Icons.lightbulb_outline,
  'Phát triển': Icons.bolt_outlined,
  'Hành trình': Icons.show_chart,
};

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  late final List<WrGuideSection> _sections = wrGuideSections();

  /// Các mục đang mở. Cho phép mở NHIỀU mục cùng lúc — khác màn "Thông tin của
  /// bạn", nơi mở cái này phải đóng cái kia vì mỗi lần chỉ sửa một trường. Ở
  /// đây người dùng đang đối chiếu ("Hiểu mình" với "Phát triển" khác nhau chỗ
  /// nào), nên tự động đóng mục họ vừa đọc là lấy đi thứ họ đang cần.
  late final Set<String> _open = {
    for (final s in _sections)
      if (s.openByDefault) s.id,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 36),
          children: [
            if (GoRouter.maybeOf(context) != null && context.canPop())
              const _BackLink(),
            const _Header(),
            const SizedBox(height: 16),
            const _ChatbotCard(),
            const SizedBox(height: 18),
            for (var i = 0; i < _sections.length; i++) ...[
              // Nhãn nhóm in một lần, ở mục đầu tiên của nhóm.
              if (i == 0 || _sections[i].group != _sections[i - 1].group) ...[
                if (i > 0) const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: WrEyebrow(_sections[i].group),
                ),
              ],
              _SectionCard(
                section: _sections[i],
                expanded: _open.contains(_sections[i].id),
                onTap: () => setState(() {
                  final id = _sections[i].id;
                  if (!_open.remove(id)) _open.add(id);
                }),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            const _FooterAsk(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Đầu màn
// ---------------------------------------------------------------------------

class _BackLink extends StatelessWidget {
  const _BackLink();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('guide_back'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.pop(),
      child: const Padding(
        // Vùng bấm cao 44 theo chuẩn ngón tay, dù chữ chỉ cao 20.
        padding: EdgeInsets.only(top: 6, bottom: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_ios_new, size: 14, color: WrColors.muted),
            SizedBox(width: 6),
            Text(
              'Quay lại',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: WrColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WrEyebrow('HỒ SƠ'),
        const SizedBox(height: 8),
        const Text(
          'Hướng dẫn sử dụng',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: WrColors.navy,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        // Gạch coral ngắn dưới tiêu đề. Đây là chi tiết duy nhất trên đầu màn
        // không mang chữ — nó tách phần tiêu đề khỏi phần thân, việc mà một
        // khoảng trắng thuần làm không đủ rõ trên nền xám.
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: WrColors.coral,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        const WrParagraph(
          kGuideIntro,
          style: TextStyle(fontSize: 14, color: WrColors.text2, height: 1.6),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thẻ Chatbot
// ---------------------------------------------------------------------------

class _ChatbotCard extends StatelessWidget {
  const _ChatbotCard();

  /// Chữ trên nền coral là NAVY pha loãng, không phải trắng (spec §03). Trắng
  /// trên coral vừa đủ tương phản để đọc nhưng làm thẻ mất hẳn giọng của brand
  /// — mọi thẻ đặc màu khác trong app đều dùng navy pha.
  static const _body = Color(0xD9093774);
  static const _quiet = Color(0xA6093774);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        key: const Key('guide_chat_card'),
        width: double.infinity,
        // Chuyển sắc rất nhẹ trên nền coral, sáng ở góc trên trái và trầm dần
        // xuống dưới phải. Bản trước đặt một vòng tròn trắng mờ ở góc — cùng
        // chi tiết với `WrCardDark` — nhưng thẻ này có chữ chạy sát mép phải,
        // nên vòng tròn cắt ngang tiêu đề và đọc ra như một vệt bẩn. Chuyển sắc
        // cho cùng cảm giác có chiều sâu mà không đụng vào chữ ở bất kỳ cỡ chữ
        // hệ thống nào.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF7767), Color(0xFFF75949)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: WrColors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 17,
                    color: WrColors.navy,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    kGuideChatTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: WrColors.navy,
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            const WrParagraph(
              kGuideChatLead,
              style: TextStyle(fontSize: 13.5, color: _body, height: 1.55),
            ),
            const SizedBox(height: 7),
            const WrParagraph(
              kGuideChatWhy,
              style: TextStyle(fontSize: 12.5, color: _quiet, height: 1.6),
            ),
            const SizedBox(height: 12),
            const _CoralRule(),
            const SizedBox(height: 10),
            const WrEyebrow('THỬ HỎI', color: _quiet),
            const SizedBox(height: 7),
            // Ví dụ câu hỏi thật, không phải lời mời chung chung: "hỏi
            // bất cứ điều gì" là lời mời khó nhận nhất — người dùng không
            // biết bắt đầu từ đâu nên không bắt đầu.
            //
            // Xếp thành hàng gói (`Wrap`) chứ không phải ba khối rộng hết
            // thẻ: ba câu ngắn nằm sát nhau đọc ra là "ví dụ", còn ba khối
            // lớn đọc ra là ba nút bấm được — mà chúng không bấm được.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in kGuideChatExamples)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: WrColors.white.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '“$q”',
                      style: WrText.serifQuote(
                        fontSize: 12,
                        color: WrColors.navy,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                key: const Key('guide_chat_cta'),
                onPressed: () => context.push(kGuideChatRoute),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.navy,
                  foregroundColor: WrColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Mở Chatbot',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 7),
                    Icon(Icons.arrow_forward_rounded, size: 17),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            // Câu dè dặt đặt DƯỚI nút, không phải trên: nó là điều cần
            // biết sau khi đã quyết định mở, không phải rào cản trước khi
            // quyết định.
            const WrParagraph(
              kGuideChatCaveat,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _quiet, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vạch kẻ mảnh trên nền coral.
class _CoralRule extends StatelessWidget {
  const _CoralRule();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: WrColors.white.withValues(alpha: 0.32));
  }
}

// ---------------------------------------------------------------------------
// Một mục gập/mở
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.expanded,
    required this.onTap,
  });

  final WrGuideSection section;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(18),
        // Mục đang mở viền coral nhạt thay vì viền xám. Người dùng mở ba mục
        // rồi cuộn xuống cuộn lên vẫn nhận ra mình đã mở những cái nào, kể cả
        // khi tiêu đề đã trôi khỏi màn.
        border: Border.all(
          color: expanded
              ? WrColors.coral.withValues(alpha: 0.38)
              : WrColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cả hàng tiêu đề là vùng bấm, không riêng mũi tên: mũi tên 18px là
          // đích quá nhỏ để trúng bằng ngón cái.
          InkWell(
            key: Key('guide_section_${section.id}'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionIcon(id: section.id, active: expanded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: WrColors.navy,
                            height: 1.35,
                            letterSpacing: -0.1,
                          ),
                        ),
                        // Tóm tắt chỉ hiện khi mục đang đóng. Mở ra rồi thì nó
                        // là bản nói lại của đoạn ngay dưới nó.
                        if (!expanded) ...[
                          const SizedBox(height: 3),
                          Text(
                            section.summary,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: WrColors.text3,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 180),
                      turns: expanded ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 21,
                        color: expanded ? WrColors.navy : WrColors.text3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // `AnimatedSize` cho phần thân: mở ra là trượt xuống chứ không nhảy
          // giật một nhịp. Khi đóng, thân bị GỠ khỏi cây widget chứ không chỉ
          // cao 0 — để `find.text` của test đọc đúng "chưa mở thì chưa có".
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: WrColors.lineSoft,
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < section.blocks.length; i++) ...[
                          if (i > 0) const SizedBox(height: 14),
                          _GuideBlockView(block: section.blocks[i]),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Ô icon vuông bo góc ở đầu mỗi mục.
class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.id, required this.active});

  final String id;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: active
            ? WrColors.coral.withValues(alpha: 0.14)
            : WrColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        // Mã lạ thì rơi về dấu chấm tròn — thêm một mục vào bộ chữ mà quên khai
        // icon thì mất một icon, không vỡ hàng.
        _kSectionIcons[id] ?? Icons.circle_outlined,
        size: 18,
        // Coral đặc trên nền coral 14% đủ tương phản; dùng `pillCoralText` cho
        // chắc, đây là tông coral đã chỉnh cho chữ/icon trên nền nhạt.
        color: active ? WrColors.pillCoralText : WrColors.navy,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Các khối nội dung
// ---------------------------------------------------------------------------

class _GuideBlockView extends StatelessWidget {
  const _GuideBlockView({required this.block});

  final WrGuideBlock block;

  @override
  Widget build(BuildContext context) {
    // `switch` vét cạn trên sealed class: thêm một kiểu khối mà quên dựng
    // widget thì compiler chặn ngay, không để lại khoảng trống trên màn.
    return switch (block) {
      WrGuideText(:final text) => WrParagraph(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: WrColors.text2,
          height: 1.75,
        ),
      ),
      WrGuideNote(:final text) => _NoteBlock(text: text),
      WrGuideBullets(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _BulletRow(item: items[i]),
          ],
        ],
      ),
      WrGuideSteps(:final items) => _StepsBlock(items: items),
      WrGuideTwoColumn(:final rows) => _TabTable(rows: rows),
      WrGuideQa(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1, color: WrColors.lineSoft),
              const SizedBox(height: 14),
            ],
            _QaRow(item: items[i]),
          ],
        ],
      ),
    };
  }
}

/// Câu lưu ý — nền teal nhạt kèm một thanh teal đặc bên trái.
///
/// Chỉ tô nền nhạt thôi thì khối này trôi lẫn vào thẻ trắng bao quanh nó; thanh
/// dọc là thứ khiến nó đọc ra là "một câu được tách riêng ra để nói".
class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: WrColors.teal),
            Expanded(
              child: Container(
                color: WrColors.teal.withValues(alpha: 0.07),
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                child: WrParagraph(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: WrColors.dark,
                    height: 1.7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.item});

  final WrGuideBullet item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7, right: 9),
          child: SizedBox(
            width: 5,
            height: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: WrColors.teal,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Không có nhãn gói cạnh tên tính năng (bỏ 26/08/2026, cùng lý do
              // với bảng so sánh gói — xem đầu `wr_user_guide.dart`). Màn này
              // chỉ nói tính năng làm gì; chuyện gói nào có nằm ở Paywall.
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              WrParagraph(
                item.text,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: WrColors.text2,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Các bước đánh số, nối nhau bằng một sợi dọc.
///
/// Sợi nối là chi tiết đáng giá nhất của khối này: không có nó thì năm bước đọc
/// ra là năm gạch đầu dòng có đánh số, còn có nó thì đọc ra là MỘT ĐƯỜNG ĐI —
/// đúng thứ luồng nhìn lại thật sự là.
class _StepsBlock extends StatelessWidget {
  const _StepsBlock({required this.items});

  final List<WrGuideStep> items;

  static const double _gutter = 26;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _gutter,
                  child: Column(
                    children: [
                      _StepBadge(index: i + 1),
                      if (i < items.length - 1)
                        Expanded(
                          child: Center(
                            child: Container(width: 1.5, color: WrColors.line),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < items.length - 1 ? 16 : 0,
                    ),
                    child: _StepBody(step: items[i]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _StepsBlock._gutter,
      height: _StepsBlock._gutter,
      decoration: BoxDecoration(
        color: WrColors.navy.withValues(alpha: 0.07),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$index',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: WrColors.navy,
          ),
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.step});

  final WrGuideStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Kéo tiêu đề xuống cho khớp tâm chữ với số trong vòng tròn bên trái.
          padding: const EdgeInsets.only(top: 2),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 7,
            runSpacing: 4,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                  height: 1.4,
                ),
              ),
              // "Bỏ qua được" nói ở ĐÚNG bước bỏ qua được. Gom xuống cuối mục
              // thì người bỏ dở giữa chừng — đúng người cần biết — lại là người
              // không đọc tới đó.
              //
              // Dùng `Wrap` chứ không `Row`: tiêu đề dài gặp cỡ chữ hệ thống to
              // thì nhãn tự xuống dòng thay vì bị bóp lại thành "bỏ q…".
              if (step.optional)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: WrColors.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'bỏ qua được',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: WrColors.text3,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        WrParagraph(
          step.text,
          style: const TextStyle(
            fontSize: 13.5,
            color: WrColors.text2,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

/// Bảng "tab nào trả lời câu hỏi gì".
///
/// Cột phải in nghiêng serif vì bốn dòng đó là CÂU HỎI CỦA NGƯỜI DÙNG tự hỏi
/// mình ("Hôm nay tôi thế nào?"), không phải chữ giao diện. Serif nghiêng là
/// giọng dành cho lời trích trong cả app — dùng ở đây là dùng đúng chỗ.
class _TabTable extends StatelessWidget {
  const _TabTable({required this.rows});

  final List<WrGuideTwoColumnRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < rows.length - 1 ? 10 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 116,
                  child: Row(
                    children: [
                      Icon(
                        _kTabIcons[rows[i].left] ?? Icons.circle_outlined,
                        size: 15,
                        color: WrColors.navy,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          rows[i].left,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: WrColors.navy,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].right,
                    style: WrText.serifQuote(
                      fontSize: 13.5,
                      color: WrColors.text2,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _QaRow extends StatelessWidget {
  const _QaRow({required this.item});

  final WrGuideQaItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        WrParagraph(
          item.answer,
          style: const TextStyle(
            fontSize: 13.5,
            color: WrColors.text2,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dòng chốt
// ---------------------------------------------------------------------------

/// Dòng cuối màn — và là lối vào Chatbot thứ hai.
///
/// Người đọc hết tám mục mà vẫn chưa thấy câu trả lời là người cần Chatbot nhất,
/// nhưng lúc đó thẻ coral đã trôi khỏi màn từ lâu. Bắt họ cuộn ngược lên đầu để
/// bấm một cái nút họ vừa đọc qua là bắt họ làm việc của phần mềm.
class _FooterAsk extends StatelessWidget {
  const _FooterAsk();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('guide_chat_footer'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(kGuideChatRoute),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(16),
          // Viền coral nhạt thay vì viền xám: nó khác hẳn tám thẻ mục ngay
          // phía trên, nên không bị đọc nhầm thành "mục thứ chín".
          border: Border.all(color: WrColors.coral.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 17,
              color: WrColors.coral,
            ),
            const SizedBox(width: 11),
            // Chữ CĂN TRÁI, không căn giữa. Bản trước căn giữa và để icon ở
            // cạnh: câu này dài hơn một dòng nên icon rơi vào giữa hai dòng,
            // trông như bị bỏ quên ở đó.
            const Expanded(
              child: WrParagraph(
                'Còn điều gì chưa rõ, cứ hỏi thẳng Chatbot.',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: WrColors.coral,
            ),
          ],
        ),
      ),
    );
  }
}
