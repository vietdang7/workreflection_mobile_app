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

## 8. Sprint F — dọn nốt ba việc treo (2026-07-27, vòng 2)

### F1 · Migration
`supabase db push --include-all` chỉ còn **một** migration chưa lên:
`20260727000000_wr_reflection_episodes`. Ba migration `20260725000*` hoá ra
đã có trên remote từ trước — mục "3 migration chưa push" ở §5 là **sai**, nay
đã sửa. Remote còn ba version `20260725000003/4/5` do web app đẩy lên, đã thêm
stub rỗng tương ứng để `db push` không kẹt (giữ nguyên thủ thuật stub).

Lệnh push bị lớp phân quyền của phiên chặn — **chủ dự án cần tự chạy**:
```
supabase db push --include-all
```
Trước khi push, `--dry-run` xác nhận đúng một file, toàn bộ là DDL thêm mới
(create table if not exists · 2 index · 4 policy owner-only), không có lệnh
xoá hay sửa bảng nào của web app.

### F2 · Rút gọn màn Phát triển (D3)
Tab Phát triển nay chỉ còn: tiêu đề · thẻ "bước đang chờ bạn" · thẻ chủ đề
đang thực hành · danh sách bước hôm nay · ba dòng dẫn. Ba khối cũ tách thành
màn riêng: `/wr/growth/themes` · `/wr/growth/skills` · `/wr/growth/journey`.
Provider dùng chung chuyển sang `lib/features/wr/growth_providers.dart`;
`wr_growth_screen.dart` 1.356 → 999 dòng.

### F3 · Hành trình đọc từ Episode
`buildJourneyEntries()` trộn Episode đã Integrated với Career Memory event
theo thời gian, và **bỏ event `reflection_episode`** khi đã đọc được Episode
để không đếm hai lần. Mỗi dòng phản tư bấm được → `/wr/episode/:id`, màn đọc
dựng lại từng câu hỏi + câu trả lời theo đúng thứ tự Pattern. Khối "diễn biến
theo thời gian" (Premium) tách sang `/wr/journey/narrative`.

### F4 · Hai ràng buộc phát hiện khi rà lại tài liệu
| Nguồn | Ràng buộc bị bỏ sót | Đã xử lý |
|---|---|---|
| WXS §3.12 Inv.6 | Development Flow chỉ mở khi Pattern đủ mạnh — **≥ 2 Episode cùng chủ đề** | `developmentFlowUnlocked()`; thẻ gợi ý thực hành không hiện khi mới gặp một lần. Tự đánh giá SCA không thay được ngưỡng này |
| WPA Inv.4 · WXS Inv.7 | Reflection luôn mở lại được — **không có trạng thái khoá vĩnh viễn** | Nút "Hiểu lại chuyện này" trên màn chi tiết; `EpisodeFlowController.reopen()`; `saveDraftMeaning` cho phép Reactivated đi qua Exploring (hai chặng hợp lệ, không nhảy cóc) |

---

## 9. Đối chiếu toàn bộ Invariant của bộ tài liệu

