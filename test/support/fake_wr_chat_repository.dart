import 'package:workreflection_mobile/core/data/wr_chat_repository.dart';
import 'package:workreflection_mobile/core/models/wr_chat.dart';

/// WrChatRepository giả, không chạm mạng.
///
/// Gieo lịch sử bằng [seedConversation], gieo lỗi bằng [nextError] (ném MỘT lần
/// rồi tự xoá, để lần đọc lịch sử lúc mở màn không nuốt mất lỗi dành cho lượt
/// gửi).
class FakeWrChatRepository implements WrChatRepository {
  /// Lượt trò chuyện theo từng cuộc.
  final Map<String, List<WrChatMessage>> _byConversation = {};
  final List<WrConversation> _conversations = [];

  /// Câu trả lời cho lượt gửi kế tiếp.
  String replyText = 'Nghe quen thuộc đấy. Điều gì khiến bạn nghĩ vậy?';

  /// Nút đi kèm câu trả lời kế tiếp.
  WrChatAction? replyAction;

  bool isPremium = false;
  int limit = 10;
  int usedToday = 0;
  bool persisted = true;

  /// Id cấp cho cuộc trò chuyện mới kế tiếp.
  int _nextId = 1;

  Object? nextError;

  final List<({String message, String? conversationId, bool? premiumOverride})>
      sendCalls = [];
  final List<String> deleteCalls = [];

  /// Gieo một cuộc trò chuyện đã có, kèm các lượt bên trong.
  void seedConversation(
    String id,
    List<WrChatMessage> messages, {
    String? title,
    DateTime? lastMessageAt,
  }) {
    _conversations.add(
      WrConversation(
        id: id,
        title: title,
        lastMessageAt: lastMessageAt ?? DateTime(2026, 8, 1),
      ),
    );
    // Mới nhất trước, khớp `order('last_message_at', ascending: false)` của
    // repo thật — nếu không, test mở "cuộc gần nhất" sẽ khoá nhầm hành vi.
    _conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    _byConversation[id] = [...messages];
  }

  void _maybeThrow() {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
  }

  @override
  Future<List<WrConversation>> fetchConversations(String userId) async {
    _maybeThrow();
    return List.unmodifiable(_conversations);
  }

  @override
  Future<List<WrChatMessage>> fetchHistory(String conversationId) async {
    _maybeThrow();
    return List.unmodifiable(_byConversation[conversationId] ?? const []);
  }

  @override
  Future<WrChatReply> send(
    String message, {
    String? conversationId,
    bool? premiumOverride,
  }) async {
    _maybeThrow();
    sendCalls.add((
      message: message,
      conversationId: conversationId,
      premiumOverride: premiumOverride,
    ));
    usedToday += 1;

    final id = conversationId ?? 'c${_nextId++}';
    if (conversationId == null) {
      _conversations.insert(
        0,
        WrConversation(
          id: id,
          title: message,
          lastMessageAt: DateTime(2026, 8, 3),
        ),
      );
    }
    (_byConversation[id] ??= [])
      ..add(WrChatMessage(role: WrChatRole.user, content: message))
      ..add(WrChatMessage(role: WrChatRole.assistant, content: replyText));

    return WrChatReply(
      reply: replyText,
      isPremium: isPremium,
      usedToday: usedToday,
      limit: limit,
      conversationId: id,
      action: replyAction,
      persisted: persisted,
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    _maybeThrow();
    deleteCalls.add(conversationId);
    _conversations.removeWhere((c) => c.id == conversationId);
    _byConversation.remove(conversationId);
  }
}
