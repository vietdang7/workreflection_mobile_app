import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
// Quyền kho ảnh
// ---------------------------------------------------------------------------

/// Xin quyền đọc kho ảnh trước khi mở bộ chọn.
///
/// KHÔNG bắt buộc về mặt kỹ thuật: từ iOS 14 `image_picker` dùng
/// `PHPickerViewController`, bộ chọn chạy ngoài tiến trình app nên app không
/// đụng vào kho ảnh và iOS không hỏi gì cả (xem `FLTImagePickerPlugin.m`, nhánh
/// `launchPHPickerWithContext`). Bước này thêm vào theo yêu cầu 27/08: người
/// dùng phải thấy app hỏi trước khi vào kho ảnh.
///
/// Chỉ áp trên iOS. Trên Android hỏi thêm ở đây sẽ đòi khai quyền trong
/// manifest, mà bộ chọn ảnh của Android cũng không cần — hỏi là tự chuốc một
/// hộp thoại luôn bị từ chối.
abstract class PhotoPermissionService {
  /// `true` nếu được phép mở kho ảnh (gồm cả "cho phép một số ảnh").
  Future<bool> ensureGranted();

  /// Mở màn Cài đặt của app để người dùng bật lại quyền đã từ chối.
  Future<void> openSettings();
}

class _RealPhotoPermissionService implements PhotoPermissionService {
  @override
  Future<bool> ensureGranted() async {
    if (kIsWeb || !Platform.isIOS) return true;
    final status = await Permission.photos.request();
    // `limited` là nhánh "Chọn ảnh…" của iOS 14+: người dùng chỉ chia sẻ vài
    // tấm. Vẫn đủ để đổi ảnh đại diện, đừng coi là từ chối.
    return status.isGranted || status.isLimited;
  }

  @override
  Future<void> openSettings() => openAppSettings();
}

final photoPermissionServiceProvider = Provider<PhotoPermissionService>(
  (_) => _RealPhotoPermissionService(),
);

/// Người dùng từ chối quyền kho ảnh. Màn hình bắt riêng lỗi này để mời mở Cài
/// đặt, thay vì báo "không tải lên được" như một sự cố mạng.
class AvatarPermissionDeniedException implements Exception {
  const AvatarPermissionDeniedException();
}

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
    // Xoá lỗi của lần trước. Thiếu dòng này thì một lần từ chối quyền sẽ để
    // lại `AsyncError` mãi, và lần sau người dùng chỉ bấm huỷ trong bộ chọn
    // cũng bị báo lỗi cũ — màn hình đọc `hasError` để quyết định có báo không.
    state = const AsyncData(null);

    // Hỏi quyền TRƯỚC khi mở bộ chọn. Từ chối thì dừng ở đây và để màn hình
    // mời mở Cài đặt — mở bộ chọn rồi mới báo lỗi là bắt người dùng thao tác
    // thừa một lượt.
    if (!await ref.read(photoPermissionServiceProvider).ensureGranted()) {
      state = AsyncError(
        const AvatarPermissionDeniedException(),
        StackTrace.current,
      );
      return null;
    }

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
