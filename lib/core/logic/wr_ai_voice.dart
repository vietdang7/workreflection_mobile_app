// Công tắc giọng đọc AI — khách 06/10: "tắt giọng AI".
//
// Khách gọi là "ElevenLabs", nhưng app chưa từng gọi ElevenLabs. Giọng đọc AI
// lúc chạy đi qua Ausynclab (Edge Function `tts-proxy`, dùng chung với web).
// Vì `tts-proxy` phục vụ cả web, ta tắt ở phía app chứ không sửa hàm đó.
//
// Tắt nghĩa là: không gọi API sinh giọng, và ẩn các nút nghe phụ thuộc API đó.
// Âm thanh đã thu sẵn trong assets (video HDSD, bài nghe có file mp3) không
// thuộc diện này.
//
// Bật lại khi build: `--dart-define=WR_AI_VOICE=true`.

/// `false` mặc định. Đọc ở MỌI chỗ sắp gọi TTS, không chỉ ở nút bấm: chặn ở
/// nút thì một luồng tự phát (đọc câu hỏi khảo sát, đọc kịch bản video) vẫn
/// gọi API.
const bool kAiVoiceEnabled = bool.fromEnvironment('WR_AI_VOICE');
