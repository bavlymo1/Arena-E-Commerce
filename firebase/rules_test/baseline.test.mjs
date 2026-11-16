import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const projectId = 'demo-arenapass';
const host = '127.0.0.1';
const port = 8180;
let environment;

before(async () => {
  const configuredHost = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(
    configuredHost === undefined || configuredHost === `${host}:${port}`,
    `Refusing emulator host ${configuredHost}; this suite only uses ${host}:${port}.`,
  );
  try {
    const response = await fetch(
      `http://${host}:${port}/emulator/v1/projects/${projectId}:ruleCoverage`,
      { signal: AbortSignal.timeout(3000) },
    );
    assert.ok(response.ok, `Firestore emulator returned HTTP ${response.status}.`);
  } catch (cause) {
    throw new Error(
      'Local Firestore emulator unavailable. Run npm run test:emulator; no cloud fallback is permitted.',
      { cause },
    );
  }
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host,
      port,
      rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
});

after(async () => {
  if (environment) {
    try {
      await environment.clearFirestore();
    } finally {
      await environment.cleanup();
    }
  }
});

function databaseFor(identity) {
  if (identity === 'unauthenticated') {
    return environment.unauthenticatedContext().firestore();
  }
  return environment.authenticatedContext(identity, {
    firebase: {
      sign_in_provider: identity === 'vendor-device' ? 'anonymous' : 'password',
    },
  }).firestore();
}

for (const identity of ['unauthenticated', 'customer-a', 'vendor-device']) {
  for (const path of [
    'users/customer-a',
    'vendorDevices/vendor-device',
    'shows/show-a',
    'shows/show-a/sessions/1900',
    'showImages/show-a',
    'bookings/booking-a',
    'bookingEvents/booking-a',
  ]) {
    test(`baseline denies ${identity} write to ${path}`, async () => {
      await assertFails(setDoc(doc(databaseFor(identity), path), { forged: true }));
    });
  }
}

test('admin fixture bypass works while owner and another customer remain denied', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const reference = doc(context.firestore(), 'bookings/booking-a');
    await setDoc(reference, { customerUid: 'customer-a', status: 'confirmed' });
    const snapshot = await getDoc(reference);
    assert.equal(snapshot.data().customerUid, 'customer-a');
  });
  for (const identity of ['customer-a', 'customer-b', 'vendor-device', 'unauthenticated']) {
    await assertFails(getDoc(doc(databaseFor(identity), 'bookings/booking-a')));
  }
});

test('baseline denies missing-booking recovery until its rules are implemented', async () => {
  await assertFails(getDoc(doc(databaseFor('customer-a'), 'bookings/missing-booking')));
});

test('baseline denies unknown collections', async () => {
  await assertFails(setDoc(doc(databaseFor('customer-a'), 'unexpected/document'), { value: 1 }));
  await assertFails(getDoc(doc(databaseFor('customer-a'), 'unexpected/document')));
});
