// Khung chung cho mọi màn trong luồng phản tư.
//
// WXS §8.7 Focused Surface: một Meaning, một nhiệm vụ trên một màn.
// Khung này cố tình chỉ có ba chỗ: một câu hỏi, một khối nội dung, một nút.
// Không có chỗ cho thanh bên, thẻ phụ hay danh sách gợi ý.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/wr_tr.dart';
import '../../../../core/logic/wr_reflect_flow.dart' show moodCheckinLabel;
import '../../../../core/logic/wr_reflect_v47.dart';
import '../../../../core/models/checkin.dart';
import '../../../../core/widgets/wr_card.dart' show WrDashedRRectPainter;
import '../../../../core/widgets/wr_hero_header.dart';
import '../../episode_flow_controller.dart' show pendingMoodProvider;
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/widgets/wr_paragraph.dart';

/// Dáng chữ của câu hỏi lớn trong luồng (`.h1.serif` 20px của mockup v47).
///
/// Mockup viết bằng Lora đứng; app chỉ nhúng Lora nghiêng (cho câu trích), nên
/// câu hỏi dùng chữ chính của app, đậm vừa.
///
/// Tách ra khỏi [WrFlowScaffold] để màn nào tự dựng câu hỏi bên trong `child`
/// vẫn viết đúng một dáng chữ với các màn còn lại — hai chỗ gõ lại cùng một
/// TextStyle là hai chỗ sẽ lệch nhau.
const TextStyle wrFlowTitleStyle = TextStyle(
  fontSize: 21,
  fontWeight: FontWeight.w700,
  color: WrColors.navy,
  height: 1.45,
);

/// Khung một bước của luồng nhìn lại — mockup v47 (`screenReflectFlow`):
/// dải phong cảnh theo cảm xúc ở đỉnh, hàng nút lùi · bốn vạch · Đóng, nhãn
/// bước, câu hỏi, nội dung, rồi nút ở đáy.
class WrFlowScaffold extends ConsumerWidget {
  const WrFlowScaffold({
    super.key,
    this.title,
    this.titleScale = 1.0,
    required this.child,
    this.eyebrow,
    this.eyebrowNote,
    this.eyebrowTrailing,
    this.subtitle,
    this.progress,
    this.step,
    this.onBack,
    this.onClose,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.aboveActions,
    this.busy = false,
  });

  final String? title;

  /// Hệ số cỡ chữ của [title].
  final double titleScale;

  final String? eyebrow;

  /// Một đoạn chữ nhỏ ngay dưới nhãn bước.
  final String? eyebrowNote;

  /// Thứ đứng cạnh nhãn bước (bước 1: chip cảm xúc vừa chọn).
  final Widget? eyebrowTrailing;

  final String? subtitle;

  final Widget child;

  /// Cách cũ: tiến trình 0–1. Đổi ra số vạch khi không truyền [step].
  final double? progress;

  /// Bước hiện tại 0–3 — bốn vạch của `.rf-segs`.
  final int? step;

  final VoidCallback? onBack;
  final VoidCallback? onClose;

  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Khối nằm ngay trên nút chính (bước 1: hai lối "Xem tình huống khác").
  final Widget? aboveActions;

  final bool busy;

