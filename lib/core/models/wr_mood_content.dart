// Thư viện Nội dung Cảm xúc + Bể Lựa chọn + Cơ hội phát triển.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §VIII, §VI, §XI.
//
// Plain immutable classes + fromJson, cùng style với wr_content.dart.
// Không phụ thuộc Flutter.

import '../l10n/wr_tr.dart';
import '../logic/wr_plain_text.dart';
import 'checkin.dart';

// ---------------------------------------------------------------------------
// MoodContent — §8.1
// ---------------------------------------------------------------------------

/// Loại nội dung, quyết định giao diện màn đọc (§8.1).
enum MoodContentType {
  reading,
  audio;

  String get dbValue => switch (this) {
        MoodContentType.reading => 'reading',
        MoodContentType.audio => 'audio',
      };

  static MoodContentType fromDb(String value) => switch (value) {
        'reading' => MoodContentType.reading,
        'audio' => MoodContentType.audio,
        _ => throw ArgumentError('Unknown MoodContentType db value: $value'),
      };
}

/// Một mục trong Thư viện Nội dung Cảm xúc.
///
/// Ánh xạ tới view `wr_mood_content_public`, KHÔNG phải bảng gốc: §XII.3 quy
/// định trường `script` (kịch bản lồng tiếng) chỉ dùng nội bộ cho đội sản xuất
/// audio và không được trả về cho app. Vì vậy lớp này cố tình không có trường
/// đó — thêm vào là vi phạm tài liệu.
///
/// §8.3: toàn bộ thư viện MIỄN PHÍ, không phân lớp Free/Paid, vì đây là nội
/// dung chăm sóc cảm xúc chứ không phải trí tuệ rút ra từ dữ liệu cá nhân.
class MoodContent {
  const MoodContent({
    required this.id,
    required this.mood,
    required this.sortOrder,
    required String title,
    required this.kind,
    required this.duration,
    required this.type,
    required String body,
    required this.placeholder,
    this.audioUrl,
    this.titleEn,
    this.bodyEn,
  })  : titleVi = title,
        bodyVi = body;

  final String id;

  /// Khớp trực tiếp với bốn lựa chọn check-in ở Home.
  final Mood mood;

  /// §8.3: Home hiện đúng mục đầu tiên của nhóm, nên thứ tự là dữ liệu.
  final int sortOrder;

  /// Tiêu đề, hai bản đặt cạnh nhau. Đọc qua [title].
  final String titleVi;
  final String? titleEn;

  /// Tiêu đề theo ngôn ngữ đang bật.
  ///
  /// Là GETTER chứ không phải trường: đọc lại mỗi lần dựng, nên đổi ngôn ngữ
  /// giữa chừng là chữ đổi theo mà không phải hỏi lại server. Chốt ngôn ngữ
  /// ngay trong `fromJson` thì bản ghi trong cache đóng băng ở ngôn ngữ lúc tải
  /// về, và người dùng đổi sang tiếng Anh vẫn đọc bài tiếng Việt.
  String get title => trDb(titleVi, titleEn);

  /// Nhãn hiển thị, ví dụ "BÀI ĐỌC".
  ///
  /// KHÔNG có cột `kind_en`: cả bảng chỉ có duy nhất một giá trị, nên thêm cột
  /// là bắt người biên tập gõ lại cùng một chữ ba mươi lần và tạo ba mươi cơ
  /// hội gõ lệch. Dịch ở đây, một chỗ, phủ cả bảng — xem [kindLabel].
  final String kind;

  /// Thời lượng hiển thị, ví dụ "3 phút đọc".
  ///
  /// Cũng không có cột `_en`, cùng lý do với [kind] — xem [durationLabel].
  final String duration;

  final MoodContentType type;

  /// Toàn văn bài đọc, hai bản đặt cạnh nhau. Đọc qua [body].
  final String bodyVi;
  final String? bodyEn;

  /// BÀI ĐỌC: toàn văn. HEALING AUDIO: mô tả ngắn dưới khối trình phát.
  String get body => trDb(bodyVi, bodyEn);

  /// [kind] theo ngôn ngữ đang bật.
  ///
  /// Dịch theo BẢNG TRA chứ không dịch tự do: giá trị nào không có trong bảng
  /// thì trả nguyên văn. Đội nội dung thêm một loại mới mà quên báo thì người
  /// dùng tiếng Anh thấy một nhãn tiếng Việt — dở, nhưng vẫn hơn một ô trống
  /// hay một nhãn bịa.
  String get kindLabel => switch (kind.trim().toUpperCase()) {
        'BÀI ĐỌC' => tr('BÀI ĐỌC', 'READING'),
        'HEALING AUDIO' => tr('HEALING AUDIO', 'HEALING AUDIO'),
        _ => kind,
      };

