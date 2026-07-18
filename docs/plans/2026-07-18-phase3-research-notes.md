# Phase 3 Research Notes — Workshop Survey Schema, Coaching Claim, RLS

**Date:** 2026-07-18  
**Researcher:** Task 0 subagent  
**Sources:** Web repo `/home/duythong/Documents/DuyThong/workreflection` + live schema dump `/tmp/p3_schema2.sql`

---

## 1a. Post-Workshop Survey Schema

### Tables involved

**`cc_workshop_question_sets`** (global question-set catalogue):
```
id               uuid PK
name             text NOT NULL
description      text | null
question_ids     uuid[]          -- ordered list of question IDs from cc_questions
question_count   int DEFAULT 0
is_active        bool | null
created_at       timestamptz | null
created_by       uuid | null
updated_at       timestamptz | null
```

**`cc_workshop_question_set_assignments`** (assignment of a question-set to a workshop):
```
id               uuid PK
workshop_id      uuid NOT NULL  FK → cc_workshops.id
question_set_id  uuid NOT NULL  FK → cc_workshop_question_sets.id
is_active        bool | null
assigned_at      timestamptz | null
assigned_by      uuid | null
```
One workshop can have multiple assignments; only `is_active = true` assignments are used.

**`cc_workshop_surveys`** (one per user per workshop per question-set):
```
id               uuid PK
user_id          uuid NOT NULL   (live schema uuid; RLS: = auth.uid())
workshop_id      uuid NOT NULL   FK → cc_workshops.id
question_set_id  uuid NOT NULL   FK → cc_workshop_question_sets.id
status           text DEFAULT 'in_progress'   CHECK IN ('in_progress','completed')
started_at       timestamptz DEFAULT now()
completed_at     timestamptz | null
created_at       timestamptz | null
```

**`cc_workshop_responses`** (one row per question per survey):
```
id               uuid PK
survey_id        uuid NOT NULL   FK → cc_workshop_surveys.id
question_id      text NOT NULL   (UUID stored as text — ID from cc_questions)
answer_value     int NOT NULL
created_at       timestamptz | null
```

### Question flow

1. Admin assigns a `cc_workshop_question_sets` to a workshop via `cc_workshop_question_set_assignments`.
2. `cc_workshop_question_sets.question_ids` is a UUID array pointing to rows in `cc_questions`.
3. On survey start, web fetches the active assignment, reads `question_ids`, queries `cc_questions` for those ids (with `is_active = true`), sorts by insertion order from `question_ids`.
4. Questions reuse `cc_questions` (same table as Phase 2 survey) — columns used: `id`, `layer`, `sub_component`, `question_text`, `question_order`, `scale_type`.
5. Scale types used: `LIKERT_5`, `ESI_5`, `ENPS_10` (same as Phase 2).
6. Likert options fetched from `cc_likert_options` by scale_type.

### Survey submission flow (web: `src/pages/workshop/Survey.tsx`)

**Step 1 — Create survey record on start:**
```typescript
// web: src/pages/workshop/Survey.tsx lines 142-159
await supabase.from("cc_workshop_surveys").insert({
  user_id: user.id,            // uuid
  workshop_id: workshopId,     // uuid string
  question_set_id: questionSetId, // uuid string
  status: "in_progress"
}).select("id").single();
```

**Step 2 — On submit, insert all responses then mark complete:**
```typescript
// web: src/pages/workshop/Survey.tsx lines 168-184
// Insert responses
const responseRows = Object.entries(answers).map(([questionId, value]) => ({
  survey_id: surveyId,     // uuid
  question_id: questionId, // text (uuid)
  answer_value: value      // int
}));
await supabase.from("cc_workshop_responses").insert(responseRows);

// Mark completed
await supabase.from("cc_workshop_surveys").update({
  status: "completed",
  completed_at: new Date().toISOString()
}).eq("id", surveyId);
```

