// Trà Chiều Nghề Nghiệp — chương trình offline của WorkReflection.
//
// Hai màn, đúng bố cục mockup Sprint 2 (`screenTraChieu` + `screenTraChieuCalendar`):
//
//   /wr/tra-chieu        vì sao lại là Trà Chiều, buổi sắp tới, một dòng dẫn
//                        sang lịch các buổi, rồi ba luật (thứ tự khách chốt
//                        2026-08-03)
//   /wr/tra-chieu/lich   toàn bộ lịch, mỗi buổi một dòng chữ
//
// ⚠ KHÔNG hiển thị ảnh ở bất kỳ đâu trong hai màn này (họp khách 2026-07-29).
//   `WorkshopDetail.imageUrl` có sẵn và cố tình không được đọc. Ảnh của web app
//   co lại trên khung điện thoại thì vỡ bố cục, mà đây là màn để đọc thông tin
//   chứ không phải để nhìn.
//
// Dữ liệu đến từ `cc_workshops` dùng chung với web app, lọc theo category
// (xem `wr_tra_chieu.dart`). App chỉ đọc — mọi buổi đều được tạo bên web.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logic/wr_tra_chieu.dart';
import '../../../core/models/workshop_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_link_row.dart';
import '../../workshops/workshops_providers.dart';

/// Ba luật của mọi buổi — nguyên văn theo mockup, không rút gọn.
const List<String> kTraChieuRules = [
  'Điều gì nói ở đây, ở lại đây. Mọi trích dẫn ra ngoài đều ẩn danh và cần '
      'người nói đồng ý.',
  'Không lời khuyên khi chưa được hỏi. Chỉ lắng nghe và hỏi lại.',
  'Được quyền im lặng. Có thể xin qua lượt bất kỳ lúc nào, không cần lý do.',
];

const String kTraChieuWhy =
    'Không phải hội thảo, không có sân khấu. Mười đến mười hai người ngồi quanh '
    'một bàn trà, cùng trả lời một câu hỏi duy nhất. Đây là chính trải nghiệm '
    'phản chiếu của WorkReflection, chỉ khác là được nói thành lời, trong một '
    'không gian an toàn.';

// ---------------------------------------------------------------------------

class WrTraChieuScreen extends ConsumerWidget {
  const WrTraChieuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshops = ref.watch(activeWorkshopsProvider).valueOrNull ?? const [];
    final next = nextTraChieu(workshops, now: DateTime.now());
    final upcoming = upcomingTraChieu(workshops, now: DateTime.now());

