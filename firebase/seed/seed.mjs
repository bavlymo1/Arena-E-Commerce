import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const SEED_DIR = path.dirname(fileURLToPath(import.meta.url));
const APP_ROOT = path.resolve(SEED_DIR, '..', '..');

export const DEFAULT_PROJECT_ID = 'demo-arenapass';
export const DEFAULT_VENDOR_ID = 'arena';
export const DEFAULT_VENDOR_DEVICE_UID = 'test-vendor-uid';
export const MAX_POSTER_BYTES = 150 * 1024; // 150 KiB target (< 204,800-byte rule cap)
export const SEED_CUSTOMER_PASSWORD = 'Local-demo-47';

const SEED_CUSTOMERS = [
  { email: 'c1@test.dev', displayName: 'Customer One' },
  { email: 'c2@test.dev', displayName: 'Customer Two' },
];

const SEED_SHOWS = [
  {
    id: 'seed-show-skyline-jam',
    title: 'Skyline Jam',
    description: 'Opening night championship qualifiers at the main arena.',
    showDate: '2026-12-20',
    createdAt: '2026-11-20T10:00:00.000Z',
    assetFile: 'skyline_jam.jpg',
    sessions: [
      { time: '14:00', label: 'Afternoon' },
      { time: '19:00', label: 'Evening' },
    ],
    prebookedSessionId: '1900',
    prebookedSeats: [1, 2, 3, 4, 5],
    prebookedBookingId: 'seed-booking-1',
  },
  {
    id: 'seed-show-kingdom-clash',
    title: 'Kingdom Clash',
    description: 'Regional quarterfinals featuring three daily arena sessions.',
    showDate: '2026-12-21',
    createdAt: '2026-11-20T11:00:00.000Z',
    assetFile: 'kingdom_clash.jpg',
    sessions: [
      { time: '14:00', label: 'Matinee' },
      { time: '19:00', label: 'Main Event' },
      { time: '21:30', label: 'Encore' },
    ],
  },
  {
    id: 'seed-show-midnight-drift',
    title: 'Midnight Drift',
    description: 'Nighttime arena finals under the main stadium lights.',
    showDate: '2026-12-22',
    createdAt: '2026-11-20T12:00:00.000Z',
    assetFile: 'midnight_drift.jpg',
    sessions: [
      { time: '16:00', label: 'Qualifier' },
      { time: '20:00', label: 'Finals' },
    ],
  },
];

/**
 * Validates that emulator hosts are strict loopback host:port values and the
 * project ID uses a demo- prefix before any network I/O is attempted.
 */
export function assertEmulatorConfig(env = process.env) {
  const authHost = parseLoopbackHostPort(
    env.FIREBASE_AUTH_EMULATOR_HOST,
    'FIREBASE_AUTH_EMULATOR_HOST',
  );
  const firestoreHost = parseLoopbackHostPort(
    env.FIRESTORE_EMULATOR_HOST,
    'FIRESTORE_EMULATOR_HOST',
  );
  const projectId =
    env.FIREBASE_PROJECT_ID ||
    env.GCLOUD_PROJECT ||
    env.GOOGLE_CLOUD_PROJECT ||
    DEFAULT_PROJECT_ID;

  if (
    typeof projectId !== 'string' ||
    !projectId.startsWith('demo-') ||
    /\s|\//.test(projectId)
  ) {
    throw new Error(
      `Refusing to seed project "${projectId}": project ID must start with "demo-".`,
    );
  }

  return { authHost, firestoreHost, projectId };
}

function parseLoopbackHostPort(raw, envName) {
  if (typeof raw !== 'string' || raw.trim() === '') {
    throw new Error(
      `Refusing to seed: ${envName} must be set to 127.0.0.1:<port> or localhost:<port>.`,
    );
  }
  const value = raw.trim();
  const match = /^(127\.0\.0\.1|localhost):(\d{1,5})$/.exec(value);
  if (!match) {
    throw new Error(
      `Refusing non-loopback or malformed ${envName}: "${raw}". Expected 127.0.0.1:<port> or localhost:<port>.`,
    );
  }
  const port = Number(match[2]);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`Refusing invalid port in ${envName}: "${raw}".`);
  }
  return `${match[1]}:${port}`;
}

/**
 * Extracts width and height from a JPEG byte buffer SOF marker.
 */
