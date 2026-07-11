// test/rules/rules_2b_test.js
//
// RFC-002.3 Phase 2B — Full compliance matrix (~215 cases)
//
// §A  Sync collections (5 collections × ~35 cases each)
// §B  users/{uid} profile (C2, m3)
// §C  favorites/{docId} (m4)
// §D  entitlements/{uid} (m1)
// §E  ai_usage/{uid} (m1)
// §F  Legacy paths (workout_history, premium_grants)
// §G  Default-deny paths
// §H  Cross-cutting edge cases (M1, schemaVersion boundary)

'use strict';

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} = require('firebase/firestore');
const { readFileSync } = require('fs');
const path = require('path');

const PROJECT_ID = 'lifton-rules-test';
const RULES_PATH = path.resolve(__dirname, '../../firestore.rules');
const ALICE = 'alice_uid_001';
const BOB   = 'bob_uid_002';

let testEnv;
let aliceDb, bobDb, anonDb;

// Valid sync payload — satisfies all validSyncWrite() conditions.
function syncPayload(overrides) {
  return Object.assign({
    exercise: 'bench_press',
    date: '2024-01-15T00:00:00.000Z',
    weight: 80.0,
    reps: 10,
    minutes: 0,
    schemaVersion: 1,
    writerDeviceId: 'dev_test_001',
    updatedAt: serverTimestamp(),
  }, overrides || {});
}

// Pre-seeded doc IDs that will exist at test start.
const SEED_LOG         = 'seed_log_2b';
const SEED_PLAN        = 'seed_plan_2b';
const SEED_INSTANCE    = 'seed_instance_2b';
const SEED_MEASUREMENT = 'seed_meas_2b';
const SEED_META        = 'seed_meta_2b';
const SEED_LEGACY_LOG  = 'seed_legacy_log_2b';  // workout_history doc

// Pre-seeded doc that has NO schemaVersion (simulates pre-RFC document) —
// used for M1 null-safe tests.
const PRE_RFC_LOG = 'pre_rfc_log_2b';

before(async function () {
  this.timeout(60000);

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
      port: 8080,
      host: '127.0.0.1',
    },
  });

  aliceDb = testEnv.authenticatedContext(ALICE).firestore();
  bobDb   = testEnv.authenticatedContext(BOB).firestore();
  anonDb  = testEnv.unauthenticatedContext().firestore();

  await testEnv.clearFirestore();

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    // Sync collection seeds (schemaVersion: 2 so we can test increase/decrease)
    const syncSeed = {
      exercise: 'squat',
      date: '2024-03-10T00:00:00.000Z',
      weight: 100.0,
      reps: 5,
      minutes: 0,
      schemaVersion: 2,
      writerDeviceId: 'dev_seed',
      updatedAt: serverTimestamp(),
    };
    await setDoc(doc(db, `users/${ALICE}/logs/${SEED_LOG}`),         syncSeed);
    await setDoc(doc(db, `users/${ALICE}/plans/${SEED_PLAN}`),       syncSeed);
    await setDoc(doc(db, `users/${ALICE}/instances/${SEED_INSTANCE}`), syncSeed);
    await setDoc(doc(db, `users/${ALICE}/measurements/${SEED_MEASUREMENT}`), syncSeed);
    await setDoc(doc(db, `users/${ALICE}/_meta/${SEED_META}`),       syncSeed);

    // Pre-RFC doc with NO schemaVersion field (M1 edge case)
    await setDoc(doc(db, `users/${ALICE}/logs/${PRE_RFC_LOG}`), {
      exercise: 'deadlift',
      date: '2023-01-01T00:00:00.000Z',
      weight: 140.0,
      reps: 3,
      minutes: 0,
      writerDeviceId: 'dev_old',
      updatedAt: serverTimestamp(),
      // schemaVersion intentionally absent
    });

    // Legacy workout_history doc
    await setDoc(doc(db, `workout_history/${ALICE}`), {
      logs: [],
      totalLogs: 0,
      updatedAt: serverTimestamp(),
    });

    // Server-owned collections
    await setDoc(doc(db, `entitlements/${ALICE}`), {
      tier: 'free',
      grantedAt: serverTimestamp(),
    });
    await setDoc(doc(db, `ai_usage/${ALICE}`), {
      promptCount: 5,
      updatedAt: serverTimestamp(),
    });
  });
});

