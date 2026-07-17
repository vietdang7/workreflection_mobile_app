import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/onboarding_state.dart';
import 'wr_repository.dart';

/// Service that calls [WrRepository.ensureSeeded] after sign-in/sign-up,
/// reading the selected onboarding situation from [onboardingNotifierProvider].
///
/// Kept outside widgets so it can be tested with fake repositories and faked
/// onboarding state.
class SeedService {
  const SeedService(this._repo, this._onboardingSituation);

  final WrRepository _repo;
  final String? _onboardingSituation;

  Future<void> ensureSeeded() async {
    await _repo.ensureSeeded(onboardingSituation: _onboardingSituation);
  }
}

final seedServiceProvider = Provider<SeedService>((ref) {
  final repo = ref.watch(wrRepositoryProvider);
  final situation =
      ref.watch(onboardingNotifierProvider).selectedSituation;
  return SeedService(repo, situation);
});