export function readJpegDimensions(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.length < 4) {
    throw new Error('Poster bytes must be a non-empty JPEG buffer.');
  }
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) {
    throw new Error('Poster bytes do not have a valid JPEG header.');
  }
  let offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] !== 0xff) break;
    while (offset < bytes.length && bytes[offset] === 0xff) offset++;
    if (offset >= bytes.length) break;
    const marker = bytes[offset++];
    if (marker === 0xd8 || marker === 0xd9 || marker === 0x01) continue;
    if (marker >= 0xd0 && marker <= 0xd7) continue;
    if (offset + 2 > bytes.length) break;
    const segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2 || offset + segmentLength > bytes.length) break;
    const isSof =
      (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf);
    if (isSof && offset + 7 <= bytes.length) {
      const height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      const width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      if (width > 0 && height > 0) return { width, height };
    }
    offset += segmentLength;
  }
  throw new Error('Unable to read JPEG dimensions from poster bytes.');
}

export function toFirestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (!Number.isInteger(value)) {
      throw new Error(`Expected integer Firestore number, got ${value}`);
    }
    return { integerValue: String(value) };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (value instanceof Uint8Array) {
    return { bytesValue: Buffer.from(value).toString('base64') };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (value && typeof value === 'object' && 'timestampValue' in value) {
    return { timestampValue: value.timestampValue };
  }
  if (value && typeof value === 'object') {
    return { mapValue: { fields: toFirestoreFields(value) } };
  }
  throw new Error(`Unsupported Firestore seed field type: ${typeof value}`);
}

export function toFirestoreFields(record) {
  return Object.fromEntries(
    Object.entries(record).map(([key, val]) => [key, toFirestoreValue(val)]),
  );
}

export async function loadPosterAssets(assetsDir = path.join(APP_ROOT, 'assets', 'demo')) {
  const loaded = new Map();
  for (const show of SEED_SHOWS) {
    const filePath = path.join(assetsDir, show.assetFile);
    const bytes = new Uint8Array(await readFile(filePath));
    if (bytes.length === 0 || bytes.length > MAX_POSTER_BYTES) {
      throw new Error(
        `Asset ${show.assetFile} size ${bytes.length} must be 1..${MAX_POSTER_BYTES} bytes.`,
      );
    }
    const { width, height } = readJpegDimensions(bytes);
    loaded.set(show.id, { bytes, width, height });
  }
  return loaded;
}

/**
 * Builds the deterministic document map matching firebase/firestore.rules.
 */
export function buildSeedDocuments({
  customerUids,
  postersByShowId,
  vendorId = DEFAULT_VENDOR_ID,
  vendorDeviceUid = DEFAULT_VENDOR_DEVICE_UID,
}) {
  const c1Uid = customerUids['c1@test.dev'];
  const c2Uid = customerUids['c2@test.dev'];
  if (!c1Uid || !c2Uid) {
    throw new Error('Customer UIDs for c1@test.dev and c2@test.dev are required.');
  }

  const docs = [];

  docs.push({
    path: `vendorDevices/${vendorDeviceUid}`,
    data: { enabled: true, vendorId },
  });

  const userCreatedAt = { timestampValue: '2026-11-20T09:00:00.000Z' };
  docs.push({
    path: `users/${c1Uid}`,
    data: { email: 'c1@test.dev', displayName: 'Customer One', createdAt: userCreatedAt },
  });
  docs.push({
    path: `users/${c2Uid}`,
    data: { email: 'c2@test.dev', displayName: 'Customer Two', createdAt: userCreatedAt },
  });

  for (const show of SEED_SHOWS) {
    const poster = postersByShowId.get(show.id);
    if (!poster) throw new Error(`Missing loaded poster for ${show.id}`);

    const sessionIds = show.sessions.map((s) => s.time.replace(':', ''));
    const prebookedSeats = show.prebookedSeats ?? [];
    const bookedCount = prebookedSeats.length;
    const lastBookingId = show.prebookedBookingId ?? '';
    const updatedAt = { timestampValue: show.createdAt };

    docs.push({
      path: `shows/${show.id}`,
      data: {
        vendorId,
        title: show.title,
        titleSearch: show.title.toLowerCase(),
        description: show.description,
        showDate: show.showDate,
        createdAt: { timestampValue: show.createdAt },
        updatedAt,
        status: 'active',
        imageId: show.id,
        sessionIds,
        bookedCount,
        lastBookingId,
      },
    });

    docs.push({
      path: `showImages/${show.id}`,
      data: {
        vendorId,
        poster: poster.bytes,
        mimeType: 'image/jpeg',
        width: poster.width,
        height: poster.height,
      },
    });

    for (const session of show.sessions) {
      const slotId = session.time.replace(':', '');
      const isPrebooked = show.prebookedSessionId === slotId;
      docs.push({
        path: `shows/${show.id}/sessions/${slotId}`,
        data: {
          time: session.time,
          label: session.label,
          capacity: 47,
          bookedSeats: isPrebooked ? [...prebookedSeats] : [],
          lastBookingId: isPrebooked ? lastBookingId : '',
          updatedAt,
        },
      });
    }

    if (show.prebookedBookingId && show.prebookedSessionId) {
      const prebookedSession = show.sessions.find(
        (s) => s.time.replace(':', '') === show.prebookedSessionId,
      );
      if (!prebookedSession) {
        throw new Error(`Missing prebooked session ${show.prebookedSessionId}`);
      }
      const bookingTime = { timestampValue: '2026-11-20T12:30:00.000Z' };
      docs.push({
        path: `bookings/${show.prebookedBookingId}`,
        data: {
          showId: show.id,
          sessionId: show.prebookedSessionId,
          customerUid: c1Uid,
          seats: [...prebookedSeats],
          showTitle: show.title,
          showDate: show.showDate,
          slotTime: prebookedSession.time,
          vendorId,
          status: 'confirmed',
          createdAt: bookingTime,
        },
      });
      docs.push({
        path: `bookingEvents/${show.prebookedBookingId}`,
        data: {
          vendorId,
          showId: show.id,
          sessionId: show.prebookedSessionId,
          bookingId: show.prebookedBookingId,
          seats: [...prebookedSeats],
          showTitle: show.title,
          slotTime: prebookedSession.time,
          slotTotal: prebookedSeats.length,
          showTotal: bookedCount,
          kind: 'booked',
          createdAt: bookingTime,
        },
      });
    }
  }

  return docs;
}

