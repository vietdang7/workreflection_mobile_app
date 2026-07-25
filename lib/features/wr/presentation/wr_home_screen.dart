import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/data/wr_repository.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/logic/wr_career_profile.dart';
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
// Check-in options — sáu lựa chọn: 3 mức năng lượng rồi 3 hướng đi.
// ---------------------------------------------------------------------------

enum _EnergyOption {
  good, // "Có năng lượng"
  ok, // "Bình thường"
  low; // "Mệt mỏi"

  String get label => switch (this) {
    _EnergyOption.good => 'Có năng lượng',
    _EnergyOption.ok => 'Bình thường',
    _EnergyOption.low => 'Mệt mỏi',
  };

  CheckinEnergy get energy => switch (this) {
    _EnergyOption.good => CheckinEnergy.good,
    _EnergyOption.ok => CheckinEnergy.ok,
    _EnergyOption.low => CheckinEnergy.low,
  };

  Mood get mood => switch (this) {
    _EnergyOption.good => Mood.happy,
    _EnergyOption.ok => Mood.okay,
    _EnergyOption.low => Mood.tired,
  };

  /// Mã cảm xúc lưu kèm memory-event khi người dùng chọn tình huống.
  String get emotionCode => switch (this) {
    _EnergyOption.good => 'good',
    _EnergyOption.ok => 'ok',
    _EnergyOption.low => 'low',
  };

  bool get isLowEnergy => this == _EnergyOption.low;

  /// Câu hỏi tiếp theo (Q2) tương ứng mức năng lượng.
  String get q2Title => switch (this) {
    _EnergyOption.low => 'Điều gì đang làm bạn mất năng lượng?',
    _EnergyOption.ok => 'Có điều gì bạn muốn nhìn lại hôm nay không?',
    _EnergyOption.good => 'Bạn muốn phát triển điều gì tiếp theo?',
  };

  /// HumanNeed dùng để lọc chip tình huống ở Q2 (theo thứ tự ưu tiên).
  List<HumanNeed> get q2Needs => switch (this) {
    _EnergyOption.low => [HumanNeed.thichNghi, HumanNeed.ketNoi],
    _EnergyOption.ok => [HumanNeed.roRang],
    _EnergyOption.good => [HumanNeed.phatTrien],
  };
}

enum _DirectionOption {
  forward, // "Tiến lên"
  steady, // "Đứng yên"
  backward; // "Thụt lùi"

  String get label => switch (this) {
    _DirectionOption.forward => 'Tiến lên',
    _DirectionOption.steady => 'Đứng yên',
    _DirectionOption.backward => 'Thụt lùi',
  };

  CheckinDirection get direction => switch (this) {
    _DirectionOption.forward => CheckinDirection.forward,
    _DirectionOption.steady => CheckinDirection.steady,
    _DirectionOption.backward => CheckinDirection.backward,
  };
}

/// Reverse-map từ check-in đã lưu → lựa chọn năng lượng, để prepopulate.
/// Ưu tiên trường `energy`; nếu thiếu thì suy ra từ `mood`.
_EnergyOption? _energyOptionFromCheckin(Checkin? checkin) {
  if (checkin == null) return null;
  return switch (checkin.energy) {
    CheckinEnergy.good => _EnergyOption.good,
    CheckinEnergy.ok => _EnergyOption.ok,
    CheckinEnergy.low => _EnergyOption.low,
    null => switch (checkin.mood) {
      Mood.happy => _EnergyOption.good,
      Mood.okay => _EnergyOption.ok,
      Mood.tired || Mood.stressed => _EnergyOption.low,
    },
  };
}