**Check if already submitted:**
```typescript
// web: src/pages/workshop/Survey.tsx lines 95-103
await supabase.from("cc_workshop_surveys")
  .select("id, status")
  .eq("user_id", user.id)
  .eq("question_set_id", questionSetId)
  .eq("workshop_id", workshopId)
  .eq("status", "completed")
  .maybeSingle();
```

**Route:** `/workshop/survey/:workshopId/:questionSetId`

### How mobile gets the question_set_id

Mobile must first query `cc_workshop_question_set_assignments` to get the active `question_set_id` for a given `workshop_id`:
```sql
SELECT question_set_id FROM cc_workshop_question_set_assignments
WHERE workshop_id = $workshopId AND is_active = true
LIMIT 1;
```
Then pass `question_set_id` when creating the survey and when checking for existing survey.

---

## 1b. Free Coaching Package Claim

**Web source:** `src/pages/services/Coaching.tsx` lines 161-200

### Step 1 — Insert cc_orders (client-side for free packages):

```typescript
// web: src/pages/services/Coaching.tsx lines 166-175
const { data: orderData, error: orderError } = await supabase
  .from("cc_orders")
  .insert({
    order_code: "TEMP",          // temporary; replaced after insert
    user_id: user.id,            // string
    product_type: "coaching",
    product_id: plan.id,         // uuid of cc_coaching_packages
    original_amount: 0,
    final_amount: 0,
    currency: plan.rawCurrency || "VND",
    status: "paid"
  })
  .select("id")
  .single();
```

### Step 2 — Update order_code:

```typescript
// web: src/pages/services/Coaching.tsx lines 177-179
const orderCode = generateOrderCode(orderData.id);
await supabase.from("cc_orders").update({ order_code: orderCode }).eq("id", orderData.id);
```

`generateOrderCode` creates a short code from the order UUID (utility in `src/lib/order-utils.ts`).

### Step 3 — Navigate to PaymentSuccess, which calls `complete_payment` RPC:

```typescript
navigate("/payment/success", { state: successState });
// PaymentSuccess.tsx calls: await supabase.rpc("complete_payment", { p_order_id: successState.orderId });
```

### Step 4 — `complete_payment` RPC creates N coaching bookings (server-side):

```sql
-- supabase/migrations/20260520000000_complete_payment_server_side_fulfillment.sql lines 115-119
IF NOT EXISTS (SELECT 1 FROM cc_coaching_bookings WHERE order_id = p_order_id) THEN
  INSERT INTO cc_coaching_bookings (user_id, package_id, order_id, status, session_number, total_sessions)
  SELECT v_user_id, v_product_id, p_order_id, 'pending', gs, v_sessions_count
  FROM generate_series(1, v_sessions_count) gs;
END IF;
```

So for a package with `sessions_count = 3`, exactly 3 booking rows are created with `session_number = 1, 2, 3` and `total_sessions = 3`, all with `status = 'pending'`, no `coach_id`, no `scheduled_at`.

### cc_coaching_bookings insert shape (via RPC, not client-side):

| Column          | Value                               |
|-----------------|-------------------------------------|
| user_id         | order.user_id (text)                |
| package_id      | order.product_id (uuid)             |
| order_id        | p_order_id (uuid)                   |
| status          | `'pending'`                         |
| session_number  | 1..sessions_count (int)             |
| total_sessions  | sessions_count (int)                |

**Important for mobile:** The mobile app should insert the `cc_orders` row, then call `complete_payment` RPC. The RPC creates the bookings. Mobile should NOT insert bookings directly.

### cc_orders insert shape (mobile implementation):

```dart
await supabase.from('cc_orders').insert({
  'order_code': 'TEMP',
  'user_id': uid,
  'product_type': 'coaching',
  'product_id': pkg.id,
  'original_amount': 0,
  'final_amount': 0,
  'currency': pkg.currency,
  'status': 'paid',
});
// Then update order_code, then call complete_payment RPC
```

---

## 1c. Free Workshop Registration

**Web source:** `src/pages/services/WorkshopDetail.tsx` lines 239-280

### Insert payload:

```typescript
// web: src/pages/services/WorkshopDetail.tsx lines 259-265
await supabase.from("cc_workshop_registrations").insert({
  user_id: user.id,           // string
  workshop_id: workshop.id,   // uuid string
  status: "registered"
});
```

