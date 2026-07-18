# Phase 5 — Parity 100% trải nghiệm NGƯỜI DÙNG với web (trừ SePay)

**Ngày:** 2026-07-18 · **Quyết định của chủ dự án:** thực thi trọn Phương án 1; Phương án 2 (enterprise-member) & 3 (admin/coach console) chỉ lập plan (xem `2026-07-18-option2-enterprise-member-plan.md`, `2026-07-18-option3-full-literal-parity-plan.md`).

**Nguồn chân lý:** web repo `/home/duythong/Documents/DuyThong/workreflection` (GitNexus repo name: `workreflection`, 3547 symbols/273 flows). Mobile: `appmobileworkreflection`. Backend Supabase chung `sukpcxevcjnhiuyaoqxi`.

**Loại trừ duy nhất theo yêu cầu:** thanh toán SePay (checkout/hoá đơn/webhook) — luồng trả phí tiếp tục hướng lên web. Voucher chỉ HIỂN THỊ danh sách (áp mã diễn ra ở checkout web).

## Task list (tuần tự, mỗi task: Sonnet implement → Fable independent review → rework tới khi đạt)

### T1 — Home discoverability + màn Hướng dẫn khảo sát
- Home: card CTA khảo sát state-aware (chưa có báo cáo → "Làm bài phản chiếu"; có → "Xem báo cáo mới nhất" + "Làm lại"). Đây là phàn nàn trực tiếp của chủ dự án ("không thấy chỗ làm bài phản chiếu").
- Thêm bước Guide giữa intro và questions, mirror `src/pages/survey/Guide.tsx` (giải thích S-C-A).

### T2 — Nâng cấp trực quan báo cáo: radar chart S-C-A
- Radar/pentagon chart trên ReportScreen mirror web (`SCAResults.tsx`/`Premium.tsx`). Dep gợi ý fl_chart (xác nhận chưa có chart dep trong pubspec trước).

### T3 — Màn chi tiết từng lớp + phân tích ESI
- 4 màn mirror web: StructureDetail, CultureDetail, ActivityDetail, ESIAnalysis — điểm tiểu cấu phần + narratives. XÁC MINH nguồn dữ liệu tiểu cấu phần từ web code (cc_reports cột nào / tính từ cc_responses?).

### T4 — Diễn giải AI cá nhân hoá + biến thể
- Gọi edge function `ai-personalize` đúng cách web gọi (Premium.tsx), cache `cc_ai_personalization_cache`, chọn variant narrative như web.

### T5 — Roadmap tracker 30 ngày
- Mirror `pages/user/RoadmapTracker.tsx`: chọn báo cáo premium → actions theo lớp, custom tasks CRUD (`cc_custom_roadmap_tasks`), tiến độ (`cc_roadmap_actions`/`cc_roadmap_progress`), cấp quyền coach xem (`cc_roadmap_coach_access`).

### T6 — Coaching: đặt lịch buổi + đánh giá coach
- GHI CHÚ: đảo quyết định Phase 3 (trước đây "đặt lịch trên web") theo chỉ đạo 100% parity — đặt lịch KHÔNG dính SePay (gói đã sở hữu).
- Mirror `CoachingSchedule.tsx`: slot từ `cc_coach_availability`, đặt `scheduled_at` đúng cơ chế web (update/RPC — xác minh).
- Hiển thị rating/review coach (`cc_coaching_reviews`) như trang Coaching web.

### T7 — Workshop: xem kết quả khảo sát + các gap còn lại
- Mirror `workshop/SurveyResults.tsx` (xem kết quả sau khi nộp).
- Kiểm tra certificate download trên web MyWorkshops — có thật thì thêm, không thì ghi rõ không tồn tại.

### T8 — Profile: avatar upload + voucher list + lời mời tổ chức
- Avatar: bucket `avatars`, path `{userId}/avatar.{ext}` (đã xác minh Phase 4); image_picker, không cần crop phức tạp (center-crop vuông đơn giản).
- Voucher: màn list mirror `user/Vouchers.tsx` (read-only, ghi chú áp mã trên web).
- Invitations: mirror `user/Invitations.tsx` — pending accept/decline (`cc_org_invitations`).

### T9 — Nhập câu trả lời khảo sát bằng giọng nói (STT)
- XÁC MINH cơ chế web trước (Whisper qua edge function? browser SpeechRecognition? xem `Questions.tsx` + `stt-telemetry.ts`). Mobile dùng cơ chế tương đương (speech_to_text on-device hoặc gọi cùng edge function). Task nặng — làm sau khi các task UI xong.

### T10 — Xuất PDF báo cáo
- Dep `pdf` + `printing`, layout đơn giản: điểm tổng, S-C-A, narratives, ESI/eNPS. Parity chức năng, không cần pixel-perfect với web.

### T11 — Final gates + adversarial review
- analyze 0 · toàn bộ test xanh · APK debug OK · detect_changes scope đúng · re-index (GLOBAL `gitnexus analyze`) · Fable adversarial checklist toàn phase · cập nhật memory.

## Ngoài phạm vi Phase 5 (ghi rõ để không hiểu nhầm)
- SePay checkout/hoá đơn (chỉ đạo của chủ dự án).
- Video report GENERATION (Remotion chạy web-side; mobile chỉ xem nếu URL có sẵn — không cam kết).
- Enterprise-member (Phương án 2), Admin/Coach console + blog/trang công khai (Phương án 3).

## Quy tắc implementer (như Phase 4, đã chứng minh hiệu quả)
1. Schema/hành vi: đọc web code hoặc GitNexus repo `workreflection` — KHÔNG ĐOÁN.
2. gitnexus_impact trước khi sửa symbol có sẵn; detect_changes trước commit.
3. Gates tự chạy và dán output thật (analyze 0 + test xanh) — Fable sẽ chạy lại độc lập.
4. l10n VI+EN mọi string; style theo codebase (WrCard, autoDispose, repository layer).
5. Chỉ commit file của task mình; message `feat(p5): ...`.
