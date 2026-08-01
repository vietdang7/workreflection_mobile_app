// Thiết lập hồ sơ — 3 bước: vai trò · mục tiêu · trăn trở.
//
// Spec: giao-dien-ho-tro.jsx — CareerSetupScreen.
//   • 3 dot chỉ tiến độ, nền navy
//   • chọn 1 lựa chọn → tự động sang bước sau sau ~300ms
//   • mỗi bước đều bỏ qua được ("Bỏ qua bước này" / "Bỏ qua, vào app")
//   • kết thúc ghi {current_role, career_goal, current_challenge}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/logic/wr_career_profile.dart';
import '../../../core/theme/wr_colors.dart';
import '../wr_providers.dart';

class WrCareerSetupScreen extends ConsumerStatefulWidget {
  const WrCareerSetupScreen({super.key, this.onDone});

  /// Điều hướng sau khi hoàn tất. Mặc định quay lại màn hình trước
  /// (fallback `/home` khi không pop được).
  final VoidCallback? onDone;

  @override
  ConsumerState<WrCareerSetupScreen> createState() =>
      _WrCareerSetupScreenState();
}

class _WrCareerSetupScreenState extends ConsumerState<WrCareerSetupScreen> {
  int _step = 0; // 0..2
  String? _role;
  String? _goal;
  String? _challenge;
  bool _saving = false;
  String? _errorMsg;

  static const _questions = <(String, String)>[
    (
      'Vai trò hiện tại của bạn là gì?',
      'Điều này giúp WorkReflection hiểu rõ hơn về bối cảnh công việc của bạn.'
    ),
    (
      'Điều bạn đang quan tâm nhất trong sự nghiệp hiện tại?',
      'Bạn có thể thay đổi bất cứ lúc nào.'
    ),
    (
      'Điều khiến bạn trăn trở nhất gần đây?',
      'Không có câu trả lời đúng hay sai.'
    ),
  ];

  List<String> get _options => switch (_step) {
        0 => kCareerRoleOptions,
        1 => kCareerGoalOptions,
        _ => kCareerChallengeOptions,
      };

  String? get _selected => switch (_step) {
        0 => _role,
        1 => _goal,
        _ => _challenge,
      };

  void _select(String value) {
    setState(() {
      switch (_step) {
        case 0:
          _role = value;
        case 1:
          _goal = value;
        default:
          _challenge = value;
      }
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _advance();
    });
  }

  void _advance() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorMsg = null;
    });
    final snapshot = CareerSnapshot(
      currentRole: _role,
      careerGoal: _goal,
      currentChallenge: _challenge,
    );
    try {
      if (!snapshot.isEmpty) {
        await ref.read(wrRepositoryProvider).saveCareerSnapshot(snapshot);
        ref.invalidate(wrCareerSnapshotProvider);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMsg = 'Chưa lưu được hồ sơ. Bạn có thể thử lại sau.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.onDone != null) {
      widget.onDone!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (question, subtitle) = _questions[_step];
    return Scaffold(
      backgroundColor: WrColors.navy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      width: i == _step ? 20 : 6,
                      decoration: BoxDecoration(
                        color: i == _step
                            ? WrColors.coral
                            : WrColors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIẾT LẬP HỒ SƠ · ${_step + 1}/3',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: WrColors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    question,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: WrColors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: WrColors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMsg!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: WrColors.coral,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Options
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final opt = _options[i];
                  final selected = _selected == opt;
                  return _OptionTile(
                    label: opt,
                    selected: selected,
                    onTap: _saving ? null : () => _select(opt),
                  );
                },
              ),
            ),

            // Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _saving ? null : _advance,
                  child: Text(
                    _step < 2 ? 'Bỏ qua bước này' : 'Bỏ qua, vào app',
                    style: TextStyle(
                      fontSize: 12,
                      color: WrColors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? WrColors.coral.withValues(alpha: 0.12)
                : WrColors.white.withValues(alpha: 0.05),
            border: Border.all(
              width: 1.5,
              color: selected
                  ? WrColors.coral
                  : WrColors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected
                        ? WrColors.white
                        : WrColors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: WrColors.coral,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 12,
                    color: WrColors.navy,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