Only 3 fields. No `payment_status`, no `order_id`, no `quantity` — those get defaults (`payment_status = 'pending'`, `quantity = 1`).

### `current_participants` increment — YES, client-side:

```typescript
// web: src/pages/services/WorkshopDetail.tsx lines 273-278
await supabase.from("cc_workshops").update({
  current_participants: (workshop.current_participants || 0) + 1
}).eq("id", workshop.id);
```

**The web increments `current_participants` client-side.** The RPC `complete_payment` also increments it for paid workshop registrations. For free registrations, only client-side increment happens.

**Mobile must also increment `current_participants` client-side** when registering free workshops, to match web behavior.

### Idempotency guard (web uses unique constraint + race-safe re-query):

Migration `20260604000000_workshop_registration_dedupe.sql` adds a partial UNIQUE index on `(user_id, workshop_id) WHERE status <> 'cancelled' AND org_id IS NULL`. The web catches `23505` (unique violation) and treats it as success (already registered). Mobile should do the same.

---

## 1d. Check-In Update

**Web source:** `src/pages/workshop/CheckIn.tsx`

### Check-in mutation (lines 86-94):

```typescript
await supabase.from("cc_workshop_registrations").update({
  checked_in_at: new Date().toISOString(),  // timestamptz
  attended: true,                            // bool
  attended_at: new Date().toISOString()     // timestamptz
}).eq("id", registration.id);
```

Three fields updated: `checked_in_at`, `attended = true`, `attended_at`.

**Note:** `status` is NOT updated to `'attended'` in the web check-in flow. The design doc mentions `status='attended'` but web source does NOT update status. Mobile should match web: update only `checked_in_at`, `attended`, `attended_at`.

### Image consent update (lines 116-124):

```typescript
await supabase.from("cc_workshop_registrations").update({
  image_consent: consent,                        // bool
  image_consent_at: new Date().toISOString()    // timestamptz
}).eq("id", registration.id);
```

Consent modal is shown only if `registration.image_consent === null || undefined` (i.e., not previously answered). Both accept and decline are recorded.

### Time-window logic (lines 144-152):

```typescript
// web: src/pages/workshop/CheckIn.tsx lines 144-152
const isWorkshopNow = () => {
  if (!workshop?.date) return false;
  const workshopDate = new Date(workshop.date);  // uses 'date' column (text), NOT starts_at
  const now = new Date();
  const twoHoursBefore = new Date(workshopDate);
  twoHoursBefore.setHours(twoHoursBefore.getHours() - 2);
  const oneHourAfter = new Date(workshopDate);
  oneHourAfter.setHours(oneHourAfter.getHours() + 4);  // variable name misleading; it's +4h
  return now >= twoHoursBefore && now <= oneHourAfter;
};
```

**Web uses the `date` column (a text field), not `starts_at`.** The mobile design doc says use `starts_at`, which makes more sense semantically. However, the check-in logic in `checkin_rules.dart` should use `starts_at` if present, fall back to `date` if not. Window: `starts_at − 2h` to `starts_at + 4h` (inclusive).

---

## 1e. Workshop Resources & Attachments

### `cc_workshop_attachments` (per-workshop, stored files):

```
id           uuid PK
workshop_id  uuid NOT NULL  FK → cc_workshops.id
file_name    text NOT NULL
file_url     text NOT NULL        (direct download/view URL)
file_type    text | null          e.g. "application/pdf", "image/jpeg", "video/url"
file_size    bigint | null        bytes
category     text DEFAULT ''      'document' | 'image' | 'video'
sort_order   int | null
created_at   timestamptz | null
```

Usage in web: Documents shown only to users with `hasPaidAccess` (registered + price=0 OR payment_status='paid'). Images and videos shown in gallery carousel to everyone.

**Visibility rule:** `category='document'` → registered + paid access required. `category='image'/'video'` → publicly visible in carousel.

### `cc_workshop_resources` (global resource library, NO workshop_id):

