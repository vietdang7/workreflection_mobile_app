# Kế hoạch tái cấu trúc app theo bộ kiến trúc WDA · HXA · WIA · WPA · WXS

Ngày 2026-07-27 · nhánh `feat/wr-data-foundation`

Nguồn: `/home/duythong/Desktop/FileTam/workreflection/` — 5 tài liệu mới
(`WORKREFLECTION_DOMAIN_ARCHITECTURE_v1.1`, `HXA_v1.0`, `WIA_v1.0`, `WPA_v1.0`,
`WXS_v1.0`) + yêu cầu UI/UX trực tiếp từ khách hàng.

---

## 1. Điều bộ tài liệu bắt buộc (trích những ràng buộc có thể kiểm chứng)

| Nguồn | Ràng buộc | Hệ quả cho app |
|---|---|---|
| HXA §2.5 | Đúng **6 Human Moment Archetypes**: Arrival · Confusion · Decision · Growth · Recovery · Celebration | Màn chọn khoảnh khắc = 6 thẻ, không hơn |
| HXA §3.5 | Đúng **6 Reflection Patterns**: Notice · Name · Explore · Reframe · Commit · Preserve | Câu hỏi dẫn dắt sinh từ pattern, không viết tay rời rạc |
| HXA Inv.5 | Người dùng **không chọn Pattern theo tên** — chọn Human Moment, hệ thống quyết định Pattern | Không có menu "chọn kiểu phản tư" |
| HXA §3.8 · WXS §4.4 | **Không nhảy cóc bước**: Captured → Committed là transition bất hợp lệ | State machine phải chặn ở tầng logic, có test |
| WXS §4.2 | **9 Experience State**: Emerging → Captured → Exploring → Meaning Forming → Meaning Confirmed → Committed → Integrated → Dormant → Reactivated | Cần bảng `wr_reflection_episodes` để persist |
| WXS §4.5 · §6.4 | Experience **pause/resume độc lập với UI session** | Mở app lại phải tiếp tục đúng điểm dừng, không hỏi lại từ đầu |
| WXS §8.7 | **Focused Surface**: một Meaning, một nhiệm vụ trên một màn | Đúng yêu cầu "một màn hình – một hành động" của khách |
| WXS Inv.3 · WIA Inv.2 | **Chỉ người dùng Confirm Meaning**, AI chỉ Propose | Nút xác nhận phải là hành động của người dùng |
| WDA Inv.6 · §6.5 | Story chỉ vào Career Memory khi đã đạt **Level 2 Reflection (Interpretation)** | Ghi chú thô không tự động thành Career Memory |
| WXS §3.12 Inv.6 | Development Flow chỉ mở khi Pattern đủ mạnh — **≥ 2 Episode cùng chủ đề** | Ngưỡng gợi ý thực hành |
| WPA §3.3 | Đúng **8 Building Blocks** | Mọi màn phải ánh xạ về một block |

Yêu cầu khách hàng (chồng lên, không mâu thuẫn):
1. Tối giản, nhiều khoảng trắng, ít chữ — không bê cảm giác web app sang mobile.
2. **Một màn hình – một hành động.** Tuyệt đối không xổ/liệt kê toàn bộ trên một trang. Màn đọc tách khỏi màn ghi chú.
3. Check-in: bỏ trùng lặp trạng thái/năng lượng, **giữ năng lượng**; thẻ gợi ý ~6 ô, to rõ; sau check-in có câu hỏi dẫn dắt → người dùng tự mô tả → lưu thành nhật ký (memory).
4. Hiểu mình: tích lũy dữ liệu (vd lặp 5 lần) → đọc ra nguyên nhân sâu. **Insight = Premium**; free chỉ xem ghi nhận hành trình.
5. Phát triển: free tối đa **2 chủ đề** cùng lúc; lặp đủ nhiều → hệ thống **chứng nhận "kỹ năng mới"**.

---

## 2. Khoảng cách với app hiện tại

