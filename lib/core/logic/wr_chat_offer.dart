// Suy lại nút hành động của chatbox từ câu chữ, khi đọc lại lịch sử.
//
// Nút (`WrChatAction`) CỐ Ý không lưu vào `wr_chat_messages` (xem
// `WrChatMessage.action`): mở lại cuộc trò chuyện ba ngày sau mà vẫn thấy lời
// mời cũ nằm giữa lịch sử là mời người ta làm một việc đã qua. Nhưng hệ quả là
// LƯỢT CUỐI mất nút trong khi câu chữ của nó vẫn hứa nút. Người dùng gặp đúng
// cảnh đó (09/09): trợ lý mời "thử một bài đọc ngắn", họ mở lại cuộc trò chuyện
// thì không có gì để bấm, hỏi "tôi có thấy đoạn đọc ngắn nào đâu", và trợ lý
// đọc lịch sử rồi xin lỗi là "quên đặt nút" — một câu sai.
//
// Nên khi đọc lại, lượt CUỐI CÙNG của trợ lý được suy lại nút từ chính câu chữ.
// Các lượt cũ hơn vẫn không có nút, giữ nguyên lý do ban đầu.
//
// Các mẫu dưới đây là bản Dart của `inferAction` trong
// `supabase/functions/wr-chat/reply_shaping.ts` (lý do của từng mẫu ghi ở đó).
// Hai bên cùng chạy bộ ca `supabase/functions/wr-chat/offer_cases.json`: sửa
// một bên mà quên bên kia thì test đỏ.
//
// Pure Dart → test được trực tiếp.

import '../models/checkin.dart' show Mood;
import '../models/wr_chat.dart';

RegExp _re(String source) => RegExp(source, caseSensitive: false);

final _riskSelfLimit = _re(r'không phải (là )?(một )?chuyên gia tâm lý');
final _riskRedirect = _re(
  r'(tìm đến|tìm tới|nói chuyện với|chia sẻ với|liên hệ)[^.?!]{0,90}(người thân|bạn bè|người bạn|chuyên gia)|(người thân|bạn bè|người bạn|ai đó|chuyên gia tâm lý)[^.?!]{0,90}(tìm đến|tìm tới|ngay bây giờ|ngay lúc này|lúc này)',
);
final _calmOffer = _re(
  r'(muốn|thử|gợi ý|giới thiệu|mình có)[^.?!]{0,40}(bài đọc|bài nghe|bài viết|audio|nội dung nhẹ|điều nhẹ nhàng)|thư viện nội dung cảm xúc',
);
final _reflectPointer = _re(
  r'(nút|bấm vào)[^.?!]{0,50}(reflection|luồng|ngay dưới|bên dưới|phía dưới)|bấm vào (nút|đó)|mở luồng (reflection|nhìn lại)',
);
final _reflectInvite = _re(
  r'(muốn|thử)[^.?!]{0,60}ghi lại[^.?!]{0,60}reflection|ghi lại thành (một )?reflection[^.?!]{0,40}\?',
);
final _reflectRefusal = _re(
  r'(không|chưa) (thể |tự |được )?(ghi|lưu)|không có quyền (ghi|lưu)',
);

final _riskSelfLimitEn = _re(
  r'\bnot an? (licensed |trained )?(therapist|psychologist|counsell?or|mental health (professional|expert))\b',
);
final _riskRedirectEn = _re(
  r"\b(reach out to|talk to|speak (to|with)|contact|turn to)\b[^.?!]{0,90}\b(someone you trust|a friend|friends|family|a professional|a therapist|a counsell?or|a doctor)\b|\b(someone you trust|a friend|family|a professional|a therapist)\b[^.?!]{0,90}\b(right now|right away)\b",
);
final _calmOfferEn = _re(
  r"\b(want|would you like|like to|try|suggest|recommend|i have|there is|there's)\b[^.?!]{0,40}\b(short read|reading|article|audio|something (gentle|gentler|calming|lighter))\b|\bemotional content library\b",
);
final _reflectPointerEn = _re(
  r'\b(button|tap)\b[^.?!]{0,50}\b(reflection|below|underneath)\b|\btap (it|that|the button|on it)\b|\bopen (the )?reflection\b',
);
final _reflectInviteEn = _re(
  r'\b(want|would you like|like to|try)\b[^.?!]{0,60}\b(record|write|capture|save|note)\b[^.?!]{0,60}\breflection\b|\b(record|write|capture|save) (it|this|that) (down )?as an? (full )?reflection\b[^.?!]{0,40}\?',
);
final _reflectRefusalEn = _re(
  r"\b(can ?not|can't|cannot|unable to|not able to)\b[^.?!]{0,20}\b(record|save|write|log)\b",
);

