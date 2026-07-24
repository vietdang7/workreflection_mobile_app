import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/data/wr_repository.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/mobile_profile.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../wr_providers.dart';
import '../wr_situation_service.dart';

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

  Mood get mood => switch (this) {
        _MoodOption.stressed => Mood.stressed,
        _MoodOption.tired    => Mood.tired,
        _MoodOption.okay     => Mood.okay,
        _MoodOption.happy    => Mood.happy,
      };

  /// Whether this option corresponds to a "low/tired" state
  bool get isLowEnergy => this == _MoodOption.stressed || this == _MoodOption.tired;

  /// Q2 title for this mood
  String get q2Title => switch (this) {
        _MoodOption.stressed => 'Điều gì đang khiến bạn căng thẳng?',
        _MoodOption.tired    => 'Bạn mệt vì điều gì?',
        _MoodOption.okay     => 'Có điều gì bạn muốn nhìn lại hôm nay không?',
        _MoodOption.happy    => 'Bạn muốn phát triển điều gì tiếp theo?',
      };

  /// HumanNeeds to filter Q2 chips for this mood (ordered by priority).
  List<HumanNeed> get q2Needs => switch (this) {
        _MoodOption.stressed => [HumanNeed.ketNoi, HumanNeed.thichNghi],
        _MoodOption.tired    => [HumanNeed.thichNghi, HumanNeed.phatTrien],
        _MoodOption.okay     => [HumanNeed.roRang],
        _MoodOption.happy    => [HumanNeed.phatTrien],
      };
}

