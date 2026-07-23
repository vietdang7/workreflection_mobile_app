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
// Mood option data
// ---------------------------------------------------------------------------

enum _MoodOption {
  stressed,  // "Tôi đang căng thẳng"
  tired,     // "Tôi mệt mỏi cần nghỉ ngơi"
  okay,      // "Tôi khá ổn"
  happy;     // "Tôi đang vui"

  String get label => switch (this) {
        _MoodOption.stressed => 'Tôi đang\ncăng thẳng',
        _MoodOption.tired    => 'Tôi mệt mỏi\ncần nghỉ ngơi',
        _MoodOption.okay     => 'Tôi\nkhá ổn',
        _MoodOption.happy    => 'Tôi\nđang vui',
      };

  CheckinEnergy get energy => switch (this) {
        _MoodOption.stressed => CheckinEnergy.low,
        _MoodOption.tired    => CheckinEnergy.low,
        _MoodOption.okay     => CheckinEnergy.ok,
        _MoodOption.happy    => CheckinEnergy.good,
      };

  Mood get mood => energy.toMood();

  /// Whether this option corresponds to a "low/tired" state (shows share card)
  bool get isLowEnergy => this == _MoodOption.stressed || this == _MoodOption.tired;
}

/// Reverse-map from saved energy → best matching _MoodOption for prepopulate.
/// low → tired, ok → okay, good → happy (stressed has same energy as tired,
/// so we default to tired for prepopulate since we can't distinguish from DB).
_MoodOption? _moodOptionFromEnergy(CheckinEnergy? energy) {
  if (energy == null) return null;
  return switch (energy) {
    CheckinEnergy.low  => _MoodOption.tired,
    CheckinEnergy.ok   => _MoodOption.okay,
    CheckinEnergy.good => _MoodOption.happy,
  };
}

// ---------------------------------------------------------------------------
// WrHomeScreen
// ---------------------------------------------------------------------------

class WrHomeScreen extends ConsumerStatefulWidget {
  const WrHomeScreen({super.key});

  @override
  ConsumerState<WrHomeScreen> createState() => _WrHomeScreenState();
}

class _WrHomeScreenState extends ConsumerState<WrHomeScreen> {
  _MoodOption? _selected;
  bool _saved = false;
  bool _prepopulated = false;

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

  Future<void> _save(_MoodOption option) async {
    final previousSelected = _selected;
    setState(() { _selected = option; });
    try {
      final repo = ref.read(wrRepositoryProvider);
      await repo.upsertCheckin(
        option.mood,
        energy: option.energy,
        direction: null,
      );
      if (mounted) {
        setState(() { _saved = true; });
        ref.invalidate(todayCheckinProvider);
        ref.invalidate(wrPatternCountsProvider);
      }
    } catch (_) {
      if (mounted) {
        // Revert selection on error
        setState(() {
          _selected = previousSelected;
          _saved = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được check-in. Thử lại.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_mobileProfileProvider);
    final patternsAsync = ref.watch(wrPatternCountsProvider);
    final situationsAsync = ref.watch(wrSituationsProvider);
    final insightAsync = ref.watch(wrLatestInsightProvider);

    // Pre-populate from today's saved check-in (runs once)
    ref.listen<AsyncValue<Checkin?>>(todayCheckinProvider, (_, next) {
      next.whenData((checkin) {
        if (checkin != null && !_prepopulated && mounted) {
          final option = _moodOptionFromEnergy(checkin.energy);
          setState(() {
            _prepopulated = true;
            _saved = true;
            if (option != null) _selected = option;
          });
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

    // Conditions based on selected mood
    final isLowSaved = _saved && (_selected?.isLowEnergy ?? false);
    final storyEyebrow = isLowSaved ? 'GỢI Ý KHI MỆT MỎI' : 'GỢI Ý HÔM NAY';

    return Scaffold(
      backgroundColor: WrColors.white,
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
                        letterSpacing: -0.03 * 32,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── check-in section: 2×2 mood grid ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
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
                    const SizedBox(height: 24),
                    // 2×2 grid
                    Column(
                      children: [
                        Row(
                          children: [
                            _MoodButton(
                              option: _MoodOption.stressed,
                              selected: _selected == _MoodOption.stressed,
                              onTap: () => _save(_MoodOption.stressed),
                            ),
                            const SizedBox(width: 12),
                            _MoodButton(
                              option: _MoodOption.tired,
                              selected: _selected == _MoodOption.tired,
                              onTap: () => _save(_MoodOption.tired),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _MoodButton(
                              option: _MoodOption.okay,
                              selected: _selected == _MoodOption.okay,
                              onTap: () => _save(_MoodOption.okay),
                            ),
                            const SizedBox(width: 12),
                            _MoodButton(
                              option: _MoodOption.happy,
                              selected: _selected == _MoodOption.happy,
                              onTap: () => _save(_MoodOption.happy),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // ── share card (low energy: stressed or tired) ───────────────
            if (isLowSaved)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
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

            // ── divider (duy nhất) ────────────────────────────────────────
            const SliverToBoxAdapter(child: WrSectionDivider()),

            // ── card hệ thống nhận ra ─────────────────────────────────────
            if (topPattern != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
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
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],

            // ── section gợi ý story ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, topPattern != null ? 0 : 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WrEyebrow(storyEyebrow),
                    const SizedBox(height: 10),
                    WrCardMinimal(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon ô 48×48
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: WrColors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              color: WrColors.navy,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Text column
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bạn chưa đọc câu chuyện nào.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: WrColors.navy,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Câu chuyện giúp bạn nhận ra pattern nghề nghiệp.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: WrColors.muted,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    WrActionLink(
                      label: 'Đọc câu chuyện đầu tiên',
                      onTap: () => context.push('/wr/story'),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // ── insight section ───────────────────────────────────────────
            if (insight != null) ...[
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
// _MoodButton — 2×2 grid button
// ---------------------------------------------------------------------------

class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _MoodOption option;
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
            option.label,
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
