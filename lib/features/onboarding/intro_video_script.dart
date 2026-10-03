// Video hướng dẫn dựng bằng AI: TOÀN BỘ chữ của video nằm ở file này.
//
// Gồm hai phần:
//   1. Lời đọc của từng cảnh ([introNarrationScenes]). Đây là chữ được gửi sang
//      dịch vụ đọc giọng nói để sinh file mp3, và cũng là phụ đề trên màn.
//   2. Chữ hiện trên hình của từng cảnh (các getter `kIntro...`).
//
// File này CHỈ được import `wr_tr.dart` (Dart thuần, không Flutter), vì script
// `tool/gen_intro_narration.dart` chạy bằng `dart run` và đọc thẳng lời đọc từ
// đây. Thêm một import Flutter là script không chạy được nữa.
//
// ---------------------------------------------------------------------------
// Sửa lời đọc thì phải sinh lại giọng đọc
// ---------------------------------------------------------------------------
//
// File `assets/intro/intro_<vi|en>.json` ghi lại đúng câu đã được đọc thành
// tiếng. Lúc chạy, app so câu trong file đó với câu ở đây: lệch một chữ là app
// bỏ tiếng, chạy cảnh theo thời lượng ước tính kèm phụ đề (không bao giờ phát
// tiếng đọc một câu cũ dưới phụ đề câu mới). Bài test
// `test/features/wr_intro_video_test.dart` cũng đỏ để nhắc. Sinh lại bằng:
//
//     dart run tool/gen_intro_narration.dart vi
//     dart run tool/gen_intro_narration.dart en
//
// Giọng app: gọi "bạn", câu ngắn, không dấu gạch dài, không emoji.

import '../../core/l10n/wr_tr.dart';

/// Sáu cảnh của video, đúng thứ tự phát. Tên enum là khoá trong file JSON
/// thời lượng, đổi tên thì phải sinh lại giọng đọc.
enum IntroSceneId { welcome, reflect, understand, grow, assistant, closing }

class IntroNarrationScene {
  const IntroNarrationScene({required this.id, required this.text});
  final IntroSceneId id;
  final String text;
}

/// Lời đọc, mỗi cảnh một đoạn. Getter (không phải `final`) để đổi ngôn ngữ là
/// đọc ra câu đúng ngôn ngữ ngay.
List<IntroNarrationScene> get introNarrationScenes => [
  IntroNarrationScene(
    id: IntroSceneId.welcome,
    text: tr(
      'Chào bạn, đây là WorkReflection. Mỗi ngày, bạn chỉ cần một hai phút '
          'để nhìn lại công việc của mình.',
      'Hi, this is WorkReflection. A minute or two a day is all you need to '
          'look back on your work.',
    ),
  ),
  IntroNarrationScene(
    id: IntroSceneId.reflect,
    text: tr(
      'Ở tab Hôm nay, bạn chạm chọn cảm xúc lúc này. Rồi bạn nhìn lại một '
          'khoảnh khắc qua bốn bước: chọn tình huống, đọc một câu chuyện, xem '
          'một góc nhìn khác, và chọn bước tiếp theo.',
      'On the Today tab, tap how you feel right now. Then look back on one '
          'moment in four steps: pick a situation, read a story, see another '
          'angle, and choose a next step.',
    ),
  ),
  IntroNarrationScene(
    id: IntroSceneId.understand,
    text: tr(
      'Qua nhiều lần nhìn lại, tab Hiểu mình chỉ ra những vòng lặp quen thuộc, '
          'những điều cứ quay lại với bạn trong công việc.',
      'Over many look-backs, the Understand tab shows your familiar loops, '
          'the things that keep coming back to you at work.',
    ),
  ),
  IntroNarrationScene(
    id: IntroSceneId.grow,
    text: tr(
      'Ở tab Phát triển, ứng dụng tự gợi ý chủ đề thực hành hợp với bạn. Mỗi '
          'lần thực hành, bạn đánh dấu một lần. Giữ đều đặn, điều đó thành kỹ '
          'năng của bạn.',
      'On the Develop tab, the app suggests practice themes that fit you. '
          'Tick off each time you practise. Keep it up, and it becomes your '
          'skill.',
    ),
  ),
  IntroNarrationScene(
    id: IntroSceneId.assistant,
    text: tr(
      'Cần hỏi gì, bạn chạm biểu tượng trò chuyện ở góc dưới bên phải để mở '
          'Trợ lý AI. Trợ lý đọc các ghi nhận của bạn, nên trả lời sát với bối '
          'cảnh của bạn.',
      'Need help? Tap the chat icon at the bottom right to open the AI '
          'assistant. It reads what you have recorded, so its answers fit '
          'your situation.',
    ),
  ),
  IntroNarrationScene(
    id: IntroSceneId.closing,
    text: tr(
      'Mọi lần nhìn lại đều được lưu ở tab Hành trình. Bắt đầu bằng một lần '
          'chạm ở tab Hôm nay nhé.',
      'Every look-back is kept on the Journey tab. Start with a single tap '
          'on the Today tab.',
    ),
  ),
];