after(async function () {
  await testEnv.cleanup();
});

// ── §A Sync collections ───────────────────────────────────────────────────────
//
// Tests run once per collection helper; helper is called 5 times.

function syncCollectionTests(collName, seedDocId) {
  // Each collection needs unique doc IDs to avoid cross-test state interference.
  const prefix = collName.replace(/[^a-z]/g, '_');
  let counter = 0;
  function uid() { return `${prefix}_${++counter}`; }

  // ── Unauthenticated deny ──────────────────────────────────────────────────

  it(`[${collName}] A1 — GET denied for unauthenticated`, () =>
    assertFails(getDoc(doc(anonDb, `users/${ALICE}/${collName}/${seedDocId}`))));

  it(`[${collName}] A2 — LIST denied for unauthenticated`, () =>
    assertFails(getDocs(collection(anonDb, `users/${ALICE}/${collName}`))));

  it(`[${collName}] A3 — CREATE denied for unauthenticated`, () =>
    assertFails(setDoc(doc(anonDb, `users/${ALICE}/${collName}/${uid()}`), syncPayload())));

  it(`[${collName}] A4 — UPDATE denied for unauthenticated`, () =>
    assertFails(setDoc(doc(anonDb, `users/${ALICE}/${collName}/${seedDocId}`), syncPayload({ schemaVersion: 3 }))));

  it(`[${collName}] A5 — DELETE denied for unauthenticated`, () =>
    assertFails(deleteDoc(doc(anonDb, `users/${ALICE}/${collName}/${seedDocId}`))));

  // ── Cross-user deny ───────────────────────────────────────────────────────

  it(`[${collName}] A6 — GET denied for other user`, () =>
    assertFails(getDoc(doc(bobDb, `users/${ALICE}/${collName}/${seedDocId}`))));

  it(`[${collName}] A7 — LIST denied for other user`, () =>
    assertFails(getDocs(collection(bobDb, `users/${ALICE}/${collName}`))));

  it(`[${collName}] A8 — CREATE denied for other user (valid payload)`, () =>
    assertFails(setDoc(doc(bobDb, `users/${ALICE}/${collName}/${uid()}`), syncPayload())));

  it(`[${collName}] A9 — UPDATE denied for other user`, () =>
    assertFails(setDoc(doc(bobDb, `users/${ALICE}/${collName}/${seedDocId}`), syncPayload({ schemaVersion: 3 }))));

  it(`[${collName}] A10 — DELETE denied for other user`, () =>
    assertFails(deleteDoc(doc(bobDb, `users/${ALICE}/${collName}/${seedDocId}`))));

  // ── Owner: read ───────────────────────────────────────────────────────────

  it(`[${collName}] A11 — GET allowed for owner`, () =>
    assertSucceeds(getDoc(doc(aliceDb, `users/${ALICE}/${collName}/${seedDocId}`))));

  it(`[${collName}] A12 — LIST allowed for owner`, () =>
    assertSucceeds(getDocs(collection(aliceDb, `users/${ALICE}/${collName}`))));

  // ── Owner: valid CREATE ───────────────────────────────────────────────────

  it(`[${collName}] A13 — CREATE with full valid payload allowed`, () =>
    assertSucceeds(setDoc(doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`), syncPayload())));

  it(`[${collName}] A14 — CREATE with deletedAt as timestamp allowed`, () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      syncPayload({ deletedAt: serverTimestamp() }),
    )));

  // ── Owner: invalid CREATE — schemaVersion ────────────────────────────────

  it(`[${collName}] A15 — CREATE missing schemaVersion denied`, () => {
    const p = syncPayload();
    delete p.schemaVersion;
    return assertFails(setDoc(doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`), p));
  });

  it(`[${collName}] A16 — CREATE schemaVersion as float denied`, () => {
    const p = syncPayload();
    delete p.schemaVersion;
    return assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      Object.assign(p, { schemaVersion: 1.5 }),
    ));
  });

  it(`[${collName}] A17 — CREATE schemaVersion as string denied`, () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      syncPayload({ schemaVersion: '1' }),
    )));

  it(`[${collName}] A18 — CREATE schemaVersion as null denied`, () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      syncPayload({ schemaVersion: null }),
    )));

  // ── Owner: invalid CREATE — writerDeviceId ───────────────────────────────

  it(`[${collName}] A19 — CREATE missing writerDeviceId denied`, () => {
    const p = syncPayload();
    delete p.writerDeviceId;
    return assertFails(setDoc(doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`), p));
  });

  it(`[${collName}] A20 — CREATE writerDeviceId empty string denied`, () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      syncPayload({ writerDeviceId: '' }),
    )));

  it(`[${collName}] A21 — CREATE writerDeviceId as int denied`, () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      syncPayload({ writerDeviceId: 42 }),
    )));

  // ── Owner: invalid CREATE — updatedAt ────────────────────────────────────

  it(`[${collName}] A22 — CREATE missing updatedAt denied`, () => {
    const p = syncPayload();
    delete p.updatedAt;
    return assertFails(setDoc(doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`), p));
  });

  it(`[${collName}] A23 — CREATE updatedAt as string denied`, () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      syncPayload({ updatedAt: '2024-01-01T00:00:00Z' }),
    )));

  it(`[${collName}] A24 — CREATE updatedAt as int denied`, () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      syncPayload({ updatedAt: 1700000000 }),
    )));

  // ── Owner: invalid CREATE — deletedAt type ────────────────────────────────

  it(`[${collName}] A25 — CREATE deletedAt as int denied`, () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      syncPayload({ deletedAt: 1700000000 }),
    )));

  it(`[${collName}] A26 — CREATE deletedAt as string denied`, () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${uid()}`),
      syncPayload({ deletedAt: '2024-01-01' }),
    )));

  // ── Owner: hard DELETE ────────────────────────────────────────────────────

  it(`[${collName}] A27 — Hard DELETE own doc denied`, () =>
    assertFails(deleteDoc(doc(aliceDb, `users/${ALICE}/${collName}/${seedDocId}`))));

  // ── Owner: valid UPDATE ───────────────────────────────────────────────────

  it(`[${collName}] A28 — UPDATE schemaVersion same (unchanged) allowed`, () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${seedDocId}`),
      syncPayload({ schemaVersion: 2 }),
    )));

  it(`[${collName}] A29 — UPDATE schemaVersion increased allowed`, () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${seedDocId}`),
      syncPayload({ schemaVersion: 3 }),
    )));

  it(`[${collName}] A30 — UPDATE adding soft-delete (deletedAt timestamp) allowed`, () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${seedDocId}`),
      syncPayload({ schemaVersion: 3, deletedAt: serverTimestamp() }),
    )));

  // ── Owner: invalid UPDATE — schemaVersion ────────────────────────────────

  it(`[${collName}] A31 — UPDATE schemaVersion decreased denied (M1)`, () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/${collName}/${seedDocId}`),
      syncPayload({ schemaVersion: 1 }),
    )));

  it(`[${collName}] A32 — UPDATE missing schemaVersion in request denied`, () => {
    const p = syncPayload();
    delete p.schemaVersion;
    return assertFails(setDoc(doc(aliceDb, `users/${ALICE}/${collName}/${seedDocId}`), p));
  });

  it(`[${collName}] A33 — UPDATE missing writerDeviceId denied`, () => {
    const p = syncPayload({ schemaVersion: 3 });
    delete p.writerDeviceId;
    return assertFails(setDoc(doc(aliceDb, `users/${ALICE}/${collName}/${seedDocId}`), p));
  });
}

// Run §A for all 5 sync collections
describe('§A logs — sync collection compliance', function () {
  syncCollectionTests('logs', SEED_LOG);
});

describe('§A plans — sync collection compliance', function () {
  syncCollectionTests('plans', SEED_PLAN);
});

describe('§A instances — sync collection compliance', function () {
  syncCollectionTests('instances', SEED_INSTANCE);
});

describe('§A measurements — sync collection compliance', function () {
  syncCollectionTests('measurements', SEED_MEASUREMENT);
});

describe('§A _meta — sync collection compliance', function () {
  syncCollectionTests('_meta', SEED_META);
});

// ── §B users/{uid} profile ────────────────────────────────────────────────────

describe('§B users/{uid} profile — C2 waiver, m3 guard', function () {

  it('B01 — GET own profile allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `users/${ALICE}`))));

  it('B02 — GET other user profile denied', () =>
    assertFails(getDoc(doc(bobDb, `users/${ALICE}`))));

  it('B03 — GET profile unauthenticated denied', () =>
    assertFails(getDoc(doc(anonDb, `users/${ALICE}`))));

  it('B04 — CREATE profile without sync fields allowed (C2 waiver)', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}`),
      { profile: { name: 'Alice', age: 30 }, updatedAt: serverTimestamp() },
    )));

  it('B05 — CREATE profile without updatedAt allowed (C2 waiver — no sync field requirements)', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}`),
      { profile: { name: 'Alice' } },
    )));

  it('B06 — UPDATE profile without sync fields allowed (C2 waiver)', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}`),
      { profile: { name: 'Alice Updated' } },
    )));

  it('B07 — CREATE profile with deletedAt denied (m3)', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}`),
      { profile: { name: 'Alice' }, deletedAt: serverTimestamp() },
    )));

  it('B08 — UPDATE profile with deletedAt denied (m3)', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}`),
      { profile: { name: 'Alice' }, deletedAt: serverTimestamp() },
    )));

  it('B09 — CREATE profile for other uid denied', () =>
    assertFails(setDoc(
      doc(bobDb, `users/${ALICE}`),
      { profile: { name: 'hijack' } },
    )));

  it('B10 — UPDATE profile for other uid denied', () =>
    assertFails(setDoc(
      doc(bobDb, `users/${ALICE}`),
      { profile: { name: 'hijack' }, updatedAt: serverTimestamp() },
    )));

  it('B11 — Hard DELETE own profile denied', () =>
    assertFails(deleteDoc(doc(aliceDb, `users/${ALICE}`))));

  it('B12 — LIST under /users denied (no collection-level rule)', () =>
    assertFails(getDocs(collection(anonDb, 'users'))));
});

