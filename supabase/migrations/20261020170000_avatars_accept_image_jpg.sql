-- Bucket `avatars` nhận thêm nhãn `image/jpg`.
--
-- App mobile tới bản 1.1.0 (Android vc7, iOS 1.1.0) gửi ảnh JPG với nhãn
-- `image/jpg` thay vì nhãn chuẩn `image/jpeg`, nên ảnh chụp camera bị trả 400
-- (ảnh chụp màn hình PNG vẫn qua). Code đã sửa sang `image/jpeg`, nhưng các bản
-- đã nộp kho chỉ chữa được ở phía server. Giữ nguyên giới hạn 2 MB.

update storage.buckets
set allowed_mime_types = array[
  'image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'
]
where id = 'avatars';