| Vấn đề | Hiện trạng | Vi phạm |
|---|---|---|
| Home là một trang cuộn dài | `wr_home_screen.dart` 1.160 dòng: năng lượng → xổ hướng đi → xổ chip tình huống → xổ thẻ xác nhận → career snapshot → pattern → story → insight, tất cả trên một màn | Yêu cầu #2 · WXS §8.7 |
| Trùng lặp trạng thái/năng lượng | `_EnergyOption` sinh cả `mood` lẫn `energy`; thêm bước `_DirectionOption` | Yêu cầu #3 |
| Không có Human Moment | Không tồn tại khái niệm archetype trong code | HXA §2.5 (Invariant 1: không Human Moment thì không Experience) |
| Không có Experience State | Chỉ có `wr_checkins` + `wr_memory_events` rời rạc; không resume được phiên đang dở | WXS §4 toàn chương |
| Reflection Pattern không được mô hình hóa | `ReflectionStepType` có 5 giá trị (notice/meaning/insight/choice/action) theo Reflection **Cycle** của WDA, thiếu tầng Pattern của HXA | HXA §3 |
| Không có ô tự mô tả ở check-in | Chỉ chọn chip; free-text duy nhất nằm trong story flow | Yêu cầu #3 |
| Quota free sai | `maxActivePracticeThemes = 3` | Yêu cầu #5 |
| Chưa có chứng nhận kỹ năng | Không tồn tại | Yêu cầu #5 |
| Free/Premium chưa đúng ranh | Free vẫn thấy `wrLatestInsightProvider` trên Home và "ĐIỀU BẠN ĐANG TÌM KIẾM" (diễn giải) ở Hiểu mình | Yêu cầu #4 |
| Bề mặt kế thừa app khảo sát | survey 49 câu, workshops, coaching, video report, roadmap, insights, `/understand` `/develop` `/journey` cũ (~12k dòng) vẫn có lối vào | HXA §6.4 Sunset Rule · WPA Inv.2 |

---

## 3. Kiến trúc mục tiêu

### 3.1 Reflection Episode là đơn vị trung tâm

```
Human Moment (6 archetype)
  └─ Reflection Episode  ── state ∈ 9 Experience State
       ├─ Reflection Step (Notice/Name/Explore/Reframe/Commit/Preserve)
       ├─ Draft Meaning  → Confirmed Insight (do người dùng xác nhận)
       ├─ Tiny Next Step
       └─ Career Memory Contribution
```

### 3.2 Luồng màn hình mới (mỗi mũi tên = một màn riêng)

```
Home (tối giản)
  → Năng lượng      3 ô to            [state: Emerging → Captured]
  → Human Moment    6 thẻ to (2×3)    [Captured, chốt archetype]
  → Phản tư         1 câu hỏi/màn     [Exploring]  ← Pattern do hệ thống chọn
  → Ghi chú         ô nhập riêng      [Exploring]  ← màn đọc ≠ màn ghi
  → Ý nghĩa         xác nhận/sửa      [Meaning Forming → Meaning Confirmed]
  → Bước nhỏ        1 câu             [Committed → Integrated]
  → Xong            về Home
```

Mỗi màn: 1 tiêu đề, tối đa 1 khối nội dung, 1 hành động chính. Thoát giữa chừng
→ Episode giữ nguyên state, Home hiện "Tiếp tục phản tư đang mở".

### 3.3 Bảng Pattern mặc định theo Archetype (HXA §3.2, §3.6)

| Human Moment | Pattern sequence |
|---|---|
| Arrival — Dừng lại | Notice → Name → Preserve |
| Confusion — Bối rối | Notice → Name → Explore → Preserve |
| Decision — Quyết định | Notice → Name → Explore → Reframe → Commit |
| Growth — Muốn tiến bộ | Notice → Explore → Commit → Preserve |
| Recovery — Mất năng lượng | Notice → Explore → Preserve |
| Celebration — Đáng tự hào | Notice → Name → Preserve |

### 3.4 Ranh giới Free / Premium

| | Free | Premium |
|---|---|---|
| Check-in + phản tư + ghi chú | ✅ không giới hạn | ✅ |
| Career Memory (nhật ký) | ✅ xem toàn bộ | ✅ |
| Hiểu mình | Chỉ **ghi nhận**: đã phản tư bao nhiêu lần, tình huống nào lặp mấy lần, dòng thời gian | Thêm **diễn giải**: nguyên nhân sâu, pattern narrative, xu hướng theo thời gian |
| Ngưỡng mở diễn giải | — | ≥ 5 lần lặp cùng tình huống/chủ đề |
| Thực hành | Tối đa **2** chủ đề đang mở | Không giới hạn |
| Chứng nhận kỹ năng | ✅ (đây là ghi nhận, không phải diễn giải) | ✅ |

---

## 4. Kế hoạch thực thi

