// Xử lý dữ liệu bằng AI — màn xem lại và đổi ý.
//
// Bản công bố (`wr_ai_disclosure.dart`) hứa với người dùng rằng "bạn tắt lại
// bất cứ lúc nào trong Tài khoản → Xử lý dữ liệu bằng AI". Đây là chỗ đó. Hứa
// mà không có chỗ thực hiện thì lời hứa ấy là một câu nói dối nằm ngay trong
// màn xin phép.
//
// Apple cũng đọc kỹ phần này: Guideline 5.1.1(i) đòi người dùng kiểm soát được
// dữ liệu của họ, không chỉ được hỏi một lần rồi thôi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/wr_ai_consent_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_ai_consent_sheet.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../ai_consent_providers.dart';

class WrAiConsentScreen extends ConsumerStatefulWidget {
  const WrAiConsentScreen({super.key});

  @override
  ConsumerState<WrAiConsentScreen> createState() => _WrAiConsentScreenState();
}

class _WrAiConsentScreenState extends ConsumerState<WrAiConsentScreen> {
  bool _saving = false;

  Future<void> _toggle(bool turnOn) async {
    setState(() => _saving = true);
    final controller = ref.read(wrAiConsentControllerProvider);
    final ok = turnOn ? await controller.grant() : await controller.revoke();
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (turnOn
                    ? tr(
                        'Đã bật. Những phần cần AI dùng được rồi.',
                        'On. The AI features are ready to use.',
                      )
                    : tr(
                        'Đã tắt. App sẽ không gửi dữ liệu của bạn đi nữa.',
                        'Off. The app will no longer send your data anywhere.',
                      ))
              : tr(
                  'Chưa lưu được. Bạn kiểm tra mạng rồi thử lại.',
                  'Not saved. Check your connection and try again.',
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consent =
        ref.watch(wrAiConsentProvider).valueOrNull ?? WrAiConsent.unknown;
    final on = consent.isGranted;

    return WrDetailScaffold(
      eyebrow: tr('QUYỀN RIÊNG TƯ', 'PRIVACY'),
      title: tr('Xử lý dữ liệu bằng AI', 'AI data processing'),
      children: [
        Container(
          key: const Key('wr_ai_consent_status'),
          decoration: BoxDecoration(
            color: on ? WrColors.teal.withValues(alpha: 0.08) : WrColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: on ? WrColors.pillTealText : WrColors.line,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      on ? tr('Đang bật', 'On') : tr('Đang tắt', 'Off'),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: on ? WrColors.pillTealText : WrColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    WrParagraph(
                      on
                          ? tr(
                              'App được phép gửi dữ liệu nêu dưới đây sang các '
                                  'dịch vụ AI để xử lý.',
                              'The app may send the data listed below to AI '
                                  'services for processing.',
                            )
                          : tr(
                              'App không gửi dữ liệu của bạn đi đâu cả. Những '
                                  'phần cần AI đang ngừng hoạt động.',
                              'The app does not send your data anywhere. The '
                                  'AI features are switched off.',
                            ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: WrColors.navy,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('wr_ai_consent_switch'),
                value: on,
                onChanged: _saving ? null : _toggle,
                activeThumbColor: WrColors.pillTealText,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const WrAiDisclosureBody(),
        const SizedBox(height: 24),
      ],
    );
  }
}