```
id             uuid PK
title          text NOT NULL
description    text | null
category       text | null           -- admin-defined category label
resource_type  text NOT NULL         CHECK IN ('video','link','document','file')
file_url       text | null
external_url   text | null
thumbnail_url  text | null
file_size      bigint | null
file_type      text | null
duration_minutes int | null
tags           text[] | null
status         text NOT NULL DEFAULT 'active'   CHECK IN ('active','draft','archived')
view_count     int DEFAULT 0
download_count int DEFAULT 0
created_by     uuid | null
created_at     timestamptz | null
updated_at     timestamptz | null
```

**Important:** `cc_workshop_resources` has NO `workshop_id` column. It is a global resource library, not linked to a specific workshop. The web detail page does NOT show `cc_workshop_resources` per workshop — only `cc_workshop_attachments` (which has `workshop_id`).

**For mobile implementation:** Use `cc_workshop_attachments` only (queried by `workshop_id`). `cc_workshop_resources` is admin-only global library — do not expose it per-workshop.

---

## 2. RLS Verification

Source: Live schema dump `/tmp/p3_schema2.sql` (authoritative).

### `cc_workshops`

| Operation | Policy | Verdict |
|-----------|--------|---------|
| SELECT (active, org_id IS NULL) | `cc_workshops_select_public`: `is_active=true AND status='active'` OR admin/coord OR org admin | **CAN** — `is_active=true, status='active'` passes for regular user |
| SELECT all (incl. completed) | `cc_workshops_select`: `USING (true)` — another policy grants all authenticated users SELECT all | **CAN** (all workshops visible to authenticated users via `cc_workshops_select`) |

Note: There are multiple SELECT policies (`cc_workshops_select`, `cc_workshops_select_public`, `cc_workshops_select_v2`). Supabase ORs them — most permissive wins. `cc_workshops_select` has `USING (true)`, so all authenticated users can see all workshops.

**Important for mobile:** Filter org workshops (`org_id IS NULL`) client-side to exclude enterprise workshops.

### `cc_workshop_registrations`

| Operation | Policy (live schema line) | Verdict |
|-----------|--------------------------|---------|
| SELECT own | `cc_workshop_registrations_select`: `user_id = auth.uid()` | **CAN** |
| INSERT own | `cc_workshop_registrations_insert`: `user_id = auth.uid()` | **CAN** |
| UPDATE own (checked_in_at, image_consent) | `cc_workshop_registrations_update`: `user_id = auth.uid()` | **CAN** |

### `cc_workshop_attachments`

| Operation | Policy | Verdict |
|-----------|--------|---------|
| SELECT | "Public can view workshop attachments": `EXISTS (cc_workshops where is_active=true)` — no auth required | **CAN** (even anonymous) |

Note: The policy has no `hasPaidAccess` gate at DB level. The web enforces document-locking in the UI only, not RLS. Mobile should mirror web UI behavior: show document list to all registered users, but display locked state if not paid (for paid workshops). For free workshops, registered = access.

### `cc_workshop_resources`

| Operation | Policy | Verdict |
|-----------|--------|---------|
| SELECT (status='active') | "Public can view active workshop resources": `status = 'active'` | **CAN** (no auth required) |

But mobile should NOT query this table per-workshop since it has no `workshop_id`.

### `cc_workshop_question_set_assignments`

| Operation | Policy | Verdict |
|-----------|--------|---------|
| SELECT (is_active=true) | "Anyone can view active assignments": `is_active = true` TO authenticated | **CAN** |

### `cc_workshop_question_sets`

| Operation | Policy | Verdict |
|-----------|--------|---------|
| SELECT (is_active=true) | "Anyone can view active question sets": `is_active = true` TO authenticated | **CAN** |

### `cc_workshop_surveys`

| Operation | Policy (live schema lines 4920/4988/5006) | Verdict |
|-----------|------------------------------------------|---------|
| SELECT own | "Users can view own surveys": `user_id = auth.uid()` TO authenticated | **CAN** |
| INSERT own | "Users can create own surveys": `user_id = auth.uid()` TO authenticated | **CAN** |
| UPDATE own (status, completed_at) | "Users can update own surveys": `user_id = auth.uid()` TO authenticated | **CAN** |

