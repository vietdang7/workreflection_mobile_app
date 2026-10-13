// Màn hình Tâm thế đang hình thành & Đang duy trì — script Sprint 2
// `screenStanceKeep`.
// Hai tầng tách bạch: tâm thế là một câu không đếm, duy trì là số lần đếm được.
//
// Câu tâm thế KHÔNG ghi cứng câu mẫu `STANCE` của script: dựng từ dữ liệu thật
// bằng [buildStanceObservation], chưa đủ dữ liệu thì nói rõ là còn ít dữ liệu.
// "Đúng với tôi" và "Ghi lại" (tự gọi tên) ghi một Cột mốc vào Career Memory
// như `confirmStance` / `saveStanceOwn`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_career_memory_rules.dart'
    show kMilestoneBehavior;
import '../../../core/logic/wr_practice_v47.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_small_button.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_growth_screen.dart' show WrKeepRow;
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

/// Số dòng "Đang duy trì" hiện sẵn, và số thêm mỗi lần "Xem thêm" (script
/// `keepShow`).
const kStanceKeepPreview = 5;

class WrStanceKeepScreen extends ConsumerStatefulWidget {
  const WrStanceKeepScreen({super.key});

  @override
  ConsumerState<WrStanceKeepScreen> createState() => _WrStanceKeepScreenState();
}