async function ensureAuthCustomer(
  { authHost, projectId },
  customer,
  fetchImpl,
) {
  const baseUrl = `http://${authHost}/identitytoolkit.googleapis.com/v1`;
  const signUpRes = await fetchImpl(
    `${baseUrl}/accounts:signUp?key=demo-emulator-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: customer.email,
        password: SEED_CUSTOMER_PASSWORD,
        displayName: customer.displayName,
        returnSecureToken: true,
      }),
      signal: AbortSignal.timeout(10000),
    },
  );
  const signUpBody = await signUpRes.json();
  if (signUpRes.ok && signUpBody.localId) {
    return signUpBody.localId;
  }
  if (signUpBody?.error?.message !== 'EMAIL_EXISTS') {
    throw new Error(
      `Auth emulator signUp failed for ${customer.email} (project ${projectId}): ${signUpRes.status}`,
    );
  }

  const signInRes = await fetchImpl(
    `${baseUrl}/accounts:signInWithPassword?key=demo-emulator-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: customer.email,
        password: SEED_CUSTOMER_PASSWORD,
        returnSecureToken: true,
      }),
      signal: AbortSignal.timeout(10000),
    },
  );
  const signInBody = await signInRes.json();
  if (!signInRes.ok || !signInBody.localId) {
    throw new Error(
      `Auth emulator signIn failed for existing ${customer.email} (project ${projectId}): ${signInRes.status}`,
    );
  }
  return signInBody.localId;
}

async function commitDocuments({ firestoreHost, projectId }, docs, fetchImpl) {
  const writes = docs.map((entry) => ({
    update: {
      name: `projects/${projectId}/databases/(default)/documents/${entry.path}`,
      fields: toFirestoreFields(entry.data),
    },
  }));
  const url = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const response = await fetchImpl(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer owner',
    },
    body: JSON.stringify({ writes }),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) {
    const bodyText = await response.text();
    throw new Error(
      `Firestore emulator commit failed (${response.status}): ${bodyText}`,
    );
  }
  return response.json();
}

export async function seedEmulator({
  env = process.env,
  fetchImpl = fetch,
  assetsDir,
} = {}) {
  // Enforce emulator-only safety guard BEFORE any filesystem/HTTP work.
  const config = assertEmulatorConfig(env);
  const postersByShowId = await loadPosterAssets(assetsDir);

  const customerUids = {};
  for (const customer of SEED_CUSTOMERS) {
    customerUids[customer.email] = await ensureAuthCustomer(
      config,
      customer,
      fetchImpl,
    );
  }

  const docs = buildSeedDocuments({ customerUids, postersByShowId });
  await commitDocuments(config, docs, fetchImpl);

  return {
    projectId: config.projectId,
    authHost: config.authHost,
    firestoreHost: config.firestoreHost,
    vendorDeviceUid: DEFAULT_VENDOR_DEVICE_UID,
    vendorId: DEFAULT_VENDOR_ID,
    customerUids,
    showIds: SEED_SHOWS.map((s) => s.id),
    documentCount: docs.length,
  };
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    const summary = await seedEmulator();
    console.log(JSON.stringify(summary, null, 2));
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