/// Reverse-map from saved Checkin → best matching _MoodOption for prepopulate.
/// Uses checkin.mood first (can distinguish stressed vs tired), falls back to
/// energy if mood doesn't match the 4 known values.
_MoodOption? _moodOptionFromCheckin(Checkin? checkin) {
  if (checkin == null) return null;
  // Prefer mood field — gives exact mapping including stressed vs tired.
  return switch (checkin.mood) {
    Mood.stressed => _MoodOption.stressed,
    Mood.tired    => _MoodOption.tired,
    Mood.okay     => _MoodOption.okay,
    Mood.happy    => _MoodOption.happy,
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
  bool _saving = false;
  _MoodOption? _pendingOption; // latest-wins: queued option while _saving==true

  // Q2 state
  String? _selectedSituationCode;   // null = no chip selected yet
  bool _situationSaved = false;     // true = chip was saved successfully
  int _situationCount = 0;          // pattern count after save (for "lần thứ N" message)
  bool _savingSituation = false;    // spinner guard for chip tap
  WrSituation? _selectedSituation; // full WrSituation after chip save, for card
  WrStory? _suggestedStory;        // story matching scaDimension after chip save
  bool _okayDone = false;           // true = user tapped "Không, hôm nay ổn"
  bool _joyDone = false;            // true = user tapped "Chỉ muốn ghi lại niềm vui"
  bool _savingJoyEscape = false;    // race guard: set true BEFORE first await, cleared in finally
  String? _joyMessage;              // message shown after joy escape tap

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
    // Latest-wins: if already saving, record the pending option and return.
    if (_saving) {
      setState(() {
        _selected = option; // optimistic UI update
        _pendingOption = option;
      });
      return;
    }

    final previousSelected = _selected;
    setState(() {
      _selected = option;
      _saving = true;
      _pendingOption = null;
      _okayDone = false;
      _joyDone = false;
      _joyMessage = null;
      _situationSaved = false;
      _selectedSituationCode = null;
      _suggestedStory = null;
    });

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
        // Only revert if no newer tap has already updated _selected.
        final hasNewerTap = _pendingOption != null;
        setState(() {
          if (!hasNewerTap) {
            _selected = previousSelected;
            _saved = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được check-in. Thử lại.')),
        );
      }
    } finally {
      if (mounted) {
        final next = _pendingOption;
        setState(() {
          _saving = false;
          _pendingOption = null;
        });
        // If a newer tap came in while saving, process it now.
        if (next != null) {
          await _save(next);
        }
      }
    }
  }

  Future<void> _saveSituation(WrSituation sit) async {
    if (_savingSituation) return;

    setState(() { _savingSituation = true; _selectedSituationCode = sit.code; });
    try {
      // Map mood to emotion string for memory event.
      final emotion = switch (_selected) {
        _MoodOption.stressed => 'low',
        _MoodOption.tired    => 'low',
        _MoodOption.okay     => 'ok',
        _MoodOption.happy    => 'good',
        null                 => null,
      };

      final count = await commitTodaySituation(ref, sit: sit, emotion: emotion);

      // Fetch a suggested story for this dimension
      WrStory? suggested;
      try {
        final storyRepo = ref.read(wrContentRepositoryProvider);
        final stories = await storyRepo.fetchStories(dimension: sit.scaDimension);
        suggested = stories.isNotEmpty ? stories.first : null;
      } catch (_) {
        suggested = null;
      }
      if (mounted) {
        setState(() {
          _situationSaved = true;
          _situationCount = count;
          _savingSituation = false;
          _selectedSituation = sit;
          _suggestedStory = suggested;
        });
        ref.invalidate(wrPatternCountsProvider);
      }
    } catch (_) {
      if (mounted) {
        setState(() { _savingSituation = false; _selectedSituationCode = null; _selectedSituation = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được tình huống. Thử lại.')),
        );
      }
    }
  }

  /// Tap on "Chỉ muốn ghi lại niềm vui" chip (happy mood escape).
  /// Inserts a reflection_step notice but does NOT call recordSituationOccurrence.
  Future<void> _tapJoyEscape() async {
    if (_joyDone || _savingJoyEscape) return;
    // Set guard IMMEDIATELY before any await to prevent double-tap race condition.
    setState(() { _savingJoyEscape = true; });
    final userId = ref.read(currentUserIdProvider) ?? '';
    if (userId.isEmpty) {
      setState(() { _savingJoyEscape = false; });
      return;
    }
    final intelRepo = ref.read(wrIntelligenceRepositoryProvider);
    try {
      await intelRepo.insertReflectionStep(ReflectionStep(
        userId: userId,
        step: ReflectionStepType.notice,
        content: 'Ghi lại niềm vui',
      ));
      if (mounted) {
        setState(() {
          _joyDone = true;
          _joyMessage = 'Đã ghi lại — thật tốt khi có một ngày như vậy.';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được. Thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() { _savingJoyEscape = false; });
    }
  }

  /// Build filtered + sorted list of Q2 situation chips for the selected mood.
  List<WrSituation> _buildQ2Chips(
    List<WrSituation> situations,
    List<PatternCount> patterns,
  ) {
    if (_selected == null || situations.isEmpty) return const [];

    final needs = _selected!.q2Needs;

    // Pool: situations whose humanNeed is in the mood's needs list.
    // Order: by needs list order (first need's sits first, then second need's, etc.)
    List<WrSituation> pool = [];
    for (final need in needs) {
      final needSits = situations.where((s) => s.humanNeed == need).toList();
      // For happy mood (phatTrien only): sort by ScaDimension enum index descending
      // so A4(9) > A3(8) > A2(7) > A1(6) — safe even if pool mixes S/C dimensions.
      if (_selected == _MoodOption.happy && need == HumanNeed.phatTrien) {
        needSits.sort((a, b) => b.scaDimension.index.compareTo(a.scaDimension.index));
      }
      pool.addAll(needSits);
    }

    // Priority: pool situations that appear in patterns, sorted by occurrenceCount desc
    final prioritySits = patterns
        .map((p) => pool.where((s) => s.code == p.situationCode).firstOrNull)
        .whereType<WrSituation>()
        .toList();
    final prioritySet = {for (final s in prioritySits) s.code};

    // Fill remaining from pool (preserving pool order)
    final fillSits = pool.where((s) => !prioritySet.contains(s.code)).toList();

    return [...prioritySits, ...fillSits].take(5).toList();
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
          final option = _moodOptionFromCheckin(checkin);
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
    final storyEyebrow = _situationSaved
        ? 'GỢI Ý CHO BẠN'
        : (isLowSaved ? 'GỢI Ý KHI MỆT MỎI' : 'GỢI Ý HÔM NAY');

    // Build Q2 chips filtered by mood's needs
    final q2Chips = _buildQ2Chips(situations, patterns);

    // Whether Q2 escape chips have been acted on (okay or happy)
    final isEscapeDone = _okayDone || _joyDone;

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
                    const WrTabBackLink(currentTab: WrTab.home),
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

            // ── check-in section: 2×2 mood grid + Q2 reveal ─────────────
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
                    // ── Q2 inline reveal (AnimatedSize) ─────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _selected == null
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                Text(
                                  _selected!.q2Title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: WrColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    // "Không, hôm nay ổn" escape chip — only for okay, before tap
                                    if (_selected == _MoodOption.okay && !_okayDone)
                                      GestureDetector(
                                        onTap: () => setState(() { _okayDone = true; }),
                                        child: _EscapeChip(label: 'Không, hôm nay ổn'),
                                      ),
                                    // "Chỉ muốn ghi lại niềm vui" escape chip — only for happy, before tap
                                    if (_selected == _MoodOption.happy && !_joyDone)
                                      GestureDetector(
                                        onTap: _tapJoyEscape,
                                        child: _EscapeChip(label: 'Chỉ muốn ghi lại niềm vui'),
                                      ),
                                    // Real situation chips (up to 5) — only when NOT escaped
                                    if (!isEscapeDone)
                                      ...q2Chips.map((sit) => GestureDetector(
                                            onTap: () => _saveSituation(sit),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _selectedSituationCode == sit.code
                                                    ? WrColors.coral
                                                    : WrColors.cream,
                                                borderRadius: BorderRadius.circular(100),
                                              ),
                                              child: Text(
                                                sit.text,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: _selectedSituationCode == sit.code
                                                      ? WrColors.white
                                                      : WrColors.navy,
                                                ),
                                              ),
                                            ),
                                          )),
                                    // "Khác →" chip — only when NOT escaped
                                    if (!isEscapeDone)
                                      GestureDetector(
                                        onTap: () => context.push('/wr/situation'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: WrColors.cream,
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: const Text(
                                            'Khác →',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: WrColors.navy,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                // "Không, hôm nay ổn" closing line
                                if (_okayDone) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Tuyệt. Hẹn gặp bạn ngày mai.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: WrColors.muted,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                                // "Chỉ muốn ghi lại niềm vui" closing line
                                if (_joyDone && _joyMessage != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _joyMessage!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: WrColors.muted,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                                // Confirmation card after chip save
                                if (_situationSaved && _selectedSituation != null) ...[
                                  const SizedBox(height: 16),
                                  WrCardMinimal(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (_selectedSituation!.expectedOutcome != null)
                                          Text(
                                            'Nghe như điều bạn đang mong: "${_selectedSituation!.expectedOutcome}"',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontStyle: FontStyle.italic,
                                              color: WrColors.navy,
                                              height: 1.5,
                                            ),
                                          ),
                                        if (_selectedSituation!.expectedOutcome != null && _selectedSituation!.scaPerspective != null)
                                          const SizedBox(height: 10),
                                        if (_selectedSituation!.scaPerspective != null)
                                          Text(
                                            _selectedSituation!.scaPerspective!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: WrColors.navy.withValues(alpha: 0.75),
                                              height: 1.5,
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _situationCount >= 2
                                              ? 'Hệ thống đã ghi nhớ — đây là lần thứ $_situationCount bạn gặp tình huống này.'
                                              : 'Hệ thống sẽ ghi nhớ điều này cho hành trình của bạn.',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: WrColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 28),
                  ],
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
                          onTap: () => context.go('/wr/discover?from=home'),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _suggestedStory != null
                                      ? _suggestedStory!.title
                                      : 'Bạn chưa đọc câu chuyện nào.',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: WrColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _suggestedStory != null
                                      ? (_suggestedStory!.situation ?? 'Câu chuyện giúp bạn nhận ra pattern nghề nghiệp.')
                                      : 'Câu chuyện giúp bạn nhận ra pattern nghề nghiệp.',
                                  style: const TextStyle(
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
                      label: _suggestedStory != null ? 'Đọc câu chuyện này' : 'Đọc câu chuyện đầu tiên',
                      onTap: () {
                        if (_suggestedStory != null && _selectedSituation != null) {
                          context.push('/wr/story/flow?dimension=${_selectedSituation!.scaDimension.dbValue}');
                        } else {
                          context.push('/wr/story');
                        }
                      },
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
// _EscapeChip — shared pill widget for escape options (okay / happy)
// ---------------------------------------------------------------------------

class _EscapeChip extends StatelessWidget {
  const _EscapeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: WrColors.cream,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: WrColors.navy,
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
