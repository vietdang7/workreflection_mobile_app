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

import '../logic/wr_ai_disclosure.dart';
import '../theme/wr_colors.dart';
import 'wr_paragraph.dart';
import '../../features/wr/ai_consent_providers.dart';

/// Kết quả người dùng chọn.
enum WrAiConsentChoice {
  granted,
  declined,
}

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
      const SnackBar(content: Text('Không mở được trang này.')),
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
        const SnackBar(
          content: Text('Chưa lưu được lựa chọn. Bạn kiểm tra mạng rồi thử lại.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      grant ? WrAiConsentChoice.granted : WrAiConsentChoice.declined,
    );
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
                children: const [
                  WrAiDisclosureBody(),
                ],
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
                saving ? 'Đang lưu…' : 'Đồng ý và tiếp tục',
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
              child: const Text(
                'Không, để sau',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
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
        const Text(
          'Trước khi dùng những phần có AI',
          key: Key('wr_ai_consent_title'),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: WrColors.navy,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        const WrParagraph(
          kWrAiDisclosureSummary,
          style: TextStyle(fontSize: 13.5, color: WrColors.navy, height: 1.6),
        ),
        const SizedBox(height: 20),

        const _SectionTitle('APP GỬI GÌ, KHI NÀO'),
        const SizedBox(height: 8),
        for (final flow in kWrAiDataFlows) ...[
          _FlowRow(flow: flow),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 8),
        const _SectionTitle('GỬI CHO AI'),
        const SizedBox(height: 8),
        for (final r in kWrAiRecipients) ...[
          _RecipientRow(recipient: r),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 8),
        const _SectionTitle('KHÔNG BAO GIỜ GỬI'),
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
        const WrParagraph(
          kWrAiRevokeNote,
          key: Key('wr_ai_consent_revoke_note'),
          style: TextStyle(fontSize: 12, color: WrColors.muted, height: 1.6),
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
      text,
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
            flow.trigger,
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
            '→ ${flow.recipient}',
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
                recipient.name,
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
          child: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Chính sách',
              style: TextStyle(
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