_DirectionOption? _directionOptionFromCheckin(Checkin? checkin) {
  return switch (checkin?.direction) {
    CheckinDirection.forward => _DirectionOption.forward,
    CheckinDirection.steady => _DirectionOption.steady,
    CheckinDirection.backward => _DirectionOption.backward,
    null => null,
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
  _EnergyOption? _selected;
  _DirectionOption? _direction;
  bool _saved = false;
  bool _prepopulated = false;
  bool _saving = false;
  String? _checkinError; // lỗi lưu check-in, hiện ngay dưới nút Lưu

  // Q2 state
  String? _selectedSituationCode; // null = no chip selected yet
  bool _situationSaved = false; // true = chip was saved successfully
  int _situationCount = 0; // pattern count after save (for "lần thứ N" message)
  bool _savingSituation = false; // spinner guard for chip tap
  WrSituation? _selectedSituation; // full WrSituation after chip save, for card
  WrStory? _suggestedStory; // story matching scaDimension after chip save
  bool _okayDone = false; // true = user tapped "Không, hôm nay ổn"
  bool _joyDone = false; // true = user tapped "Chỉ muốn ghi lại niềm vui"
  bool _savingJoyEscape =
      false; // race guard: set true BEFORE first await, cleared in finally
  String? _joyMessage; // message shown after joy escape tap

  String _dateLabel() {
    final now = todayVn();
    final weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    return '${weekdays[now.weekday - 1]}, $day/$month';
  }

  /// Chọn mức năng lượng. Chưa ghi gì — chỉ mở phần chọn hướng đi và dọn lại
  /// trạng thái Q2 của lần check-in trước.
  void _selectEnergy(_EnergyOption option) {
    if (_saving) return;
    setState(() {
      _selected = option;
      _saved = false;
      _checkinError = null;
      _okayDone = false;
      _joyDone = false;
      _joyMessage = null;
      _situationSaved = false;
      _selectedSituationCode = null;
      _selectedSituation = null;
      _suggestedStory = null;
    });
  }

  void _selectDirection(_DirectionOption option) {
    if (_saving) return;
    setState(() {
      _direction = option;
      _saved = false;
      _checkinError = null;
    });
  }

  /// Ghi check-in — chỉ chạy khi người dùng bấm nút Lưu, và chỉ khi đã chọn
  /// đủ cả năng lượng lẫn hướng đi.
  Future<void> _saveCheckin() async {
    final option = _selected;
    final direction = _direction;
    if (option == null || direction == null || _saving) return;

    setState(() {
      _saving = true;
      _checkinError = null;
    });

    try {
      final repo = ref.read(wrRepositoryProvider);
      await repo.upsertCheckin(
        option.mood,
        energy: option.energy,
        direction: direction.direction,
      );
      if (mounted) {
        setState(() {
          _saved = true;
        });
        ref.invalidate(todayCheckinProvider);
        ref.invalidate(wrPatternCountsProvider);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saved = false;
          _checkinError = 'Không lưu được check-in. Thử lại.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveSituation(WrSituation sit) async {
    if (_savingSituation) return;

    setState(() {
      _savingSituation = true;
      _selectedSituationCode = sit.code;
    });
    try {
      // Map energy to emotion string for memory event.
      final emotion = _selected?.emotionCode;

      final count = await commitTodaySituation(ref, sit: sit, emotion: emotion);

      // Fetch a suggested story for this dimension
      WrStory? suggested;
      try {
        final storyRepo = ref.read(wrContentRepositoryProvider);
        final stories = await storyRepo.fetchStories(
          dimension: sit.scaDimension,
        );
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
        setState(() {
          _savingSituation = false;
          _selectedSituationCode = null;
          _selectedSituation = null;
        });
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
    setState(() {
      _savingJoyEscape = true;
    });
    final userId = ref.read(currentUserIdProvider) ?? '';
    if (userId.isEmpty) {
      setState(() {
        _savingJoyEscape = false;
      });
      return;
    }
    final intelRepo = ref.read(wrIntelligenceRepositoryProvider);
    try {
      await intelRepo.insertReflectionStep(
        ReflectionStep(
          userId: userId,
          step: ReflectionStepType.notice,
          content: 'Ghi lại niềm vui',
        ),
      );
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
      if (mounted) {
        setState(() {
          _savingJoyEscape = false;
        });
      }
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
      // For good energy (phatTrien only): sort by ScaDimension enum index descending
      // so A4(9) > A3(8) > A2(7) > A1(6) — safe even if pool mixes S/C dimensions.
      if (_selected == _EnergyOption.good && need == HumanNeed.phatTrien) {
        needSits.sort(
          (a, b) => b.scaDimension.index.compareTo(a.scaDimension.index),
        );
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
          final option = _energyOptionFromCheckin(checkin);
          final direction = _directionOptionFromCheckin(checkin);
          setState(() {
            _prepopulated = true;
            _saved = true;
            if (option != null) _selected = option;
            if (direction != null) _direction = direction;
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName.isNotEmpty
                                    ? 'Chào $displayName'
                                    : 'Chào bạn',
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
                        // Avatar → hồ sơ (Tôi không còn là một tab riêng).
                        _ProfileAvatarButton(displayName: displayName),
                      ],
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
                      'Ngày hôm nay của bạn như thế nào?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        letterSpacing: -0.02 * 22,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Bước 1 — mức năng lượng (3 lựa chọn)
                    const WrEyebrow('NĂNG LƯỢNG'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final option in _EnergyOption.values) ...[
                          if (option != _EnergyOption.values.first)
                            const SizedBox(width: 10),
                          _ChoiceButton(
                            label: option.label,
                            selected: _selected == option,
                            onTap: () => _selectEnergy(option),
                          ),
                        ],
                      ],
                    ),
                    // Bước 2 — hướng đi, chỉ hiện sau khi đã chọn năng lượng
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _selected == null
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                const WrEyebrow('HÔM NAY BẠN THẤY MÌNH'),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    for (final option
                                        in _DirectionOption.values) ...[
                                      if (option !=
                                          _DirectionOption.values.first)
                                        const SizedBox(width: 10),
                                      _ChoiceButton(
                                        label: option.label,
                                        selected: _direction == option,
                                        onTap: () => _selectDirection(option),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    key: const Key('wr_save_checkin_button'),
                                    onPressed: (_direction == null || _saving)
                                        ? null
                                        : _saveCheckin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: WrColors.navy,
                                      foregroundColor: WrColors.white,
                                      disabledBackgroundColor: WrColors.cream,
                                      disabledForegroundColor: WrColors.muted,
                                      minimumSize: const Size.fromHeight(48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      _saved
                                          ? 'Đã lưu check-in'
                                          : 'Lưu check-in',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_checkinError != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    _checkinError!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: WrColors.coral,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    // ── Q2 inline reveal (AnimatedSize) ─────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: (_selected == null || !_saved)
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
                                    if (_selected == _EnergyOption.ok &&
                                        !_okayDone)
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          _okayDone = true;
                                        }),
                                        child: _EscapeChip(
                                          label: 'Không, hôm nay ổn',
                                        ),
                                      ),
                                    // "Chỉ muốn ghi lại niềm vui" escape chip — only for happy, before tap
                                    if (_selected == _EnergyOption.good &&
                                        !_joyDone)
                                      GestureDetector(
                                        onTap: _tapJoyEscape,
                                        child: _EscapeChip(
                                          label: 'Chỉ muốn ghi lại niềm vui',
                                        ),
                                      ),
                                    // Real situation chips (up to 5) — only when NOT escaped
                                    if (!isEscapeDone)
                                      ...q2Chips.map(
                                        (sit) => GestureDetector(
                                          onTap: () => _saveSituation(sit),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  _selectedSituationCode ==
                                                      sit.code
                                                  ? WrColors.coral
                                                  : WrColors.cream,
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                            child: Text(
                                              sit.text,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    _selectedSituationCode ==
                                                        sit.code
                                                    ? WrColors.white
                                                    : WrColors.navy,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // "Khác →" chip — only when NOT escaped
                                    if (!isEscapeDone)
                                      GestureDetector(
                                        onTap: () =>
                                            context.push('/wr/situation'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: WrColors.cream,
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
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
                                if (_situationSaved &&
                                    _selectedSituation != null) ...[
                                  const SizedBox(height: 16),
                                  WrCardMinimal(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_selectedSituation!
                                                .expectedOutcome !=
                                            null)
                                          Text(
                                            'Nghe như điều bạn đang mong: "${_selectedSituation!.expectedOutcome}"',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontStyle: FontStyle.italic,
                                              color: WrColors.navy,
                                              height: 1.5,
                                            ),
                                          ),
                                        if (_selectedSituation!
                                                    .expectedOutcome !=
                                                null &&
                                            _selectedSituation!
                                                    .scaPerspective !=
                                                null)
                                          const SizedBox(height: 10),
                                        if (_selectedSituation!
                                                .scaPerspective !=
                                            null)
                                          Text(
                                            _selectedSituation!.scaPerspective!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: WrColors.navy.withValues(
                                                alpha: 0.75,
                                              ),
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

            // ── career snapshot ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: _CareerSnapshotCard(
                  snapshot:
                      ref.watch(wrCareerSnapshotProvider).valueOrNull ??
                      const CareerSnapshot(),
                ),
              ),
            ),

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
                padding: EdgeInsets.fromLTRB(
                  24,
                  topPattern != null ? 0 : 28,
                  24,
                  0,
                ),
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
                                      ? (_suggestedStory!.situation ??
                                            'Câu chuyện giúp bạn nhận ra pattern nghề nghiệp.')
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
                      label: _suggestedStory != null
                          ? 'Đọc câu chuyện này'
                          : 'Đọc câu chuyện đầu tiên',
                      onTap: () {
                        if (_suggestedStory != null &&
                            _selectedSituation != null) {
                          context.push(
                            '/wr/story/flow?dimension=${_selectedSituation!.scaDimension.dbValue}',
                          );
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
// _ChoiceButton — ô chọn dùng chung cho hàng năng lượng và hàng hướng đi
// ---------------------------------------------------------------------------

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
// _ProfileAvatarButton — lối vào hồ sơ từ header
// ---------------------------------------------------------------------------

class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({required this.displayName});

  final String displayName;

  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return 'WR';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('wr_home_profile_button'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/profile'),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: WrColors.cream,
          shape: BoxShape.circle,
        ),
        child: Text(
          _initials,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Career Snapshot card
// Spec: giao-dien-ho-tro.jsx — CareerSnapshotCard.
// Chưa thiết lập → lời mời; đã thiết lập → tóm tắt + "Cập nhật".
// ---------------------------------------------------------------------------

class _CareerSnapshotCard extends StatelessWidget {
  const _CareerSnapshotCard({required this.snapshot});

  final CareerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final empty = snapshot.isEmpty;
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrEyebrow('CAREER SNAPSHOT'),
          const SizedBox(height: 10),
          if (empty) ...[
            const Text(
              'Thêm vài thông tin để WorkReflection gợi ý đúng với bối cảnh '
              'công việc của bạn.',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            WrActionLink(
              label: 'Thiết lập hồ sơ',
              onTap: () => context.push('/wr/career-setup'),
            ),
          ] else ...[
            if (snapshot.currentRole != null)
              _SnapshotRow(label: 'Vai trò', value: snapshot.currentRole!),
            if (snapshot.careerGoal != null)
              _SnapshotRow(label: 'Quan tâm', value: snapshot.careerGoal!),
            if (snapshot.currentChallenge != null)
              _SnapshotRow(
                label: 'Trăn trở',
                value: snapshot.currentChallenge!,
              ),
            const SizedBox(height: 10),
            WrActionLink(
              label: 'Cập nhật',
              onTap: () => context.push('/wr/career-setup'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: WrColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
