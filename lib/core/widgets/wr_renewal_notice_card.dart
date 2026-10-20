// Thẻ nhắc trước khi kỳ thuê bao App Store kết thúc.
//
// Khách chốt 08/09/2026: gói tự động gia hạn, "nhưng phải thông báo nếu gần hết
// hạn". Toàn bộ phần quyết định NÓI GÌ nằm ở `wr_iap_renewal.dart`; file này
// chỉ vẽ.
//
// Thẻ tự biến mất khi không có gì để nói — nên chỗ nào cần cũng đặt được, không
// phải hỏi trước xem người dùng có thuê bao hay không.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/wr/iap_providers.dart';
import '../l10n/wr_tr.dart';
import '../logic/wr_iap_catalog.dart';
import '../logic/wr_iap_renewal.dart';
import '../theme/wr_colors.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

// Nút quản lý gói mở thẳng trang thuê bao của kho
// ([WrIapStore.manageSubscriptionsUrl]) chứ không hướng dẫn "vào Cài đặt → chạm
// tên bạn → …": một đường dẫn bấm được luôn thì người ta bấm, còn một lộ trình
// bốn bước thì người ta bỏ. Việc huỷ nằm hoàn toàn trong hệ thống của kho — app
// không chặn được và cũng không cần biết kết quả ngay, kho sẽ báo qua
// `wr-apple-notifications` / `wr-google-notifications`.

class WrRenewalNoticeCard extends ConsumerWidget {
  const WrRenewalNoticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(wrRenewalNoticeProvider);
    if (notice == null) return const SizedBox.shrink();

    // Sắp mất quyền thì viền coral cho nổi; sắp bị trừ tiền thì là tin bình
    // thường, dùng viền mảnh như mọi thẻ khác. Doạ người ta bằng màu ở một việc
    // họ đã đồng ý từ đầu là làm mòn chính màu đó.
    final urgent = notice.kind == WrRenewalKind.willEnd;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: urgent ? WrColors.coral : WrColors.line,
            width: urgent ? 1.4 : 1,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wrKeepCompounds(notice.title),
              key: const Key('wr_renewal_notice_title'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: WrColors.navy,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              wrKeepCompounds(notice.body),
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.text2,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              key: const Key('wr_renewal_notice_manage'),
              onTap: () => openWrManageSubscriptions(context),
              child: Text(
                wrKeepCompounds(
                  tr('Quản lý gói đăng ký', 'Manage subscription'),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WrColors.pillTealText,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mở trang quản lý thuê bao của kho đang bán (App Store hoặc Google Play).
///
/// Dùng chung cho thẻ nhắc gia hạn ở màn Tôi và trang Bản Premium.
Future<void> openWrManageSubscriptions(BuildContext context) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(WrIapStore.current.manageSubscriptionsUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wrKeepCompounds(
            tr(
              'Không mở được trang quản lý gói. Bạn vào '
                  '${WrIapStore.current.manageHint} nhé.',
              'Could not open subscription management. Go to '
                  '${WrIapStore.current.manageHint}.',
            ),
          ),
        ),
      ),
    );
  }
}
