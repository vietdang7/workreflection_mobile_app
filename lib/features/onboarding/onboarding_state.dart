import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  const OnboardingState({
    this.currentStep = 0,
    this.selectedSituation,
  });

  final int currentStep;
  final String? selectedSituation;

  OnboardingState copyWith({int? currentStep, String? selectedSituation}) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      selectedSituation: selectedSituation ?? this.selectedSituation,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void selectSituation(String situation) {
    // Toggling: if same value tapped again, deselect
    if (state.selectedSituation == situation) {
      state = OnboardingState(currentStep: state.currentStep);
    } else {
      state = state.copyWith(selectedSituation: situation);
    }
  }

  void reset() {
    state = const OnboardingState();
  }
}

final onboardingNotifierProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
