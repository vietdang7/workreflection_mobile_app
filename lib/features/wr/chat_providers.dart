// Trạng thái màn Trò chuyện — AI Chatbox System Prompt v1.0.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_chat_repository.dart';
import '../../core/logic/wr_chat_starters.dart';
import '../../core/logic/wr_repeated_situations.dart';
import '../../core/models/wr_chat.dart';
import 'wr_providers.dart';

/// Trạng thái một cuộc trò chuyện đang mở.
class WrChatState {
  const WrChatState({
    this.messages = const [],
    this.conversationId,
    this.loading = true,
    this.sending = false,
    this.error,
    this.quotaExhausted = false,
    this.remaining,
    this.isPremium = false,
  });

  /// Cũ trước mới sau, đúng thứ tự đọc từ trên xuống.
  final List<WrChatMessage> messages;

  /// Cuộc đang mở. Null = cuộc mới, chưa gửi câu nào.
  ///
  /// Cuộc chỉ được TẠO ở máy chủ khi lượt đầu tiên gửi đi. Tạo ngay lúc bấm nút
  /// sẽ đẻ ra cuộc rỗng nằm lại trong lịch sử khi người dùng đổi ý.
  final String? conversationId;

  /// Đang tải lịch sử lần đầu.
  final bool loading;

  /// Đang chờ trả lời cho lượt vừa gửi.
  final bool sending;

  /// Lỗi của lượt gửi gần nhất, đã là câu hiển thị được cho người dùng.
  final String? error;

  /// True khi lỗi gần nhất là hết lượt trong ngày, không phải trục trặc.
  final bool quotaExhausted;

  /// Số lượt còn lại hôm nay. Null khi chưa gửi lượt nào trong phiên này nên
  /// chưa biết — cố ý không đoán, thà không hiện còn hơn hiện một con số sai.
  final int? remaining;

  final bool isPremium;

  bool get isEmpty => messages.isEmpty;

  WrChatState copyWith({
    List<WrChatMessage>? messages,
    Object? conversationId = _keep,
    bool? loading,
    bool? sending,
    Object? error = _keep,
    bool? quotaExhausted,
    Object? remaining = _keep,
    bool? isPremium,
  }) {
    return WrChatState(
      messages: messages ?? this.messages,
      conversationId: conversationId == _keep
          ? this.conversationId
          : conversationId as String?,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      error: error == _keep ? this.error : error as String?,
      quotaExhausted: quotaExhausted ?? this.quotaExhausted,
      remaining: remaining == _keep ? this.remaining : remaining as int?,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  /// Dấu "giữ nguyên", để phân biệt với "đặt về null" khi xoá lỗi hoặc khi mở
  /// một cuộc trò chuyện mới.
  static const Object _keep = Object();
}

class WrChatController extends StateNotifier<WrChatState> {
  WrChatController(this._repo, this._userId, this._premiumOverride)
      : super(const WrChatState()) {
    load();
  }

  final WrChatRepository _repo;
  final String? _userId;

  /// Công tắc Premium thử nghiệm, null khi chưa động vào.
  ///
  /// Gửi kèm mỗi lượt để trợ lý trả lời theo đúng gói đang xem thử. Trước đây
  /// chatbox là thứ DUY NHẤT trong app không đổi theo công tắc, nên bật Premium
  /// lên xem thử thì mọi màn khác đổi còn trợ lý vẫn nói giọng gói miễn phí.
  /// Máy chủ tự kiểm tra email nên gửi lên đây không mở được gì cho người khác.
  final bool? _premiumOverride;

  /// Mở cuộc gần nhất, hoặc một cuộc trống nếu chưa từng trò chuyện.
  ///
  /// Vào thẳng cuộc gần nhất chứ không vào màn danh sách: phần lớn lần mở là để
  /// nói tiếp chuyện đang dở, bắt qua một màn chọn là thêm một chạm cho việc
  /// thường gặp nhất.
  Future<void> load() async {
    final userId = _userId;
    if (userId == null) {
      state = state.copyWith(
        loading: false,
        error: 'Cần đăng nhập để trò chuyện.',
      );
      return;
    }
    try {
      final conversations = await _repo.fetchConversations(userId);
      if (conversations.isEmpty) {
        state = state.copyWith(loading: false, error: null);
        return;
      }
      final latest = conversations.first;
      final history = await _repo.fetchHistory(latest.id);
      state = state.copyWith(
        messages: history,
        conversationId: latest.id,
        loading: false,
        error: null,
      );
    } catch (_) {
      // Không đọc được lịch sử thì vẫn cho trò chuyện tiếp, ở một cuộc mới.
      // Khoá màn hình lại vì không tải được phần đã cuộn qua là chặn người ta
      // khỏi việc họ vào đây để làm.
      state = state.copyWith(loading: false);
    }
  }

  /// Bắt đầu một cuộc trò chuyện mới.
  ///
  /// Chỉ dọn màn hình, KHÔNG gọi máy chủ: cuộc được tạo lúc gửi câu đầu tiên.
  void startNew() {
    state = state.copyWith(
      messages: const [],
      conversationId: null,
      error: null,
      quotaExhausted: false,
    );
  }

  /// Mở một cuộc trò chuyện đã có.
  Future<void> open(String conversationId) async {
    state = state.copyWith(
      loading: true,
      messages: const [],
      conversationId: conversationId,
      error: null,
      quotaExhausted: false,
    );
    try {
      final history = await _repo.fetchHistory(conversationId);
      state = state.copyWith(messages: history, loading: false);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Chưa mở được cuộc trò chuyện này. Bạn thử lại nhé.',
      );
    }
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending) return;

    // Hiện câu vừa gõ ngay, đừng bắt người ta nhìn ô trống trong lúc chờ.
    final pending = WrChatMessage(
      role: WrChatRole.user,
      content: text,
      pending: true,
    );
    state = state.copyWith(
      messages: [...state.messages, pending],
      sending: true,
      error: null,
      quotaExhausted: false,
    );

    try {
      final reply = await _repo.send(
        text,
        conversationId: state.conversationId,
        premiumOverride: _premiumOverride,
      );
      state = state.copyWith(
        messages: [
          // Bỏ bản `pending` đi và đặt lại bản đã được máy chủ xác nhận.
          ...state.messages.where((m) => !m.pending),
          WrChatMessage(role: WrChatRole.user, content: text),
          WrChatMessage(
            role: WrChatRole.assistant,
            content: reply.reply,
            action: reply.action,
          ),
        ],
        // Lượt đầu của một cuộc mới là lúc máy chủ trả id về.
        conversationId: reply.conversationId ?? state.conversationId,
        sending: false,
        remaining: reply.remaining,
        isPremium: reply.isPremium,
        error: null,
      );
    } on WrChatException catch (e) {
      // Gỡ câu chưa gửi được ra khỏi danh sách. Để lại sẽ thành một lượt trông
      // như đã gửi mà máy chủ không hề biết, và lần sau mở lại thì nó biến mất.
      state = state.copyWith(
        messages: state.messages.where((m) => !m.pending).toList(),
        sending: false,
        error: e.message,
        quotaExhausted: e.quotaExhausted,
      );
    } catch (_) {
      state = state.copyWith(
        messages: state.messages.where((m) => !m.pending).toList(),
        sending: false,
        error: 'Mình chưa trả lời được lúc này. Bạn thử gửi lại nhé.',
      );
    }
  }