/// Nút mà câu chữ [text] đang hứa, hoặc null. Cùng thứ tự luật với máy chủ.
WrChatAction? inferChatAction(String text) {
  if ((_riskSelfLimit.hasMatch(text) && _riskRedirect.hasMatch(text)) ||
      (_riskSelfLimitEn.hasMatch(text) && _riskRedirectEn.hasMatch(text))) {
    return WrChatAction.calm;
  }
  if (_calmOffer.hasMatch(text) || _calmOfferEn.hasMatch(text)) {
    return WrChatAction.calm;
  }
  if (_reflectPointer.hasMatch(text) || _reflectPointerEn.hasMatch(text)) {
    return WrChatAction.reflect;
  }
  if ((_reflectInvite.hasMatch(text) && !_reflectRefusal.hasMatch(text)) ||
      (_reflectInviteEn.hasMatch(text) && !_reflectRefusalEn.hasMatch(text))) {
    return WrChatAction.reflect;
  }
  return null;
}

/// Lịch sử vừa đọc từ database, với nút được suy lại cho lượt cuối.
///
/// Chỉ khi lượt cuối là của TRỢ LÝ: nếu người dùng đã nói sau lời mời thì lời
/// mời đó đã được trả lời rồi.
List<WrChatMessage> restoreLastChatAction(List<WrChatMessage> history) {
  if (history.isEmpty) return history;
  final last = history.last;
  if (last.role.isUser || last.action != null) return history;
  final action = inferChatAction(last.content);
  if (action == null) return history;
  return [
    ...history.take(history.length - 1),
    WrChatMessage(
      id: last.id,
      role: last.role,
      content: last.content,
      createdAt: last.createdAt,
      pending: last.pending,
      action: action,
    ),
  ];
}

// Nút "Xem điều gì đó nhẹ nhàng" mở Thư viện theo cảm xúc của hôm nay. Chưa
// check-in thì Thư viện rơi về "Khá ổn", tức là trợ lý vừa thấy người dùng mệt
// mà nút lại mở nhóm bài cho người đang ổn (test máy thật 08/10). Khi đó đọc
// cảm xúc từ chính lời người dùng vừa nói; không nhận ra thì lấy "căng thẳng",
// nhóm bài dịu lại chung nhất.
final _moodTired = _re(
  r'mệt|kiệt sức|đuối|uể oải|buồn ngủ|\btired\b|exhausted|drained|worn out|burn(ed|t)? out',
);
final _moodFoggy = _re(
  r'rối|mông lung|mơ hồ|lạc hướng|không rõ|\bfoggy\b|confused|lost|unclear',
);
final _moodOutOfSync = _re(
  r'lệch|lạc lõng|không hợp|không ăn khớp|out of sync|misaligned|don.t fit',
);
final _moodStressed = _re(
  r'căng|áp lực|lo lắng|stress|bực|tense|pressure|anxious|overwhelm',
);

Mood calmMoodFor(String? userText) {
  final t = userText ?? '';
  if (_moodTired.hasMatch(t)) return Mood.tired;
  if (_moodStressed.hasMatch(t)) return Mood.stressed;
  if (_moodFoggy.hasMatch(t)) return Mood.foggy;
  if (_moodOutOfSync.hasMatch(t)) return Mood.outofsync;
  return Mood.stressed;
}