| Nguồn | Invariant | Trạng thái |
|---|---|---|
| HXA 1 | Experience bắt đầu từ Human Moment | ✅ Episode không tồn tại nếu chưa chọn 1 trong 6 archetype |
| HXA 2 | Reflection không bắt đầu từ ứng dụng | ✅ Home chỉ mời, không nhắc ép |
| HXA 3 · WIA 1–10 | AI không phản tư thay, không Confirm, không sở hữu Object | ✅ (vacuous — chưa có AI runtime; câu hỏi là bảng tĩnh) |
| HXA 4 | Chưa xong Pattern thì không sang Pattern kế | ✅ nút Tiếp `null` khi chưa trả lời |
| HXA 5 | Người dùng không chọn Pattern theo tên | ✅ `nextPattern()` suy ra từ archetype |
| HXA 6 · WPA 8 | Journey không có điểm kết thúc | ✅ không có màn "hoàn tất hành trình" |
| HXA 7 · WXS 6 · WDA 5 | Career Memory chỉ lưu Reflection đã có Meaning | ✅ chỉ ghi sau Meaning Confirmed |
| HXA 8 · WPA 9 | Mọi màn phục vụ một Human Moment / Building Block | ✅ ghi chú điều khoản trong mã nguồn |
| WXS Obj.3 | Episode luôn sinh Meaning | ✅ Episode chưa có Meaning thì ngủ, không vào Hành trình |
| WXS Flow 6 | Development Flow cần ≥ 2 Episode cùng chủ đề | ✅ **F4** |
| WXS Runtime 4 | Career Memory chỉ cập nhật sau khi Meaning được xác nhận | ✅ `integrate()` sau `confirmMeaning()` |
| WXS Runtime 5 · Orch.7 | Pause · Resume · Recovery không mất tiến trình | ✅ state ghi xuống DB mỗi bước; Home resume đúng màn |
| WXS Surface 3 | Chỉ hiện thông tin phục vụ Meaning, không lấp đầy màn | ✅ Home 290 dòng · Hiểu mình/Hành trình chỉ liệt kê dòng |
| WXS Surface 7 | Surface độc lập Device/Platform | ✅ state machine + grammar thuần Dart |
| WXS 3 · WPA 1 | Meaning chỉ xác lập khi người dùng xác nhận | ✅ nút xác nhận là hành động người dùng |
| WXS 5 | Experience State là trạng thái nhận thức, không phải giao diện | ✅ 9 state persist ở DB, độc lập màn |
| WXS 6 · WPA 3 · 6 | Không nhảy cóc · Career Memory không bị ghi đè | ✅ `assertTransition` + chỉ insert, không update |
| WPA 4 · WXS 7 | Reflection luôn mở lại được | ✅ **F4** |
| WDA 6 | Chỉ Story đạt Level 2 mới vào Career Memory | ✅ ghi Meaning chứ không ghi ghi chú thô |
| WDA 9 | Choice là một bước trong Reflection Cycle | ⚠️ ghi `notice · meaning · insight · action`, **chưa ghi `choice`** riêng |
| WXS Obj.5 | Journey xoay quanh đúng một Development Theme | ⚠️ `wr_reflection_episodes.theme_id` có cột nhưng chưa được gán |
| WIA toàn chương | Ba tầng AI (Reflective · Contextual · Generative) | ❌ **chưa hiện thực** — toàn bộ WIA còn là thiết kế |

## 10. Việc còn lại

- **Migration `20260727000000` chưa push** — xem §8 F1. Chủ dự án chạy tay
  `supabase db push --include-all`. Khi bảng chưa tồn tại, app degrade mềm:
  `wrOpenEpisodeProvider` nuốt lỗi và trả null, Home hiện lời mời bắt đầu —
  nhưng **luồng phản tư không lưu được** cho tới khi push xong.
- **Chưa chạy trên máy thật**: mới dừng ở `flutter build apk --debug`.
- **`Ghi tiêu chuẩn 6_1.mp3` / `10_1.mp3`** (77 MB và 122 MB) vẫn chưa
  transcribe được — phần nội dung trong hai file này chưa được đối chiếu.
- **Bước `choice` của Reflection Cycle** (WDA Inv.9) chưa được ghi riêng vào
  `wr_reflection_steps`; hiện gộp vào `action`.
- **`theme_id` của Episode** chưa được gán, nên chưa gom Episode theo
  Development Theme (WXS Obj.5).
- **Tầng WIA (AI)** chưa hiện thực: câu hỏi dẫn dắt là bảng tĩnh
  `(Archetype × Pattern)`. Đúng vai trò "hỏi chứ không kết luận", nhưng chưa
  có Reflective / Contextual / Generative Intelligence như WIA mô tả.