    return WrDetailScaffold(
      eyebrow: 'OFFLINE · $kTraChieuLabel',
      title: kTraChieuLabel,
      children: [
        const Text(
          '$kTraChieuFormatLabel.',
          style: TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
        ),
        const SizedBox(height: 22),

        // ── Vì sao lại là Trà Chiều ────────────────────────────────────
        //
        // Thứ tự màn (khách 2026-08-03): vì sao → buổi sắp tới → lịch các buổi
        // → ba luật. Nói "cái này là gì" trước rồi mới mời một buổi cụ thể;
        // ba luật là điều kiện tham dự nên đứng cuối, sau khi đã có lý do.
        WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Vì sao lại là Trà Chiều',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
              SizedBox(height: 10),
              Text(
                kTraChieuWhy,
                style: TextStyle(
                  fontSize: 14,
                  color: WrColors.dark,
                  height: 1.75,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ── Buổi sắp tới ───────────────────────────────────────────────
        if (next == null)
          const _NoSessionCard()
        else
          _NextSessionCard(session: next),

        // ── Lịch các buổi ──────────────────────────────────────────────
        const SizedBox(height: 18),
        WrLinkRow(
          key: const Key('wr_tra_chieu_calendar_row'),
          label: 'Xem lịch các buổi',
          hint: upcoming.isEmpty ? null : '${upcoming.length} buổi',
          onTap: () => context.push('/wr/tra-chieu/lich'),
        ),
        const SizedBox(height: 18),

        // ── Ba luật ────────────────────────────────────────────────────
        WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ba luật của mọi buổi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              for (final rule in kTraChieuRules) ...[
                if (rule != kTraChieuRules.first) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.check, size: 15, color: WrColors.teal),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rule,
                        style: const TextStyle(
                          fontSize: 14,
                          color: WrColors.dark,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thẻ navy "buổi sắp tới" — chủ đề, thời gian, địa điểm, giá, nút xem chi tiết.
// ---------------------------------------------------------------------------

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.session});

  final WorkshopDetail session;

  @override
  Widget build(BuildContext context) {
    return WrCardDark(
      key: const Key('wr_tra_chieu_next'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(
            'BUỔI SẮP TỚI',
            color: WrColors.cream.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            '"${session.title}"',
            style: const TextStyle(
              fontSize: 19,
              fontStyle: FontStyle.italic,
              color: WrColors.cream,
              height: 1.5,
            ),
          ),
          // Mô tả ngắn của buổi, nếu bên web có nhập. Chỉ ba dòng: đây là thẻ
          // để quyết định có đi hay không, không phải trang giới thiệu — phần
          // dài nằm bên web sau nút "Xem chi tiết".
          if (session.description != null &&
              session.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              session.description!.trim(),
              key: const Key('wr_tra_chieu_next_description'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: WrColors.cream.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: WrColors.cream.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          _DarkLine(traChieuWhenLabel(session)),
          if (session.location != null && session.location!.isNotEmpty)
            _DarkLine(session.location!),
          _DarkLine(traChieuSeatLabel(session)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('wr_tra_chieu_detail_button'),
              onPressed: () =>
                  openTraChieuOnWeb(context, traChieuUrlKey(session)),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Xem chi tiết và đăng ký',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          // Lối thứ hai: nhắn thẳng Zalo. Giữ chỗ một buổi 10–12 người là việc
          // của người tổ chức chứ không cần một form đăng ký, nên với nhiều
          // người đây mới là đường ngắn nhất.
          if (kTraChieuZaloUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('wr_tra_chieu_zalo_button'),
                onPressed: () => openTraChieuZalo(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WrColors.cream,
                  side: BorderSide(
                    color: WrColors.cream.withValues(alpha: 0.3),
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Nhắn Zalo để giữ một ghế',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkLine extends StatelessWidget {
  const _DarkLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: WrColors.cream.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _NoSessionCard extends StatelessWidget {
  const _NoSessionCard();

  @override
  Widget build(BuildContext context) {
    return const WrCardMinimal(
      key: Key('wr_tra_chieu_empty'),
      child: Text(
        'Chưa có buổi nào được mở. Lịch Trà Chiều thường được công bố trước '
        'khoảng hai tuần.',
        style: TextStyle(fontSize: 14, color: WrColors.muted, height: 1.7),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lịch các buổi — mỗi buổi một dòng CHỮ: chủ đề, ngày giờ, địa điểm, giá.
// ---------------------------------------------------------------------------

class WrTraChieuCalendarScreen extends ConsumerWidget {
  const WrTraChieuCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshops = ref.watch(activeWorkshopsProvider).valueOrNull ?? const [];
    final sessions = upcomingTraChieu(workshops, now: DateTime.now());

    return WrDetailScaffold(
      eyebrow: kTraChieuLabel.toUpperCase(),
      title: 'Lịch các buổi',
      children: [
        if (sessions.isEmpty)
          const Text(
            'Chưa có buổi nào được mở.',
            key: Key('wr_tra_chieu_calendar_empty'),
            style: TextStyle(fontSize: 14, color: WrColors.muted, height: 1.7),
          )
        else
          for (final s in sessions) ...[
            _SessionRow(session: s),
            if (s != sessions.last) const SizedBox(height: 12),
          ],
        const SizedBox(height: 22),
        const Text(
          'Chủ đề đổi mỗi buổi. Định kỳ hai tuần một lần, chiều thứ Bảy.',
          style: TextStyle(fontSize: 13, color: WrColors.muted, height: 1.7),
        ),
      ],
    );
  }
}

/// Một buổi trong lịch.
///
/// Khách 2026-07-30: "thêm cho tôi cái nút để chuyển tới, chứ để chạm vào là
/// chuyển như vậy dễ chạm nhầm lắm, chỉ vuốt lên thôi mà vô tình chạm cũng bất
/// tiện". Nên cả thẻ KHÔNG còn bắt chạm nữa — chỉ nút mới rời khỏi app. Đây là
/// hành động một chiều (mở trình duyệt, mất ngữ cảnh đang đọc), loại hành động
/// không được phép xảy ra do một cú vuốt trượt tay.
///
/// Bố cục: ngày giờ trên một dải kem đậm, tên buổi, mô tả ngắn, rồi hai dòng
/// địa điểm và giá có icon dẫn, cuối cùng là nút. Đủ năm thứ khách liệt kê cho
/// tab này, tất cả bằng chữ.
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final WorkshopDetail session;

  @override
  Widget build(BuildContext context) {
    final location = session.location?.trim();
    final description = session.description?.trim();

    return WrCardMinimal(
      key: Key('wr_tra_chieu_session_${session.id}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: WrColors.white,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              traChieuWhenLabel(session),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WrColors.coral,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '"${session.title}"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.4,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (location != null && location.isNotEmpty)
            _MetaLine(icon: Icons.place_outlined, text: location),
          _MetaLine(
            icon: Icons.local_activity_outlined,
            text: traChieuSeatLabel(session),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: Key('wr_tra_chieu_session_button_${session.id}'),
              onPressed: () =>
                  openTraChieuOnWeb(context, traChieuUrlKey(session)),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.navy,
                foregroundColor: WrColors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Xem chi tiết và đăng ký',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng thông tin phụ: icon dẫn + chữ.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: WrColors.coral),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.dark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Mở trang chi tiết của buổi trên web app.
///
/// Không mở được (không có trình duyệt, không mạng) thì nói ra chứ không im
/// lặng: người dùng vừa bấm một nút và phải biết vì sao không có gì xảy ra.
Future<void> openTraChieuOnWeb(BuildContext context, String workshopId) =>
    _open(context, traChieuWebUrl(workshopId), 'Không mở được trang chi tiết.');

/// Mở Zalo để giữ chỗ. Chỉ gọi khi [kTraChieuZaloUrl] có giá trị.
Future<void> openTraChieuZalo(BuildContext context) =>
    _open(context, kTraChieuZaloUrl, 'Không mở được Zalo.');

Future<void> _open(BuildContext context, String url, String failure) async {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
  }
}
