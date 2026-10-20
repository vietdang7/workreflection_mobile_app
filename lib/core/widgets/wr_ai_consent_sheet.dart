// Màn xin phép gửi dữ liệu sang dịch vụ AI bên thứ ba.
//
// Đây là thứ Apple đòi ở Guideline 5.1.1(i) / 5.1.2(i) và là thứ bản 1.0 (6)
// không có. Nội dung lấy từ `wr_ai_disclosure.dart` chứ không viết thẳng ở đây:
// cùng một bản công bố phải dùng cho cả lần hỏi đầu lẫn màn xem lại trong Tài
// khoản, hai chỗ nói khác nhau là tự mâu thuẫn.
//
// ---------------------------------------------------------------------------
// BA QUY TẮC CỦA MÀN NÀY, ĐỀU CÓ LÝ DO
//
//   1. KHÔNG có nút X, không đóng được bằng cách chạm ra ngoài. Đóng bằng cách
//      lơ đi thì không rõ người dùng đã trả lời gì, mà app thì cần một câu trả
//      lời rõ ràng trước khi gửi bất cứ thứ gì.
//
//   2. Nút "Để sau" NGANG HÀNG với nút "Đồng ý", không phải một dòng chữ mờ ở
//      góc. Một lựa chọn bị vẽ cho khó thấy thì không còn là lựa chọn.
//
//   3. Danh sách bên nhận nêu ĐÍCH DANH và kèm link chính sách của từng bên.
//      "các đối tác công nghệ" là cách nói tránh, và Apple đòi "identify who the
//      data is sent to".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/wr_tr.dart';
import '../logic/wr_ai_disclosure.dart';
import '../theme/wr_colors.dart';
import 'wr_paragraph.dart';
import '../../features/wr/ai_consent_providers.dart';

/// Kết quả người dùng chọn.
enum WrAiConsentChoice { granted, declined }

/// Mở màn xin phép và trả về lựa chọn.
///
/// Trả null khi màn bị đóng mà không có lựa chọn nào (chỉ xảy ra nếu người dùng
/// bấm nút Back cứng của Android) — người gọi phải coi đó là CHƯA đồng ý.
Future<WrAiConsentChoice?> showWrAiConsentSheet(BuildContext context) {
  return showModalBottomSheet<WrAiConsentChoice>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ConsentSheet(),
  );
}

/// Cổng chặn đặt trước MỌI hành động có gửi dữ liệu sang AI.
///
/// Trả true khi được phép đi tiếp. Chưa trả lời thì hỏi ngay tại chỗ; đã từ
/// chối thì trả false mà KHÔNG hỏi lại — hỏi tới hỏi lui cho tới khi người ta
/// bấm bừa là ép buộc, không phải xin phép. Muốn bật lại thì vào Tài khoản, và
/// [kWrAiRevokeNote] đã nói với họ điều đó ngay lúc từ chối.
///
/// Người gọi phải `await` và dừng lại khi trả false. Đây là chốt chặn ở phía
/// app; máy chủ còn kiểm lại lần nữa trước khi gọi OpenRouter.
Future<bool> ensureAiConsent(BuildContext context, WidgetRef ref) async {
  final consent = await ref.read(wrAiConsentProvider.future);
  if (consent.isGranted) return true;
  if (consent.hasAnswered) return false;
  if (!context.mounted) return false;

  final choice = await showWrAiConsentSheet(context);
  return choice == WrAiConsentChoice.granted;
}

Future<void> openAiPrivacyUrl(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wrKeepCompounds(tr('Không mở được trang này.', 'Could not open this page.')),
        ),
      ),
    );
  }
}

class _ConsentSheet extends ConsumerStatefulWidget {
  const _ConsentSheet();