// ── §C favorites/{docId} — m4 ─────────────────────────────────────────────────

describe('§C favorites/{docId} — m4 exerciseIds size constraint', function () {

  it('C01 — GET own favorites/list allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `users/${ALICE}/favorites/list`))));

  it('C02 — LIST own favorites allowed', () =>
    assertSucceeds(getDocs(collection(aliceDb, `users/${ALICE}/favorites`))));

  it('C03 — GET favorites/list denied for other user', () =>
    assertFails(getDoc(doc(bobDb, `users/${ALICE}/favorites/list`))));

  it('C04 — CREATE favorites without exerciseIds field allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/custom_doc`),
      { label: 'Push Day', updatedAt: serverTimestamp() },
    )));

  it('C05 — CREATE favorites with exerciseIds.size() = 0 allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/empty_list`),
      { exerciseIds: [], updatedAt: serverTimestamp() },
    )));

  it('C06 — CREATE favorites with exerciseIds.size() = 1 allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/single_item`),
      { exerciseIds: ['squat'], updatedAt: serverTimestamp() },
    )));

  it('C07 — CREATE favorites with exerciseIds.size() = 500 allowed (boundary)', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/at_limit`),
      {
        exerciseIds: Array.from({ length: 500 }, (_, i) => `ex_${String(i).padStart(4, '0')}`),
        updatedAt: serverTimestamp(),
      },
    )));

  it('C08 — CREATE favorites with exerciseIds.size() = 501 denied (over limit)', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/over_limit`),
      {
        exerciseIds: Array.from({ length: 501 }, (_, i) => `ex_${String(i).padStart(4, '0')}`),
        updatedAt: serverTimestamp(),
      },
    )));

  it('C09 — UPDATE favorites with exerciseIds.size() = 500 allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/list`),
      {
        exerciseIds: Array.from({ length: 500 }, (_, i) => `up_${String(i).padStart(4, '0')}`),
        updatedAt: serverTimestamp(),
      },
    )));

  it('C10 — UPDATE favorites with exerciseIds.size() = 501 denied', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/list`),
      {
        exerciseIds: Array.from({ length: 501 }, (_, i) => `up_${String(i).padStart(4, '0')}`),
        updatedAt: serverTimestamp(),
      },
    )));

  it('C11 — CREATE favorites for other user denied', () =>
    assertFails(setDoc(
      doc(bobDb, `users/${ALICE}/favorites/list`),
      { exerciseIds: ['bench'], updatedAt: serverTimestamp() },
    )));

  it('C12 — Hard DELETE own favorites denied', () =>
    assertFails(deleteDoc(doc(aliceDb, `users/${ALICE}/favorites/list`))));

  it('C13 — Wildcard rule covers non-list docId (favorites/current)', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/current`),
      { exerciseIds: ['deadlift', 'row'], updatedAt: serverTimestamp() },
    )));
});