  /// [duration] theo ngôn ngữ đang bật.
  ///
  /// Bảng chỉ chứa dạng "N phút đọc", nên bóc lấy con số rồi dựng lại câu. Dạng
  /// nào không khớp thì trả nguyên văn, cùng lý do với [kindLabel].
  String get durationLabel {
    final match = RegExp(r'^(\d+)\s*phút đọc$').firstMatch(duration.trim());
    if (match == null) return duration;
    final minutes = match.group(1)!;
    return tr('$minutes phút đọc', '$minutes min read');
  }

  /// §8.2: true = còn nháp, chưa thu âm hoặc biên tập chính thức.
  final bool placeholder;

  /// Bản thu đã dựng cho mục HEALING AUDIO. Null = chưa có bản thu.
  ///
  /// Dựng một lần rồi lưu xuống DB, không sinh lại mỗi lần mở màn: cùng một
  /// đoạn chữ thì cùng một bản thu, và gọi lại là đốt credit của dịch vụ TTS.
  final String? audioUrl;

  /// True khi mục này phát được ngay.
  bool get hasAudio => (audioUrl?.trim().isNotEmpty ?? false);

  /// True khi nội dung đã sẵn sàng phát hành.
  ///
  /// §XII.3: "không phát hành nội dung placeholder true ra bản production."
  bool get isPublishable => !placeholder;

  /// True khi mục này có thứ để người dùng dùng ngay khi mở ra.
  ///
  /// BÀI ĐỌC luôn có: toàn văn nằm sẵn ở [body]. HEALING AUDIO thì không —
  /// [body] của mục audio chỉ là một hai câu mô tả dưới khối trình phát, nên
  /// mục audio chưa có bản thu mở ra là một màn hình trống rỗng.
  ///
  /// Khách chốt 04/08/2026: ẩn hết mục audio chưa có nội dung, mốt có thì mở
  /// lại. Điều kiện buộc vào chính [audioUrl] nên việc "mở lại" không cần sửa
  /// code: đội vận hành ghi bản thu vào `wr_mood_content.audio_url` là mục tự
  /// hiện trở lại.
  bool get isUsable => type != MoodContentType.audio || hasAudio;

  /// Lọc danh sách theo đúng §XII.3, tuỳ chế độ build.
  ///
  /// Bản release chỉ được thấy nội dung đã biên tập xong. Bản debug thì giữ
  /// nguyên nội dung nháp, để còn thử được luồng.
  ///
  /// Riêng [isUsable] lọc ở CẢ HAI chế độ, không theo `isRelease`: một mục
  /// audio không có bản thu thì trên bản debug cũng chẳng thử được gì ngoài
  /// thông báo lỗi dựng giọng đọc.
  ///
  /// Đây là cổng chặn thật, không phải quy ước: 10 mục audio trong seed đều
  /// còn nháp và chưa có bản thu, nên nếu thiếu hàm này thì bản production sẽ
  /// phát hành đúng thứ tài liệu cấm phát hành.
  /// Đúng bằng `kReleaseMode`, viết lại bằng hằng của dart:core để file này
  /// giữ lời hứa ở đầu file: không phụ thuộc Flutter.
  static const bool kIsRelease = bool.fromEnvironment('dart.vm.product');

  static List<MoodContent> releasable(
    List<MoodContent> items, {
    bool isRelease = kIsRelease,
  }) {
    return items
        .where((item) => item.isUsable)
        .where((item) => !isRelease || item.isPublishable)
        .toList();
  }

  /// Các đoạn của [body], tách theo dòng trống — dùng để dựng khối văn bản.
  List<String> get paragraphs => body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  factory MoodContent.fromJson(Map<String, dynamic> json) {
    return MoodContent(
      id: json['id'] as String,
      mood: _moodFromContentKey(json['mood'] as String),
      sortOrder: json['sort_order'] as int,
      title: json['title'] as String,
      kind: json['kind'] as String,
      duration: json['duration'] as String,
      type: MoodContentType.fromDb(json['type'] as String),
      body: json['body'] as String,
      // Cột mới (migration 20260910190000). Đọc mềm như `audio_url`: bản app
      // mới vẫn phải chạy được với một cơ sở dữ liệu chưa kịp chạy migration.
      titleEn: json['title_en'] as String?,
      bodyEn: json['body_en'] as String?,
      placeholder: json['placeholder'] as bool,
      // Cột mới (migration 20260729000000). Đọc mềm để bản app mới vẫn chạy
      // được với một cơ sở dữ liệu chưa kịp chạy migration.
      audioUrl: json['audio_url'] as String?,
    );
  }
}

