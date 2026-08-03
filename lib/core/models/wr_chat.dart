// Mô hình cho tính năng Trò chuyện — AI Chatbox System Prompt v1.0.
//
// Ghi chú kiến trúc: app KHÔNG bao giờ tự ghi vào `wr_chat_messages`. Mọi lượt
// đi qua Edge Function `wr-chat`, nơi giữ khoá OpenRouter và áp hạn mức. Vì vậy
// ở đây không có `toInsert()` — không có chỗ nào trong app cần nó.

/// Ai nói câu này.
enum WrChatRole {
  user,
  assistant;

  static WrChatRole fromDb(String value) =>
      value == 'assistant' ? WrChatRole.assistant : WrChatRole.user;

  bool get isUser => this == WrChatRole.user;
}

/// Nút hành động hiện dưới một bong bóng trả lời.
///
/// Mục 5 của system prompt yêu cầu trợ lý MỜI người dùng vào luồng Reflection,
/// và bước 3 của mục 8 yêu cầu đề nghị Thư viện Nội dung Cảm xúc. Trước
/// 2026-08-03 trợ lý nói được câu mời nhưng không có đường nào đi tới, nên lời
/// mời rơi vào khoảng không. Đây là đường đó.
enum WrChatAction {
  /// Mở luồng Reflection năm bước.
  reflect,

  /// Mở Thư viện Nội dung Cảm xúc.
  calm;

  static WrChatAction? fromWire(String? value) => switch (value) {
        'reflect' => WrChatAction.reflect,
        'calm' => WrChatAction.calm,
        _ => null,
      };

  /// Chữ trên nút.
  String get label => switch (this) {
        WrChatAction.reflect => 'Ghi lại thành một Reflection',
        WrChatAction.calm => 'Xem điều gì đó nhẹ nhàng',
      };

  /// Đường dẫn mở ra.
  ///
  /// `reflect` vào bước đầu của luồng năm bước chứ không vào giữa: bước năng
  /// lượng là nơi luồng khởi động, nhảy thẳng vào giữa sẽ để lại một Episode
  /// thiếu dữ liệu của các bước trước.
  String get route => switch (this) {
        WrChatAction.reflect => '/wr/flow/energy',
        WrChatAction.calm => '/wr/mood-library',
      };
}

/// Một lượt trong cuộc trò chuyện.
class WrChatMessage {
  const WrChatMessage({
    required this.role,
    required this.content,
    this.id,
    this.createdAt,
    this.pending = false,
    this.action,
  });

  final String? id;
  final WrChatRole role;
  final String content;
  final DateTime? createdAt;

  /// Nút đi kèm lượt này. Chỉ có ở lượt vừa nhận trong phiên hiện tại.
  ///
  /// CỐ Ý không lưu vào database: một lời mời "ghi lại chuyện này thành
  /// Reflection" chỉ có nghĩa ngay lúc đó. Mở lại cuộc trò chuyện ba ngày sau mà
  /// vẫn thấy nút cũ nằm giữa lịch sử là mời người ta ghi lại một chuyện họ
  /// không còn nhớ.
  final WrChatAction? action;

  /// True khi lượt này chỉ đang nằm trên màn hình, chưa được máy chủ xác nhận.
  ///
  /// Dùng để hiện câu người dùng vừa gõ ngay lập tức trong lúc chờ trả lời. Một
  /// lượt `pending` gửi hỏng sẽ bị gỡ khỏi danh sách, nên nó không bao giờ được
  /// coi là đã lưu.
  final bool pending;

  factory WrChatMessage.fromJson(Map<String, dynamic> json) => WrChatMessage(
        id: json['id'] as String?,
        role: WrChatRole.fromDb(json['role'] as String),
        content: json['content'] as String,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}

/// Kết quả một lượt gửi, kèm trạng thái hạn mức để màn hình nói được còn bao
/// nhiêu lượt mà không phải gọi thêm một vòng nữa.
class WrChatReply {
  const WrChatReply({
    required this.reply,
    required this.isPremium,
    required this.usedToday,
    required this.limit,
    this.conversationId,
    this.action,
    this.persisted = true,
  });

  final String reply;
  final bool isPremium;
  final int usedToday;
  final int limit;

  /// Cuộc trò chuyện lượt này thuộc về.
  ///
  /// Máy chủ tạo cuộc mới khi app gửi lên null, nên lượt đầu tiên là lúc app
  /// biết mình đang ở cuộc nào.
  final String? conversationId;

  final WrChatAction? action;

  /// False khi máy chủ trả lời được nhưng không ghi được lượt vào lịch sử.
  /// Mở lại màn hình thì lượt này sẽ biến mất, nên phải nói ra.
  final bool persisted;

  int get remaining => (limit - usedToday).clamp(0, limit);

  factory WrChatReply.fromJson(Map<String, dynamic> json) => WrChatReply(
        reply: json['reply'] as String,
        isPremium: json['isPremium'] as bool? ?? false,
        usedToday: (json['usedToday'] as num?)?.toInt() ?? 0,
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        conversationId: json['conversationId'] as String?,
        action: WrChatAction.fromWire(json['action'] as String?),
        persisted: json['persisted'] as bool? ?? true,
      );
}

/// Một cuộc trò chuyện trong danh sách lịch sử.
class WrConversation {
  const WrConversation({
    required this.id,
    required this.lastMessageAt,
    this.title,
  });

  final String id;

  /// Câu đầu tiên người dùng gõ, đã cắt ngắn. Null với dữ liệu cũ chưa có tiêu
  /// đề — màn hình tự thay bằng một nhãn chung.
  final String? title;

  final DateTime lastMessageAt;

  String get displayTitle {
    final t = title?.trim();
    return (t == null || t.isEmpty) ? 'Cuộc trò chuyện' : t;
  }

  factory WrConversation.fromJson(Map<String, dynamic> json) => WrConversation(
        id: json['id'] as String,
        title: json['title'] as String?,
        lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      );
}

/// Lỗi một lượt trò chuyện, kèm sẵn câu để hiển thị thẳng cho người dùng.
///
/// Câu này do Edge Function soạn bằng tiếng Việt. App không tự đặt lại câu chữ
/// theo mã lỗi: làm vậy sẽ có hai nơi cùng viết cùng một thông báo và chúng sẽ
/// lệch nhau.
class WrChatException implements Exception {
  const WrChatException(this.message, {this.quotaExhausted = false});

  final String message;

  /// True khi lỗi là do hết lượt trong ngày, không phải trục trặc kỹ thuật.
  /// Màn hình dùng cờ này để mời xem gói Premium thay vì mời gửi lại.
  final bool quotaExhausted;

  @override
  String toString() => message;
}