### Sprint A — Nền Reflection Episode
- **A1** Migration `20260727000000_wr_reflection_episodes.sql`: bảng episode
  (user_id, human_moment, energy, situation_code, state, draft_meaning,
  confirmed_insight_id, tiny_action, theme, opened_at, updated_at, closed_at)
  + RLS theo `auth.uid()` + index `(user_id, state)`.
- **A2** `lib/core/models/wr_episode.dart`: enum `HumanMoment` (6),
  `ExperienceState` (9), `ReflectionPattern` (6), class `ReflectionEpisode`.
- **A3** `lib/core/logic/wr_experience_state.dart` (pure Dart): bảng transition
  hợp lệ, hàm `canTransition`, `nextPattern(archetype, doneSteps)`.
- **A4** Repository + provider: `openEpisode`, `advance`, `saveDraftMeaning`,
  `confirmMeaning`, `commitAction`, `activeEpisodeProvider`.
- **A5** Unit test: mọi transition hợp lệ/bất hợp lệ, pause-resume, mapping
  archetype → pattern sequence.

### Sprint B — Luồng check-in tách màn
- **B1** `wr_energy_screen.dart` — 3 ô lớn, không có gì khác trên màn.
- **B2** `wr_moment_screen.dart` — 6 thẻ Human Moment 2×3, to rõ.
- **B3** `wr_reflect_screen.dart` — mỗi lần 1 câu hỏi theo Pattern hiện tại;
  nút "Tiếp" chỉ mở khi đã trả lời (chặn nhảy cóc).
- **B4** `wr_note_screen.dart` — màn ghi chú riêng (đọc ≠ ghi).
- **B5** `wr_meaning_screen.dart` — hệ thống đề xuất tóm lược (Proposed),
  người dùng sửa/xác nhận (Confirmed). Không tự động confirm.
- **B6** `wr_commit_screen.dart` — 1 bước nhỏ; xong → Integrated + ghi
  Career Memory + về Home.
- **B7** Viết lại `wr_home_screen.dart` ≤ 250 dòng: lời chào + ngày, một CTA
  duy nhất, thẻ "tiếp tục phản tư đang mở" (nếu có), một dòng ý nghĩa gần nhất.
  Bỏ khỏi Home: career snapshot, pattern card, story suggestion, insight block.
- **B8** Bỏ bước "hướng đi" khỏi UI; `mood` vẫn ghi ngầm suy ra từ energy
  (cột `wr_checkins.mood` là NOT NULL — không đổi schema).

### Sprint C — Hiểu mình: ghi nhận vs diễn giải
- **C1** Viết lại `wr_discover_screen.dart` thành danh sách dòng gọn; mỗi dòng
  bấm vào mở màn chi tiết riêng (`wr_pattern_detail_screen.dart`).
- **C2** Free: chỉ số ghi nhận (số phiên, tình huống lặp N lần, timeline).
  Bỏ "ĐIỀU BẠN ĐANG TÌM KIẾM" (diễn giải) khỏi tầng free.
- **C3** Premium: diễn giải sâu, chỉ hiện khi ≥ 5 lần lặp; dưới ngưỡng hiện
  "còn N lần nữa để hệ thống đọc được nguyên nhân".

### Sprint D — Phát triển & chứng nhận kỹ năng
- **D1** `maxActivePracticeThemes`: 3 → **2**.
- **D2** Migration `20260727000001_wr_skill_certifications.sql` + logic:
  một hành vi lặp ≥ 5 lần trong 30 ngày → cấp "kỹ năng mới", ghi Career Memory.
- **D3** `wr_growth_screen.dart` gọn lại: chỉ chủ đề đang thực hành + bước kế
  tiếp; danh sách chủ đề khác chuyển sang màn riêng.

### Sprint E — Gỡ bề mặt cũ & dọn giao diện
- **E1** Gỡ lối vào survey 49 câu, workshops, coaching, video report, roadmap,
  insights, `/understand` `/develop` `/journey` khỏi mọi màn còn dùng
  (giữ file + route, chỉ cắt liên kết).
  → **Đã sẵn ở trạng thái này**: rà toàn bộ `context.push` / `context.go` trong
  5 tab (Hôm nay · Hiểu mình · Phát triển · Hành trình · Tôi) và các màn con,
  không màn nào còn trỏ tới nhóm cũ. Các lối vào duy nhất nằm bên trong chính
  nhóm màn cũ, vốn đã bị bỏ khỏi shell từ trước. Không cần cắt thêm liên kết.
  Sau Sprint B, `/wr/situation` cũng thành route mồ côi (Home không còn gọi).
