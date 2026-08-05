import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_career_profile.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

// Phase order cho story flow
enum _StoryPhase { story, aha, confidence, reflection, practice, memory }

const _phaseLabels = {
  _StoryPhase.story: 'Bạn có bao giờ?',
  _StoryPhase.aha: 'Điều WorkReflection nhận ra',
  _StoryPhase.confidence: 'Mức độ nhận ra',
  _StoryPhase.reflection: 'Ghi lại suy nghĩ',
  _StoryPhase.practice: 'Thực hành nhỏ',
  _StoryPhase.memory: 'Phân loại trải nghiệm',
};

class WrStoryFlowScreen extends ConsumerStatefulWidget {
  const WrStoryFlowScreen({super.key, this.initialDimension});

  final ScaDimension? initialDimension;

  @override
  ConsumerState<WrStoryFlowScreen> createState() => _WrStoryFlowScreenState();
}

class _WrStoryFlowScreenState extends ConsumerState<WrStoryFlowScreen> {
  _StoryPhase _phase = _StoryPhase.story;
  WrStory? _story;
  int _storyIndex = 0;
  List<WrStory> _stories = [];
  bool _loaded = false;

  int _intensity = 0; // 3=Rất, 2=Hơi, 1=Không
  String _reflectionText = '';
  bool _practiceAdded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    final contentRepo = ref.read(wrContentRepositoryProvider);
    final allStories = await contentRepo.fetchStories(dimension: widget.initialDimension);
    final events = await contentRepo.fetchMemoryEvents(limit: 200);
    final seenIds = events.map((e) => e.storyId).whereType<String>().toSet();

    // Xếp theo Career Snapshot: ba chiều của vai trò trước, phần còn lại theo
    // thứ tự đợt triển khai (DataSpec v3 Tầng 4). Chưa có hồ sơ → thứ tự đợt.
    final snapshot =
        ref.read(wrCareerSnapshotProvider).valueOrNull ?? const CareerSnapshot();
    final sorted = rankStoriesForProfile(allStories, snapshot);

    // Remove seen, but keep fallback
    final unseen = sorted.where((s) => !seenIds.contains(s.storyId)).toList();
    final list = unseen.isNotEmpty ? unseen : sorted;

    if (mounted) {
      setState(() {
        _stories = list;
        _story = list.isNotEmpty ? list.first : null;
        _loaded = true;
      });
    }
  }

  void _nextStory() {
    final next = _storyIndex + 1;
    if (next < _stories.length) {
      setState(() {
        _storyIndex = next;
        _story = _stories[next];
        _phase = _StoryPhase.story;
        _intensity = 0;
        _reflectionText = '';
        _practiceAdded = false;
      });
    } else {
      if (mounted) context.go('/home');
    }
  }

  Future<void> _saveMemory(String memType) async {
    if (_story == null) return;
    setState(() => _saving = true);
    try {
      final userId = ref.read(currentUserIdProvider) ?? '';
      final contentRepo = ref.read(wrContentRepositoryProvider);
      final intelRepo = ref.read(wrIntelligenceRepositoryProvider);
      final story = _story!;

      // (a) insert CareerMemoryEvent
      await contentRepo.insertMemoryEvent(CareerMemoryEvent(
        id: '',
        userId: userId,
        storyId: story.storyId,
        scaDimension: story.scaDimension,
        humanNeed: story.humanNeed,
        intensity: _intensity,
        reflectionText: _reflectionText.isNotEmpty ? _reflectionText : null,
        behavior: memType,
      ));

      // (b) insert WrInsight
      if (story.ahaMessage != null) {
        await intelRepo.insertInsight(WrInsight(
          userId: userId,
          source: 'story',
          scaDimension: story.scaDimension,
          humanNeed: story.humanNeed,
          content: story.ahaMessage!,
        ));
      }

      // (c) insert ReflectionSteps: insight + action
      await intelRepo.insertReflectionStep(ReflectionStep(
        userId: userId,
        step: ReflectionStepType.insight,
        content: story.ahaMessage,
      ));
      if (_practiceAdded && story.practiceAction != null) {
        await intelRepo.insertReflectionStep(ReflectionStep(
          userId: userId,
          step: ReflectionStepType.action,
          content: story.practiceAction,
        ));
      } else {
        await intelRepo.insertReflectionStep(ReflectionStep(
          userId: userId,
          step: ReflectionStepType.action,
          content: null,
        ));
      }

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  double get _progress {
    const phases = _StoryPhase.values;
    final idx = phases.indexOf(_phase);
    return (idx + 1) / phases.length;
  }

  String get _phaseLabel => _phaseLabels[_phase] ?? '';

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_story == null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Không có câu chuyện nào.'),
            TextButton(onPressed: () => context.go('/home'), child: const Text('Về trang chủ')),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: back + progress + close
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: _phase == _StoryPhase.story ? null : () {
                      setState(() {
                        final idx = _StoryPhase.values.indexOf(_phase);
                        if (idx > 0) _phase = _StoryPhase.values[idx - 1];
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: WrColors.line,
                          color: WrColors.navy,
                          minHeight: 3,
                        ),
                        const SizedBox(height: 4),
                        Text(_phaseLabel,
                            style: const TextStyle(fontSize: 11.5, color: WrColors.text3, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildPhase()),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase() {
    final story = _story!;
    return switch (_phase) {
      _StoryPhase.story => _PhaseStory(
          story: story,
          onResonates: () => setState(() => _phase = _StoryPhase.aha),
          onNotResonates: _nextStory,
        ),
      _StoryPhase.aha => _PhaseAha(
          story: story,
          onContinue: () => setState(() => _phase = _StoryPhase.confidence),
        ),
      _StoryPhase.confidence => _PhaseConfidence(
          onSelect: (intensity) => setState(() {
            _intensity = intensity;
            _phase = _StoryPhase.reflection;
          }),
        ),
      _StoryPhase.reflection => _PhaseReflection(
          story: story,
          onSave: (text) => setState(() {
            _reflectionText = text;
            _phase = _StoryPhase.practice;
          }),
          onSkip: () => setState(() => _phase = _StoryPhase.practice),
        ),
      _StoryPhase.practice => _PhasePractice(
          story: story,
          onAdd: () => setState(() {
            _practiceAdded = true;
            _phase = _StoryPhase.memory;
          }),
          onSkip: () => setState(() => _phase = _StoryPhase.memory),
        ),
      _StoryPhase.memory => _PhaseMemory(saving: _saving, onSelect: _saveMemory),
    };
  }
}

// ---------------------------------------------------------------------------
// Phase widgets
// ---------------------------------------------------------------------------

class _PhaseStory extends StatelessWidget {
  const _PhaseStory({required this.story, required this.onResonates, required this.onNotResonates});
  final WrStory story;
  final VoidCallback onResonates;
  final VoidCallback onNotResonates;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        Text(
          '"${story.storyContent}"',
          style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: WrColors.dark, height: 1.7),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: onResonates,
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy, foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Tôi cũng từng như vậy', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onNotResonates,
          child: const Text('Câu chuyện này không quen với tôi', style: TextStyle(color: WrColors.muted)),
        ),
      ],
    );
  }
}

class _PhaseAha extends StatelessWidget {
  const _PhaseAha({required this.story, required this.onContinue});
  final WrStory story;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        if (story.ahaMessage != null)
          WrParagraph(story.ahaMessage!,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: WrColors.dark, height: 1.5)),
        if (story.selfReflection != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: WrColors.coral, width: 3)),
              color: WrColors.navy.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: WrParagraph(story.selfReflection!,
                style: const TextStyle(fontSize: 15.5, color: WrColors.muted, height: 1.6)),
          ),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy, foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Tiếp tục', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _PhaseConfidence extends StatelessWidget {
  const _PhaseConfidence({required this.onSelect});
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        const Text('Điều này có liên quan đến bạn không?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: WrColors.dark, height: 1.4)),
        const SizedBox(height: 24),
        _ConfidenceOption(label: 'Rất liên quan', onTap: () => onSelect(3)),
        const SizedBox(height: 10),
        _ConfidenceOption(label: 'Hơi liên quan', onTap: () => onSelect(2)),
        const SizedBox(height: 10),
        _ConfidenceOption(label: 'Không liên quan', onTap: () => onSelect(1)),
      ],
    );
  }
}

class _ConfidenceOption extends StatelessWidget {
  const _ConfidenceOption({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x1A2C335D)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500, color: WrColors.dark)),
      ),
    );
  }
}

class _PhaseReflection extends StatefulWidget {
  const _PhaseReflection({required this.story, required this.onSave, required this.onSkip});
  final WrStory story;
  final ValueChanged<String> onSave;
  final VoidCallback onSkip;

  @override
  State<_PhaseReflection> createState() => _PhaseReflectionState();
}

class _PhaseReflectionState extends State<_PhaseReflection> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final question = widget.story.reflectionQuestion ?? 'Điều này gợi lên điều gì với bạn?';
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        WrParagraph(
          question,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: WrColors.dark,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Viết suy nghĩ của bạn...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1A2C335D))),
            filled: true, fillColor: WrColors.white,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => widget.onSave(_ctrl.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy, foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Lưu và tiếp tục', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: widget.onSkip, child: const Text('Bỏ qua', style: TextStyle(color: WrColors.muted))),
      ],
    );
  }
}

class _PhasePractice extends StatelessWidget {
  const _PhasePractice({required this.story, required this.onAdd, required this.onSkip});
  final WrStory story;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        if (story.practiceAction != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WrColors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1A2C335D)),
            ),
            child: Text(story.practiceAction!,
                style: const TextStyle(fontSize: 16.5, color: WrColors.dark, height: 1.5)),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy, foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Thêm vào lịch thực hành', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: onSkip, child: const Text('Lần này bỏ qua', style: TextStyle(color: WrColors.muted))),
      ],
    );
  }
}

class _PhaseMemory extends StatelessWidget {
  const _PhaseMemory({required this.saving, required this.onSelect});
  final bool saving;
  final ValueChanged<String> onSelect;

  static const _options = [
    ('reflection', 'Nhận ra điều gì đó'),
    ('insight', 'Góc nhìn mới'),
    ('discovery', 'Khám phá về mình'),
    ('decision', 'Quyết định đã rõ'),
  ];

  @override
  Widget build(BuildContext context) {
    if (saving) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        const Text('Trải nghiệm này thuộc loại nào?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: WrColors.dark, height: 1.4)),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5,
          children: _options.map((opt) => _MemoryTypeBtn(
            label: opt.$2,
            onTap: () => onSelect(opt.$1),
          )).toList(),
        ),
      ],
    );
  }
}

class _MemoryTypeBtn extends StatelessWidget {
  const _MemoryTypeBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: WrColors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x1A2C335D)),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: WrColors.dark)),
      ),
    );
  }
}
