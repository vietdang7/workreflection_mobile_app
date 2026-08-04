import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/pill_button.dart';
import '../onboarding_state.dart';
import 'wr_logo.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: Padding(
          // HTML .ob-screen uses padding: 24px 36px 36px
          padding: const EdgeInsets.fromLTRB(36, 0, 36, 36),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Progress dots row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepDot(index: 0, currentStep: state.currentStep),
                  const SizedBox(width: 8),
                  _StepDot(index: 1, currentStep: state.currentStep),
                  const SizedBox(width: 8),
                  _StepDot(index: 2, currentStep: state.currentStep),
                ],
              ),
              const SizedBox(height: 40),
              // Step content
              Expanded(
                child: _buildStep(context, ref, state, notifier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    WidgetRef ref,
    OnboardingState state,
    OnboardingNotifier notifier,
  ) {
    switch (state.currentStep) {
      case 0:
        return _Step1(onNext: notifier.nextStep);
      case 1:
        return _Step2(
          onNext: notifier.nextStep,
          selectedSituation: state.selectedSituation,
          onSelect: notifier.selectSituation,
        );
      case 2:
        return _Step3(
          onFinish: () async {
            await setSeenOnboarding();
            // appRouterProvider watches seenOnboardingProvider → invalidate làm
            // router rebuild với giá trị mới → router mới redirect /splash →
            // /auth. Không cần context.go — router mới tự điều hướng.
            // invalidate + await future đảm bảo AsyncData(true) sẵn sàng
            // trước frame rebuild kế tiếp, đóng cửa sổ race.
            ref.invalidate(seenOnboardingProvider);
            await ref.read(seenOnboardingProvider.future);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Shared layout scaffold: scrollable content + pinned CTA at bottom
// ---------------------------------------------------------------------------

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.children, required this.cta});
  final List<Widget> children;
  final Widget cta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        const SizedBox(height: 16),
        cta,
        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Reflect
// ---------------------------------------------------------------------------

class _Step1 extends StatelessWidget {
  const _Step1({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _StepScaffold(
      cta: WrPillButton(
        label: l10n.onb1Cta,
        onPressed: onNext,
        variant: WrPillVariant.navy,
      ),
      children: [
        const WrLogo(),
        const SizedBox(height: 40),
        _StepTag(label: l10n.onb1Tag, color: WrColors.navy),
        const SizedBox(height: 16),
        Text(
          l10n.onb1Title,
          style: WrTextStyles.hLarge.copyWith(fontSize: 32, fontWeight: FontWeight.w300, height: 1.25, letterSpacing: -0.02 * 32),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.onb1Body,
          style: WrTextStyles.body.copyWith(fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Understand
// ---------------------------------------------------------------------------

class _Step2 extends StatelessWidget {
  const _Step2({
    required this.onNext,
    required this.selectedSituation,
    required this.onSelect,
  });
  final VoidCallback onNext;
  final String? selectedSituation;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = [
      l10n.onb2Opt1,
      l10n.onb2Opt2,
      l10n.onb2Opt3,
      l10n.onb2Opt4,
    ];
    return _StepScaffold(
      cta: WrPillButton(
        label: l10n.onb2Cta,
        onPressed: onNext,
        variant: WrPillVariant.coral,
      ),
      children: [
        const WrLogo(),
        const SizedBox(height: 32),
        _StepTag(label: l10n.onb2Tag, color: WrColors.coral),
        const SizedBox(height: 16),
        Text(
          l10n.onb2Title,
          style: WrTextStyles.hLarge.copyWith(fontSize: 32, fontWeight: FontWeight.w300, height: 1.25, letterSpacing: -0.02 * 32),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.onb2Body,
          style: WrTextStyles.body.copyWith(fontSize: 16, height: 1.65),
        ),
        const SizedBox(height: 24),
        ...options.map(
          (opt) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SituationCard(
              label: opt,
              isSelected: selectedSituation == opt,
              onTap: () => onSelect(opt),
              dotColor: opt == l10n.onb2Opt4 ? WrColors.teal : WrColors.coral,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Grow
// ---------------------------------------------------------------------------

class _Step3 extends StatelessWidget {
  const _Step3({required this.onFinish});
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _StepScaffold(
      cta: WrPillButton(
        label: l10n.onb3Cta,
        onPressed: onFinish,
        variant: WrPillVariant.teal,
      ),
      children: [
        const WrLogo(),
        const SizedBox(height: 32),
        _StepTag(label: l10n.onb3Tag, color: WrColors.teal),
        const SizedBox(height: 16),
        Text(
          l10n.onb3Title,
          style: WrTextStyles.hLarge.copyWith(fontSize: 32, fontWeight: FontWeight.w300, height: 1.25, letterSpacing: -0.02 * 32),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.onb3Body,
          style: WrTextStyles.body.copyWith(fontSize: 16, height: 1.65),
        ),
        const SizedBox(height: 24),
        _PromiseCard(
          title: l10n.onb3Promise1Title,
          subtitle: l10n.onb3Promise1Sub,
        ),
        const SizedBox(height: 12),
        _PromiseCard(
          title: l10n.onb3Promise2Title,
          subtitle: l10n.onb3Promise2Sub,
        ),
        const SizedBox(height: 12),
        _PromiseCard(
          title: l10n.onb3Promise3Title,
          subtitle: l10n.onb3Promise3Sub,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StepTag extends StatelessWidget {
  const _StepTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SituationCard extends StatelessWidget {
  const _SituationCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.dotColor,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? WrColors.coral.withValues(alpha: 0.08) : WrColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? WrColors.coral : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: WrTextStyles.body.copyWith(
                  color: isSelected ? WrColors.coral : WrColors.dark,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: WrColors.coral, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PromiseCard extends StatelessWidget {
  const _PromiseCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: WrColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: WrColors.navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: WrColors.navy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: WrTextStyles.hMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: WrTextStyles.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress dot. Active = coral pill 24×8, done = navy 25%, future = navy 10%.
class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.currentStep});
  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    if (index == currentStep) {
      return Container(
        width: 24,
        height: 8,
        decoration: BoxDecoration(
          color: WrColors.coral,
          borderRadius: BorderRadius.circular(100),
        ),
      );
    } else if (index < currentStep) {
      // done — navy 25%
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: WrColors.navy.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
      );
    } else {
      // future — navy 10% (matches HTML: rgba(9,55,116,0.1))
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: WrColors.navy.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
      );
    }
  }
}