### `cc_workshop_responses`

| Operation | Policy (live schema lines 4914/5000) | Verdict |
|-----------|--------------------------------------|---------|
| SELECT own | "Users can view own responses": EXISTS(cc_workshop_surveys where survey_id=survey_id AND user_id=auth.uid()) | **CAN** |
| INSERT own | "Users can create own responses": EXISTS(cc_workshop_surveys where survey_id and user_id=auth.uid()) | **CAN** |

### `cc_coaching_packages`

| Operation | Policy | Verdict |
|-----------|--------|---------|
| SELECT | `cc_coaching_packages_select`: `USING (true)` TO authenticated | **CAN** |
| SELECT (anon) | `cc_coaching_packages_select_anon`: `is_active = true` TO anon | **CAN** |

### `cc_coaches`

| Operation | Policy | Verdict |
|-----------|--------|---------|
| SELECT | "Anyone can view active coaches": `is_active = true` (no TO clause = all roles) | **CAN** |

### `cc_coaching_bookings`

| Operation | Policy (live schema) | Verdict |
|-----------|---------------------|---------|
| SELECT own | "Users can view own bookings": `user_id = auth.uid()::text` | **CAN** |
| INSERT own | "Users can insert own bookings": `user_id = auth.uid()::text` | **CAN** (but mobile should NOT insert directly — use complete_payment RPC) |
| UPDATE own | "Users can update own bookings": `user_id = auth.uid()::text` | **CAN** (but mobile should not update bookings) |

Note: `cc_coaching_bookings_insert` (from migration 001) is admin-only, but the newer "Users can insert own bookings" policy overrides it (Supabase ORs permissive policies). Bookings are created via `complete_payment` RPC (SECURITY DEFINER), which bypasses RLS anyway.

### `cc_orders`

| Operation | Policy (live schema line 5400/5408) | Verdict |
|-----------|-------------------------------------|---------|
| SELECT all | `cc_orders_select`: `USING (true)` TO authenticated | **CAN** (sees ALL orders — not filtered to own) |
| INSERT own | `cc_orders_insert`: `user_id = auth.uid()::text` | **CAN** |
| UPDATE own | `cc_orders_update`: `user_id = auth.uid()::text OR is_cc_admin()` | **CAN** (own only) |

⚠️ **NOTE:** `cc_orders_select` allows all authenticated users to see ALL orders (not filtered to own). This is a pre-existing gap in the web app that the mobile app must NOT expose by displaying other users' orders. Always filter by `user_id = uid` when querying orders.

### Summary — All Required Capabilities

| Capability | Verdict |
|------------|---------|
| SELECT cc_workshops (active, org_id=null) | ✅ CAN |
| SELECT cc_workshop_attachments | ✅ CAN |
| SELECT cc_coaching_packages | ✅ CAN |
| SELECT cc_coaches | ✅ CAN |
| SELECT own cc_workshop_registrations | ✅ CAN |
| SELECT own cc_coaching_bookings | ✅ CAN |
| SELECT own cc_orders | ✅ CAN (filter by user_id!) |
| SELECT active cc_workshop_question_set_assignments | ✅ CAN |
| SELECT active cc_workshop_question_sets | ✅ CAN |
| INSERT own cc_workshop_registrations | ✅ CAN |
| INSERT cc_orders (own) | ✅ CAN |
| INSERT cc_coaching_bookings (via RPC) | ✅ CAN (RPC is SECURITY DEFINER) |
| INSERT cc_workshop_surveys (own) | ✅ CAN |
| INSERT cc_workshop_responses (own survey) | ✅ CAN |
| UPDATE own cc_workshop_registrations (checked_in_at, attended, image_consent) | ✅ CAN |
| UPDATE own cc_workshop_surveys (status, completed_at) | ✅ CAN |

**No RLS blockers found. All required operations are permitted.**

---