/// Khoá nhóm của Thư viện Nội dung Cảm xúc (§8.1) dùng 'stress' và 'ok', trong
/// khi `wr_checkins.mood` đã dùng 'stressed' và 'okay' từ trước. Hai bảng ra
/// đời ở hai thời điểm khác nhau nên không khớp chuỗi; ánh xạ nằm gọn ở đây
/// thay vì rải ra mỗi chỗ đọc dữ liệu.
Mood _moodFromContentKey(String value) => switch (value) {
      'stress' => Mood.stressed,
      'tired' => Mood.tired,
      'foggy' => Mood.foggy,
      'outofsync' => Mood.outofsync,
      'ok' => Mood.okay,
      'happy' => Mood.happy,
      _ => throw ArgumentError('Unknown mood_content mood: $value'),
    };

/// Chiều ngược lại của [_moodFromContentKey] — dùng khi truy vấn theo cảm xúc.
///
/// Hai cảm xúc thêm 24/08/2026 dùng CÙNG một chuỗi ở cả hai bảng (`foggy`,
/// `outofsync`), nên chỗ lệch tên chỉ còn đúng hai cặp cũ.
extension MoodContentKey on Mood {
  String get moodContentKey => switch (this) {
        Mood.stressed => 'stress',
        Mood.tired => 'tired',
        Mood.foggy => 'foggy',
        Mood.outofsync => 'outofsync',
        Mood.okay => 'ok',
        Mood.happy => 'happy',
      };
}

// ---------------------------------------------------------------------------
// GrowthOpportunity — §11.5
// ---------------------------------------------------------------------------

/// Gợi ý hướng năng lực tiếp theo, tổng hợp từ toàn bộ hành trình Reflection.
///
/// §11.4: lớp truy cập Paid, cùng nhóm với Pattern nâng cao và AI Insight.
///
/// ⚠ §11.2 + §XII.7: [suggestionText] và [confidenceNote] KHÔNG được tách rời ở
///   tầng hiển thị. Cả hai đều `required` và non-null để không thể dựng một
///   đối tượng thiếu ghi chú độ chính xác.
class GrowthOpportunity {
  const GrowthOpportunity({
    required this.id,
    required this.userId,
    required this.suggestionText,
    required this.confidenceNote,
    required this.basedOn,
    required this.generatedAt,
  });

  final String id;
  final String userId;

  /// §11.1: luôn ở thể điều kiện, không phát biểu như một kết luận chắc chắn.
  final String suggestionText;

  /// §11.2: câu ghi chú cố định về giới hạn độ chính xác. Không đổi theo gợi ý.
  final String confidenceNote;

  /// §11.5: Pattern/Story đã dùng để tổng hợp, phục vụ minh bạch và gỡ lỗi.
  final List<String> basedOn;

  final DateTime generatedAt;

  /// Câu ghi chú bắt buộc theo §11.2, viết lại theo khách 09/09/2026 (§12.4).
  ///
  /// Vẫn giữ đúng chức năng §11.2 đòi: nói ra gợi ý này dựa trên đâu, và nói ra
  /// nó chưa đủ sát. Chỉ đổi cách nói phần thứ hai — từ "độ chính xác còn giới
  /// hạn" (nghe như lời chối trách nhiệm) sang một lối đi ("cung cấp thêm bối
  /// cảnh").
  static String get kConfidenceNote => tr('Gợi ý này được đúc kết từ hoạt động nhìn lại của bạn. Bạn có thể cung '
      'cấp thêm bối cảnh để nhận phân tích "may đo" sát hơn', 'This suggestion is drawn from your own looking back. Add more context '
      'and the reading can be tailored more closely to you');

