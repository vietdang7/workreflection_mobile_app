# WR Spec Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Đưa app mobile WorkReflection khớp 100% với bộ spec trong `/home/duythong/Desktop/FileTam/workreflection` (Career Situation Library, DataSpec v3, Kiến trúc Dữ liệu Hai Lớp v1.2, mockup `giao-dien-ho-tro.jsx`).

**Architecture:** Giữ nguyên kiến trúc hiện tại: seed JSON trong `assets/seed/` → `WrContentRepository`; Supabase tables `wr_*` → `WrIntelligenceRepository`; Riverpod providers trong `lib/features/wr/wr_providers.dart`; gating qua `WrEntitlement` (3 cấp). Bổ sung là mở rộng dữ liệu + logic thuần Dart (test được) + màn hình Flutter.

**Tech Stack:** Flutter 3 / Dart 3, Riverpod, go_router, Supabase, flutter_test.

---

## Kết quả đối chiếu spec ↔ app (baseline 2026-07-25)

| Hạng mục | Spec | App | Trạng thái |
|---|---|---|---|
| Story library | 100 story (10 chiều × 10) | 100 | ✅ đủ |
| Situation list | 60 (10 chiều × 6) | 49 | ❌ thiếu 11 |
| 15 câu SCA Self-Check | 15 | 15 | ✅ |
| Reflection Cycle 5 bước | Notice→Meaning→Insight→Choice→Action | có enum + bảng | ✅ |
| Bảng dữ liệu 2 lớp | 23 bảng | 23 bảng | ✅ |
| Entitlement 3 cấp | feature/content/quota | có + test | ✅ |
| Career Setup (vai trò/mục tiêu/trăn trở) + Career Snapshot | mockup | không có | ❌ |
| Cá nhân hoá theo vai trò (ROLE_TO_DIMS/STAGES) | mockup | không có | ❌ |
| Self-Check diễn giải sâu (Paid) | Hai Lớp §II | chỉ 3 thanh điểm | ❌ |
| Self-Check phát hiện mất cân bằng trụ | Hai Lớp §II | không có | ❌ |
| Self-Check xu hướng theo thời gian (Paid) | Hai Lớp §II | không có | ❌ |
| Pattern Nâng cao (narrative) | Hai Lớp §III | repo có, UI không | ❌ |
| Growth Journey snapshot (Paid) | Hai Lớp §III | bảng có, UI không | ❌ |
| Context Document JD/CV | Hai Lớp §III/IV | bảng có, UI không | ❌ |

Không đánh giá được: `Ghi tiêu chuẩn 6_1.mp3` (77 MB audio) — không transcribe được trong phiên này.

---

### Task 1: Bổ sung 11 tình huống còn thiếu

**Files:**
- Modify: `assets/seed/wr_situations.json`
- Test: `test/core/wr_situation_library_coverage_test.dart` (create)

11 tình huống thiếu (theo Career Situation Library Tầng 1):
S2 `Công việc phụ thuộc quá nhiều người` · S3 `Thiếu dữ liệu để ra quyết định` ·
C1 `Khó giao việc cho người khác`, `Thiếu sự hỗ trợ từ đội nhóm` ·
C2 `Sợ mắc lỗi trước tập thể` · C3 `Không biết cách góp ý` ·
A1 `Không chắc mình đang đi đúng hướng` ·
A2 `Không hoàn thành được việc quan trọng`, `Cảm thấy mất kiểm soát với công việc` ·
A3 `Không có thời gian nhìn lại` · A4 `Không biết bước tiếp theo để phát triển`

Mỗi mục cần `code`, `text`, `sca_dimension`, `human_need`, `expected_outcome`, `sca_perspective`, `wave` — viết theo giọng đọc-vị-thấu-cảm của DataSpec v3, không lộ mã S1/C2/A4.

**Step 1:** Viết test khẳng định 60 tình huống, mỗi chiều đúng 6, không rỗng field nào.
**Step 2:** Chạy test → FAIL (49 ≠ 60).
**Step 3:** Thêm 11 entry vào JSON.
**Step 4:** Chạy test → PASS. **Step 5:** Commit.

### Task 2: Career Snapshot — model + repo + migration

**Files:**
- Create: `supabase/migrations/20260725000000_wr_career_snapshot.sql` (thêm cột `current_role`, `career_goal`, `current_challenge` vào `wr_mobile_profiles`)
- Modify: `lib/core/models/mobile_profile.dart`, `lib/core/data/wr_repository.dart`
- Test: `test/core/wr_career_snapshot_test.dart`

### Task 3: Logic cá nhân hoá theo vai trò

**Files:**
- Create: `lib/core/logic/wr_career_profile.dart` (`kRoleOptions`, `kGoalOptions`, `kChallengeOptions`, `roleToDimensions()`, `roleToCareerStages()`, `rankStoriesForProfile()`)
- Test: `test/core/wr_career_profile_test.dart`

### Task 4: Màn hình Career Setup 3 bước + Career Snapshot card

**Files:**
- Create: `lib/features/wr/presentation/wr_career_setup_screen.dart` (route `/wr/career-setup`)
- Modify: `lib/core/router/app_router.dart`, `lib/features/wr/presentation/wr_home_screen.dart`
- Test: `test/features/wr_career_setup_test.dart`

### Task 5: Self-Check — diễn giải sâu + mất cân bằng (logic thuần)

**Files:**
- Create: `lib/core/logic/wr_self_check_narrative.dart` (`pillarBand()`, `pillarNarrative()`, `detectPillarImbalance()`, `imbalanceNarrative()`, `trendFromHistory()`)
- Test: `test/core/wr_self_check_narrative_test.dart`

### Task 6: Self-Check result — gắn Free/Paid vào UI

**Files:**
- Modify: `lib/features/wr/presentation/wr_self_check_screen.dart`
- Test: `test/features/wr_self_check_premium_test.dart`

Free: 3 thanh + 1 câu diễn giải ngắn cho trụ thấp nhất. Paid: diễn giải đầy đủ 3 trụ, khối mất cân bằng, xu hướng qua các lần trước, đối chiếu Pattern. Free thấy khối mờ + nút nâng cấp `/wr/paywall`.

### Task 7: Pattern Nâng cao UI (Paid)

**Files:** Modify `lib/features/wr/presentation/wr_journey_screen.dart`; Test `test/features/wr_pattern_advanced_test.dart`

### Task 8: Growth Journey snapshot UI (Paid)

**Files:** Modify `lib/features/wr/presentation/wr_growth_screen.dart`; Test `test/features/wr_growth_journey_test.dart`

### Task 9: Context Document JD/CV

**Files:** Create `lib/features/wr/presentation/wr_context_doc_screen.dart` (route `/wr/context-docs`); Modify router + profile entry; Test `test/features/wr_context_doc_test.dart`

Free: lưu tối đa 1 tài liệu (quota `WrEntitlement.maxContextDocuments`). Paid: không giới hạn + khối "Phân tích sâu".

### Task 10: Gate cuối

`flutter analyze` = 0 · `flutter test` toàn bộ xanh · `gitnexus_detect_changes` · re-index.