class _WrStanceKeepScreenState extends ConsumerState<WrStanceKeepScreen> {
  String? _feedback; // 'yes', 'no', 'paused', 'own', null
  String? _ownText;
  bool _writing = false;
  bool _busy = false;
  final _ownController = TextEditingController();
  int _showLimit = kStanceKeepPreview;

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
    setState(() {
      _feedback = fb;
      _writing = false;
    });
    try {
      final sp = await SharedPreferences.getInstance();
      if (fb == null) {
        await sp.remove(_prefStanceFbKey);
      } else {
        await sp.setString(_prefStanceFbKey, fb);
      }
    } catch (_) {}
  }

  /// Ghi một Cột mốc vào Career Memory. Trả về false khi không ghi được.
  Future<bool> _writeMilestone(String text) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    try {
      await ref
          .read(wrContentRepositoryProvider)
          .insertMemoryEvent(
            CareerMemoryEvent(
              id: '${DateTime.now().millisecondsSinceEpoch}s',
              userId: userId,
              behavior: kMilestoneBehavior,
              reflectionText: text,
            ),
          );
      ref.invalidate(practiceMemoryEventsProvider);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wrKeepCompounds(tr(
                'Chưa ghi nhận được. Thử lại.',
                'Could not save it. Try again.',
              )),
            ),
          ),
        );
      }
      return false;
    }
  }

  /// "Đúng với tôi" (script `confirmStance`): một lần người dùng nhận ra mình,
  /// nên ghi vào hành trình.
  Future<void> _confirmStance() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await _writeMilestone(
      tr(
        'Bạn xác nhận một tâm thế đang hình thành',
        'You confirmed a stance that is taking shape',
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await _saveFeedback('yes');
  }

  /// "Ghi lại" (script `saveStanceOwn`): cách gọi của người dùng thay cho câu
  /// của hệ thống, và được lưu như một mốc trong hành trình. Để trống thì chỉ
  /// đóng ô viết.
  Future<void> _saveOwnText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) {
      setState(() => _writing = false);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await _writeMilestone(
      tr(
        'Bạn tự gọi tên điều đang hình thành: “$text”',
        'You named what is taking shape: “$text”',
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    setState(() {
      _ownText = text;
      _writing = false;
      _feedback = 'own';
    });
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_prefStanceOwnKey, text);
      await sp.setString(_prefStanceFbKey, 'own');
    } catch (_) {}
  }

  /// "Chưa gọi tên được" / "Để sau" (script `skipStance`).
  void _skipStance() => _saveFeedback('paused');

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(wrKeepingThemesProvider);
    final events =
        ref.watch(practiceMemoryEventsProvider).valueOrNull ?? const [];
    final notes = ref.watch(practiceStepNotesProvider).valueOrNull ?? const {};
    final stance = buildStanceObservation(
      events: events,
      notes: notes.values.toList(),
    );

    final visibleItems = items.take(_showLimit).toList();
    final remaining = items.length - visibleItems.length;
    final now = DateTime.now();

    return WrDetailScaffold(
      art: WrHeroArt.act,
      eyebrow: tr('TÂM THẾ & DUY TRÌ', 'STANCE & UPKEEP'),
      title: tr('Những gì đang hình thành', 'What is taking shape'),
      children: [
        _buildStanceCard(stance),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            wrKeepCompounds(tr('ĐANG DUY TRÌ', 'MAINTAINING')),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: WrColors.text3,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          WrCard(
            key: const Key('wr_stance_keep_list'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < visibleItems.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: WrColors.lineSoft,
                    ),
                  WrKeepRow(
                    item: visibleItems[i],
                    now: now,
                    doneLabel: tr('✓ Đã ghi hôm nay', '✓ Recorded today'),
                  ),
                ],
                if (remaining > 0) ...[
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: WrColors.lineSoft,
                  ),
                  InkWell(
                    key: const Key('wr_stance_keep_more'),
                    onTap: () => setState(
                      () => _showLimit = _showLimit + kStanceKeepPreview,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Center(
                        child: Text(
                          wrKeepCompounds(tr(
                            'Xem thêm ${remaining < kStanceKeepPreview ? remaining : kStanceKeepPreview} chủ đề',
                            'See ${remaining < kStanceKeepPreview ? remaining : kStanceKeepPreview} more themes',
                          )),
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
            wrKeepCompounds(tr(
              'Mỗi lần bạn thực hành trong công việc thật, bấm “Ghi nhận” để lưu giữ hành trình.',
              'Each time you practise in real work, tap “Record” to keep it in your journey.',
            )),
            style: const TextStyle(
              fontSize: 12.5,
              color: WrColors.text3,
              height: 1.55,
            ),
          ),
        ],
      ],
    );
  }

  Widget _eyebrow(String text, {Color color = WrColors.teal}) => Text(
    wrKeepCompounds(text),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.6,
    ),
  );

  Widget _buildStanceCard(String? stance) {
    if (_ownText != null) {
      return WrCard(
        key: const Key('wr_stance_own'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow(tr('BẠN TỰ GỌI TÊN', 'YOU NAMED IT YOURSELF')),
            const SizedBox(height: 9),
            Text(
              wrKeepCompounds('“$_ownText”'),
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
              wrKeepCompounds(tr(
                'Cách gọi này là của bạn. Những lần thực hành tới sẽ được đọc lại dựa trên nó.',
                'This wording is yours. Your next practices will be read back with it as the base.',
              )),
              style: const TextStyle(
                fontSize: 12.5,
                color: WrColors.text2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                setState(() {
                  _ownText = null;
                  _feedback = null;
                  _writing = false;
                });
                try {
                  final sp = await SharedPreferences.getInstance();
                  await sp.remove(_prefStanceOwnKey);
                  await sp.remove(_prefStanceFbKey);
                } catch (_) {}
              },
              child: Center(
                child: Text(
                  wrKeepCompounds(tr(
                    'Xem lại quan sát của hệ thống',
                    'See the app’s observation again',
                  )),
                  style: const TextStyle(fontSize: 12.5, color: WrColors.text3),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_writing) {
      return WrCard(
        key: const Key('wr_stance_writing'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow(tr('BẠN GỌI TÊN NÓ THẾ NÀO?', 'HOW WOULD YOU NAME IT?')),
            const SizedBox(height: 7),
            Text(
              wrKeepCompounds(tr(
                'Không cần đúng chữ nghĩa. Viết theo cách bạn hay nói với chính mình cũng được.',
                'It does not have to be precise. Write it the way you talk to yourself.',
              )),
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
                key: const Key('wr_stance_own_field'),
                controller: _ownController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontSize: 15, color: WrColors.navy),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: tr(
                    'Ví dụ: Mình không nói ra sớm hơn, mình chỉ bớt thấy ngại khi chưa biết hết.',
                    'For example: I am not speaking up sooner, I just feel less uneasy when I do not know everything.',
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
                    key: const Key('wr_stance_own_save'),
                    kind: WrSmallButtonKind.primary,
                    label: tr('Ghi lại', 'Save'),
                    onTap: _busy
                        ? null
                        : () => _saveOwnText(_ownController.text),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WrSmallButton(
                    key: const Key('wr_stance_own_skip'),
                    kind: WrSmallButtonKind.ghost,
                    label: tr('Chưa gọi tên được', 'Cannot name it yet'),
                    onTap: _skipStance,
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
        key: const Key('wr_stance_no'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow(
              tr('QUAN SÁT CHƯA KHỚP', 'OBSERVATION DOES NOT FIT'),
              color: WrColors.text3,
            ),
            const SizedBox(height: 8),
            Text(
              wrKeepCompounds(tr(
                'Quan sát này được cất đi, sẽ không hiện lại nữa. Hệ thống sẽ đọc lại sau vài lần thực hành nữa.',
                'This observation is put away and will not show again. The app will read again after a few more practices.',
              )),
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
                    kind: WrSmallButtonKind.primary,
                    label: tr('Tôi tự gọi tên', 'I will name it'),
                    onTap: () => setState(() => _writing = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WrSmallButton(
                    kind: WrSmallButtonKind.ghost,
                    label: tr('Để sau', 'Later'),
                    onTap: _skipStance,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_feedback == 'paused') {
      return _quietCard(
        key: const Key('wr_stance_paused'),
        eyebrow: tr('ĐANG ĐỌC LẠI', 'READING AGAIN'),
        body: tr(
          'Chưa có quan sát nào mới. Sau vài lần thực hành nữa, phần này sẽ có nội dung trở lại.',
          'No new observation yet. After a few more practices, this part will have something again.',
        ),
      );
    }

    // Script §1: dưới ngưỡng dữ liệu thì để trống và nói rõ là còn ít dữ liệu.
    if (stance == null) {
      return _quietCard(
        key: const Key('wr_stance_low_data'),
        eyebrow: tr('TÂM THẾ ĐANG HÌNH THÀNH', 'A STANCE TAKING SHAPE'),
        body: tr(
          'Phần này còn trống vì dữ liệu còn ít. Khi bạn thực hành thêm vài lần, '
              'trên hơn một chủ đề, một quan sát đầu tiên sẽ hiện ở đây.',
          'This part is empty because there is little to go on yet. Once you '
              'practise a few more times, across more than one theme, a first '
              'observation will appear here.',
        ),
      );
    }

    return WrCard(
      key: const Key('wr_stance_observation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(tr('TÂM THẾ ĐANG HÌNH THÀNH', 'A STANCE TAKING SHAPE')),
          const SizedBox(height: 9),
          Text(
            wrKeepCompounds(stance),
            key: const Key('wr_stance_text'),
            style: const TextStyle(
              fontSize: 15,
              height: 1.62,
              color: WrColors.navy,
            ),
          ),
          if (_feedback == 'yes') ...[
            const SizedBox(height: 12),
            Text(
              wrKeepCompounds(tr('✓ Bạn thấy điều này đúng', '✓ You found this true')),
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
                    key: const Key('wr_stance_yes'),
                    kind: WrSmallButtonKind.ghost,
                    label: tr('Đúng với tôi', 'True for me'),
                    onTap: _busy ? null : _confirmStance,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WrSmallButton(
                    key: const Key('wr_stance_not_quite'),
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
            wrKeepCompounds(tr(
              'Đây là một quan sát từ hệ thống, bạn xem lại với những gì mình trải nghiệm và chọn để lưu lại hành trình nhé.',
              'This is an observation from the app. Check it against what you have lived through, and choose whether to keep it in your journey.',
            )),
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

  /// Thẻ chữ xám có lối "Tự gọi tên bây giờ".
  Widget _quietCard({
    required Key key,
    required String eyebrow,
    required String body,
  }) {
    return WrCard(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(eyebrow, color: WrColors.text3),
          const SizedBox(height: 8),
          Text(
            wrKeepCompounds(body),
            style: const TextStyle(
              fontSize: 14,
              color: WrColors.text2,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: const Key('wr_stance_name_now'),
            onTap: () => setState(() => _writing = true),
            child: Center(
              child: Text(
                wrKeepCompounds(tr('Tự gọi tên bây giờ', 'Name it now')),
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
}