  factory GrowthOpportunity.fromJson(Map<String, dynamic> json) {
    return GrowthOpportunity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      // Mục 17.1 — câu gợi ý do AI viết, thẻ "Góc nhìn phát triển" dựng bằng
      // `Text` thuần.
      suggestionText: stripMarkdown(json['suggestion_text'] as String),
      confidenceNote: json['confidence_note'] as String,
      basedOn: (json['based_on'] as List?)?.cast<String>() ?? const [],
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }

  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'suggestion_text': suggestionText,
        'confidence_note': confidenceNote,
        'based_on': basedOn,
        'generated_at': generatedAt.toUtc().toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// CareerQuestion — câu hỏi nghề nghiệp người dùng tự đặt
// ---------------------------------------------------------------------------

/// Một câu hỏi người dùng gửi từ ô hỏi tự do ở tab Hành trình.
///
/// Họp khách 2026-07-29: "bạn muốn hỏi gì trong hành trình công việc của bạn
/// thì bạn có thể hỏi ở đây… phần nào hệ thống trả lời được thì nó trả lời, còn
/// không thì nó sẽ nói là hệ thống ghi nhận câu hỏi của bạn và chúng tôi sẽ gửi
/// chi tiết gợi ý cho bạn vào email."
///
/// Vì vậy [answer] là NULLABLE và mặc định null: chưa có AI thì câu hỏi vẫn
/// phải được lưu lại nguyên vẹn để người vận hành đọc và trả lời qua email.
/// Một ô hỏi không lưu được gì là một ô hỏi vô nghĩa.
///
/// ⚠ Ô này KHÔNG phải hộp chat qua lại. Khách chốt rõ: "cái nói chuyện qua nói
///   chuyện lại chị nghĩ cái đó nó sẽ chờ sau." Một câu hỏi, một lần gửi.
class CareerQuestion {
  const CareerQuestion({
    required this.userId,
    required this.question,
    this.id,
    this.answer,
    this.answeredAt,
    this.createdAt,
  });

  final String? id;
  final String userId;
  final String question;

  /// Câu trả lời đã có. Null = đang chờ người vận hành trả lời qua email.
  final String? answer;

  final DateTime? answeredAt;
  final DateTime? createdAt;

  bool get isAnswered => (answer?.trim().isNotEmpty ?? false);

  factory CareerQuestion.fromJson(Map<String, dynamic> json) {
    return CareerQuestion(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String?,
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'question': question,
      };
}

// ---------------------------------------------------------------------------
// PracticeStepNote — §VII
// ---------------------------------------------------------------------------

/// Mã behavior của mục Career Memory sinh ra từ ghi chú Thực hành (§VII).
///
/// Tách khỏi `practice_step_done`: dòng kia là dấu hệ thống ghi mỗi lần xong
/// một bước, dòng này chỉ có khi người dùng tự viết. Gộp chung thì không phân
/// biệt được "đã làm" với "đã làm và có điều muốn nhớ".
const String kPracticeStepNoteBehavior = 'practice_step_note';

/// Ghi chú tùy chọn khi đánh dấu hoàn thành một bước Thực hành.
///
/// §VII: "việc chia sẻ là phần thưởng ghi nhận thêm, không phải điều kiện bắt
/// buộc để hoàn thành." Bảng chỉ có dòng khi người dùng thực sự viết gì đó.
class PracticeStepNote {
  const PracticeStepNote({
    required this.userId,
    required this.stepId,
    required this.note,
    this.id,
    this.memoryEventId,
    this.createdAt,
  });

  final String? id;
  final String userId;
  final String stepId;
  final String note;

  /// Mục Career Memory đã sinh ra từ ghi chú này, để truy vết ngược.
  final String? memoryEventId;

  final DateTime? createdAt;

  factory PracticeStepNote.fromJson(Map<String, dynamic> json) {
    return PracticeStepNote(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      stepId: json['step_id'] as String,
      note: json['note'] as String,
      memoryEventId: json['memory_event_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'step_id': stepId,
        'note': note,
        if (memoryEventId != null) 'memory_event_id': memoryEventId,
      };
}

// ---------------------------------------------------------------------------
// ChoicePoolLine — §VI
// ---------------------------------------------------------------------------

/// Một câu trong Bể Lựa chọn, chở CẢ hai ngôn ngữ.
///
/// Trước đây `fetchChoicePool` trả thẳng `List<String>` đã dịch xong ngay trong
/// repository. Đọc thì gọn, nhưng nó chốt ngôn ngữ vào lúc GỌI SERVER: giá trị
/// nằm trong cache của Riverpod là tiếng Việt thì có dựng lại màn bao nhiêu lần
/// cũng vẫn là tiếng Việt, phải hỏi lại server mới đổi được. Một lượt mạng chỉ
/// để đổi chữ — và trong lúc chờ, màn Cam kết là ô duy nhất còn tiếng cũ giữa
/// một màn đã sang tiếng mới.
///
/// Chở cả hai rồi chọn ở GETTER thì cache dùng được cho cả hai ngôn ngữ, và
/// việc đổi ngôn ngữ chỉ còn là dựng lại widget — không có lượt mạng nào.
class ChoicePoolLine {
  const ChoicePoolLine({required this.textVi, this.textEn});

  final String textVi;
  final String? textEn;

  /// Câu hiển thị theo ngôn ngữ đang bật. Chưa dịch thì rơi về tiếng Việt.
  String get text => trDb(textVi, textEn);

  factory ChoicePoolLine.fromJson(Map<String, dynamic> json) => ChoicePoolLine(
        textVi: json['text'] as String,
        textEn: json['text_en'] as String?,
      );
}
