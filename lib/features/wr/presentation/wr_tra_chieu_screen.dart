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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_tra_chieu.dart';
import '../../../core/models/workshop_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../workshops/workshops_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

/// Ba nguyên tắc cốt lõi — nguyên văn theo mockup, không rút gọn.
List<String> get kTraChieuRules => [
  tr(
    'Điều gì nói ở đây, ở lại đây. Mọi trích dẫn ra ngoài đều ẩn danh và cần '
        'người nói đồng ý.',
    'What is said here stays here. Anything quoted outside is anonymous and '
        'needs the speaker\'s consent.',
  ),
  tr(
    'Không lời khuyên khi chưa được hỏi. Chỉ lắng nghe và hỏi lại.',
    'No advice unless it is asked for. Just listen, and ask back.',
  ),
  tr(
    'Được quyền im lặng. Có thể xin qua lượt bất kỳ lúc nào, không cần lý do.',
    'You may stay silent. You can pass at any point, no reason needed.',
  ),
];

/// "Vì sao lại là Trà Chiều" — nguyên văn script `screenTraChieu`.
String get kTraChieuWhy => tr(
  'Không phải hội thảo, không có sân khấu. Mười đến mười hai người ngồi '
      'quanh một bàn trà, cùng trả lời một câu hỏi duy nhất. Đây là chính '
      'trải nghiệm phản chiếu của WorkReflection, chỉ khác là được nói thành '
      'lời, trong một không gian an toàn.',
  'Not a seminar, no stage. Ten to twelve people sit around one tea table, '
      'answering a single question together. It is the same reflection you do '
      'in WorkReflection, only spoken out loud, in a safe space.',
);

// ---------------------------------------------------------------------------

class WrTraChieuScreen extends ConsumerWidget {
  const WrTraChieuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshops =
        ref.watch(activeWorkshopsProvider).valueOrNull ?? const [];
    final next = nextTraChieu(workshops, now: DateTime.now());

