import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/mobile_profile.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/wr_card.dart';
import '../wr_providers.dart';

// ---------------------------------------------------------------------------
// Local providers
// ---------------------------------------------------------------------------

final _mobileProfileProvider = FutureProvider<MobileProfile?>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  return repo.getMobileProfile();
});

// ---------------------------------------------------------------------------
// WrHomeScreen
// ---------------------------------------------------------------------------

class WrHomeScreen extends ConsumerStatefulWidget {
  const WrHomeScreen({super.key});

  @override
  ConsumerState<WrHomeScreen> createState() => _WrHomeScreenState();
}

class _WrHomeScreenState extends ConsumerState<WrHomeScreen> {
  CheckinEnergy? _energy;
  CheckinDirection? _direction;
  bool _saved = false;
  bool _saving = false;
  bool _autoSaveTriggered = false;

  String _dateLabel() {
    final now = todayVn();
    final weekdays = [
      'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm',
      'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
    ];
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    return '${weekdays[now.weekday - 1]}, $day/$month';
  }

  Future<void> _save() async {
    if (_energy == null || _direction == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(wrRepositoryProvider);
      await repo.upsertCheckin(
        _energy!.toMood(),
        energy: _energy,
        direction: _direction,
      );
      if (mounted) {
        setState(() { _saved = true; _saving = false; });
        ref.invalidate(todayCheckinProvider);
        ref.invalidate(wrPatternCountsProvider);
      }
    } catch (_) {
      if (mounted) {
        setState(() { _saving = false; _saved = false; _autoSaveTriggered = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được check-in. Thử lại.')),
        );
      }
    }
  }

  void _onEnergySelected(CheckinEnergy e) {
    setState(() { _energy = e; });
    _tryAutoSave();
  }

  void _onDirectionSelected(CheckinDirection d) {
    setState(() { _direction = d; });
    _tryAutoSave();
  }

  void _tryAutoSave() {
    if (_energy != null && _direction != null && !_saved && !_autoSaveTriggered) {
      _autoSaveTriggered = true;
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_mobileProfileProvider);
    final patternsAsync = ref.watch(wrPatternCountsProvider);
    final situationsAsync = ref.watch(wrSituationsProvider);
    final insightAsync = ref.watch(wrLatestInsightProvider);

    // Pre-populate saved state from existing check-in (runs once when data arrives)
    ref.listen<AsyncValue<Checkin?>>(todayCheckinProvider, (_, next) {
      next.whenData((checkin) {
        if (checkin != null && !_saved && mounted) {
          setState(() { _saved = true; });
        }
      });
    });

    final displayName = profileAsync.valueOrNull?.displayName ?? '';
    final patterns = patternsAsync.valueOrNull ?? const [];
    final situations = situationsAsync.valueOrNull ?? const [];
    final sitMap = {for (final s in situations) s.code: s.text};
    final insight = insightAsync.valueOrNull;

    // Top pattern with count >= 2
    PatternCount? topPattern;
    if (patterns.isNotEmpty && patterns.first.occurrenceCount >= 2) {
      topPattern = patterns.first;
    }

    // Eyebrow text for story section
    final isLowSaved = _saved && _energy == CheckinEnergy.low;
    final storyEyebrow = isLowSaved ? 'GỢI Ý KHI MỆT MỎI' : 'GỢI Ý HÔM NAY';

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── top-area ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty ? 'Chào $displayName' : 'Chào bạn',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: WrColors.muted,
                        letterSpacing: -0.01,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateLabel(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: WrColors.navy,
                        letterSpacing: -0.03 * 32, // -3% em tracking per mockup
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── divider ───────────────────────────────────────────────────
            const SliverToBoxAdapter(child: WrSectionDivider()),

            // ── check-in section ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bạn đang trải qua điều gì?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        letterSpacing: -0.02 * 22,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Energy row — always visible
                    Row(
                      children: [
                        _WrCheckinButton(
                          label: 'Có năng lượng',
                          selected: _energy == CheckinEnergy.good,
                          onTap: () => _onEnergySelected(CheckinEnergy.good),
                        ),
                        const SizedBox(width: 12),
                        _WrCheckinButton(
                          label: 'Bình thường',
                          selected: _energy == CheckinEnergy.ok,
                          onTap: () => _onEnergySelected(CheckinEnergy.ok),
                        ),
                        const SizedBox(width: 12),
                        _WrCheckinButton(
                          label: 'Mệt mỏi',
                          selected: _energy == CheckinEnergy.low,
                          onTap: () => _onEnergySelected(CheckinEnergy.low),
                        ),
                      ],
                    ),
                    // Direction row — revealed after energy selected
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: _energy != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  _WrCheckinButton(
                                    label: 'Tiến lên',
                                    selected: _direction == CheckinDirection.forward,
                                    onTap: () => _onDirectionSelected(CheckinDirection.forward),
                                  ),
                                  const SizedBox(width: 12),
                                  _WrCheckinButton(
                                    label: 'Đứng yên',
                                    selected: _direction == CheckinDirection.steady,
                                    onTap: () => _onDirectionSelected(CheckinDirection.steady),
                                  ),
                                  const SizedBox(width: 12),
                                  _WrCheckinButton(
                                    label: 'Thụt lùi',
                                    selected: _direction == CheckinDirection.backward,
                                    onTap: () => _onDirectionSelected(CheckinDirection.backward),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    // Saving indicator
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: WrColors.coral),
                        ),
                      ),
                    // Saved badge
                    if (_saved && !_saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: _SavedBadge(),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── share card (energy=low) ───────────────────────────────────
            if (_saved && _energy == CheckinEnergy.low)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                  child: WrCardMinimal(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bạn mệt vì điều gì?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: WrColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Đôi khi hiểu được nguyên nhân giúp bạn nhẹ hơn một chút.',
                          style: TextStyle(
                            fontSize: 13,
                            color: WrColors.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        WrActionLink(
                          label: 'Chia sẻ thêm',
                          onTap: () => context.push('/wr/situation'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── divider ───────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: WrSectionDivider(),
              ),
            ),

            // ── card hệ thống nhận ra ─────────────────────────────────────
            if (topPattern != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: WrCardDark(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WrEyebrow(
                          'HỆ THỐNG NHẬN RA',
                          color: WrColors.cream.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Đây là lần thứ ${topPattern.occurrenceCount} bạn gặp tình huống '
                          '"${sitMap[topPattern.situationCode] ?? topPattern.situationCode ?? 'này'}".',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: WrColors.cream,
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        WrActionLink(
                          label: 'Tìm hiểu thêm',
                          onTap: () => context.go('/wr/discover'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],

            // ── section gợi ý story ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WrEyebrow(storyEyebrow),
                    const SizedBox(height: 10),
                    WrCardMinimal(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bạn chưa đọc câu chuyện nào.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: WrColors.navy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Các câu chuyện giúp bạn nhận ra patterns trong cuộc sống nghề nghiệp.',
                            style: TextStyle(
                              fontSize: 13,
                              color: WrColors.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          WrActionLink(
                            label: 'Đọc câu chuyện đầu tiên',
                            onTap: () => context.push('/wr/story'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── insight section ───────────────────────────────────────────
            if (insight != null) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: WrSectionDivider(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WrEyebrow('INSIGHT GẦN NHẤT'),
                      const SizedBox(height: 12),
                      Text(
                        '"${insight.content}"',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                          color: WrColors.navy,
                          height: 1.45,
                          letterSpacing: -0.015,
                        ),
                      ),
                      if (insight.createdAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Lưu ngày ${insight.createdAt!.day.toString().padLeft(2, '0')}/${insight.createdAt!.month.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: WrColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WrCheckinButton
// ---------------------------------------------------------------------------

class _WrCheckinButton extends StatelessWidget {
  const _WrCheckinButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? WrColors.coral : WrColors.cream,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? WrColors.white : WrColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SavedBadge
// ---------------------------------------------------------------------------

class _SavedBadge extends StatelessWidget {
  const _SavedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: WrColors.successBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_outline, color: WrColors.success, size: 16),
          SizedBox(width: 6),
          Text(
            'Đã lưu · Check-in hôm nay',
            style: TextStyle(
              fontSize: 13,
              color: WrColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