// ── §D entitlements/{uid} — m1 ────────────────────────────────────────────────

describe('§D entitlements/{uid} — GET own only, no client writes (m1)', function () {

  it('D01 — GET own entitlements allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `entitlements/${ALICE}`))));

  it('D02 — GET other user entitlements denied', () =>
    assertFails(getDoc(doc(bobDb, `entitlements/${ALICE}`))));

  it('D03 — GET entitlements unauthenticated denied', () =>
    assertFails(getDoc(doc(anonDb, `entitlements/${ALICE}`))));

  it('D04 — LIST entitlements denied (no list rule)', () =>
    assertFails(getDocs(collection(aliceDb, 'entitlements'))));

  it('D05 — CREATE own entitlements from client denied (m1)', () =>
    assertFails(setDoc(
      doc(aliceDb, `entitlements/${ALICE}`),
      { tier: 'premium', grantedAt: serverTimestamp() },
    )));

  it('D06 — UPDATE own entitlements from client denied (m1)', () =>
    assertFails(setDoc(
      doc(aliceDb, `entitlements/${ALICE}`),
      { tier: 'premium', grantedAt: serverTimestamp() },
    )));

  it('D07 — DELETE own entitlements from client denied (m1)', () =>
    assertFails(deleteDoc(doc(aliceDb, `entitlements/${ALICE}`))));
});

// ── §E ai_usage/{uid} — m1 ────────────────────────────────────────────────────

describe('§E ai_usage/{uid} — GET own only, no client writes (m1)', function () {

  it('E01 — GET own ai_usage allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `ai_usage/${ALICE}`))));

  it('E02 — GET other user ai_usage denied', () =>
    assertFails(getDoc(doc(bobDb, `ai_usage/${ALICE}`))));

  it('E03 — GET ai_usage unauthenticated denied', () =>
    assertFails(getDoc(doc(anonDb, `ai_usage/${ALICE}`))));

  it('E04 — LIST ai_usage denied (no list rule)', () =>
    assertFails(getDocs(collection(aliceDb, 'ai_usage'))));

  it('E05 — CREATE own ai_usage from client denied (m1)', () =>
    assertFails(setDoc(
      doc(aliceDb, `ai_usage/${ALICE}`),
      { promptCount: 0, updatedAt: serverTimestamp() },
    )));

  it('E06 — UPDATE own ai_usage from client denied (m1)', () =>
    assertFails(setDoc(
      doc(aliceDb, `ai_usage/${ALICE}`),
      { promptCount: 999, updatedAt: serverTimestamp() },
    )));

  it('E07 — DELETE own ai_usage from client denied (m1)', () =>
    assertFails(deleteDoc(doc(aliceDb, `ai_usage/${ALICE}`))));
});

// ── §F Legacy paths ───────────────────────────────────────────────────────────

describe('§F Legacy paths — workout_history, premium_grants (§2.6)', function () {

  // workout_history
  it('F01 — GET own workout_history allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `workout_history/${ALICE}`))));

  it('F02 — GET other user workout_history denied', () =>
    assertFails(getDoc(doc(bobDb, `workout_history/${ALICE}`))));

  it('F03 — GET workout_history unauthenticated denied', () =>
    assertFails(getDoc(doc(anonDb, `workout_history/${ALICE}`))));

  it('F04 — CREATE workout_history without sync fields allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `workout_history/${ALICE}`),
      { logs: [{ date: '2024-01-01', reps: 5 }], totalLogs: 1 },
    )));

  it('F05 — UPDATE workout_history without sync fields allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `workout_history/${ALICE}`),
      { logs: [], totalLogs: 0 },
    )));

  it('F06 — Hard DELETE workout_history denied', () =>
    assertFails(deleteDoc(doc(aliceDb, `workout_history/${ALICE}`))));

  it('F07 — CREATE workout_history for other user denied', () =>
    assertFails(setDoc(
      doc(bobDb, `workout_history/${ALICE}`),
      { logs: [], totalLogs: 0 },
    )));

  // premium_grants
  it('F08 — GET own premium_grants allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `premium_grants/${ALICE}`))));

  it('F09 — GET other user premium_grants denied', () =>
    assertFails(getDoc(doc(bobDb, `premium_grants/${ALICE}`))));

  it('F10 — GET premium_grants unauthenticated denied', () =>
    assertFails(getDoc(doc(anonDb, `premium_grants/${ALICE}`))));

  it('F11 — CREATE premium_grants without sync fields allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `premium_grants/${ALICE}`),
      { productId: 'lifton_premium', grantedAt: serverTimestamp() },
    )));

  it('F12 — Hard DELETE premium_grants denied', () =>
    assertFails(deleteDoc(doc(aliceDb, `premium_grants/${ALICE}`))));
});

