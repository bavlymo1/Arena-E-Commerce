import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import {
  assertEmulatorConfig,
  buildSeedDocuments,
  loadPosterAssets,
  MAX_POSTER_BYTES,
  seedEmulator,
} from './seed.mjs';

const SEED_SCRIPT = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'seed.mjs',
);

function makeNoCallFetch() {
  return async (url) => {
    throw new Error(`HTTP call must not happen on invalid config: ${url}`);
  };
}

test('guard rejects missing emulator env vars before any HTTP request', async () => {
  await assert.rejects(
    () => seedEmulator({ env: {}, fetchImpl: makeNoCallFetch() }),
    /FIREBASE_AUTH_EMULATOR_HOST/,
  );
  await assert.rejects(
    () =>
      seedEmulator({
        env: { FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099' },
        fetchImpl: makeNoCallFetch(),
      }),
    /FIRESTORE_EMULATOR_HOST/,
  );
});

test('guard rejects non-loopback or malformed emulator hosts before HTTP', async () => {
  for (const badHost of [
    'firestore.googleapis.com:443',
    '192.168.1.25:8180',
    'http://127.0.0.1:8180',
    '127.0.0.1',
    '127.0.0.1:70000',
    'evil.example.com:9099',
  ]) {
    assert.throws(
      () =>
        assertEmulatorConfig({
          FIREBASE_AUTH_EMULATOR_HOST: badHost,
          FIRESTORE_EMULATOR_HOST: '127.0.0.1:8180',
          GCLOUD_PROJECT: 'demo-arenapass',
        }),
      /Refusing/,
    );
    await assert.rejects(
      () =>
        seedEmulator({
          env: {
            FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099',
            FIRESTORE_EMULATOR_HOST: badHost,
            GCLOUD_PROJECT: 'demo-arenapass',
          },
          fetchImpl: makeNoCallFetch(),
        }),
      /Refusing/,
    );
  }
});

test('guard rejects live or non-demo project IDs before any HTTP request', async () => {
  for (const projectId of ['arenapass-prod', 'my-firebase-app', 'prod-demo-1']) {
    await assert.rejects(
      () =>
        seedEmulator({
          env: {
            FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
            FIRESTORE_EMULATOR_HOST: '127.0.0.1:8180',
            GCLOUD_PROJECT: projectId,
          },
          fetchImpl: makeNoCallFetch(),
        }),
      /demo-/,
    );
  }
});

test('CLI subprocess exits non-zero without emulator env vars', () => {
  const result = spawnSync(process.execPath, [SEED_SCRIPT], {
    env: { PATH: process.env.PATH ?? '' },
    encoding: 'utf8',
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Refusing/);
});

test('demo assets load under 150 KiB with valid JPEG dimensions', async () => {
  const posters = await loadPosterAssets();
  assert.equal(posters.size, 3);
  for (const [showId, poster] of posters.entries()) {
    assert.ok(poster.bytes.length > 0, `${showId} poster empty`);
    assert.ok(
      poster.bytes.length <= MAX_POSTER_BYTES,
      `${showId} poster ${poster.bytes.length} exceeds 150 KiB`,
    );
    assert.ok(poster.width > 0 && poster.height > 0);
  }
});

test('buildSeedDocuments produces rules-compatible vendor, customer, show, session, image, booking, and event schema', async () => {
  const postersByShowId = await loadPosterAssets();
  const docs = buildSeedDocuments({
    customerUids: { 'c1@test.dev': 'uid-c1', 'c2@test.dev': 'uid-c2' },
    postersByShowId,
  });

  const byPath = new Map(docs.map((d) => [d.path, d.data]));
  assert.deepEqual(byPath.get('vendorDevices/test-vendor-uid'), {
    enabled: true,
    vendorId: 'arena',
  });
  assert.equal(byPath.get('users/uid-c1').email, 'c1@test.dev');
  assert.equal(byPath.get('users/uid-c2').email, 'c2@test.dev');

  const shows = docs.filter((d) => /^shows\/[^/]+$/.test(d.path));
  assert.equal(shows.length, 3);
  const createdAts = new Set(shows.map((s) => s.data.createdAt.timestampValue));
  assert.equal(createdAts.size, 3);

  for (const showDoc of shows) {
    const showId = showDoc.path.split('/')[1];
    const s = showDoc.data;
    assert.equal(s.vendorId, 'arena');
    assert.equal(s.titleSearch, s.title.toLowerCase());
    assert.equal(s.imageId, showId);
    assert.equal(s.status, 'active');
    assert.match(s.showDate, /^\d{4}-\d{2}-\d{2}$/);
    assert.ok(s.sessionIds.length >= 2 && s.sessionIds.length <= 3);
    for (const slotId of s.sessionIds) {
      assert.match(slotId, /^([01]\d|2[0-3])[0-5]\d$/);
      const sess = byPath.get(`shows/${showId}/sessions/${slotId}`);
      assert.ok(sess, `Missing session ${slotId} for ${showId}`);
      assert.equal(sess.capacity, 47);
      assert.equal(sess.time.replace(':', ''), slotId);
      assert.equal(typeof sess.label, 'string');
    }

    const img = byPath.get(`showImages/${showId}`);
    assert.equal(img.mimeType, 'image/jpeg');
    assert.equal(img.vendorId, 'arena');
    assert.ok(Number.isInteger(img.width) && img.width > 0);
    assert.ok(Number.isInteger(img.height) && img.height > 0);
    assert.ok(img.poster instanceof Uint8Array);
  }

  const bookedShow = byPath.get('shows/seed-show-skyline-jam');
  assert.equal(bookedShow.bookedCount, 5);
  assert.equal(bookedShow.lastBookingId, 'seed-booking-1');

  const bookedSession = byPath.get('shows/seed-show-skyline-jam/sessions/1900');
  assert.deepEqual(bookedSession.bookedSeats, [1, 2, 3, 4, 5]);
  assert.equal(bookedSession.lastBookingId, 'seed-booking-1');

  const booking = byPath.get('bookings/seed-booking-1');
  assert.equal(booking.customerUid, 'uid-c1');
  assert.equal(booking.status, 'confirmed');
  assert.deepEqual(booking.seats, [1, 2, 3, 4, 5]);

  const event = byPath.get('bookingEvents/seed-booking-1');
  assert.equal(event.kind, 'booked');
  assert.equal(event.slotTotal, 5);
  assert.equal(event.showTotal, 5);
  assert.equal(event.bookingId, 'seed-booking-1');
  assert.equal('customerUid' in event, false);
});

test('seedEmulator targets only loopback endpoints and uses Bearer owner', async () => {
  const calls = [];
  const fakeFetch = async (url, init) => {
    calls.push({ url, init });
    if (url.includes('accounts:signUp')) {
      const email = JSON.parse(init.body).email;
      return new Response(
        JSON.stringify({ localId: email === 'c1@test.dev' ? 'uid-c1' : 'uid-c2' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }
    if (url.endsWith('/emulatorSeeds/tier1')) {
      return new Response(null, { status: 404 });
    }
    if (url.includes('documents:commit')) {
      return new Response(JSON.stringify({ writeResults: [] }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    throw new Error(`Unexpected URL: ${url}`);
  };

  const summary = await seedEmulator({
    env: {
      FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9499',
      FIRESTORE_EMULATOR_HOST: '127.0.0.1:8580',
      GCLOUD_PROJECT: 'demo-arenapass',
    },
    fetchImpl: fakeFetch,
  });

  assert.equal(summary.projectId, 'demo-arenapass');
  assert.equal(calls.length, 4);
  assert.ok(calls.every((c) => /^http:\/\/(127\.0\.0\.1|localhost):/.test(c.url)));
  const commitCall = calls[3];
  assert.equal(commitCall.init.headers.Authorization, 'Bearer owner');
  const payload = JSON.parse(commitCall.init.body);
  assert.ok(payload.writes.every((write) => write.currentDocument.exists === false));
  assert.ok(payload.writes.some((write) => write.update.name.endsWith('/emulatorSeeds/tier1')));
  const skylineImg = payload.writes.find((w) =>
    w.update.name.endsWith('/showImages/seed-show-skyline-jam'),
  );
  assert.equal(typeof skylineImg.update.fields.poster.bytesValue, 'string');
  assert.ok(skylineImg.update.fields.poster.bytesValue.length > 0);
});
