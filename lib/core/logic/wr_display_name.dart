// Tên để gọi người dùng — một nguồn duy nhất cho mọi chỗ chào hỏi.
//
// Khách báo ở họp 26_1: "app đang chào bằng email chứ không chào bằng tên".
// Nguyên nhân không nằm ở màn nào cả, nó nằm ở chỗ GHI:
//
//   • `SupabaseAuthRepository.signUp` gửi metadata `{'display_name': …}`, nhưng
//     trigger `handle_new_user` bên Postgres chỉ đọc `full_name` hoặc `name`.
//     Hai khoá không khớp, nên mọi tài khoản tạo từ app di động đều có
//     `cc_profiles.full_name = NULL` — trong khi tài khoản tạo từ web thì có.
//   • `WrRepository.ensureSeeded` dựng hàng hồ sơ lần đầu với
//     `userMetadata['display_name'] ?? user.email` — tức là khi không đọc được
//     tên thì GHI THẲNG EMAIL vào ô tên. Đăng nhập bằng Google rơi đúng vào
//     nhánh này (Google trả về `name`/`full_name`, không trả `display_name`).
//     Email đã nằm trong DB rồi thì mọi màn đọc ô tên đều chào bằng email.
//
// Hai chỗ ghi đã sửa. File này lo phần ĐỌC, và phải lo tiếp: những hàng đã bị
// ghi email vào ô tên vẫn còn nguyên trong DB, không có migration nào đụng tới
// dữ liệu người dùng thật được. Nên nơi đọc phải tự nhận ra "cái tên này là một
// địa chỉ email" và coi như chưa biết tên.

/// Chuỗi này thật ra là một địa chỉ email chứ không phải tên người.
///
/// Chỉ cần một dấu `@`: không có tên người nào chứa ký tự đó, và mọi email đều
/// chứa. Cố ý KHÔNG kiểm tra kỹ hơn — mục tiêu là loại email ra khỏi ô tên,
/// không phải kiểm tra email có hợp lệ hay không.
bool looksLikeEmail(String s) => s.contains('@');

/// Tên để chào, hoặc `null` khi thật sự chưa biết tên.
///
/// Trả `null` chứ không trả sẵn "bạn": nơi gọi cần phân biệt được hai trường
/// hợp để dựng câu khác nhau ("Chào Thông" / "Chào bạn"), và một vài chỗ (chữ
/// tắt trên avatar) không dùng chữ "bạn" được.
///
/// Thứ tự ưu tiên đọc theo độ tin cậy của nguồn:
///   1. `cc_profiles.full_name` — do người dùng tự nhập lúc đăng ký, dùng chung
///      với bản web.
///   2. `wr_mobile_profiles.display_name` — người dùng sửa được ở màn Hồ sơ.
///   3. metadata của tài khoản đăng nhập (`display_name`, `full_name`, `name`) —
///      chỗ Google trả tên về.
///
/// Ứng viên nào là email thì bỏ qua và xét tiếp ứng viên sau, chứ không dừng
/// lại: hàng cũ có `display_name` là email nhưng metadata lại có tên thật.
String? wrGreetingName({
  String? ccFullName,
  String? displayName,
  Map<String, dynamic>? userMetadata,
}) {
  final candidates = <String?>[
    ccFullName,
    displayName,
    userMetadata?['display_name'] as String?,
    userMetadata?['full_name'] as String?,
    userMetadata?['name'] as String?,
  ];

  for (final c in candidates) {
    final trimmed = c?.trim();
    if (trimmed == null || trimmed.isEmpty) continue;
    if (looksLikeEmail(trimmed)) continue;
    return trimmed;
  }
  return null;
}

/// Câu chào đầu màn Hôm nay.
String wrGreeting(String? name) => name == null ? 'Chào bạn' : 'Chào $name';