## 3. Implications for Mobile Implementation

### WorkshopRepository method signatures (final)

```dart
abstract class WorkshopRepository {
  Future<List<WorkshopDetail>> getActiveWorkshops();
  // Query: is_active=true, status='active', org_id IS NULL, order date asc

  Future<WorkshopDetail?> getWorkshop(String id);
  
  Future<WorkshopRegistration?> getMyRegistration(String workshopId);
  // .eq('user_id', uid).eq('workshop_id', workshopId).neq('status','cancelled').maybeSingle()

  Future<List<WorkshopRegistration>> getMyRegistrations();

  Future<void> registerFree(String workshopId);
  // 1. INSERT cc_workshop_registrations {user_id, workshop_id, status:'registered'}
  // 2. UPDATE cc_workshops SET current_participants = current + 1
  // 3. Catch 23505 → treat as already registered (idempotent)

  Future<WorkshopDetail?> getWorkshopByCheckinCode(String code);
  // .eq('checkin_code', code.toUpperCase()).single()

  Future<void> checkIn(String registrationId);
  // UPDATE cc_workshop_registrations SET
  //   checked_in_at = now(), attended = true, attended_at = now()
  // WHERE id = registrationId
  // Note: do NOT update status to 'attended' (web doesn't)

  Future<void> setImageConsent(String registrationId, bool consent);
  // UPDATE cc_workshop_registrations SET
  //   image_consent = consent, image_consent_at = now()
  // WHERE id = registrationId

  Future<List<WorkshopAttachment>> getAttachments(String workshopId);
  // FROM cc_workshop_attachments WHERE workshop_id = workshopId
  // ORDER BY sort_order ASC
  // All categories returned; UI filters by category

  // Post-workshop survey
  Future<bool> hasSubmittedWorkshopSurvey(String workshopId);
  // Requires: first get active question_set_id for the workshop
  // Then: SELECT FROM cc_workshop_surveys WHERE user_id=uid AND workshop_id=workshopId
  //        AND question_set_id=questionSetId AND status='completed'

  Future<String?> getActiveQuestionSetId(String workshopId);
  // SELECT question_set_id FROM cc_workshop_question_set_assignments
  // WHERE workshop_id=workshopId AND is_active=true LIMIT 1

  Future<void> submitWorkshopSurvey(
    String workshopId,
    String questionSetId,
    Map<String, int> answers, // {questionId: answerValue}
  );
  // 1. INSERT cc_workshop_surveys {user_id, workshop_id, question_set_id, status:'in_progress'}
  //    → get surveyId
  // 2. INSERT cc_workshop_responses (bulk) {survey_id, question_id, answer_value}
  // 3. UPDATE cc_workshop_surveys SET status='completed', completed_at=now() WHERE id=surveyId
}
```

### WorkshopAttachment model (replaces WorkshopResource in plan):

```dart
class WorkshopAttachment {
  final String id;
  final String workshopId;
  final String fileName;
  final String fileUrl;
  final String? fileType;   // 'application/pdf', 'image/jpeg', 'video/url', etc.
  final int? fileSizeBytes;
  final String category;    // 'document' | 'image' | 'video'
  final int? sortOrder;
}
```

Note: The design doc calls this `WorkshopResource` but the actual table is `cc_workshop_attachments`. Rename to `WorkshopAttachment` for clarity. `cc_workshop_resources` is unrelated.

### claimFreePackage insert shape (CoachingRepository):

```dart
Future<void> claimFreePackage(CoachingPackage pkg) async {
  // Step 1: Insert order
  final orderResult = await supabase.from('cc_orders').insert({
    'order_code': 'TEMP',
    'user_id': uid,
    'product_type': 'coaching',
    'product_id': pkg.id,
    'original_amount': 0,
    'final_amount': 0,
    'currency': pkg.currency,
    'status': 'paid',
  }).select('id').single();
  
  final orderId = orderResult['id'] as String;
  
  // Step 2: Generate and update order_code (mirror web generateOrderCode)
  // Use first 8 chars of orderId uppercase
  final orderCode = 'CC${orderId.replaceAll('-','').substring(0,8).toUpperCase()}';
  await supabase.from('cc_orders').update({'order_code': orderCode}).eq('id', orderId);
  
  // Step 3: Call complete_payment RPC (SECURITY DEFINER) — creates N booking rows
  await supabase.rpc('complete_payment', params: {'p_order_id': orderId});
  // RPC inserts: cc_coaching_bookings {user_id, package_id, order_id, status:'pending',
  //              session_number: 1..N, total_sessions: N}
}
```