// ---------------------------------------------------------------------------
// Chữ trên hình
// ---------------------------------------------------------------------------

/// Tên bốn tab, đúng nhãn của thanh tab dưới đáy app.
String get kIntroTabToday => tr('Hôm nay', 'Today');
String get kIntroTabUnderstand => tr('Hiểu mình', 'Understand');
String get kIntroTabDevelop => tr('Phát triển', 'Develop');
String get kIntroTabJourney => tr('Hành trình', 'Journey');

String get kIntroWelcomeTagline =>
    tr('Một hai phút mỗi ngày', 'A minute or two a day');

String get kIntroReflectTitle =>
    tr('Nhìn lại một khoảnh khắc', 'Look back on a moment');

/// Sáu lựa chọn cảm xúc ở tab Hôm nay (theo màn Hướng dẫn).
List<String> get kIntroMoods => [
  tr('Căng thẳng', 'Tense'),
  tr('Mệt mỏi', 'Worn out'),
  tr('Mơ hồ', 'Unclear'),
  tr('Mọi thứ lệch nhau', 'Out of step'),
  tr('Khá ổn', 'Doing okay'),
  tr('Đang vui', 'Feeling good'),
];

/// Bốn bước nhìn lại (HDSD v4).
List<String> get kIntroReflectSteps => [
  tr('Chọn tình huống', 'Pick a situation'),
  tr('Đọc một câu chuyện', 'Read a story'),
  tr('Xem một góc nhìn khác', 'See another angle'),
  tr('Chọn bước tiếp theo', 'Choose a next step'),
];

String get kIntroUnderstandTitle =>
    tr('Những vòng lặp quen thuộc', 'Familiar loops');

/// Nhãn nhỏ: các dòng bên dưới chỉ là ví dụ, không phải dữ liệu của ai.
String get kIntroExampleLabel => tr('Ví dụ minh hoạ', 'Example');

List<String> get kIntroLoopExamples => [
  tr('Họp xong vẫn chưa rõ ai làm gì', 'Meetings end without clear owners'),
  tr('Việc gấp chen ngang kế hoạch', 'Urgent work cuts into the plan'),
  tr('Ngại góp ý với đồng nghiệp', 'Holding back feedback'),
];

String get kIntroGrowTitle => tr('Chủ đề thực hành', 'Practice theme');

String get kIntroGrowTheme =>
    tr('Nói rõ điều mình cần', 'Say clearly what you need');

String get kIntroGrowSkill => tr('Kỹ năng đã hình thành', 'Skill formed');

String get kIntroAssistantTitle => tr('Trợ lý AI', 'AI assistant');

String get kIntroAssistantQuestion =>
    tr('Tôi hay bực chuyện gì nhất?', 'What annoys me most?');

String get kIntroAssistantAnswer => tr(
  'Gần đây, chuyện họp xong chưa rõ ai làm gì quay lại nhiều nhất.',
  'Lately, meetings ending without clear owners come up the most.',
);

String get kIntroClosingLine =>
    tr('Bắt đầu từ tab Hôm nay', 'Start on the Today tab');
