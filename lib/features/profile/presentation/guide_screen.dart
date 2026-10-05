// "Hướng dẫn sử dụng" — mục trong Hồ sơ, yêu cầu §4 họp 26_1.
//
// Bộ chữ nằm ở `lib/core/logic/wr_user_guide.dart`; màn này chỉ dựng. Tách như
// vậy vì chữ là thứ khách còn sửa nhiều vòng, còn bố cục thì không — và vì mọi
// con số trong hướng dẫn phải đọc từ hằng số của app, thứ dễ kiểm tra bằng test
// thuần Dart hơn là bằng widget test.
//
// ---------------------------------------------------------------------------
// Ba quyết định về bố cục
// ---------------------------------------------------------------------------
//
// 1. GẬP/MỞ, không phải một trang chữ dài. Bản Word đọc một mạch từ trên xuống
//    được vì người đọc đang ngồi đọc tài liệu. Người mở màn này thì đang mắc ở
//    một chỗ cụ thể ("cái Career Snapshot kia là gì") — các tiêu đề nhìn thấy
//    hết trong một màn là cách nhanh nhất để họ tới đúng chỗ. Mỗi tiêu đề kèm
//    một dòng tóm tắt, nên gập lại vẫn đọc được bên trong có gì.
//
// 2. TRỢ LÝ AI NẰM NGOÀI DANH SÁCH. Khách chốt hướng dẫn phải làm nổi bật trợ
//    lý; một mục thứ tư trong mười một mục thì không nổi bật. Nó là thẻ riêng,
//    luôn mở, có nút mở thẳng trợ lý.
//
// 3. CHIA CỤM BẰNG NHÃN NHỎ. Mười một mục xếp thẳng một hàng đọc ra là một
//    danh sách dài; bản v4 chia thành bốn cụm (Bắt đầu · Bốn tab chính ·
//    Thông tin công việc · Tài khoản và hỗ trợ) và mắt biết mình đang ở đâu.
//
// ---------------------------------------------------------------------------
// Màu: theo bản v4 về CÁCH DÙNG, theo brand identity về HEX
// ---------------------------------------------------------------------------
//
// Bản mockup v4 dùng một dải xám trung tính (#1F2937 · #6B7280 · #5B6472 ·
// #8A93A3) mà spec §01b cấm — chữ phụ của WorkReflection luôn là Deep Space
// #2C335D pha alpha để giữ tông ấm cùng Navy, xem `wr_colors.dart`. Nên chỗ
// nào v4 chỉ định một sắc xám thì ở đây là `text2`/`text3` tương ứng, không
// chép hex.
//
// Còn CÁCH dùng màu thì theo v4 sát:
//   • gạch coral 48×4 dưới tiêu đề màn;
//   • callout có viền trái 4px — teal cho mẹo dùng, coral cho phần Premium
//     (trước đây chỉ có một tông teal cho cả hai);
//   • số thứ tự là chấm navy ĐẶC chữ trắng, không phải navy pha loãng;
//   • thẻ trợ lý là panel navy nhạt với ô biểu tượng coral, thay cho thẻ coral
//     đặc của bản 26/08. `#F1F4F9` của v4 là xám ngả xanh, tức navy pha rất
//     loãng — chép thẳng hex đó lên nền `#F4F4F6` thì thẻ biến mất, nên dựng
//     bằng `navy` pha alpha;
//   • thẻ chốt màn cùng họ navy nhạt, bấm được để mở trợ lý.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_user_guide.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../../onboarding/intro_video_script.dart';
import '../../onboarding/presentation/wr_intro_video_sheet.dart';

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
    // Nhãn cụm chỉ in ở mục ĐẦU của cụm. So với mục liền trước chứ không đếm
    // trước thành từng nhóm: thứ tự mục là thứ tự hiển thị, nên so hàng xóm là
    // đủ và không phải dựng thêm một cấu trúc lồng.
    //
    // Dựng bằng vòng lặp thường chứ không phải `collection-for` trong
    // `children`: biến `previousGroup` phải nhích theo lúc DỰNG DANH SÁCH, mà
    // trong collection-for thì không đặt được câu lệnh gán.
    final sectionWidgets = <Widget>[];
    String? previousGroup;
    for (final section in _sections) {
      if (section.group != previousGroup) {
        if (previousGroup != null) {
          sectionWidgets.add(const SizedBox(height: 10));
        }
        sectionWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: WrEyebrow(section.group),
          ),
        );
        previousGroup = section.group;
      }
      sectionWidgets.add(
        _SectionCard(
          section: section,
          expanded: _open.contains(section.id),
          onTap: () => setState(() {
            if (!_open.remove(section.id)) _open.add(section.id);
          }),
        ),
      );
      sectionWidgets.add(const SizedBox(height: 10));
    }

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
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_back_ios_new,
                        size: 14,
                        color: WrColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tr('Quay lại', 'Back'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: WrColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            WrEyebrow(tr('HỒ SƠ', 'PROFILE')),
            const SizedBox(height: 8),
            Text(
              tr('Hướng dẫn sử dụng', 'User guide'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: WrColors.navy,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            // Gạch coral dưới tiêu đề (`.rule` của v4).
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: WrColors.coral,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            WrParagraph(
              kGuideIntro,
              style: const TextStyle(
                fontSize: 14.5,
                color: WrColors.text2,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            const _GuideVideoShowcase(),
            const SizedBox(height: 16),
            const _AssistantCard(),
            const SizedBox(height: 20),
            ...sectionWidgets,
            const SizedBox(height: 8),
            // Thẻ chốt: hướng dẫn không phải hợp đồng, và người đọc tới đây vẫn
            // còn thắc mắc thì đã có sẵn chỗ hỏi — chính trợ lý ở trên.
            const _ClosingCta(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video hướng dẫn sử dụng (Showcase & Playlist)
// ---------------------------------------------------------------------------

class _GuideVideoTopic {
  const _GuideVideoTopic({
    required this.id,
    required this.number,
    required this.tabLabel,
    required this.heroTitle,
    required this.chapterTitle,
    required this.subtitle,
    required this.imageAsset,
    required this.duration,
    required this.sceneId,
  });

  final String id;
  final String number;
  final String tabLabel;
  final String heroTitle;
  final String chapterTitle;
  final String subtitle;
  final String imageAsset;
  final String duration;
  final IntroSceneId sceneId;
}

class _GuideVideoShowcase extends StatefulWidget {
  const _GuideVideoShowcase();

  @override
  State<_GuideVideoShowcase> createState() => _GuideVideoShowcaseState();
}

class _GuideVideoShowcaseState extends State<_GuideVideoShowcase> {
  int _selectedIndex = 0;

  List<_GuideVideoTopic> get _topics => [
    _GuideVideoTopic(
      id: 'overview',
      number: '01',
      tabLabel: tr('Tổng quan', 'Overview'),
      heroTitle: tr('Xem lại video hướng dẫn', 'Watch the intro video again'),
      chapterTitle: tr('Tổng quan WorkReflection', 'WorkReflection Overview'),
      subtitle: tr(
        'Khám phá tổng quan WorkReflection và cách nhìn lại công việc mỗi ngày',
        'Overview of WorkReflection and how to reflect on work daily',
      ),
      imageAsset: 'assets/images/thumb_intro_overview.jpg',
      duration: '1:00',
      sceneId: IntroSceneId.welcome,
    ),
    _GuideVideoTopic(
      id: 'reflect',
      number: '02',
      tabLabel: tr('Hôm nay', 'Today'),
      heroTitle: tr(
        'Tab Hôm nay & Check-in cảm xúc',
        'Today tab & Emotion check-in',
      ),
      chapterTitle: tr(
        'Phản chiếu 3 phút & Chọn cảm xúc',
        '3-min reflection & emotions',
      ),
      subtitle: tr(
        'Cách check-in cảm xúc và 4 bước nhìn lại khoảnh khắc sự nghiệp',
        'How to check-in emotions and reflect on moments in 4 steps',
      ),
      imageAsset: 'assets/images/thumb_daily_reflect.jpg',
      duration: '1:00',
      sceneId: IntroSceneId.reflect,
    ),
    _GuideVideoTopic(
      id: 'understand',
      number: '03',
      tabLabel: tr('Hiểu mình', 'Understand'),
      heroTitle: tr(
        'Hiểu mình & Kế hoạch phát triển',
        'Understand self & Growth plan',
      ),
      chapterTitle: tr(
        'Mẫu hình lặp lại & Thực hành kỹ năng',
        'Repeating patterns & skills',
      ),
      subtitle: tr(
        'Nhận diện các mẫu hình lặp lại và kế hoạch thực hành kỹ năng',
        'Recognize repeating patterns and skill practice plan',
      ),
      imageAsset: 'assets/images/thumb_understand_grow.jpg',
      duration: '1:00',
      sceneId: IntroSceneId.understand,
    ),
    _GuideVideoTopic(
      id: 'assistant',
      number: '04',
      tabLabel: tr('Trợ lý AI', 'AI Assistant'),
      heroTitle: tr(
        'Đồng hành cùng Trợ lý AI Mentoring',
        'Companion with AI Mentor',
      ),
      chapterTitle: tr(
        'Trò chuyện & Tham vấn Trợ lý AI',
        'Chat & consult with AI Mentor',
      ),
      subtitle: tr(
        'Trò chuyện, hỏi đáp và nhận góc nhìn bám sát bối cảnh công việc',
        'Chat, ask questions, and get contextual work advice',
      ),
      imageAsset: 'assets/images/thumb_ai_mentor.jpg',
      duration: '1:00',
      sceneId: IntroSceneId.assistant,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final topics = _topics;
    final current = topics[_selectedIndex.clamp(0, topics.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: WrEyebrow(tr('VIDEO HƯỚNG DẪN', 'VIDEO TUTORIALS')),
        ),
        // Thẻ Video Hero lớn điện ảnh
        Semantics(
          button: true,
          label: current.heroTitle,
          child: GestureDetector(
            key: const Key('guide_replay_video'),
            behavior: HitTestBehavior.opaque,
            onTap: () => showIntroVideo(context, startScene: current.sceneId),
            child: Container(
              height: 204,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WrColors.line),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18093774),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Ảnh thumbnail
                  Image.asset(
                    current.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [WrColors.navy, Color(0xFF1B4E92)],
                        ),
                      ),
                    ),
                  ),
                  // Lớp phủ Gradient điện ảnh: tối dần về phía đáy
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.45, 1.0],
                        colors: [
                          Color(0x2E000000),
                          Color(0x55093774),
                          Color(0xEE093774),
                        ],
                      ),
                    ),
                  ),
                  // Huy hiệu chủ đề góc trên bên trái
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: WrColors.navy.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: WrColors.coral,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            current.tabLabel.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Huy hiệu thời lượng góc trên bên phải
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            current.duration,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Nút Play ở trung tâm
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: WrColors.coral,
                        boxShadow: [
                          BoxShadow(
                            color: WrColors.coral.withValues(alpha: 0.55),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Thông tin chữ đặt ở đáy thumbnail (lớp gradient)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          current.heroTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          current.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Danh sách 4 bài học hướng dẫn
        for (var i = 0; i < topics.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ChapterItem(
            key: Key('guide_video_chip_${topics[i].id}'),
            topic: topics[i],
            selected: i == _selectedIndex,
            onTap: () => setState(() => _selectedIndex = i),
            onPlay: () {
              setState(() => _selectedIndex = i);
              showIntroVideo(context, startScene: topics[i].sceneId);
            },
          ),
        ],
      ],
    );
  }
}

class _ChapterItem extends StatelessWidget {
  const _ChapterItem({
    super.key,
    required this.topic,
    required this.selected,
    required this.onTap,
    required this.onPlay,
  });

  final _GuideVideoTopic topic;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? WrColors.coral.withValues(alpha: 0.04)
                : WrColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? WrColors.coral : WrColors.line,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0E093774),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Badge số thứ tự
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? WrColors.coral
                      : WrColors.navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  topic.number,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : WrColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Tiêu đề & mô tả
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.chapterTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected ? WrColors.navy : WrColors.text2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topic.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: WrColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Nút Play nhỏ
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPlay,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? WrColors.coral.withValues(alpha: 0.12)
                        : WrColors.pageBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected
                            ? Icons.play_arrow_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 16,
                        color: selected ? WrColors.coral : WrColors.muted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        topic.duration,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? WrColors.coral : WrColors.muted,
                        ),
                      ),
                    ],
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
// Thẻ Trợ lý AI
// ---------------------------------------------------------------------------

