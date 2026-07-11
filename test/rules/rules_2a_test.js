// test/rules/rules_2a_test.js
//
// RFC-002.3 Phase 2A — Core smoke tests (38 cases)
// Runs against the Firestore emulator via @firebase/rules-unit-testing.
//
// §1  Authentication gates — unauthenticated deny (11)
// §2  Cross-user ownership gates (8)
// §3  Basic valid access (12)
// §4  Critical rule denials (7)

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

before(async function () {
  this.timeout(30000);

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

  // Seed documents that tests need to read.
  // Uses withSecurityRulesDisabled — bypasses rules, simulates server-side writes.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    // Log doc for read (test 21) and hard-delete attempt (test 36)
    await setDoc(doc(db, `users/${ALICE}/logs/pre_seeded_log`), {
      exercise: 'squat',
      date: '2024-03-10T00:00:00.000Z',
      weight: 100.0,
      reps: 5,
      minutes: 0,
      schemaVersion: 1,
      writerDeviceId: 'dev_seed_001',
      updatedAt: serverTimestamp(),
    });

    // entitlements and ai_usage can only be written server-side (m1)
    await setDoc(doc(db, `entitlements/${ALICE}`), {
      tier: 'free',
      grantedAt: serverTimestamp(),
    });
    await setDoc(doc(db, `ai_usage/${ALICE}`), {
      promptCount: 3,
      updatedAt: serverTimestamp(),
    });
  });
});

after(async function () {
  await testEnv.cleanup();
});

// ── §1 Authentication gates — unauthenticated deny (11 cases) ────────────────