  @override
  ConsumerState<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends ConsumerState<_ConsentSheet> {
  bool _saving = false;

  Future<void> _answer(bool grant) async {
    setState(() => _saving = true);
    final controller = ref.read(wrAiConsentControllerProvider);
    final ok = grant ? await controller.grant() : await controller.revoke();
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      // Ghi hỏng thì KHÔNG đóng màn và KHÔNG trả về "đã đồng ý". Trả về bừa là
      // app tưởng được phép rồi gửi dữ liệu đi, trong khi máy chủ vẫn thấy chưa
      // đồng ý và sẽ chặn — người dùng nhận một lỗi khó hiểu ở màn khác.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wrKeepCompounds(tr(
              'Chưa lưu được lựa chọn. Bạn kiểm tra mạng rồi thử lại.',
              'Your choice was not saved. Check your connection and try again.',
            )),
          ),
        ),
      );
      return;
    }

    Navigator.of(
      context,
    ).pop(grant ? WrAiConsentChoice.granted : WrAiConsentChoice.declined);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
                children: const [WrAiDisclosureBody()],
              ),
            ),
            _Actions(saving: _saving, onAnswer: _answer),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.saving, required this.onAnswer});

  final bool saving;
  final Future<void> Function(bool grant) onAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      decoration: const BoxDecoration(
        color: WrColors.white,
        border: Border(top: BorderSide(color: WrColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('wr_ai_consent_accept'),
              onPressed: saving ? null : () => onAnswer(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                wrKeepCompounds(saving
                    ? tr('Đang lưu…', 'Saving…')
                    : tr('Bật phần đọc hiểu bằng AI', 'Turn on AI understanding')),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('wr_ai_consent_decline'),
              onPressed: saving ? null : () => onAnswer(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: WrColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: WrColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                wrKeepCompounds(tr('Để sau', 'Not now')),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phần nội dung công bố, tách riêng để màn Tài khoản dùng lại nguyên văn.
class WrAiDisclosureBody extends StatelessWidget {
  const WrAiDisclosureBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wrKeepCompounds(tr(
            'Phần đọc hiểu bằng AI hoạt động như thế nào',
            'How AI understanding works in WorkReflection',
          )),
          key: const Key('wr_ai_consent_title'),
          style: const TextStyle(
            fontSize: 19.5,
            fontWeight: FontWeight.w800,
            color: WrColors.navy,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          wrKeepCompounds(tr(
            'WorkReflection dùng AI ở một vài chỗ để đồng hành cùng bạn:',
            'WorkReflection uses AI in a few places to accompany you:',
          )),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: WrColors.navy,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _OverviewFeatureCard(
          title: tr('Người đồng hành', 'Companion'),
          desc: tr(
            'Trò chuyện cùng bạn về hành trình nhìn lại.',
            'Chat with you about your reflection journey.',
          ),
        ),
        const SizedBox(height: 8),
        _OverviewFeatureCard(
          title: tr('Diễn biến trong tab Hành trình', 'Your story in Journey tab'),
          desc: tr(
            'Đọc lại nhiều lần nhìn lại của bạn để viết bản tổng kết một chặng.',
            'Reflect on your look-backs to summarize a period.',
          ),
        ),
        const SizedBox(height: 8),
        _OverviewFeatureCard(
          title: tr('Bạn đang khó ở chỗ nào (tab Hiểu mình)', 'Where it is hard for you (Understand tab)'),
          desc: tr(
            'Đọc ra điểm khó thật từ những gì bạn đã viết.',
            'Identify genuine challenges from what you have logged.',
          ),
        ),
        const SizedBox(height: 8),
        _OverviewFeatureCard(
          title: tr('Bối cảnh công việc', 'Work context'),
          desc: tr(
            'Đọc bản mô tả công việc (JD) hoặc hồ sơ năng lực (CV) bạn tải lên để hiểu vai trò của bạn.',
            'Read the job description (JD) or resume (CV) you upload to understand your role.',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          wrKeepCompounds(tr(
            'Bốn phần này gửi nội dung tới DeepSeek, một mô hình ngôn ngữ của bên thứ ba.',
            'These four parts send content to DeepSeek, a third-party language model.',
          )),
          style: const TextStyle(
            fontSize: 13,
            color: WrColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: WrColors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WrColors.teal.withValues(alpha: 0.15)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wrKeepCompounds(tr('ĐIỀU BẠN NÊN BIẾT', 'WHAT YOU SHOULD KNOW')),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: WrColors.pillTealText,
                ),
              ),
              const SizedBox(height: 12),
              _PeaceOfMindRow(
                title: tr('Nội dung được gửi', 'What is sent'),
                desc: tr(
                  'Thông tin bạn viết trong các lần nhìn lại và JD/CV. Họ tên, email, số điện thoại, địa chỉ và các dòng liên lạc cá nhân đều được xoá tự động trước khi gửi.',
                  'Information from your look-backs, JD, or CV. Names, emails, phone numbers, addresses, and contacts are automatically removed before sending.',
                ),
              ),
              const SizedBox(height: 10),
              _PeaceOfMindRow(
                title: tr('Bạn luôn là người quyết định', 'You always decide'),
                desc: tr(
                  'Mỗi điều AI đọc ra chỉ là một gợi ý. Bạn có thể đồng ý, không đồng ý, hoặc viết lại cho đúng ý mình. Phần bạn viết lại là phần duy nhất được lưu.',
                  'Everything the AI reads is just a suggestion. You can agree, disagree, or rewrite it. Only what you rewrite is saved.',
                ),
              ),
              const SizedBox(height: 10),
              _PeaceOfMindRow(
                title: tr('Bật tắt lúc nào cũng được', 'Switch on or off anytime'),
                desc: tr(
                  'Bạn có thể thay đổi trong Cài đặt tài khoản bất kỳ lúc nào.',
                  'You can change this in Account Settings at any time.',
                ),
              ),
              const SizedBox(height: 10),
              _PeaceOfMindRow(
                title: tr('Nếu bạn không chọn tính năng AI', 'If you do not choose AI'),
                desc: tr(
                  'Chỉ bốn phần kể trên tạm nghỉ, toàn bộ các tính năng khác của WorkReflection vẫn chạy đủ.',
                  'Only the four parts above pause; all other features of WorkReflection continue working fully.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        _SectionTitle(
          tr('CHI TIẾT CÁC LUỒNG DỮ LIỆU', 'DETAILED DATA FLOWS'),
        ),
        const SizedBox(height: 8),
        for (final flow in kWrAiDataFlows) ...[
          _FlowRow(flow: flow),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 8),
        _SectionTitle(tr('GỬI CHO AI', 'WHO IT GOES TO')),
        const SizedBox(height: 8),
        for (final r in kWrAiRecipients) ...[
          _RecipientRow(recipient: r),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 8),
        _SectionTitle(tr('KHÔNG BAO GIỜ GỬI', 'NEVER SENT')),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: WrColors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in kWrAiNeverSent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '·  ',
                        style: TextStyle(
                          fontSize: 13,
                          color: WrColors.pillTealText,
                        ),
                      ),
                      Expanded(
                        child: WrParagraph(
                          item,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: WrColors.navy,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        WrParagraph(
          kWrAiRevokeNote,
          key: const Key('wr_ai_consent_revoke_note'),
          style: const TextStyle(
            fontSize: 12,
            color: WrColors.muted,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      wrKeepCompounds(text),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: WrColors.muted,
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({required this.flow});
  final WrAiDataFlow flow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WrColors.line),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wrKeepCompounds(flow.trigger),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 5),
          WrParagraph(
            flow.data,
            style: const TextStyle(
              fontSize: 12.5,
              color: WrColors.navy,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            wrKeepCompounds('→ ${flow.recipient}'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WrColors.pillTealText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({required this.recipient});
  final WrAiRecipient recipient;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wrKeepCompounds(recipient.name),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              WrParagraph(
                recipient.role,
                style: const TextStyle(
                  fontSize: 12,
                  color: WrColors.muted,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => openAiPrivacyUrl(context, recipient.privacyUrl),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              wrKeepCompounds(tr('Chính sách', 'Policy')),
              style: const TextStyle(
                fontSize: 11.5,
                color: WrColors.pillTealText,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewFeatureCard extends StatelessWidget {
  const _OverviewFeatureCard({required this.title, required this.desc});
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WrColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wrKeepCompounds(title),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            wrKeepCompounds(desc),
            style: const TextStyle(
              fontSize: 12.5,
              color: WrColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeaceOfMindRow extends StatelessWidget {
  const _PeaceOfMindRow({required this.title, required this.desc});
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 15,
              color: WrColors.pillTealText,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                wrKeepCompounds(title),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 21),
          child: Text(
            wrKeepCompounds(desc),
            style: const TextStyle(
              fontSize: 12.5,
              color: WrColors.navy,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

