// "Hướng dẫn sử dụng" — mục trong Hồ sơ, yêu cầu §4 họp 26_1.
//
// Bộ chữ nằm ở `lib/core/logic/wr_user_guide.dart`; màn này chỉ dựng. Tách như
// vậy vì chữ là thứ khách còn sửa nhiều vòng, còn bố cục thì không — và vì mọi
// con số trong hướng dẫn phải đọc từ hằng số của app, thứ dễ kiểm tra bằng test
// thuần Dart hơn là bằng widget test.
//
// ---------------------------------------------------------------------------
// Hai quyết định về bố cục
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_user_guide.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_paragraph.dart';

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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            if (GoRouter.maybeOf(context) != null && context.canPop())
              GestureDetector(
                key: const Key('guide_back'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.pop(),
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_new,
                          size: 14, color: WrColors.muted),
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
              ),
            const WrEyebrow('HỒ SƠ'),
            const SizedBox(height: 8),
            const Text(
              'Hướng dẫn sử dụng',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: WrColors.navy,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            const WrParagraph(
              kGuideIntro,
              style: TextStyle(
                fontSize: 14.5,
                color: WrColors.text2,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            const _ChatbotCard(),
            const SizedBox(height: 16),
            for (final section in _sections) ...[
              _SectionCard(
                section: section,
                expanded: _open.contains(section.id),
                onTap: () => setState(() {
                  if (!_open.remove(section.id)) _open.add(section.id);
                }),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            // Dòng chốt: hướng dẫn không phải hợp đồng, và người đọc tới đây
            // vẫn còn thắc mắc thì đã có sẵn chỗ hỏi — chính Chatbot ở trên.
            Center(
              child: WrParagraph(
                'Còn điều gì chưa rõ, cứ hỏi thẳng Chatbot.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: WrColors.text3,
                  height: 1.6,
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
// Thẻ Chatbot
// ---------------------------------------------------------------------------

class _ChatbotCard extends StatelessWidget {
  const _ChatbotCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('guide_chat_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WrColors.coral,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 18, color: WrColors.navy),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  kGuideChatTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: WrColors.navy,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // §03: chữ trên nền coral là navy pha loãng, không đổi sang trắng.
          const WrParagraph(
            kGuideChatLead,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xBF093774),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 6),
          const WrParagraph(
            kGuideChatWhy,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xBF093774),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
          // Ví dụ câu hỏi thật, không phải lời mời chung chung: "hỏi bất cứ
          // điều gì" là lời mời khó nhận nhất — người dùng không biết bắt đầu
          // từ đâu nên không bắt đầu.
          //
          // Xếp thành hàng gói (`Wrap`) chứ không phải ba khối rộng hết thẻ:
          // ba câu ngắn nằm sát nhau đọc ra là "ví dụ", còn ba khối lớn đọc ra
          // là ba nút bấm được — mà chúng không bấm được.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in kGuideChatExamples)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: WrColors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '“$q”',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WrColors.navy,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const WrParagraph(
            kGuideChatCaveat,
            style: TextStyle(
              fontSize: 12,
              color: Color(0x99093774),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('guide_chat_cta'),
            onPressed: () => context.push(kGuideChatRoute),
            style: ElevatedButton.styleFrom(
              backgroundColor: WrColors.navy,
              foregroundColor: WrColors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Mở Chatbot',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WrColors.line),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            height: 1.3,
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
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: expanded ? 0.5 : 0,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: WrColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final block in section.blocks) ...[
                    _GuideBlockView(block: block),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
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
            height: 1.7,
          ),
        ),
      WrGuideNote(:final text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: WrColors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: WrParagraph(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: WrColors.dark,
              height: 1.65,
            ),
          ),
        ),
      WrGuideBullets(:final items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BulletRow(item: item),
              ),
          ],
        ),
      WrGuideSteps(:final items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StepRow(index: i + 1, step: items[i]),
              ),
          ],
        ),
      WrGuideTwoColumn(:final rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        row.left,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.right,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: WrColors.text2,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      WrGuideQa(:final items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.question,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    WrParagraph(
                      item.answer,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: WrColors.text2,
                        height: 1.65,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
    };
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
          padding: EdgeInsets.only(top: 7, right: 8),
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
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.step});

  final int index;
  final WrGuideStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: WrColors.navy.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.45,
                      ),
                    ),
                  ),
                  // "Bỏ qua được" nói ở ĐÚNG bước bỏ qua được. Gom xuống cuối
                  // mục thì người bỏ dở giữa chừng — đúng người cần biết — lại
                  // là người không đọc tới đó.
                  if (step.optional) ...[
                    const SizedBox(width: 6),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
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
                ],
              ),
              const SizedBox(height: 3),
              WrParagraph(
                step.text,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: WrColors.text2,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