describe('§1 Authentication gates — unauthenticated deny', function () {
  it('01 — GET users/{uid} denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `users/${ALICE}`))));

  it('02 — GET users/{uid}/logs/{id} denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `users/${ALICE}/logs/pre_seeded_log`))));

  it('03 — GET users/{uid}/plans/{id} denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `users/${ALICE}/plans/plan_001`))));

  it('04 — GET users/{uid}/instances/{id} denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `users/${ALICE}/instances/inst_001`))));

  it('05 — GET users/{uid}/measurements/{id} denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `users/${ALICE}/measurements/meas_001`))));

  it('06 — GET users/{uid}/_meta/sync denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `users/${ALICE}/_meta/sync`))));

  it('07 — GET users/{uid}/favorites/list denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `users/${ALICE}/favorites/list`))));

  it('08 — GET workout_history/{uid} denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `workout_history/${ALICE}`))));

  it('09 — GET premium_grants/{uid} denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `premium_grants/${ALICE}`))));

  it('10 — GET entitlements/{uid} denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `entitlements/${ALICE}`))));

  it('11 — GET ai_usage/{uid} denied for unauthenticated', () =>
    assertFails(getDoc(doc(anonDb, `ai_usage/${ALICE}`))));
});

// ── §2 Cross-user ownership gates (8 cases) ───────────────────────────────────

describe('§2 Cross-user ownership gates', function () {
  it('12 — GET users/alice/logs/{id} denied for bob', () =>
    assertFails(getDoc(doc(bobDb, `users/${ALICE}/logs/pre_seeded_log`))));

  it('13 — CREATE users/alice/logs/{id} denied for bob (valid payload)', () =>
    assertFails(setDoc(doc(bobDb, `users/${ALICE}/logs/bobs_attempt`), syncPayload())));

  it('14 — GET users/alice profile denied for bob', () =>
    assertFails(getDoc(doc(bobDb, `users/${ALICE}`))));

  it('15 — WRITE users/alice profile denied for bob', () =>
    assertFails(setDoc(doc(bobDb, `users/${ALICE}`), {
      profile: { name: 'hijack' }, updatedAt: serverTimestamp(),
    })));

  it('16 — READ workout_history/alice denied for bob', () =>
    assertFails(getDoc(doc(bobDb, `workout_history/${ALICE}`))));

  it('17 — WRITE workout_history/alice denied for bob', () =>
    assertFails(setDoc(doc(bobDb, `workout_history/${ALICE}`), {
      logs: [], updatedAt: serverTimestamp(),
    })));

  it('18 — READ premium_grants/alice denied for bob', () =>
    assertFails(getDoc(doc(bobDb, `premium_grants/${ALICE}`))));

  it('19 — GET entitlements/alice denied for bob', () =>
    assertFails(getDoc(doc(bobDb, `entitlements/${ALICE}`))));
});

// ── §3 Basic valid access (12 cases) ─────────────────────────────────────────

describe('§3 Basic valid access', function () {
  it('20 — CREATE log with valid sync payload allowed for owner', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/new_log_001`),
      syncPayload(),
    )));

  it('21 — GET own log allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `users/${ALICE}/logs/pre_seeded_log`))));

  it('22 — LIST own logs allowed', () =>
    assertSucceeds(getDocs(collection(aliceDb, `users/${ALICE}/logs`))));

  it('23 — WRITE profile without sync fields allowed (C2 waiver)', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}`),
      { profile: { name: 'Alice' }, updatedAt: serverTimestamp() },
    )));

  it('24 — GET own profile allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `users/${ALICE}`))));

  it('25 — WRITE favorites/list with exerciseIds allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/list`),
      { exerciseIds: ['squat', 'bench_press', 'pull_up'], updatedAt: serverTimestamp() },
    )));

  it('26 — GET own favorites/list allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `users/${ALICE}/favorites/list`))));

  it('27 — WRITE workout_history without sync fields allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `workout_history/${ALICE}`),
      { logs: [], updatedAt: serverTimestamp(), totalLogs: 0 },
    )));

  it('28 — READ own workout_history allowed', () =>
    assertSucceeds(getDoc(doc(aliceDb, `workout_history/${ALICE}`))));

  it('29 — WRITE own premium_grants allowed', () =>
    assertSucceeds(setDoc(
      doc(aliceDb, `premium_grants/${ALICE}`),
      { productId: 'lifton_premium', grantedAt: serverTimestamp() },
    )));

  it('30 — GET own entitlements allowed (server-seeded)', () =>
    assertSucceeds(getDoc(doc(aliceDb, `entitlements/${ALICE}`))));

  it('31 — GET own ai_usage allowed (server-seeded)', () =>
    assertSucceeds(getDoc(doc(aliceDb, `ai_usage/${ALICE}`))));
});

// ── §4 Critical rule denials (7 cases) ────────────────────────────────────────

describe('§4 Critical rule denials', function () {
  it('32 — CREATE log missing schemaVersion denied', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/bad_log_32`),
      {
        exercise: 'squat',
        date: '2024-01-15T00:00:00.000Z',
        weight: 100.0,
        reps: 5,
        minutes: 0,
        // schemaVersion intentionally absent
        writerDeviceId: 'dev_test_001',
        updatedAt: serverTimestamp(),
      },
    )));

  it('33 — CREATE log missing writerDeviceId denied', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/bad_log_33`),
      {
        exercise: 'squat',
        date: '2024-01-15T00:00:00.000Z',
        weight: 100.0,
        reps: 5,
        minutes: 0,
        schemaVersion: 1,
        // writerDeviceId intentionally absent
        updatedAt: serverTimestamp(),
      },
    )));

  it('34 — CREATE log missing updatedAt denied', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/logs/bad_log_34`),
      {
        exercise: 'squat',
        date: '2024-01-15T00:00:00.000Z',
        weight: 100.0,
        reps: 5,
        minutes: 0,
        schemaVersion: 1,
        writerDeviceId: 'dev_test_001',
        // updatedAt intentionally absent
      },
    )));

  it('35 — WRITE profile with deletedAt field denied (m3)', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}`),
      {
        profile: { name: 'Alice' },
        updatedAt: serverTimestamp(),
        deletedAt: serverTimestamp(),
      },
    )));

  it('36 — Hard DELETE own log denied', () =>
    assertFails(deleteDoc(doc(aliceDb, `users/${ALICE}/logs/pre_seeded_log`))));

  it('37 — CREATE entitlements from client denied (m1)', () =>
    assertFails(setDoc(
      doc(aliceDb, `entitlements/${ALICE}`),
      { tier: 'premium', grantedAt: serverTimestamp() },
    )));

  it('38 — WRITE favorites with exerciseIds.size() = 501 denied (m4)', () =>
    assertFails(setDoc(
      doc(aliceDb, `users/${ALICE}/favorites/list`),
      {
        exerciseIds: Array.from({ length: 501 }, (_, i) => `ex_${String(i).padStart(4, '0')}`),
        updatedAt: serverTimestamp(),
      },
    )));
});