  /// Xoá cuộc đang mở.
  Future<void> clear() async {
    final id = state.conversationId;
    // Cuộc chưa gửi câu nào thì chưa tồn tại ở máy chủ, chỉ cần dọn màn hình.
    if (id == null) {
      state = state.copyWith(messages: const [], error: null);
      return;
    }
    final previous = state.messages;
    state = state.copyWith(
      messages: const [],
      conversationId: null,
      error: null,
    );
    try {
      await _repo.deleteConversation(id);
    } catch (_) {
      // Xoá hỏng thì trả lại nguyên trạng: để màn hình trống trong khi máy chủ
      // vẫn giữ nguyên là nói dối người dùng về điều vừa xảy ra.
      state = state.copyWith(
        messages: previous,
        conversationId: id,
        error: 'Chưa xoá được cuộc trò chuyện. Bạn thử lại nhé.',
      );
    }
  }

  /// Bỏ câu báo lỗi khi người dùng bắt đầu gõ lại.
  void dismissError() {
    if (state.error != null) {
      state = state.copyWith(error: null, quotaExhausted: false);
    }
  }
}

final wrChatControllerProvider =
    StateNotifierProvider<WrChatController, WrChatState>((ref) {
  // Chỉ đọc công tắc khi tài khoản này được phép bật, giống hệt điều kiện
  // `wrEntitlementProvider` dùng — nếu không, một giá trị sót lại trong
  // SharedPreferences sẽ đổi giọng trợ lý của người không được phép.
  final canToggle = ref.watch(canTogglePremiumProvider);
  return WrChatController(
    ref.watch(wrChatRepositoryProvider),
    ref.watch(currentUserIdProvider),
    canToggle ? ref.watch(premiumOverrideProvider) : null,
  );
});

/// Danh sách cuộc trò chuyện cho màn lịch sử.
///
/// `autoDispose` để mỗi lần mở tấm lịch sử là một lần đọc mới: vừa gửi một lượt
/// xong mà danh sách còn giữ thứ tự cũ thì cuộc vừa nói lại không nằm ở đầu.
final wrConversationsProvider =
    FutureProvider.autoDispose<List<WrConversation>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(wrChatRepositoryProvider).fetchConversations(userId);
});

/// Gợi ý mở lời cho màn trò chuyện trống.
///
/// Dựng từ chính những tình huống người dùng hay chọn khi nhìn lại, thay cho
/// danh sách gán cứng trước đây. Xem `wr_chat_starters.dart` để biết vì sao.
///
/// Đọc hai nguồn đã có sẵn trong app, KHÔNG thêm truy vấn mới:
///   • [wrEpisodeHistoryProvider] — chính là recentSituationIds (v2.0 §4.3).
///   • [wrSituationsProvider] — bảng tra mã sang tiêu đề tiếng Việt.
///
/// `valueOrNull ?? const []` chứ không `await`: màn chat phải mở được ngay cả
/// khi hai nguồn kia còn đang tải hoặc đã hỏng. Thiếu dữ liệu thì
/// [chatStarters] tự rơi về danh sách dự phòng, tức là vẫn có ba ô bấm được.
final wrChatStartersProvider = Provider<List<String>>((ref) {
  final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
  final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
  return chatStarters(
    recent: recentSituationIds(episodes),
    situations: situations,
  );
});
