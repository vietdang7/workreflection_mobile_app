# Bàn giao — WR Spec Parity (2026-07-25)

Nhánh: `feat/wr-data-foundation`
Kế hoạch gốc: `docs/plans/2026-07-25-wr-spec-parity.md`
Nguồn spec: `/home/duythong/Desktop/FileTam/workreflection`

## Trạng thái gate

- `flutter analyze` — 1 warning **có sẵn từ trước** khi tôi bắt đầu
  (`test/features/wr_screens_test.dart:143` `_situation` không dùng). Không phát sinh mới.
- `flutter test` — **1351 tests, all passed**.
- Chưa chạy `flutter build apk` trong phiên này.
- Chưa chạy `npx gitnexus analyze` lại sau các commit mới (index đang stale).

## Đã xong

### 1. Nội dung tình huống 49 → 60 ✔ (commit `feat(wr-content)`)
Career Situation Library quy định 10 chiều × 6 = 60; seed cũ chỉ có 49 (bám bảng
ánh xạ DataSpec v3 vốn thiếu 11 mục).
- `assets/seed/wr_situations.json` — thêm 11 mục kèm `expected_outcome` +
  `sca_perspective` viết theo giọng đọc-vị-thấu-cảm, không lộ mã nội bộ.
- `supabase/migrations/20260721000000_…sql` — seed block regenerate bằng
  `python3 tool/gen_wr_seed_sql.py`.
- `supabase/migrations/20260725000000_wr_situations_full_60.sql` — additive
  insert 11 dòng cho DB đã provision (idempotent).
- Test: `test/core/wr_situation_library_coverage_test.dart` (7 test).

### 2. Career Snapshot + cá nhân hoá theo vai trò ✔ (commit `feat(wr-profile)`)
- `supabase/migrations/20260725000001_wr_career_snapshot.sql` — 3 cột
  `current_role` / `career_goal` / `current_challenge`.
- `lib/core/logic/wr_career_profile.dart` — `CareerSnapshot`, danh sách lựa chọn,
  `roleToDimensions` / `roleToCareerStages` / `effectiveDimensionOrder` /
  `rankStoriesForProfile`.
- `MobileProfile.careerSnapshot`, `WrRepository.saveCareerSnapshot`.
- `WrCareerSetupScreen` — route `/wr/career-setup`, 3 bước, auto-advance, bỏ qua được.
- Card Career Snapshot trên Home; story flow xếp theo hồ sơ thay bảng ưu tiên cứng.
- Test: `wr_career_profile_test.dart` (19), `wr_career_setup_test.dart` (6).

### 3. Self-Check tầng Free/Paid ✔ (commit `feat(wr-selfcheck)`)
- `lib/core/logic/wr_self_check_narrative.dart` — `bandForScore` (4 khoảng
  4.2/3.5/2.8/0 như bộ narrative SCA), `pillarNarrative` 3 trụ × 4 khoảng,
  `detectPillarImbalance` + `imbalanceNarrative` (7 kiểu), `trendFromHistory`,
  `patternsForPillar`, `lowestPillar`.
- `wr_self_check_screen` — Free: "Điều đáng chú ý nhất"; Paid: diễn giải 3 trụ +
  mất cân bằng + xu hướng + đối chiếu Pattern. Free thấy khối mờ + nút paywall.
- Test: `wr_self_check_narrative_test.dart` (21), `wr_self_check_premium_test.dart` (6).

### 4. Pattern Nâng cao · Growth Journey · Context Document ⚠️ CHƯA COMMIT
Đang nằm trong working tree, tests xanh:
- Providers mới: `wrPatternNarrativesProvider`, `wrGrowthSnapshotsProvider`,
  `wrContextDocumentsProvider`.
- `lib/core/widgets/wr_premium_lock.dart` — khối khoá dùng chung.
- **Hành trình**: khối "DIỄN BIẾN THEO THỜI GIAN" thay banner placeholder
  "Phân tích mô thức chuyên sâu" (banner cũ chỉ dẫn sang paywall, người trả tiền
  cũng không có nội dung gì).
- **Phát triển**: khối "CHẶNG ĐƯỜNG PHÁT TRIỂN" đọc `wr_growth_journey_snapshots`.
- **Tài liệu bối cảnh**: `WrContextDocScreen` route `/wr/context-docs`, lối vào từ
  tab Tôi. Free quota 1 (`WrEntitlement.maxContextDocuments`), Paid không giới hạn;
  khối "Phân tích sâu" khoá cho Free.
- `WrRepository.uploadContextDocument` + migration
  `20260725000002_wr_context_docs_bucket.sql` (bucket private + 4 RLS policy).
- Test: `wr_premium_surfaces_test.dart` (7); cập nhật 1 test cũ trong
  `wr_screens_test.dart` cho khối mới.

## Việc còn lại

1. **Chạy migration lên Supabase** — 3 file `20260725*` chưa push. Dự án dùng
   backend chung `sukpcxevcjnhiuyaoqxi` với web app → cần duyệt trước khi push.
2. **Upload tài liệu bối cảnh dùng `image_picker`** (ảnh/scan). JD/CV thật thường
   là PDF/DOCX — muốn hỗ trợ cần thêm dependency `file_picker`, chưa làm vì đó là
   thay đổi dependency cần bạn đồng ý.
3. **Nội dung Paid chưa có nguồn sinh**: `wr_pattern_narratives` và
   `wr_growth_journey_snapshots` mới chỉ có UI đọc; chưa có job/edge function nào
   ghi dữ liệu vào. Người dùng Premium hiện thấy trạng thái "chưa đủ dữ liệu".
   Đây là khoảng trống backend, không phải mobile.
4. **`Ghi tiêu chuẩn 6_1.mp3` (77 MB)** trong thư mục spec — tôi không transcribe
   được audio trong phiên này nên **chưa đối chiếu** nội dung file đó. Nếu trong
   đó có yêu cầu bổ sung thì phần đối chiếu hiện chưa phủ.
5. **Chưa làm phần giải thích trải nghiệm khách hàng** (vòng tự đặt câu hỏi ↔
   kiểm chứng ↔ chỉnh app) mà bạn yêu cầu ở nửa sau của prompt.
6. Gate còn thiếu: `flutter build apk`, `npx gitnexus analyze`.

## Đã đối chiếu và KHÔNG có vấn đề

100 story (10 chiều × 10 — file docx lặp mỗi id 2 lần nên trông như 200), 15 câu
Self-Check, Reflection Cycle 5 bước, 23 bảng dữ liệu hai lớp, `WrEntitlement` 3
cấp khoá, giới hạn Career Memory cho Free, paywall.
