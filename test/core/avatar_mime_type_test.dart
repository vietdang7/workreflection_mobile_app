import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';

// Bucket `avatars` chỉ nhận image/jpeg, image/png, image/webp, image/gif.
// Gửi image/jpg là 400: ảnh camera không lên được (máy thật 20/10/2026).
void main() {
  const allowed = {'image/jpeg', 'image/png', 'image/webp', 'image/gif'};

  test('jpg và jpeg đều gửi nhãn chuẩn image/jpeg', () {
    expect(avatarMimeType('jpg'), 'image/jpeg');
    expect(avatarMimeType('jpeg'), 'image/jpeg');
  });

  test(
    'mọi đuôi mà màn chọn ảnh cho qua đều nằm trong danh sách bucket nhận',
    () {
      for (final ext in ['jpg', 'jpeg', 'png', 'webp', 'gif']) {
        expect(allowed, contains(avatarMimeType(ext)), reason: ext);
      }
    },
  );
}