### registerFree shape:

```dart
// Step 1: Race-safe duplicate check
final existing = await supabase
  .from('cc_workshop_registrations')
  .select('id')
  .eq('user_id', uid)
  .eq('workshop_id', workshopId)
  .neq('status', 'cancelled')
  .limit(1)
  .maybeSingle();
if (existing != null) return; // already registered

// Step 2: Insert
try {
  await supabase.from('cc_workshop_registrations').insert({
    'user_id': uid,
    'workshop_id': workshopId,
    'status': 'registered',
  });
} on PostgrestException catch (e) {
  if (e.code == '23505') return; // concurrent insert, treat as success
  rethrow;
}

// Step 3: Increment participant count (match web behavior)
await supabase.from('cc_workshops').update({
  'current_participants': (currentParticipants ?? 0) + 1,
}).eq('id', workshopId);
```

### checkIn update shape:

```dart
await supabase.from('cc_workshop_registrations').update({
  'checked_in_at': DateTime.now().toIso8601String(),
  'attended': true,
  'attended_at': DateTime.now().toIso8601String(),
}).eq('id', registrationId);
// Note: do NOT update 'status' — web doesn't update status on check-in
```

### setImageConsent update shape:

```dart
await supabase.from('cc_workshop_registrations').update({
  'image_consent': consent,
  'image_consent_at': DateTime.now().toIso8601String(),
}).eq('id', registrationId);
```

### Check-in time window (for checkin_rules.dart):

```dart
// Source: web CheckIn.tsx lines 144-152
// Web uses workshop.date (text field), but mobile should use starts_at if available
// Window: starts_at - 2h to starts_at + 4h (inclusive)
CheckinWindow checkinWindow(DateTime? startsAt, DateTime now) {
  if (startsAt == null) return CheckinWindow.unknown; // treat as open
  final openTime = startsAt.subtract(const Duration(hours: 2));
  final closeTime = startsAt.add(const Duration(hours: 4));
  if (now.isBefore(openTime)) return CheckinWindow.tooEarly;
  if (now.isAfter(closeTime)) return CheckinWindow.closed;
  return CheckinWindow.open;
}
```

---

## 4. Key Deviations from Design Doc

1. **`WorkshopResource` model name**: Actual table is `cc_workshop_attachments` (has `workshop_id`). `cc_workshop_resources` is a global library with no `workshop_id`. Model should be `WorkshopAttachment`, not `WorkshopResource`.

2. **Check-in does NOT update `status='attended'`**: Web only updates `checked_in_at`, `attended=true`, `attended_at`. The plan says `status='attended'` but web source does not do this. Follow web behavior.

3. **`current_participants` IS incremented client-side**: Web does this in the free registration mutation. Mobile must do the same.

4. **Survey needs `question_set_id`**: Mobile must first fetch active `question_set_id` via `cc_workshop_question_set_assignments` before showing or submitting the survey.

5. **`cc_orders_select` is not row-scoped**: Policy uses `USING (true)`. Always filter by `user_id = uid` in queries.

6. **`cc_workshop_surveys.user_id` is `uuid` in DB** (not `text` like `cc_coaching_bookings.user_id`). The Supabase client handles this transparently.

7. **Coaching bookings are created by `complete_payment` RPC**, not by client insert. Mobile `claimFreePackage` must call the RPC.

8. **Web check-in uses `workshop.date`** (text column), but design doc uses `starts_at`. Mobile should prefer `starts_at` (timestamptz, available on WorkshopDetail), falling back to parsing `date` if `starts_at` is null.
