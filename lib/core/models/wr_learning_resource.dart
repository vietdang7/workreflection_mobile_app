// Thư viện học tập — video, tài liệu online dùng chung với web app.
//
// Khách 10/10: "chị đang làm chuỗi series [Tâm thế người đi làm], định add vào
// app như Trà Chiều". Người dùng chốt cùng ngày:
//   • thẻ ở tab Phát triển, cạnh thẻ Trà Chiều;
//   • trước mắt nhận HẾT tài liệu của thư viện, chưa lọc riêng một series;
//   • video phát NGAY TRONG APP, không đẩy ra YouTube;
//   • KHÔNG ảnh bìa: lúc đầu chốt lấy ảnh YouTube, nhưng ảnh mỗi tập một khổ,
//     cắt vào khung nào cũng lệch — "mất công canh ảnh khi upload lên".
//
// Dữ liệu ở `cc_workshop_resources` (trang "Thư viện học tập" của web). Bảng mở
// đọc cho mọi người với `status = 'active'`. App chỉ đọc — khách thêm tập ở web.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

import '../l10n/wr_tr.dart';

class LearningResource {
  const LearningResource({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.resourceType,
    this.externalUrl,
    this.fileUrl,
    this.durationMinutes,
    this.createdAt,
  });

  factory LearningResource.fromJson(Map<String, dynamic> json) =>
      LearningResource(
        id: json['id'] as String,
        title: (json['title'] as String?)?.trim() ?? '',
        description: _blankToNull(json['description']),
        category: _blankToNull(json['category']),
        resourceType: _blankToNull(json['resource_type']),
        externalUrl: _blankToNull(json['external_url']),
        fileUrl: _blankToNull(json['file_url']),
        durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
      );

  final String id;
  final String title;
  final String? description;
  final String? category;

  /// `video`, `document`, `link`… — web để ô tự do nên không làm enum.
  final String? resourceType;
  final String? externalUrl;
  final String? fileUrl;
  final int? durationMinutes;
  final DateTime? createdAt;

  /// Link mở được: link ngoài trước, file tải lên sau.
  String? get url => externalUrl ?? fileUrl;

  /// Mã video YouTube nếu link là YouTube — có mã thì phát trong app.
  String? get youtubeId => youtubeVideoId(url);

  bool get isVideo => resourceType == 'video' || youtubeId != null;

  /// Nhãn loại: "Video" / "Tài liệu".
  String get kindLabel =>
      isVideo ? tr('Video', 'Video') : tr('Tài liệu', 'Reading');

  /// "9 phút" — null khi web không nhập thời lượng.
  String? get durationLabel => switch (durationMinutes) {
    final m? when m > 0 => tr('$m phút', '$m min'),
    _ => null,
  };

  static String? _blankToNull(Object? value) {
    final s = (value as String?)?.trim();
    return s == null || s.isEmpty ? null : s;
  }
}

/// Mã 11 ký tự của một link YouTube, hoặc null nếu không phải YouTube.
///
/// Nhận các dạng web hay dán: `youtu.be/<id>`, `youtube.com/watch?v=<id>`,
/// `/embed/<id>`, `/shorts/<id>`, `/live/<id>`, có hoặc không `www.`/`m.`.
String? youtubeVideoId(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m)\.'), '');
  final String? candidate;
  if (host == 'youtu.be') {
    candidate = uri.pathSegments.firstOrNull;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    final segs = uri.pathSegments;
    if (segs.firstOrNull == 'watch') {
      candidate = uri.queryParameters['v'];
    } else if (segs.length >= 2 &&
        const {'embed', 'shorts', 'live', 'v'}.contains(segs.first)) {
      candidate = segs[1];
    } else {
      candidate = null;
    }
  } else {
    candidate = null;
  }
  if (candidate == null) return null;
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate) ? candidate : null;
}
