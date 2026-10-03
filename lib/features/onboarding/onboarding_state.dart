import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Trạng thái màn chào.
///
/// Màn chào giờ chỉ còn MỘT màn (đợt E, họp khách 01/10), không còn bước và
/// không còn câu hỏi chọn tình huống. [selectedSituation] giữ lại, luôn null,
/// để `seedServiceProvider` không phải đổi chữ ký: cột `onboarding_situation`
/// không có nơi nào đọc (đã grep `lib` và `supabase/functions` ngày 01/10), và
/// `ensureSeeded` nhận null được.
class OnboardingState {
  const OnboardingState();

  String? get selectedSituation => null;
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();
}

final onboardingNotifierProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );
