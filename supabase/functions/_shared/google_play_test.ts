// Test phần thuần của `google_play.ts` — không gọi mạng.
//
// Chạy: deno test supabase/functions/_shared/google_play_test.ts
//
// Phần đáng kiểm nhất là chuẩn hoá phản hồi của Google: cấu trúc lồng nhau,
// trường bool bị bỏ khi bằng false, nhiều dòng `lineItems`. Đọc sai một chỗ là
// cấp nhầm Premium (hoặc cắt nhầm của người đã trả tiền) mà không có lỗi nào
// nổi lên.

import { assert, assertEquals, assertThrows } from 'jsr:@std/assert@1';
import {
  GooglePlayConfigError,
  isPlayEntitled,
  normalizeSubscriptionV2,
  parseServiceAccount,
  playInactiveMessage,
  signServiceAccountJwt,
  SUBSCRIPTION_STATE,
} from './google_play.ts';

const YEARLY = 'app.workreflection.mobile.premium.yearly';
const MONTHLY = 'app.workreflection.mobile.premium.monthly';
const USER_ID = '6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b';

/// Phản hồi mẫu theo đúng hình dạng tài liệu `SubscriptionPurchaseV2`.
function sample(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    kind: 'androidpublisher#subscriptionPurchaseV2',
    startTime: '2026-10-01T08:00:00.000Z',
    regionCode: 'VN',
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    latestOrderId: 'GPA.3345-1234-5678-90123..2',
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
    externalAccountIdentifiers: { obfuscatedExternalAccountId: USER_ID },
    lineItems: [
      {
        productId: YEARLY,
        expiryTime: '2027-10-01T08:00:00.000Z',
        autoRenewingPlan: { autoRenewEnabled: true },
        offerDetails: { basePlanId: 'yearly' },
      },
    ],
    ...overrides,
  };
}

Deno.test('chuẩn hoá phản hồi đầy đủ', () => {
  const sub = normalizeSubscriptionV2(sample(), 'tok-1');
  assertEquals(sub.purchaseToken, 'tok-1');
  assertEquals(sub.productId, YEARLY);
  assertEquals(sub.expiryTimeMs, Date.parse('2027-10-01T08:00:00.000Z'));
  assertEquals(sub.startTimeMs, Date.parse('2026-10-01T08:00:00.000Z'));
  assertEquals(sub.subscriptionState, SUBSCRIPTION_STATE.ACTIVE);
  assertEquals(sub.autoRenewEnabled, true);
  assertEquals(sub.obfuscatedExternalAccountId, USER_ID);
  assertEquals(sub.latestOrderId, 'GPA.3345-1234-5678-90123..2');
  assertEquals(sub.linkedPurchaseToken, undefined);
  assertEquals(sub.acknowledgementState, 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED');
  assertEquals(sub.environment, 'Production');
});

Deno.test('nhiều dòng: lấy dòng hết hạn muộn nhất, product id theo dòng đó', () => {
  const sub = normalizeSubscriptionV2(
    sample({
      lineItems: [
        { productId: MONTHLY, expiryTime: '2026-11-01T00:00:00Z', autoRenewingPlan: {} },
        { productId: YEARLY, expiryTime: '2027-10-01T00:00:00Z', autoRenewingPlan: { autoRenewEnabled: true } },
        { productId: 'khac', expiryTime: '2026-10-15T00:00:00Z' },
      ],
    }),
    't',
  );
  assertEquals(sub.productId, YEARLY);
  assertEquals(sub.expiryTimeMs, Date.parse('2027-10-01T00:00:00Z'));
  assertEquals(sub.autoRenewEnabled, true);
});

Deno.test('autoRenewingPlan rỗng nghĩa là ĐÃ tắt gia hạn (proto3 bỏ trường false)', () => {
  const sub = normalizeSubscriptionV2(
    sample({ lineItems: [{ productId: YEARLY, expiryTime: '2027-01-01T00:00:00Z', autoRenewingPlan: {} }] }),
    't',
  );
  assertEquals(sub.autoRenewEnabled, false);
});

Deno.test('gói trả trước không tự gia hạn; không có dòng nào thì chưa biết', () => {
  const prepaid = normalizeSubscriptionV2(
    sample({ lineItems: [{ productId: MONTHLY, expiryTime: '2026-11-01T00:00:00Z', prepaidPlan: {} }] }),
    't',
  );
  assertEquals(prepaid.autoRenewEnabled, false);

  const empty = normalizeSubscriptionV2(sample({ lineItems: [] }), 't');
  assertEquals(empty.autoRenewEnabled, null);
  assertEquals(empty.productId, '');
  assertEquals(empty.expiryTimeMs, null);
});

Deno.test('dòng không có expiryTime (PENDING) vẫn đọc được product id', () => {
  const sub = normalizeSubscriptionV2(
    sample({
      subscriptionState: 'SUBSCRIPTION_STATE_PENDING',
      lineItems: [{ productId: MONTHLY, autoRenewingPlan: { autoRenewEnabled: true } }],
    }),
    't',
  );
  assertEquals(sub.productId, MONTHLY);
  assertEquals(sub.expiryTimeMs, null);
});

Deno.test('testPurchase có mặt (dù rỗng) → Sandbox', () => {
  assertEquals(normalizeSubscriptionV2(sample({ testPurchase: {} }), 't').environment, 'Sandbox');
  assertEquals(normalizeSubscriptionV2(sample(), 't').environment, 'Production');
});

Deno.test('đọc linkedPurchaseToken và thiếu externalAccountIdentifiers', () => {
  const sub = normalizeSubscriptionV2(
    sample({ linkedPurchaseToken: 'old-token', externalAccountIdentifiers: undefined }),
    'new-token',
  );
  assertEquals(sub.linkedPurchaseToken, 'old-token');
  assertEquals(sub.obfuscatedExternalAccountId, undefined);
});

Deno.test('thiếu subscriptionState → UNSPECIFIED, không được coi là đang hưởng', () => {
  const sub = normalizeSubscriptionV2(sample({ subscriptionState: undefined }), 't');
  assertEquals(sub.subscriptionState, 'SUBSCRIPTION_STATE_UNSPECIFIED');
  assertEquals(isPlayEntitled(sub.subscriptionState, sub.expiryTimeMs, 0), false);
});

Deno.test('isPlayEntitled: bảng trạng thái', () => {
  const now = Date.parse('2026-10-20T00:00:00Z');
  const future = now + 86_400_000;
  const past = now - 1;

  assert(isPlayEntitled(SUBSCRIPTION_STATE.ACTIVE, future, now));
  assert(isPlayEntitled(SUBSCRIPTION_STATE.IN_GRACE_PERIOD, future, now));
  // Đã tắt gia hạn nhưng còn hạn → vẫn hưởng tới hết kỳ đã trả tiền.
  assert(isPlayEntitled(SUBSCRIPTION_STATE.CANCELED, future, now));

  assert(!isPlayEntitled(SUBSCRIPTION_STATE.CANCELED, past, now));
  assert(!isPlayEntitled(SUBSCRIPTION_STATE.ACTIVE, past, now));
  assert(!isPlayEntitled(SUBSCRIPTION_STATE.ACTIVE, null, now));
  assert(!isPlayEntitled(SUBSCRIPTION_STATE.ACTIVE, now, now));
  for (const s of [
    SUBSCRIPTION_STATE.ON_HOLD,
    SUBSCRIPTION_STATE.PAUSED,
    SUBSCRIPTION_STATE.EXPIRED,
    SUBSCRIPTION_STATE.PENDING,
    SUBSCRIPTION_STATE.PENDING_PURCHASE_CANCELED,
  ]) {
    assert(!isPlayEntitled(s, future, now), s);
  }
});

Deno.test('playInactiveMessage: mỗi trạng thái một câu tiếng Việt, không mã lỗi', () => {
  const states = [
    SUBSCRIPTION_STATE.PENDING,
    SUBSCRIPTION_STATE.ON_HOLD,
    SUBSCRIPTION_STATE.PAUSED,
    SUBSCRIPTION_STATE.PENDING_PURCHASE_CANCELED,
    SUBSCRIPTION_STATE.EXPIRED,
  ];
  const messages = states.map(playInactiveMessage);
  assertEquals(new Set(messages).size, states.length);
  for (const m of messages) {
    assert(!m.includes('SUBSCRIPTION_STATE'), m);
  }
  assert(playInactiveMessage(SUBSCRIPTION_STATE.PENDING).includes('chờ thanh toán'));
  assertEquals(playInactiveMessage(SUBSCRIPTION_STATE.EXPIRED), 'Gói này đã hết hạn.');
});

Deno.test('parseServiceAccount: thiếu / hỏng là lỗi cấu hình', () => {
  assertThrows(() => parseServiceAccount(undefined), GooglePlayConfigError);
  assertThrows(() => parseServiceAccount('  '), GooglePlayConfigError);
  assertThrows(() => parseServiceAccount('{not json'), GooglePlayConfigError);
  assertThrows(() => parseServiceAccount('{"client_email":"a@b"}'), GooglePlayConfigError);

  const ok = parseServiceAccount(
    JSON.stringify({ client_email: 'sa@x.iam.gserviceaccount.com', private_key: 'PEM' }),
  );
  assertEquals(ok.tokenUri, 'https://oauth2.googleapis.com/token');
});

Deno.test('JWT ký RS256 kiểm lại được bằng khoá công khai', async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
  let bin = '';
  for (const b of der) bin += String.fromCharCode(b);
  // Dạng `\n` hai ký tự như khi secret bị dán qua dashboard.
  const pem = `-----BEGIN PRIVATE KEY-----\\n${btoa(bin)}\\n-----END PRIVATE KEY-----\\n`;

  const jwt = await signServiceAccountJwt(
    { clientEmail: 'sa@x.iam.gserviceaccount.com', privateKeyPem: pem, tokenUri: 'https://oauth2.googleapis.com/token' },
    1_700_000_000,
  );
  const [h, c, s] = jwt.split('.');
  const dec = (p: string) => {
    const b = atob(p.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (p.length % 4)) % 4));
    return Uint8Array.from(b, (ch) => ch.charCodeAt(0));
  };
  const header = JSON.parse(new TextDecoder().decode(dec(h)));
  const claims = JSON.parse(new TextDecoder().decode(dec(c)));
  assertEquals(header.alg, 'RS256');
  assertEquals(claims.iss, 'sa@x.iam.gserviceaccount.com');
  assertEquals(claims.scope, 'https://www.googleapis.com/auth/androidpublisher');
  assertEquals(claims.exp - claims.iat, 3600);

  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    pair.publicKey,
    dec(s),
    new TextEncoder().encode(`${h}.${c}`),
  );
  assert(valid);
});

Deno.test('private_key hỏng là lỗi cấu hình', async () => {
  let caught: unknown;
  try {
    await signServiceAccountJwt(
      { clientEmail: 'a', privateKeyPem: '-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----', tokenUri: 'u' },
      0,
    );
  } catch (e) {
    caught = e;
  }
  assert(caught instanceof GooglePlayConfigError);
});
