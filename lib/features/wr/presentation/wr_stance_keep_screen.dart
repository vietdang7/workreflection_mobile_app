// Màn hình Tâm thế đang hình thành & Đang duy trì — Sprint 2 `screenStanceKeep`.
// Hai tầng tách bạch: tâm thế là một câu không đếm, duy trì là số lần đếm được.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_small_button.dart';
import '../growth_providers.dart';

class WrStanceKeepScreen extends ConsumerStatefulWidget {
  const WrStanceKeepScreen({super.key});

  @override
  ConsumerState<WrStanceKeepScreen> createState() => _WrStanceKeepScreenState();
}

class _WrStanceKeepScreenState extends ConsumerState<WrStanceKeepScreen> {
  String? _feedback; // 'yes', 'no', 'paused', null
  String? _ownText;
  bool _writing = false;
  final _ownController = TextEditingController();
  final Set<String> _markedToday = {};
  int _showLimit = 5;

  static const _prefStanceFbKey = 'wr_stance_feedback';
  static const _prefStanceOwnKey = 'wr_stance_own_text';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _ownController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _feedback = sp.getString(_prefStanceFbKey);
        _ownText = sp.getString(_prefStanceOwnKey);
      });
    } catch (_) {}
  }

  Future<void> _saveFeedback(String? fb) async {
    setState(() => _feedback = fb);
    try {
      final sp = await SharedPreferences.getInstance();
      if (fb == null) {
        await sp.remove(_prefStanceFbKey);
      } else {
        await sp.setString(_prefStanceFbKey, fb);
      }
    } catch (_) {}
  }

  Future<void> _saveOwnText(String text) async {
    setState(() {
      _ownText = text.trim().isEmpty ? null : text.trim();
      _writing = false;
      _feedback = 'own';
    });
    try {
      final sp = await SharedPreferences.getInstance();
      if (_ownText == null) {
        await sp.remove(_prefStanceOwnKey);
      } else {
        await sp.setString(_prefStanceOwnKey, _ownText!);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final enrollments =
        ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];

    // Dựng danh sách duy trì từ các chủ đề đã hoàn thành + danh sách mặc định
    final completedEnrollments =
        enrollments.where((e) => e.completedAt != null).toList();

    final keepingItems = <_KeepItem>[
      for (final e in completedEnrollments)
        if (themes.where((t) => t.themeId == e.themeId).firstOrNull
            case final t?)
          _KeepItem(
            id: 'e-${e.themeId}',
            name: t.title,
            count: (e.completedSteps.length).clamp(1, 99),
            last: tr('hôm qua', 'yesterday'),
          ),
      _KeepItem(
        id: 'k1',
        name: tr('Rõ ràng về điều được kỳ vọng', 'Clarity on expectations'),
        count: 12,
        last: tr('hôm qua', 'yesterday'),
      ),
      _KeepItem(
        id: 'k2',
        name: tr(
            'Thoát khỏi vòng lặp phản ứng', 'Breaking reactive feedback loops'),
        count: 7,
        last: tr('3 ngày trước', '3 days ago'),
      ),
      _KeepItem(
        id: 'k3',
        name: tr('Giữ năng lượng đường dài', 'Sustaining energy over time'),
        count: 2,
        last: tr('tuần trước', 'last week'),
      ),
    ];

    final visibleItems = keepingItems.take(_showLimit).toList();
    final remaining = keepingItems.length - visibleItems.length;

    return WrDetailScaffold(
      art: WrHeroArt.act,
      eyebrow: tr('TÂM THẾ & DUY TRÌ', 'STANCE & RETENTION'),
      title: tr('Những gì đang hình thành', 'What is taking shape'),
      children: [
        _buildStanceCard(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr('ĐANG DUY TRÌ', 'MAINTAINING'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WrColors.text3,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              '${keepingItems.length} ${tr('chủ đề', 'themes')}',
              style: const TextStyle(
                fontSize: 12,
                color: WrColors.text3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        WrCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < visibleItems.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: WrColors.line,
                  ),
                _buildKeepRow(visibleItems[i]),
              ],
              if (remaining > 0) ...[
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: WrColors.line,
                ),
                InkWell(
                  onTap: () => setState(() => _showLimit = _showLimit + 5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Center(
                      child: Text(
                        tr(
                          'Xem thêm $remaining chủ đề',
                          'See $remaining more themes',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: WrColors.pillTealText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tr(
            'Mỗi lần bạn thực hành trong công việc thật, bấm “Ghi nhận” để lưu giữ hành trình.',
            'Each time you practice in real work, tap "Record" to preserve your journey.',
          ),
          style: const TextStyle(
            fontSize: 12.5,
            color: WrColors.text3,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildStanceCard() {
    if (_ownText != null) {
      return WrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('BẠN TỰ GỌI TÊN', 'YOU NAMED IT YOURSELF'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WrColors.teal,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              '“$_ownText”',
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                height: 1.6,
                color: WrColors.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                'Cách gọi này là của bạn. Những lần thực hành tới sẽ được đọc lại dựa trên nó.',
                'This wording is yours. Upcoming practice reviews will be phrased around it.',
              ),
              style: const TextStyle(
                fontSize: 12.5,
                color: WrColors.text2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final sp = await SharedPreferences.getInstance();
                await sp.remove(_prefStanceOwnKey);
                await sp.remove(_prefStanceFbKey);
                setState(() {
                  _ownText = null;
                  _feedback = null;
                  _writing = false;
                });
              },
              child: Center(
                child: Text(
                  tr('Xem lại quan sát của hệ thống', 'Review system observation'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WrColors.text3,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_writing) {
      return WrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('BẠN GỌI TÊN NÓ THẾ NÀO?', 'HOW WOULD YOU NAME IT?'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WrColors.teal,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              tr(
                'Không cần đúng chữ nghĩa. Viết theo cách bạn hay nói với chính mình cũng được.',
                'It does not have to be formal. Write how you speak to yourself.',
              ),
              style: const TextStyle(
                fontSize: 13.5,
                color: WrColors.text2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: WrColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WrColors.line),
              ),
              child: TextField(
                controller: _ownController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontSize: 15, color: WrColors.navy),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: tr(
                    'Ví dụ: Mình không nói ra sớm hơn, mình chỉ bớt thấy ngại khi chưa biết hết.',
                    'E.g., I did not speak sooner, I just felt less shy when not knowing all.',
                  ),
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: WrColors.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: WrSmallButton(
                    kind: WrSmallButtonKind.dark,
                    label: tr('Ghi lại', 'Save'),
                    onTap: () => _saveOwnText(_ownController.text),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WrSmallButton(
                    kind: WrSmallButtonKind.ghost,
                    label: tr('Chưa gọi tên được', 'Not yet'),
                    onTap: () => setState(() => _writing = false),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_feedback == 'no') {
      return WrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('QUAN SÁT CHƯA KHỚP', 'OBSERVATION NOT ALIGNED'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WrColors.text3,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'Quan sát này được cất đi, sẽ không hiện lại nữa. Hệ thống sẽ đọc lại sau vài lần thực hành nữa.',
                'This observation is put away. The system will read again after a few more practices.',
              ),
              style: const TextStyle(
                fontSize: 14,
                color: WrColors.text2,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: WrSmallButton(
                    kind: WrSmallButtonKind.dark,
                    label: tr('Tôi tự gọi tên', 'Name it myself'),
                    onTap: () => setState(() => _writing = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WrSmallButton(
                    kind: WrSmallButtonKind.ghost,
                    label: tr('Để sau', 'Later'),
                    onTap: () => _saveFeedback('paused'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_feedback == 'paused') {
      return WrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('ĐANG ĐỌC LẠI', 'REREADING IN PROGRESS'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WrColors.text3,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'Chưa có quan sát nào mới. Sau vài lần thực hành nữa, phần này sẽ có nội dung trở lại.',
                'No new observations yet. After more practice sessions, content will return.',
              ),
              style: const TextStyle(
                fontSize: 14,
                color: WrColors.text2,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _writing = true),
              child: Center(
                child: Text(
                  tr('Tự gọi tên bây giờ', 'Name it now'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WrColors.pillTealText,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default observation
    return WrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('TÂM THẾ ĐANG HÌNH THÀNH', 'EMERGING STANCE'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: WrColors.teal,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            tr(
              'Những ghi chú đầu tiên của bạn phần lớn là chuyện chờ: chờ đủ thông tin, '
                  'chờ người khác hỏi trước, chờ đến lúc thật chắc chắn. Mấy lần thử gần đây '
                  'có thêm một nhịp khác, bạn nói ra sớm hơn khi mọi thứ còn chưa rõ hết. '
                  'Nhịp này đã lặp lại vài lần, chưa thành phản xạ nhưng đã đủ để nhìn thấy.',
              'Your earliest notes were mostly about waiting: waiting for enough info, '
                  'waiting for others to ask first, waiting for full certainty. Recent trials '
                  'show a different rhythm: speaking up sooner before everything is clear. '
                  'This has repeated a few times, visible though not yet reflex.',
            ),
            style: const TextStyle(
              fontSize: 15,
              height: 1.62,
              color: WrColors.navy,
            ),
          ),
          if (_feedback == 'yes') ...[
            const SizedBox(height: 12),
            Text(
              tr('✓ Bạn thấy điều này đúng', '✓ You found this accurate'),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: WrColors.teal,
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: WrSmallButton(
                    kind: WrSmallButtonKind.ghost,
                    label: tr('Đúng với tôi', 'Fits me'),
                    onTap: () => _saveFeedback('yes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WrSmallButton(
                    kind: WrSmallButtonKind.ghost,
                    label: tr('Chưa đúng lắm', 'Not quite'),
                    onTap: () => _saveFeedback('no'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 11),
          Text(
            tr(
              'Đây là một quan sát từ hệ thống, bạn xem lại với những gì mình trải nghiệm và chọn để lưu lại hành trình nhé.',
              'This is a system observation. Review against your experience to guide your journey.',
            ),
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

  Widget _buildKeepRow(_KeepItem item) {
    final marked = _markedToday.contains(item.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.count} ${tr('lần', 'times')} · ${tr('gần nhất', 'last')} ${item.last}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: WrColors.text3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          WrSmallButton(
            kind: marked ? WrSmallButtonKind.ghost : WrSmallButtonKind.dark,
            label: marked
                ? tr('✓ Đã ghi hôm nay', '✓ Recorded today')
                : tr('Ghi nhận', 'Record'),
            onTap: () {
              setState(() {
                if (marked) {
                  _markedToday.remove(item.id);
                } else {
                  _markedToday.add(item.id);
                  item.count++;
                  item.last = tr('hôm nay', 'today');
                }
              });
            },
          ),
        ],
      ),
    );
  }
}

class _KeepItem {
  _KeepItem({
    required this.id,
    required this.name,
    required this.count,
    required this.last,
  });

  final String id;
  final String name;
  int count;
  String last;
}
