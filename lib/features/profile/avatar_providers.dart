import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/wr_repository.dart';
import 'profile_providers.dart';

// ---------------------------------------------------------------------------
// Image picker abstraction — overridable in tests.
// ---------------------------------------------------------------------------

/// Abstract interface so tests can inject a fake picker.
abstract class AvatarPickerService {
  Future<XFile?> pickFromGallery({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });
}

class _RealAvatarPickerService implements AvatarPickerService {
  @override
  Future<XFile?> pickFromGallery({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) {
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth?.toDouble(),
      maxHeight: maxHeight?.toDouble(),
      imageQuality: imageQuality,
    );
  }
}

final avatarPickerServiceProvider = Provider<AvatarPickerService>(
  (_) => _RealAvatarPickerService(),
);

// ---------------------------------------------------------------------------
// Avatar upload notifier
// ---------------------------------------------------------------------------

/// State: null = idle, true = uploading, false = done (callers use isLoading).
class AvatarUploadNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Pick an image from gallery, downscale to 512px, and upload.
  /// Returns the new public URL or null if cancelled / failed.
  Future<String?> pickAndUpload() async {
    final picker = ref.read(avatarPickerServiceProvider);
    final file = await picker.pickFromGallery(
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return null; // user cancelled

    state = const AsyncLoading();
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      // Normalise ext to known image types; default to jpg.
      final safeExt =
          {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(ext) ? ext : 'jpg';
      final url =
          await ref.read(wrRepositoryProvider).uploadAvatar(bytes, safeExt);
      // Invalidate cc_profiles so ProfileScreen refreshes.
      ref.invalidate(ccProfileProvider);
      state = const AsyncData(null);
      return url;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

final avatarUploadProvider =
    AsyncNotifierProvider<AvatarUploadNotifier, void>(
  AvatarUploadNotifier.new,
);
