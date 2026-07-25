import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../wr_situation_service.dart';

class WrSituationFlowScreen extends ConsumerStatefulWidget {
  const WrSituationFlowScreen({super.key});

  @override
  ConsumerState<WrSituationFlowScreen> createState() => _WrSituationFlowScreenState();
}

class _WrSituationFlowScreenState extends ConsumerState<WrSituationFlowScreen> {
  int _step = 0; // 0=list, 1=confirm, 2=saved
  WrSituation? _selected;
  bool _saving = false;
  int _patternCountAfterSave = 0;

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _saving = true);
    try {
      final sit = _selected!;
      final count = await commitTodaySituation(ref, sit: sit, emotion: 'low');
      if (mounted) {
        setState(() {
          _step = 2;
          _saving = false;
          _patternCountAfterSave = count;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được tình huống. Thử lại.')),
        );
      }
    }
  }

  double get _progress => switch (_step) {
        0 => 0.33,
        1 => 0.66,
        _ => 1.0,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => setState(() => _step--),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => context.pop(),
                    ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: WrColors.navy,
                      minHeight: 3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_step) {
                0 => _StepList(onSelect: (s) => setState(() { _selected = s; _step = 1; })),
                1 => _StepConfirm(situation: _selected!, saving: _saving, onSave: _save),
                _ => _StepSaved(patternCount: _patternCountAfterSave),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: List
// ---------------------------------------------------------------------------

class _StepList extends ConsumerWidget {
  const _StepList({required this.onSelect});
  final ValueChanged<WrSituation> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final situationsAsync = ref.watch(_situationsProvider);
    return situationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (situations) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        children: [
          const Text('Bạn đang gặp điều gì?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: WrColors.dark)),
          const SizedBox(height: 6),
          const Text('Chọn tình huống gần nhất với bạn lúc này.',
              style: TextStyle(fontSize: 13, color: Color(0xFF737373), height: 1.5)),
          const SizedBox(height: 20),
          ...situations.map((s) => _SituationTile(situation: s, onTap: () => onSelect(s))),
        ],
      ),
    );
  }
}

class _SituationTile extends StatelessWidget {
  const _SituationTile({required this.situation, required this.onTap});
  final WrSituation situation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A2C335D)),
        ),
        child: Text(situation.text,
            style: const TextStyle(fontSize: 14, color: WrColors.dark, height: 1.5)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Confirm
// ---------------------------------------------------------------------------

class _StepConfirm extends StatelessWidget {
  const _StepConfirm({required this.situation, required this.saving, required this.onSave});
  final WrSituation situation;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      children: [
        const Text('Điều bạn đang mong muốn:',
            style: TextStyle(fontSize: 12, color: Color(0xFFA3A3A3), fontWeight: FontWeight.w600, letterSpacing: 0.04)),
        const SizedBox(height: 8),
        if (situation.expectedOutcome != null)
          Text(situation.expectedOutcome!,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: WrColors.dark, height: 1.4)),
        if (situation.scaPerspective != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(situation.scaPerspective!,
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.6)),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: saving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy,
            foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: WrColors.white))
              : const Text('Lưu vào hành trình', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Saved
// ---------------------------------------------------------------------------

class _StepSaved extends StatelessWidget {
  const _StepSaved({required this.patternCount});
  final int patternCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 36),
          const SizedBox(height: 16),
          const Text('Đã ghi nhận',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: WrColors.dark)),
          const SizedBox(height: 8),
          if (patternCount >= 3)
            Text('Đây là lần thứ $patternCount bạn gặp tình huống này.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.5)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.go('/wr/story'),
            child: const Text('Đọc một câu chuyện tương tự →',
                style: TextStyle(fontSize: 14, color: WrColors.navy, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _situationsProvider = FutureProvider<List<WrSituation>>((ref) async {
  final repo = ref.watch(wrContentRepositoryProvider);
  final all = await repo.fetchSituations();
  // Sort by wave asc, then by code asc
  final sorted = List.of(all)
    ..sort((a, b) {
      final waveCmp = a.wave.compareTo(b.wave);
      if (waveCmp != 0) return waveCmp;
      return a.code.compareTo(b.code);
    });
  return sorted;
});