- **E2** Chuẩn khoảng trắng/typography tối giản dùng chung cho các màn flow.
  → Xong qua `WrFlowScaffold`: padding 24, một tiêu đề 26px, một khối, một nút
  52px; các ô chọn cao 92–104px.
- **E3** Cập nhật test, `flutter analyze`, `flutter test`, `flutter build apk`.

---

## 5. Rủi ro

| Rủi ro | Xử lý |
|---|---|
| 3 migration `20260725*` + 2 migration mới **chưa push** lên Supabase (backend dùng chung với web app) | Đưa vào mục bàn giao; app phải chịu được khi bảng chưa tồn tại (bắt lỗi, degrade mềm) |
| Test hiện có bám vào Home cũ | Viết lại test theo flow mới trong cùng sprint B |
| Ghi chú thô không được tự động thành Career Memory (WDA Inv.6) | Chỉ ghi Career Memory sau bước Meaning Confirmed |
| Gỡ lối vào survey có thể làm hụt luồng cũ | Giữ nguyên route để khôi phục bằng một dòng link |

## 6. Cổng nghiệm thu

- `flutter analyze` không có cảnh báo mới.
- Toàn bộ test xanh (bao gồm test mới cho state machine và flow check-in).
- `flutter build apk --debug` thành công.
- Đối chiếu 8 câu Experience Audit (WXS §7.8) cho luồng check-in mới.

---

## 7. Đối chiếu Experience Audit (WXS §7.8) — luồng phản tư mới

| # | Câu hỏi Audit | Trả lời |
|---|---|---|
| 1 | Experience bắt đầu từ Human Moment chưa? | Có — màn thứ hai của luồng là chọn 1 trong 6 Archetype; Episode không tồn tại nếu chưa chọn |
| 2 | Reflection có đủ Integrity (đủ chuỗi) không? | Có — Pattern sequence theo archetype, nút Tiếp bị khoá khi chưa trả lời, state machine chặn nhảy cóc |
| 3 | Meaning do Human tạo ra hay AI tạo ra? | Human — hệ thống chỉ nạp sẵn chính lời người dùng đã viết; Insight chỉ được tạo sau khi bấm xác nhận |
| 4 | Career Memory có được làm giàu không? | Có — mỗi Episode khép lại ghi một Career Memory Event kèm Meaning, tình huống, năng lượng |
| 5 | AI có xuất hiện đúng State không? | Chưa có AI runtime; câu hỏi dẫn dắt là bảng tĩnh theo (Archetype × Pattern), đúng vai trò hỏi chứ không kết luận |
| 6 | Journey Continuity có bị gián đoạn không? | Không — thoát giữa chừng thì Episode ngủ, Home mời "Tiếp tục" đúng màn của trạng thái |
| 7 | Experience có độc lập với Platform không? | Có — state machine và Pattern nằm ở `core/logic`, thuần Dart, không phụ thuộc Flutter |
| 8 | Có truy ngược được về WDA/HXA/WIA/WPA không? | Có — mỗi quyết định đều chú thích điều khoản tương ứng trong mã nguồn |

## 8. Việc còn lại

- **Migration chưa push**: `20260725000000/1/2` (từ đợt trước) và
  `20260727000000_wr_reflection_episodes` — backend dùng chung với web app,
  cần được duyệt trước khi push. Khi bảng chưa tồn tại, app degrade mềm:
  `wrOpenEpisodeProvider` nuốt lỗi và trả null, Home hiện lời mời bắt đầu.
- **Chưa chạy trên máy thật**: mới dừng ở `flutter build apk --debug`.
- **`Ghi tiêu chuẩn 6_1.mp3` / `10_1.mp3`** (77 MB và 122 MB) vẫn chưa
  transcribe được — phần nội dung trong hai file này chưa được đối chiếu.
- **Tab Hành trình** chưa đọc từ `wr_reflection_episodes`; vẫn dựa trên
  `wr_career_memory_events` như cũ. Hoạt động đúng nhưng chưa tận dụng Episode.
- **Sprint D3** (rút gọn màn Phát triển, tách danh sách chủ đề khác sang màn
  riêng) chưa làm — màn này vẫn còn dài hơn mức tối giản mong muốn.
