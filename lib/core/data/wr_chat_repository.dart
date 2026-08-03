// Kho dữ liệu cho tính năng Trò chuyện — AI Chatbox System Prompt v1.0.
//
// Hai đường khác nhau, cố ý:
//   • ĐỌC lịch sử: truy vấn thẳng `wr_chat_messages` / `wr_chat_conversations`,
//     RLS lo phần chỉ thấy của mình. Nhanh, rẻ, không đánh thức Edge Function.
//   • GỬI một lượt: gọi Edge Function `wr-chat`. Đây là đường DUY NHẤT ghi được
//     vào hai bảng đó — chúng cố ý không có policy insert cho người dùng, xem
//     migration 20260803000000 và 20260803120000.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wr_chat.dart';

/// Tên Edge Function giữ khoá OpenRouter.
const String kWrChatFunction = 'wr-chat';

/// Số lượt tải lên màn hình khi mở một cuộc trò chuyện.
///
/// Khớp với `HISTORY_LIMIT` của Edge Function: hiện nhiều hơn phần model thật
/// sự nhớ sẽ làm người dùng tưởng nó nhớ cả cuộc trò chuyện từ đầu.
const int kWrChatHistoryLimit = 20;

/// Số cuộc trò chuyện hiện trong màn lịch sử.
const int kWrConversationListLimit = 50;

abstract class WrChatRepository {
  /// Các cuộc trò chuyện của [userId], mới nói gần đây nhất đứng đầu.
  Future<List<WrConversation>> fetchConversations(String userId);

  /// Lượt trò chuyện của [conversationId], CŨ TRƯỚC MỚI SAU.
  Future<List<WrChatMessage>> fetchHistory(String conversationId);

  /// Gửi một câu và chờ trả lời.
  ///
  /// [conversationId] null nghĩa là mở cuộc mới; máy chủ tạo và trả id về trong
  /// [WrChatReply.conversationId].
  ///
  /// Ném [WrChatException] kèm câu tiếng Việt hiển thị được cho người dùng.
  Future<WrChatReply> send(String message, {String? conversationId});

  /// Xoá một cuộc trò chuyện. Lượt bên trong bị xoá theo (cascade).
  Future<void> deleteConversation(String conversationId);
}

final wrChatRepositoryProvider = Provider<WrChatRepository>((ref) {
  return SupabaseWrChatRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------

class SupabaseWrChatRepository implements WrChatRepository {
  const SupabaseWrChatRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<WrConversation>> fetchConversations(String userId) async {
    final rows = await _client
        .from('wr_chat_conversations')
        .select()
        .eq('user_id', userId)
        .order('last_message_at', ascending: false)
        .limit(kWrConversationListLimit);
    return rows.map(WrConversation.fromJson).toList();
  }

  @override
  Future<List<WrChatMessage>> fetchHistory(String conversationId) async {
    // Sắp giảm dần rồi đảo lại, chứ không sắp tăng dần: `limit` phải cắt lấy
    // đầu GẦN ĐÂY. Sắp tăng dần rồi limit 20 sẽ cho ra 20 lượt đầu tiên của
    // cuộc trò chuyện, và người dùng mở ra thấy đoạn mở màn thay vì đoạn dở.
    final rows = await _client
        .from('wr_chat_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(kWrChatHistoryLimit);
    return rows.map(WrChatMessage.fromJson).toList().reversed.toList();
  }

  @override
  Future<WrChatReply> send(String message, {String? conversationId}) async {
    try {
      final res = await _client.functions.invoke(
        kWrChatFunction,
        body: {
          'message': message,
          if (conversationId != null) 'conversationId': conversationId,
        },
      );
      final data = res.data;
      if (data is! Map || data['reply'] == null) {
        throw const WrChatException(
          'Mình chưa trả lời được lúc này. Bạn thử gửi lại nhé.',
        );
      }
      return WrChatReply.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (e) {
      throw _fromFunctionException(e);
    } on WrChatException {
      rethrow;
    } catch (_) {
      // Mất mạng, DNS hỏng, máy chủ không với tới được. Nói đúng điều người
      // dùng làm được: thử lại.
      throw const WrChatException(
        'Không kết nối được lúc này. Bạn kiểm tra mạng rồi gửi lại nhé.',
      );
    }
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _client
        .from('wr_chat_conversations')
        .delete()
        .eq('id', conversationId);
  }

  /// Lấy câu báo lỗi do Edge Function soạn sẵn.
  ///
  /// `details` là thân phản hồi đã giải mã JSON khi máy chủ trả JSON. Nếu vì lý
  /// do nào đó nó không có dạng mong đợi (ví dụ gateway chen vào một trang HTML
  /// 502), rơi về một câu chung thay vì ném nguyên `details` lên màn hình.
  WrChatException _fromFunctionException(FunctionException e) {
    final d = e.details;
    if (d is Map) {
      final msg = d['error'];
      if (msg is String && msg.trim().isNotEmpty) {
        return WrChatException(
          msg,
          quotaExhausted: d['quotaExhausted'] == true,
        );
      }
    }
    if (e.status == 401) {
      return const WrChatException(
        'Phiên đăng nhập đã hết hạn. Bạn đăng nhập lại nhé.',
      );
    }
    return const WrChatException(
      'Mình chưa trả lời được lúc này. Bạn thử gửi lại nhé.',
    );
  }
}