class _AssistantCard extends StatelessWidget {
  const _AssistantCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('guide_chat_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WrColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WrColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ô biểu tượng coral — chỗ DUY NHẤT trên màn dùng coral đặc,
              // đúng spec §01 "một CTA chính mỗi màn".
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: WrColors.coral,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: WrColors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kGuideChatTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: WrColors.navy,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kGuideChatSubtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: WrColors.text3,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          WrParagraph(
            kGuideChatLead,
            style: const TextStyle(
              fontSize: 13.5,
              color: WrColors.text2,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          WrParagraph(
            kGuideChatWhy,
            style: const TextStyle(
              fontSize: 13.5,
              color: WrColors.text2,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          WrEyebrow(kGuideChatExamplesLabel),
          const SizedBox(height: 8),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: WrColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: WrColors.line),
                  ),
                  child: Text(
                    '“$q”',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WrColors.text2,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('guide_chat_cta'),
              onPressed: () => context.push(kGuideChatRoute),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.navy,
                foregroundColor: WrColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kGuideChatCta,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          WrParagraph(
            kGuideChatCaveat,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: WrColors.text3,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thẻ chốt màn
// ---------------------------------------------------------------------------

class _ClosingCta extends StatelessWidget {
  const _ClosingCta();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('guide_closing_cta'),
      onTap: () => context.push(kGuideChatRoute),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WrColors.navy.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WrColors.navy.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: WrColors.navy,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                kGuideClosingCta,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 17,
              color: WrColors.navy,
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(16),
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
                  _SectionIcon(icon: section.icon),
                  const SizedBox(width: 13),
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
                              height: 1.45,
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
                      color: WrColors.text3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
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

/// Vòng tròn biểu tượng bên trái tiêu đề mục (`.ico` của bản v4).
///
/// Hai tông đúng như v4: nền navy nhạt cho hầu hết mục, nền coral nhạt cho hai
/// mục "Ba bước để bắt đầu" và "Gói Premium có gì" — một cái là lối vào, một
/// cái là thứ phải trả tiền, cả hai đều muốn mắt dừng lại.
class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon});

  final WrGuideIcon icon;

  @override
  Widget build(BuildContext context) {
    // `switch` vét cạn: thêm một giá trị vào `WrGuideIcon` mà quên chọn glyph
    // thì compiler chặn ngay, không để lại một ô trống trên màn.
    final (glyph, coral) = switch (icon) {
      WrGuideIcon.compass => (Icons.explore_outlined, false),
      WrGuideIcon.flag => (Icons.flag_outlined, true),
      WrGuideIcon.eye => (Icons.visibility_outlined, false),
      WrGuideIcon.bulb => (Icons.lightbulb_outline_rounded, false),
      WrGuideIcon.bolt => (Icons.bolt_outlined, false),
      WrGuideIcon.trend => (Icons.trending_up_rounded, false),
      WrGuideIcon.briefcase => (Icons.work_outline_rounded, false),
      WrGuideIcon.person => (Icons.person_outline_rounded, false),
      // Cùng glyph Premium với phần còn lại của app (§17.2): vương miện, không
      // phải ngôi sao.
      WrGuideIcon.crown => (Icons.workspace_premium_outlined, true),
      WrGuideIcon.question => (Icons.help_outline_rounded, false),
    };

    final accent = coral ? WrColors.coral : WrColors.navy;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: coral ? 0.12 : 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(glyph, size: 21, color: accent),
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
      WrGuideHeading(:final text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: WrColors.dark,
          height: 1.4,
        ),
      ),
      WrGuideText(:final text) => WrParagraph(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: WrColors.text2,
          height: 1.7,
        ),
      ),
      WrGuideNote(:final text, :final tone) => _NoteBox(text: text, tone: tone),
      WrGuideChecks(:final items, :final footnote) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3, right: 10),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: WrColors.teal,
                    ),
                  ),
                  Expanded(
                    child: WrParagraph(
                      item,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: WrColors.text2,
                        height: 1.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: WrParagraph(
                footnote,
                style: const TextStyle(
                  fontSize: 13,
                  color: WrColors.text3,
                  height: 1.6,
                ),
              ),
            ),
        ],
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

/// Callout viền trái 4px — teal cho mẹo dùng, coral cho phần Premium.
class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text, required this.tone});

  final String text;
  final WrGuideNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      WrGuideNoteTone.teal => WrColors.teal,
      WrGuideNoteTone.coral => WrColors.coral,
    };
    final textColor = switch (tone) {
      WrGuideNoteTone.teal => WrColors.dark,
      WrGuideNoteTone.coral => WrColors.pillCoralText,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: WrParagraph(
        text,
        style: TextStyle(fontSize: 13, color: textColor, height: 1.65),
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
          padding: EdgeInsets.only(top: 7, right: 10),
          child: SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: WrColors.navy,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.dark,
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
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: WrColors.navy,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WrColors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                        color: WrColors.dark,
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
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: WrColors.navy.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tr('bỏ qua được', 'skippable'),
                        style: const TextStyle(
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