// ── §G Default-deny paths ─────────────────────────────────────────────────────

describe('§G Default-deny paths — no match rule should deny all', function () {

  it('G01 — GET /arbitrary_collection/{id} denied', () =>
    assertFails(getDoc(doc(anonDb, 'arbitrary_collection/some_doc'))));

  it('G02 — WRITE /arbitrary_collection/{id} denied (authenticated)', () =>
    assertFails(setDoc(
      doc(aliceDb, 'arbitrary_collection/some_doc'),
      { data: 'test' },
    )));

  it('G03 — GET /users/{uid}/unknown_subcollection/{id} denied', () =>
    assertFails(getDoc(doc(aliceDb, `users/${ALICE}/unknown_subcollection/doc_001`))));

  it('G04 — WRITE /users/{uid}/unknown_subcollection/{id} denied', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/unknown_subcollection/doc_001`),
      { data: 'test' },
    )));
});

// ── §H Cross-cutting edge cases ───────────────────────────────────────────────

describe('§H Cross-cutting edge cases — M1 null-safe, schemaVersion boundaries', function () {

  // M1: pre-RFC document with no schemaVersion field.
  // resource.data.get('schemaVersion', 0) defaults to 0; schemaVersion >= 0 is true.

  it('H01 — UPDATE pre-RFC doc (no schemaVersion) with schemaVersion=0 allowed (M1 default)', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/${PRE_RFC_LOG}`),
      syncPayload({ schemaVersion: 0 }),
    )));

  it('H02 — UPDATE pre-RFC doc with schemaVersion=1 allowed (M1 default)', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/${PRE_RFC_LOG}`),
      syncPayload({ schemaVersion: 1 }),
    )));

  it('H03 — UPDATE pre-RFC doc with schemaVersion=-1 denied (M1 default=0, -1 < 0)', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/${PRE_RFC_LOG}`),
      syncPayload({ schemaVersion: -1 }),
    )));

  // schemaVersion = 0 on a new CREATE should pass (0 is a valid int)
  it('H04 — CREATE with schemaVersion=0 allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/h04_new_doc`),
      syncPayload({ schemaVersion: 0 }),
    )));

  // Equal schemaVersion on UPDATE is explicitly allowed
  it('H05 — UPDATE with same schemaVersion as stored allowed (non-decreasing = equal is ok)', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/${SEED_LOG}`),
      // SEED_LOG was seeded with schemaVersion:2; after §A tests it may be 3.
      // Re-seed to a known value first via a higher number.
      syncPayload({ schemaVersion: 10 }),
    )));

  // Verify schemaVersion cannot go back after an increase
  it('H06 — After UPDATE to schemaVersion=10, decreasing to 5 denied', async () => {
    // H05 set SEED_LOG to schemaVersion:10
    await assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/${SEED_LOG}`),
      syncPayload({ schemaVersion: 5 }),
    ));
  });

  // deletedAt field: null is NOT a timestamp — ensure it is treated as invalid
  it('H07 — CREATE with deletedAt: null denied (null is not a timestamp)', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/h07_null_deleted`),
      syncPayload({ deletedAt: null }),
    )));

  // C1 boundary: C2 waiver applies ONLY to users/{uid} profile root.
  // Sync subcollections require validSyncWrite() regardless.
  it('H08 — CREATE in sync collection without sync fields denied even for owner (C1)', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/plans/h08_no_sync`),
      { planName: 'My Plan', createdAt: serverTimestamp() },
    )));

  // m2 — no collection group query should reach subcollections
  it('H09 — GET /logs/{id} at root (collection group path) denied — no match rule', () =>
    assertFails(getDoc(doc(aliceDb, `logs/any_doc`))));

  it('H10 — GET /instances/{id} at root denied — no match rule', () =>
    assertFails(getDoc(doc(aliceDb, `instances/any_doc`))));
});