  int? get _segment {
    if (step != null) return step;
    final p = progress;
    if (p == null) return null;
    return ((p.clamp(0.0, 1.0) * kFlowSegments).ceil() - 1).clamp(
      0,
      kFlowSegments - 1,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = moodBandId(ref.watch(pendingMoodProvider));
    final hasActions =
        primaryLabel != null || secondaryLabel != null || aboveActions != null;
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: WrReflectBand(mood: mood),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FlowHeader(
                  segment: _segment,
                  onBack: onBack,
                  onClose: onClose,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                eyebrow!.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: WrColors.text3,
                                ),
                              ),
                              ?eyebrowTrailing,
                            ],
                          ),
                          SizedBox(height: eyebrowNote == null ? 8 : 6),
                        ],
                        if (eyebrowNote != null) ...[
                          WrParagraph(
                            eyebrowNote!,
                            key: const Key('wr_flow_eyebrow_note'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: WrColors.text2,
                              height: 1.55,
                            ),
                            textAlign: TextAlign.start,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (title != null)
                          WrParagraph(
                            title!,
                            style: titleScale == 1.0
                                ? wrFlowTitleStyle
                                : wrFlowTitleStyle.copyWith(
                                    fontSize:
                                        wrFlowTitleStyle.fontSize! * titleScale,
                                  ),
                            textAlign: TextAlign.start,
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          WrParagraph(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: WrColors.text2,
                              height: 1.6,
                            ),
                          ),
                        ],
                        if (title != null || subtitle != null)
                          const SizedBox(height: 20),
                        child,
                      ],
                    ),
                  ),
                ),
                if (hasActions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                    child: Column(
                      children: [
                        ?aboveActions,
                        if (primaryLabel != null)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const Key('wr_flow_primary'),
                              onPressed: busy ? null : onPrimary,
                              style: FilledButton.styleFrom(
                                backgroundColor: WrColors.coral,
                                foregroundColor: WrColors.navy,
                                disabledBackgroundColor: WrColors.line,
                                disabledForegroundColor: WrColors.text3,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: WrColors.navy,
                                      ),
                                    )
                                  : Text(
                                      primaryLabel!,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        if (secondaryLabel != null) ...[
                          const SizedBox(height: 8),
                          // `.btn-ghost`: viền navy nhạt, không nền.
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              key: const Key('wr_flow_secondary'),
                              onPressed: busy ? null : onSecondary,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: WrColors.navy,
                                minimumSize: const Size.fromHeight(50),
                                side: const BorderSide(
                                  color: Color(0x40093774),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                secondaryLabel!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Số vạch tiến trình của luồng v47.
const int kFlowSegments = kReflectV47Steps;

/// `.backrow`: nút lùi tròn · bốn vạch · "Đóng".
class _FlowHeader extends StatelessWidget {
  const _FlowHeader({this.segment, this.onBack, this.onClose});

  final int? segment;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: onBack == null
                ? null
                : Semantics(
                    button: true,
                    label: tr('Quay lại', 'Back'),
                    child: InkResponse(
                      key: const Key('wr_flow_back'),
                      onTap: onBack,
                      radius: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: WrColors.navy.withValues(alpha: 0.06),
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: segment == null
                  ? const SizedBox.shrink()
                  : Row(
                      key: const Key('wr_flow_segments'),
                      children: [
                        for (var k = 0; k < kFlowSegments; k++) ...[
                          if (k > 0) const SizedBox(width: 4),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: k <= segment!
                                    ? WrColors.navy
                                    : WrColors.navy.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          if (onClose != null)
            TextButton(
              key: const Key('wr_flow_close'),
              onPressed: onClose,
              style: TextButton.styleFrom(
                foregroundColor: WrColors.text2,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                tr('Đóng', 'Close'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            const SizedBox(width: 30),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Không còn phiên phản tư nào đang chạy — đưa người dùng về Home nhẹ nhàng.
// Xảy ra khi vào thẳng route của luồng hoặc sau khi phiên đã khép.
// ---------------------------------------------------------------------------

class WrFlowGone extends StatelessWidget {
  const WrFlowGone({super.key, required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return WrFlowScaffold(
      title: tr(
        'Phiên phản tư đã khép lại.',
        'This reflection session has closed.',
      ),
      subtitle: tr(
        'Bạn có thể bắt đầu một lần nhìn lại mới bất cứ lúc nào.',
        'You can start a new look back any time.',
      ),
      primaryLabel: tr('Về trang chủ', 'Back to home'),
      onPrimary: onHome,
      child: const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Ô chọn lớn — dùng chung cho màn năng lượng và màn Human Moment.
// ---------------------------------------------------------------------------

class WrBigChoiceTile extends StatelessWidget {
  const WrBigChoiceTile({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.height = 92,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Chiều cao TỐI THIỂU, không phải chiều cao cố định: nhãn tình huống dài hai
  /// dòng, và từ khi cỡ chữ tăng theo brand identity mới thì một ô cao cứng cắt
  /// mất dòng thứ hai. Ô nào cần cao hơn thì tự cao lên.
  final double height;

  /// Dòng chữ nhỏ phía trên nhãn. Dùng cho ô neo ở bước Notice ("Lần trước"),
  /// để người dùng nhận ra ngay đây là điều mình đã chọn lần rồi và chạm lại
  /// được — không có dấu này thì nó trông y hệt bốn gợi ý mới.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    // §03: chữ trên nền Coral là Navy, không phải trắng.
    const fg = WrColors.navy;
    final text = WrParagraph(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: fg,
      ),
      textAlign: TextAlign.start,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected ? WrColors.coral : WrColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: WrColors.line),
        ),
        child: badge == null
            ? text
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: selected
                          ? WrColors.navy.withValues(alpha: 0.75)
                          : WrColors.navy,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Flexible(child: text),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dòng chọn có nút tròn (`.opt.rf`, mockup v47)
// ---------------------------------------------------------------------------

/// Một lựa chọn trong danh sách có nút tròn. [custom] là dòng "Điều khác":
/// viền nét đứt, không nền, biểu tượng bút thay cho nút tròn.
class WrRadioOption extends StatelessWidget {
  const WrRadioOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.custom = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool custom;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));
    final Color bg = selected
        ? WrColors.coral.withValues(alpha: 0.07)
        : (custom ? Colors.transparent : WrColors.white);
    final leading = custom
        ? Icon(
            Icons.edit_outlined,
            size: 20,
            color: selected ? WrColors.coral : WrColors.text2,
          )
        : AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? WrColors.coral : Colors.transparent,
              border: Border.all(
                color: selected ? WrColors.coral : const Color(0x47093774),
                width: 1.5,
              ),
            ),
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: WrColors.white,
                  )
                : null,
          );
    Widget body = Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: WrParagraph(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: custom && !selected ? WrColors.text2 : WrColors.navy,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
    body = Material(
      type: MaterialType.transparency,
      child: InkWell(borderRadius: radius, onTap: onTap, child: body),
    );
    final borderColor = selected ? WrColors.coral : const Color(0x1F093774);
    return Semantics(
      selected: selected,
      button: true,
      child: custom
          ? CustomPaint(
              foregroundPainter: WrDashedRRectPainter(
                color: selected ? WrColors.coral : const Color(0x33093774),
                radius: 12,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: ColoredBox(color: bg, child: body),
              ),
            )
          : AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: radius,
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: body,
            ),
    );
  }
}

/// Chip cảm xúc vừa chọn (`.mood-chip`): chấm màu theo `RF_PAL` + tên.
class WrMoodChip extends StatelessWidget {
  const WrMoodChip({super.key, required this.mood});

  final Mood mood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: WrColors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WrColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: WrMoodPalette.dot(moodBandId(mood)),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              moodCheckinLabel(mood),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