    return WrDetailScaffold(
      art: WrHeroArt.act,
      eyebrow: tr('Offline · Trà Chiều Nghề Nghiệp', 'Offline · Career Tea Time'),
      title: kTraChieuLabel,
      children: [
        Text(
          wrKeepWords(kTraChieuFormatLabel),
          style: const TextStyle(fontSize: 14.5, color: WrColors.muted, height: 1.55),
        ),
        const SizedBox(height: 20),

        // ── 1. Buổi sắp tới (Thẻ xanh Navy đứng đầu theo đúng script) ──
        if (next == null)
          const _DefaultNextSessionCard()
        else
          _NextSessionCard(session: next),

        const SizedBox(height: 18),

        // ── 2. Vì sao lại là Trà Chiều ────────────────────────────────
        WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wrKeepCompounds(tr('Vì sao lại là Trà Chiều', 'Why Tea Time')),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                wrKeepWords(kTraChieuWhy),
                style: const TextStyle(
                  fontSize: 14.5,
                  color: WrColors.dark,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── 3. Ba luật của mọi buổi ───────────────────────────────────
        WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wrKeepCompounds(tr('Ba luật của mọi buổi', 'Three rules of every session')),
                style: const TextStyle(
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
                      child: Icon(Icons.check, size: 16, color: WrColors.teal),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        wrKeepCompounds(rule),
                        style: const TextStyle(
                          fontSize: 15,
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

        const SizedBox(height: 18),

        // ── 4. Xem lịch các buổi (Card theo mockup script) ───────────
        WrCard(
          key: const Key('wr_tra_chieu_calendar_row'),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          onTap: () => context.push('/wr/tra-chieu/lich'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wrKeepCompounds(tr('Xem lịch các buổi', 'See the schedule')),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wrKeepCompounds(tr(
                        'Chủ đề đổi mỗi buổi, theo đúng thứ tự ưu tiên',
                        'Theme changes each session, in priority order',
                      )),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WrColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: WrColors.navy,
                size: 24,
              ),
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
            tr('BUỔI SẮP TỚI', 'NEXT SESSION'),
            color: WrColors.cream.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            wrKeepCompounds('"${session.title}"'),
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
              wrKeepCompounds(session.description!.trim()),
              key: const Key('wr_tra_chieu_next_description'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.7,
                color: WrColors.cream.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: WrColors.cream.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          _DarkLine(traChieuWhenLabel(session)),
          _DarkLine(
            session.location?.trim().isNotEmpty ?? false
                ? session.location!.trim()
                : kTraChieuNoVenue,
          ),
          _DarkLine(traChieuSeatLabel(session)),
          const SizedBox(height: 18),
          if (kTraChieuZaloUrl.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wr_tra_chieu_zalo_button'),
                onPressed: () => openTraChieuZalo(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.coral,
                  foregroundColor: WrColors.navy,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  wrKeepCompounds(tr(
                    'Nhắn Zalo "Trà Chiều" để giữ một ghế',
                    'Message on Zalo "Tea Time" to reserve a seat',
                  )),
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('wr_tra_chieu_detail_button'),
                onPressed: () =>
                    openTraChieuOnWeb(context, traChieuUrlKey(session)),
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
                child: Text(
                  wrKeepCompounds(tr('Xem chi tiết và đăng ký', 'See details and sign up')),
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
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
                child: Text(
                  wrKeepCompounds(tr('Xem chi tiết và đăng ký', 'See details and sign up')),
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DefaultNextSessionCard extends StatelessWidget {
  const _DefaultNextSessionCard();

  @override
  Widget build(BuildContext context) {
    const s = kDefaultTraChieuSessions;
    final first = s.first;

    return WrCardDark(
      key: const Key('wr_tra_chieu_next'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(
            tr('BUỔI SẮP TỚI', 'NEXT SESSION'),
            color: WrColors.cream.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            wrKeepCompounds('"${first.topic}"'),
            style: const TextStyle(
              fontSize: 19,
              fontStyle: FontStyle.italic,
              color: WrColors.cream,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: WrColors.cream.withValues(alpha: 0.15)),
          const SizedBox(height: 14),
          _DarkLine('${first.label}, 15:30 đến 17:30'),
          _DarkLine(kTraChieuNoVenue),
          _DarkLine(tr(
            'Giữ chỗ 199.000đ, bao gồm trà và bánh',
            'Reserve spot 199,000 VND, includes tea & pastry',
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('wr_tra_chieu_zalo_button'),
              onPressed: () => openTraChieuZalo(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                wrKeepCompounds(tr(
                  'Nhắn Zalo "Trà Chiều" để giữ một ghế',
                  'Message on Zalo "Tea Time" to reserve a seat',
                )),
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
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
        wrKeepCompounds(text),
        style: TextStyle(
          fontSize: 15.5,
          height: 1.6,
          color: WrColors.cream.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Lịch các buổi — bố cục thẻ duy nhất gom tất cả các buổi (script `screenTraChieuCalendar`).
// ---------------------------------------------------------------------------

class WrTraChieuCalendarScreen extends ConsumerWidget {
  const WrTraChieuCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshops =
        ref.watch(activeWorkshopsProvider).valueOrNull ?? const [];
    final sessions = upcomingTraChieu(workshops, now: DateTime.now());

    return WrDetailScaffold(
      art: WrHeroArt.act,
      eyebrow: kTraChieuLabel.toUpperCase(),
      title: tr('Lịch các buổi', 'Session schedule'),
      children: [
        WrCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (sessions.isNotEmpty)
                for (var i = 0; i < sessions.length; i++) ...[
                  _SessionCalendarRow(
                    key: Key('wr_tra_chieu_session_${sessions[i].id}'),
                    label: traChieuWhenLabel(sessions[i]),
                    topic: sessions[i].title,
                    note: sessions[i].description,
                    onTap: () => _showTraChieuSessionSheet(
                      context,
                      label: traChieuWhenLabel(sessions[i]),
                      topic: sessions[i].title,
                      note: sessions[i].description,
                      publicSession: true,
                      webUrlKey: traChieuUrlKey(sessions[i]),
                    ),
                  ),
                  if (i < sessions.length - 1)
                    const Divider(height: 1, thickness: 1, color: WrColors.lineSoft),
                ]
              else
                for (var i = 0; i < kDefaultTraChieuSessions.length; i++) ...[
                  _SessionCalendarRow(
                    key: Key('wr_tra_chieu_session_${kDefaultTraChieuSessions[i].id}'),
                    label: '${kDefaultTraChieuSessions[i].label}${!kDefaultTraChieuSessions[i].publicSession ? ' · Buổi kín' : ''}',
                    topic: kDefaultTraChieuSessions[i].topic,
                    note: kDefaultTraChieuSessions[i].note,
                    dimmed: !kDefaultTraChieuSessions[i].publicSession,
                    onTap: () => _showTraChieuSessionSheet(
                      context,
                      label: kDefaultTraChieuSessions[i].label,
                      topic: kDefaultTraChieuSessions[i].topic,
                      note: kDefaultTraChieuSessions[i].note,
                      publicSession: kDefaultTraChieuSessions[i].publicSession,
                    ),
                  ),
                  if (i < kDefaultTraChieuSessions.length - 1)
                    const Divider(height: 1, thickness: 1, color: WrColors.lineSoft),
                ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          wrKeepCompounds(tr(
            'Định kỳ 2 tuần một lần, chiều thứ Bảy. Có thể dày hơn nếu lượng '
                'đăng ký trước đủ đông.',
            'Every 2 weeks, on Saturday afternoon. Possibly more often if enough '
                'people sign up early.',
          )),
          key: const Key('wr_tra_chieu_calendar_footer'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, color: WrColors.muted, height: 1.7),
        ),
      ],
    );
  }
}

void _showTraChieuSessionSheet(
  BuildContext context, {
  required String label,
  required String topic,
  String? note,
  bool publicSession = true,
  String? webUrlKey,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: WrColors.creamBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: WrColors.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: publicSession
                          ? WrColors.coral.withValues(alpha: 0.12)
                          : WrColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      publicSession
                          ? tr('TRÀ CHIỀU NGHỀ NGHIỆP', 'CAREER TEA TIME')
                          : tr('BUỔI KÍN', 'PRIVATE SESSION'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: publicSession ? WrColors.coral : WrColors.navy,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: WrColors.muted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                wrKeepCompounds('"$topic"'),
                style: const TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                  height: 1.38,
                ),
              ),
              if (note != null && note.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  wrKeepCompounds(note.trim()),
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: WrColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              WrCardMinimal(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _sheetInfoRow(Icons.calendar_today_rounded, '$label · 15:30 đến 17:30'),
                    const SizedBox(height: 10),
                    _sheetInfoRow(Icons.place_outlined, kTraChieuNoVenue),
                    const SizedBox(height: 10),
                    _sheetInfoRow(
                      Icons.groups_outlined,
                      tr('10 đến 12 người · 2 tiếng · 1 câu hỏi', '10 to 12 people · 2 hours · 1 question'),
                    ),
                    const SizedBox(height: 10),
                    _sheetInfoRow(
                      Icons.local_cafe_outlined,
                      tr('Giữ chỗ 199.000đ, bao gồm trà và bánh', 'Reserve 199,000 VND, includes tea & pastries'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                wrKeepWords(tr(
                  'Không hội thảo, không sân khấu. Ngồi quanh một bàn trà, cùng trả lời một câu hỏi duy nhất trong không gian an toàn và bảo mật.',
                  'No seminar, no stage. Sitting around a tea table, answering one question in a safe and confidential space.',
                )),
                style: const TextStyle(fontSize: 13, color: WrColors.muted, height: 1.55),
              ),
              const SizedBox(height: 20),
              if (publicSession) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('wr_tra_chieu_sheet_zalo_button'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      openTraChieuZalo(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WrColors.coral,
                      foregroundColor: WrColors.navy,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      wrKeepCompounds(tr(
                        'Nhắn Zalo "Trà Chiều" để giữ một ghế',
                        'Message on Zalo "Tea Time" to reserve a seat',
                      )),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (webUrlKey != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        openTraChieuOnWeb(context, webUrlKey);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WrColors.navy,
                        side: BorderSide(color: WrColors.navy.withValues(alpha: 0.2)),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        wrKeepCompounds(tr('Xem chi tiết và đăng ký trên web', 'See details and sign up on web')),
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WrColors.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    wrKeepWords(tr(
                      'Buổi kín: Chỉ dành cho khách mời từ danh sách chờ hoặc người đã từng tham gia.',
                      'Private session: Reserved for invitees from waitlist or prior participants.',
                    )),
                    style: const TextStyle(fontSize: 13, color: WrColors.dark, height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      openTraChieuZalo(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WrColors.navy,
                      foregroundColor: WrColors.cream,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      wrKeepCompounds(tr(
                        'Nhắn Zalo để vào danh sách chờ',
                        'Message on Zalo to join waitlist',
                      )),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Widget _sheetInfoRow(IconData icon, String text) {
  return Row(
    children: [
      Icon(icon, size: 16, color: WrColors.teal),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          wrKeepCompounds(text),
          style: const TextStyle(
            fontSize: 13.5,
            color: WrColors.dark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _SessionCalendarRow extends StatelessWidget {
  const _SessionCalendarRow({
    super.key,
    required this.label,
    required this.topic,
    this.note,
    this.dimmed = false,
    this.onTap,
  });

  final String label;
  final String topic;
  final String? note;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: dimmed ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wrKeepCompounds(label),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      wrKeepCompounds('"$topic"'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: WrColors.navy,
                        height: 1.35,
                      ),
                    ),
                    if (note != null && note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        wrKeepCompounds(note!.trim()),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: WrColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: WrColors.muted,
              ),
            ],
          ),
        ),
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
    _open(
      context,
      traChieuWebUrl(workshopId),
      tr('Không mở được trang chi tiết.', 'Could not open the details page.'),
    );

/// Mở Zalo để giữ chỗ.
Future<void> openTraChieuZalo(BuildContext context) async {
  final url = kTraChieuZaloUrl.isNotEmpty
      ? kTraChieuZaloUrl
      : kTraChieuDefaultZaloUrl;
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.platformDefault,
      );
    } catch (_) {
      opened = false;
    }
  }
  if (!opened && context.mounted) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          wrKeepCompounds(tr('Giữ chỗ Trà Chiều', 'Tea Time Reservation')),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: WrColors.navy),
        ),
        content: Text(
          wrKeepCompounds(tr(
            'Mở ứng dụng Zalo và gửi tin nhắn "TRÀ CHIỀU" đến số 0866883047 để giữ một ghế tham gia.',
            'Open Zalo and send message "TEA TIME" to 0866883047 to reserve a seat.',
          )),
          style: const TextStyle(fontSize: 14.5, color: WrColors.dark, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: '0866883047'));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr(
                    'Đã sao chép số Zalo 0866883047',
                    'Copied Zalo number 0866883047',
                  )),
                ),
              );
            },
            child: Text(
              tr('Sao chép số', 'Copy number'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: WrColors.teal),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              tr('Đã hiểu', 'Got it'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: WrColors.navy),
            ),
          ),
        ],
      ),
    );
  }
}

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(wrKeepCompounds(failure))));
  }
}
