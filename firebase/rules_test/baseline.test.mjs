import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  Bytes, collection, deleteDoc, doc, getDoc, getDocFromServer, getDocs,
  query, runTransaction, serverTimestamp, setDoc, snapshotEqual, updateDoc, where, writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-arenapass';
const host = '127.0.0.1';
const port = 8180;
let environment;
let vendor;
let customer;
const times = ['10:00', '12:00', '14:00', '16:00', '19:00'];
const sessionPath = 'shows/show-a/sessions/1900';

before(async () => {
  const configuredHost = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(configuredHost === undefined || configuredHost === `${host}:${port}`,
    `Refusing emulator host ${configuredHost}; only ${host}:${port} is allowed.`);
  const response = await fetch(
    `http://${host}:${port}/emulator/v1/projects/${projectId}:ruleCoverage`,
    { signal: AbortSignal.timeout(3000) },
  ).catch((cause) => { throw new Error('Local emulator unavailable; no cloud fallback.', { cause }); });
  assert.ok(response.ok);
  environment = await initializeTestEnvironment({
    projectId, firestore: { host, port, rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
beforeEach(async () => {
  await environment.clearFirestore();
  vendor = databaseFor('vendor-device', 'anonymous');
  customer = databaseFor('customer-a');
  await admin(async (db) => {
    await setDoc(doc(db, 'vendorDevices/vendor-device'), { enabled: true, vendorId: 'vendor-a' });
    await setDoc(doc(db, 'vendorDevices/vendor-disabled'), { enabled: false, vendorId: 'vendor-a' });
    await setDoc(doc(db, 'vendorDevices/vendor-other'), { enabled: true, vendorId: 'vendor-b' });
  });
});
after(async () => {
  if (environment) {
    try {
      const response = await fetch(`http://${host}:${port}/emulator/v1/projects/${projectId}:ruleCoverage`);
      await writeFile(new URL('./rule-coverage.json', import.meta.url), await response.text());
      await environment.clearFirestore();
    } finally { await environment.cleanup(); }
  }
});
function databaseFor(uid, provider = 'password') {
  if (uid === null) return environment.unauthenticatedContext().firestore();
  return environment.authenticatedContext(uid, {
    email: `${uid}@example.test`, firebase: { sign_in_provider: provider },
  }).firestore();
}
async function admin(action) { return environment.withSecurityRulesDisabled((context) => action(context.firestore())); }
function showData(id = 'show-a') {
  return {
    vendorId: 'vendor-a', title: 'Arena Show', titleSearch: 'arena show', description: 'A live show',
    showDate: '2026-12-01', imageId: id, status: 'active', bookedCount: 0, lastBookingId: '',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
}
function imageData() {
  return { vendorId: 'vendor-a', poster: Bytes.fromUint8Array(new Uint8Array([255,216,255,217])),
    mimeType: 'image/jpeg', width: 2, height: 2 };
}
function sessionData(time = '19:00') {
  return { time, capacity: 47, bookedSeats: [], lastBookingId: '', updatedAt: serverTimestamp() };
}
function addShow(db = vendor, { id = 'show-a', slots = times, mutate = () => {}, image = true } = {}) {
  const batch = writeBatch(db);
  const s = showData(id);
  const poster = imageData();
  const sessions = slots.map((time) => ({ id: time.replace(':',''), data: sessionData(time) }));
  mutate({ show: s, image: poster, sessions });
  batch.set(doc(db, `shows/${id}`), s);
  if (image) batch.set(doc(db, `showImages/${id}`), poster);
  for (const slot of sessions) batch.set(doc(db, `shows/${id}/sessions/${slot.id}`), slot.data);
  return batch.commit();
}
function bookingWrites(db, id, seats, s, slot, { uid = 'customer-a', mutate = () => {}, omit } = {}) {
  const b = { showId: 'show-a', sessionId: '1900', customerUid: uid, seats,
    showTitle: s.title, showDate: s.showDate, slotTime: slot.time, vendorId: s.vendorId,
    status: 'confirmed', createdAt: serverTimestamp() };
  const event = { vendorId: s.vendorId, showId: 'show-a', sessionId: '1900', bookingId: id, seats,
    showTitle: s.title, slotTime: slot.time, slotTotal: slot.bookedSeats.length + seats.length,
    showTotal: s.bookedCount + seats.length, kind: 'booked', createdAt: serverTimestamp() };
  const show = { bookedCount: s.bookedCount + seats.length, lastBookingId: id, updatedAt: serverTimestamp() };
  const session = { bookedSeats: [...slot.bookedSeats, ...seats], lastBookingId: id, updatedAt: serverTimestamp() };
  mutate({ booking: b, event, show, session });
  return (writer) => {
    if (omit !== 'show') writer.update(doc(db, 'shows/show-a'), show);
    if (omit !== 'session') writer.update(doc(db, sessionPath), session);
    if (omit !== 'booking') writer.set(doc(db, `bookings/${id}`), b);
    if (omit !== 'event') writer.set(doc(db, `bookingEvents/${id}`), event);
  };
}
async function book(db = customer, id = 'booking-a', seats = [1], options = {}) {
  const [s, slot] = await Promise.all([getDoc(doc(db, 'shows/show-a')), getDoc(doc(db, sessionPath))]);
  const batch = writeBatch(db);
  bookingWrites(db, id, seats, s.data(), slot.data(), options)(batch);
  return batch.commit();
}
async function transactionBooking(db, id, seats, uid, { afterRead, mutate } = {}) {
  const requestedSeats = Object.freeze([...seats]);
  const showRef = doc(db, 'shows/show-a');
  const slotRef = doc(db, sessionPath);
  const bookingRef = doc(db, `bookings/${id}`);
  const maxAttempts = 3;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    let inputs;
    try {
      await runTransaction(db, async (tx) => {
        const s = await tx.get(showRef);
        const slot = await tx.get(slotRef);
        inputs = [s, slot];
        // Harness-only observer permits deterministic contention/forgery tests.
        await afterRead?.({ id, seats: requestedSeats, attempt });
        if (requestedSeats.some((seat) => slot.data().bookedSeats.includes(seat))) {
          throw new Error('Seat conflict');
        }
        bookingWrites(db, id, requestedSeats, s.data(), slot.data(), { uid, mutate })(tx);
      });
      return;
    } catch (error) {
      if (error.code !== 'permission-denied' || attempt === maxAttempts || !inputs) throw error;
      let current;
      try {
        // These are the customer's authorized server reads, never admin bypass.
        current = await Promise.all([
          getDocFromServer(bookingRef), getDocFromServer(showRef), getDocFromServer(slotRef),
        ]);
      } catch {
        throw error;
      }
      const [booking, s, slot] = current;
      const authoritative = [...inputs, ...current].every((snapshot) =>
        !snapshot.metadata.fromCache && !snapshot.metadata.hasPendingWrites);
      if (!authoritative || booking.exists() || !s.exists() || !slot.exists()
          || (snapshotEqual(inputs[0], s) && snapshotEqual(inputs[1], slot))) throw error;
      // Rules can reject stale optimistic writes before updateTime contention is
      // returned as ABORTED. Re-enter the entire transaction only with proven
      // changed input and confirmed absence, retaining this exact logical ID.
    }
  }
}
async function markDeleting(db = vendor) {
  return updateDoc(doc(db, 'shows/show-a'), { status: 'deleting', updatedAt: serverTimestamp() });
}
function deletePairs(db, ids) {
  const batch = writeBatch(db);
  for (const id of ids) { batch.delete(doc(db, `bookings/${id}`)); batch.delete(doc(db, `bookingEvents/${id}`)); }
  return batch.commit();
}
async function assertNoBooking(id = 'booking-a') {
  await admin(async (db) => {
    assert.equal((await getDoc(doc(db, `bookings/${id}`))).exists(), false);
    assert.equal((await getDoc(doc(db, `bookingEvents/${id}`))).exists(), false);
    assert.equal((await getDoc(doc(db, 'shows/show-a'))).data().bookedCount, 0);
    assert.deepEqual((await getDoc(doc(db, sessionPath))).data().bookedSeats, []);
  });
}

test('enrolled vendor atomically creates show, JPEG and five deterministic sessions', async () => {
  await assertSucceeds(addShow());
  const snapshots = await getDocs(collection(customer, 'shows/show-a/sessions'));
  assert.equal(snapshots.size, 5);
  assert.equal((await getDoc(doc(customer, 'showImages/show-a'))).data().poster.toUint8Array().length, 4);
});
for (const [name, mutate] of [
  ['invalid calendar date', ({show}) => { show.showDate = '2026-02-31'; }],
  ['invalid leap day', ({show}) => { show.showDate = '2026-02-29'; }],
  ['year zero', ({show}) => { show.showDate = '0000-01-01'; }],
  ['wrong image ID', ({show}) => { show.imageId = 'different'; }],
  ['wrong search title', ({show}) => { show.titleSearch = 'WRONG'; }],
  ['nonzero creation counter', ({show}) => { show.bookedCount = 1; }],
  ['unknown show field', ({show}) => { show.role = 'admin'; }],
  ['oversized image', ({image}) => { image.poster = Bytes.fromUint8Array(new Uint8Array(204801)); }],
  ['empty image', ({image}) => { image.poster = Bytes.fromUint8Array(new Uint8Array()); }],
  ['base64 image', ({image}) => { image.poster = 'not-bytes'; }],
  ['wrong image vendor', ({image}) => { image.vendorId = 'vendor-b'; }],
  ['forged image field', ({image}) => { image.secret = 'x'; }],
  ['invalid time', ({sessions}) => { sessions[0].data.time = '24:00'; }],
  ['noncanonical session ID', ({sessions}) => { sessions[0].id = 'x'; }],
  ['non47 capacity', ({sessions}) => { sessions[0].data.capacity = 48; }],
  ['prebooked session', ({sessions}) => { sessions[0].data.bookedSeats = [1]; }],
  ['forged session timestamp', ({sessions}) => { sessions[0].data.updatedAt = new Date(0); }],
]) {
  test(`addShow denies ${name} and leaves no parent`, async () => {
    await assertFails(addShow(vendor, { mutate }));
    assert.equal((await getDoc(doc(customer, 'shows/show-a'))).exists(), false);
  });
}
for (const [uid, provider] of [['customer-a','password'], ['vendor-disabled','anonymous'], ['vendor-other','anonymous'], ['unknown','anonymous'], [null,'password']]) {
  test(`show creation denies unenrolled or wrong vendor ${uid}`, async () => {
    await assertFails(addShow(databaseFor(uid, provider)));
  });
}
test('show without required paired image and orphan image are denied', async () => {
  await assertFails(addShow(vendor, { image: false }));
  await assertFails(setDoc(doc(vendor, 'showImages/orphan'), imageData()));
});
test('late session addition and session management edits are denied', async () => {
  await addShow();
  await assertFails(setDoc(doc(vendor, 'shows/show-a/sessions/2000'), sessionData('20:00')));
  await assertFails(updateDoc(doc(vendor, sessionPath), { capacity: 40 }));
});
test('documented schema limitation: zero and six sessions cannot be counted by Rules', async () => {
  await assertSucceeds(addShow(vendor, { id: 'no-sessions', slots: [] }));
  await assertSucceeds(addShow(vendor, { id: 'six-sessions', slots: [...times, '20:00'] }));
});

test('customer books row five (11 seats) atomically with exact totals', async () => {
  await addShow();
  const seats = Array.from({length:11}, (_,i) => i + 37);
  await assertSucceeds(book(customer, 'booking-a', seats));
  const own = await getDoc(doc(customer, 'bookings/booking-a'));
  assert.deepEqual(own.data().seats, seats);
  const event = (await getDoc(doc(vendor, 'bookingEvents/booking-a'))).data();
  assert.equal(event.slotTotal, 11); assert.equal(event.showTotal, 11);
  assert.equal('customerUid' in event, false);
});
test('all 47 seats can be booked in one request; 48th seat cannot', async () => {
  await addShow();
  await assertSucceeds(book(customer, 'booking-a', Array.from({length:47}, (_,i) => i+1)));
  await assertFails(book(customer, 'booking-b', [48]));
});
for (const [name, seats, options] of [
  ['empty seats', [], {}], ['duplicate seats', [1,1], {}], ['zero seat', [0], {}], ['out of range seat', [48], {}],
  ['noninteger seat', [1.5], {}], ['string seat', ['1'], {}],
  ['another customer UID', [1], {uid:'customer-b'}],
  ...['show','session','booking','event'].map((omit) => [`missing atomic ${omit}`, [1], {omit}]),
  ['spoofed slot total', [1], {mutate: ({event}) => { event.slotTotal = 2; }}],
  ['spoofed show total', [1], {mutate: ({event}) => { event.showTotal = 2; }}],
  ['spoofed event vendor', [1], {mutate: ({event}) => { event.vendorId = 'vendor-b'; }}],
  ['wrong event booking ID', [1], {mutate: ({event}) => { event.bookingId = 'other'; }}],
  ['customer identity in event', [1], {mutate: ({event}) => { event.customerUid = 'customer-a'; }}],
  ['spoofed booking title', [1], {mutate: ({booking}) => { booking.showTitle = 'Forged'; }}],
  ['spoofed booking date', [1], {mutate: ({booking}) => { booking.showDate = '2000-01-01'; }}],
  ['spoofed slot time', [1], {mutate: ({booking}) => { booking.slotTime = '20:00'; }}],
  ['spoofed status', [1], {mutate: ({booking}) => { booking.status = 'cancelled'; }}],
  ['inflated counter', [1], {mutate: ({show}) => { show.bookedCount = 2; }}],
  ['metadata mutation', [1], {mutate: ({show}) => { show.title = 'Forged'; }}],
  ['capacity mutation', [1], {mutate: ({session}) => { session.capacity = 99; }}],
  ['extra session seat', [1], {mutate: ({session}) => { session.bookedSeats = [1,2]; }}],
  ['mismatched show booking reference', [1], {mutate: ({show}) => { show.lastBookingId = 'wrong'; }}],
]) {
  test(`booking denies ${name} without partial writes`, async () => {
    await addShow(); await assertFails(book(customer, 'booking-a', seats, options)); await assertNoBooking();
  });
}
for (const provider of ['anonymous','google.com']) {
  test(`${provider} identity cannot book or recover customer records`, async () => {
    await addShow(); const db = databaseFor('customer-a', provider);
    await assertFails(book(db)); await assertFails(getDoc(doc(db, 'bookings/missing')));
  });
}
test('overlap rejects all requested seats and cannot remove existing seats', async () => {
  await addShow(); await book();
  await assertFails(book(customer, 'booking-b', [1,2]));
  await assertFails(book(customer, 'booking-c', [2], {mutate: ({session}) => { session.bookedSeats = [2]; }}));
  assert.deepEqual((await getDoc(doc(customer, sessionPath))).data().bookedSeats, [1]);
});
test('existing booking cannot be replayed to inflate counter', async () => {
  await addShow(); await book();
  await assertFails(updateDoc(doc(customer, 'shows/show-a'), {
    bookedCount: 2, lastBookingId: 'booking-a', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(customer, 'bookings/booking-a'), { seats: [1,2] }));
  await assertFails(updateDoc(doc(vendor, 'bookingEvents/booking-a'), { slotTotal: 99 }));
});
test('two customer transaction race has exactly one winner and no partial losing request', async () => {
  await addShow();
  const outcomes = await Promise.allSettled([
    transactionBooking(customer, 'race-a', [1,2], 'customer-a'),
    transactionBooking(databaseFor('customer-b'), 'race-b', [2,3], 'customer-b'),
  ]);
  assert.equal(outcomes.filter((x) => x.status === 'fulfilled').length, 1);
  await admin(async (db) => {
    assert.equal((await getDocs(collection(db, 'bookings'))).size, 1);
    assert.equal((await getDocs(collection(db, 'bookingEvents'))).size, 1);
    assert.equal((await getDoc(doc(db, 'shows/show-a'))).data().bookedCount, 2);
    assert.equal((await getDoc(doc(db, sessionPath))).data().bookedSeats.length, 2);
  });
});
test('concurrent disjoint bookings serialize exact event-time totals', async () => {
  await addShow();
  const observed = [];
  const firstReaders = new Set();
  let release;
  const bothRead = new Promise((resolve) => { release = resolve; });
  const afterRead = async (request) => {
    observed.push(request);
    if (firstReaders.has(request.id)) return;
    firstReaders.add(request.id);
    if (firstReaders.size === 2) release();
    await bothRead;
  };
  await Promise.all([
    transactionBooking(customer, 'race-a', [1,2], 'customer-a', { afterRead }),
    transactionBooking(databaseFor('customer-b'), 'race-b', [3], 'customer-b', { afterRead }),
  ]);
  const events = (await getDocs(query(collection(vendor, 'bookingEvents'), where('vendorId','==','vendor-a')))).docs.map((x) => x.data());
  assert.equal(events.length, 2);
  const totals = events.map((e) => e.showTotal).sort((a,b) => a-b);
  assert.equal(totals[1], 3); assert.ok(totals[0] === 1 || totals[0] === 2);
  assert.ok(events.every((e) => e.showTotal === e.slotTotal));
  assert.ok(observed.length >= 3, 'forced contention must rerun a transaction callback');
  for (const request of observed) {
    assert.deepEqual(request.seats, request.id === 'race-a' ? [1,2] : [3]);
  }
  assert.deepEqual(events.map((event) => event.bookingId).sort(), ['race-a', 'race-b']);
  assert.deepEqual((await getDocFromServer(doc(customer, sessionPath))).data().bookedSeats.sort(), [1,2,3]);
});

test('unchanged permission denial is not retried', async () => {
  await addShow();
  let callbacks = 0;
  await assertFails(transactionBooking(customer, 'forged', [1], 'customer-a', {
    afterRead: () => { callbacks++; },
    mutate: ({show, event}) => { show.bookedCount++; event.showTotal++; },
  }));
  assert.equal(callbacks, 1);
  await assertNoBooking('forged');
});

test('changed inputs do not authorize forged transaction payloads', async () => {
  await addShow();
  let callbacks = 0;
  await assertFails(transactionBooking(customer, 'forged', [4], 'customer-a', {
    afterRead: async () => {
      if (++callbacks === 1) {
        await book(databaseFor('customer-b'), 'contender', [1,2], { uid: 'customer-b' });
      }
    },
    mutate: ({show, event}) => { show.bookedCount++; event.showTotal++; },
  }));
  assert.equal(callbacks, 2, 'changed authoritative inputs permit one fresh attempt, not permission bypass');
  await admin(async (db) => {
    assert.equal((await getDoc(doc(db, 'bookings/forged'))).exists(), false);
    assert.equal((await getDoc(doc(db, 'bookingEvents/forged'))).exists(), false);
    assert.equal((await getDoc(doc(db, 'shows/show-a'))).data().bookedCount, 2);
    assert.deepEqual((await getDoc(doc(db, sessionPath))).data().bookedSeats, [1,2]);
  });
});

test('continually changed inputs cannot exceed the three-attempt bound', async () => {
  await addShow();
  let callbacks = 0;
  await assertFails(transactionBooking(customer, 'forged', [47], 'customer-a', {
    afterRead: async ({attempt}) => {
      callbacks++;
      await book(databaseFor('customer-b'), `contender-${attempt}`, [10 + attempt], { uid: 'customer-b' });
    },
    mutate: ({show, event}) => { show.bookedCount++; event.showTotal++; },
  }));
  assert.equal(callbacks, 3);
  await admin(async (db) => {
    assert.equal((await getDoc(doc(db, 'bookings/forged'))).exists(), false);
    assert.equal((await getDoc(doc(db, 'bookingEvents/forged'))).exists(), false);
    assert.equal((await getDocs(collection(db, 'bookings'))).size, 3);
    assert.equal((await getDoc(doc(db, 'shows/show-a'))).data().bookedCount, 3);
  });
});

test('contention retry snapshots the same logical ID and seats', async () => {
  await addShow();
  const requestedSeats = [3];
  const observed = [];
  await transactionBooking(customer, 'stable-reference', requestedSeats, 'customer-a', {
    afterRead: async (request) => {
      observed.push(request);
      if (observed.length === 1) {
        requestedSeats.push(47);
        await book(databaseFor('customer-b'), 'contender', [1], { uid: 'customer-b' });
      }
    },
  });
  assert.equal(observed.length, 2);
  for (const request of observed) {
    assert.equal(request.id, 'stable-reference');
    assert.deepEqual(request.seats, [3]);
  }
  const booking = (await getDocFromServer(doc(customer, 'bookings/stable-reference'))).data();
  assert.deepEqual(booking.seats, [3]);
  assert.equal(booking.customerUid, 'customer-a');
  assert.deepEqual(requestedSeats, [3,47]);
});

for (const owner of ['customer-a', 'customer-b']) {
  test(`existing ${owner} booking is never overwritten or retried after denial`, async () => {
    await addShow();
    await book(databaseFor(owner), 'existing', [1], { uid: owner });
    let callbacks = 0;
    await assertFails(transactionBooking(customer, 'existing', [3], 'customer-a', {
      afterRead: async () => {
        callbacks++;
        await book(databaseFor('customer-b'), 'contender', [2], { uid: 'customer-b' });
      },
    }));
    assert.equal(callbacks, 1, 'existing or unreadable recovery evidence cannot justify retry');
    await admin(async (db) => {
      const booking = (await getDoc(doc(db, 'bookings/existing'))).data();
      assert.equal(booking.customerUid, owner);
      assert.deepEqual(booking.seats, [1]);
      assert.equal((await getDocs(collection(db, 'bookings'))).size, 2);
    });
  });
}

test('server missing recovery allowed; another owner and anonymous existing booking denied', async () => {
  await addShow(); await book();
  const missing = await assertSucceeds(getDocFromServer(doc(customer, 'bookings/missing')));
  assert.equal(missing.exists(), false); assert.equal(missing.metadata.fromCache, false);
  await assertSucceeds(getDocFromServer(doc(customer, 'bookings/booking-a')));
  for (const db of [databaseFor('customer-b'), vendor, databaseFor(null)]) {
    await assertFails(getDocFromServer(doc(db, 'bookings/booking-a')));
  }
});
test('owner query works with all four filters; unscoped or other-owner queries denied', async () => {
  await addShow(); await book();
  const scoped = query(collection(customer, 'bookings'), where('customerUid','==','customer-a'),
    where('showId','==','show-a'), where('sessionId','==','1900'), where('status','==','confirmed'));
  assert.equal((await assertSucceeds(getDocs(scoped))).size, 1);
  await assertFails(getDocs(collection(customer, 'bookings')));
  await assertFails(getDocs(query(collection(databaseFor('customer-b'), 'bookings'), where('customerUid','==','customer-a'))));
});
test('feed filters active shows, direct deleting/missing gets work, vendor event scope enforced', async () => {
  await addShow(); await book();
  await assertSucceeds(getDocs(query(collection(customer, 'shows'), where('status','==','active'))));
  await assertFails(getDocs(collection(customer, 'shows')));
  await assertFails(getDocs(collection(customer, 'bookingEvents')));
  await assertFails(getDocs(collection(vendor, 'bookingEvents')));
  await assertFails(getDoc(doc(databaseFor('vendor-other', 'anonymous'), 'bookingEvents/booking-a')));
  await markDeleting();
  assert.equal((await getDoc(doc(customer, 'shows/show-a'))).data().status, 'deleting');
  assert.equal((await getDoc(doc(customer, 'shows/missing'))).exists(), false);
});

test('active show/children cannot be deleted, counters cannot be reset by vendor', async () => {
  await addShow(); await book();
  for (const path of ['shows/show-a','showImages/show-a',sessionPath,'bookings/booking-a','bookingEvents/booking-a']) {
    await assertFails(deleteDoc(doc(vendor, path)));
  }
  await assertFails(updateDoc(doc(vendor, 'shows/show-a'), { bookedCount: 0, updatedAt: serverTimestamp() }));
});
test('deleting blocks booking, reactivation and standalone pair deletes', async () => {
  await addShow(); await book(); await markDeleting();
  await assertFails(book(customer, 'booking-b', [2]));
  await assertFails(updateDoc(doc(vendor, 'shows/show-a'), {status:'active', updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(doc(vendor, 'bookings/booking-a')));
  await assertFails(deleteDoc(doc(vendor, 'bookingEvents/booking-a')));
  await assertFails(deletePairs(databaseFor('vendor-other','anonymous'), ['booking-a']));
  await assertFails(deletePairs(customer, ['booking-a']));
});
test('three-pair cleanup fits uncached18 calls; sessions/image cleanup then parent removal', async () => {
  await addShow();
  for (let i = 1; i <= 3; i++) await book(customer, `booking-${i}`, [i]);
  await markDeleting(); await assertSucceeds(deletePairs(vendor, ['booking-1','booking-2','booking-3']));
  await assertFails(deleteDoc(doc(vendor, 'shows/show-a')));
  const cleanup = writeBatch(vendor);
  for (const time of times) cleanup.delete(doc(vendor, `shows/show-a/sessions/${time.replace(':','')}`));
  cleanup.delete(doc(vendor, 'showImages/show-a')); await assertSucceeds(cleanup.commit());
  await assertSucceeds(deleteDoc(doc(vendor, 'shows/show-a')));
  await admin(async (db) => {
    for (const path of ['shows','showImages','bookings','bookingEvents','shows/show-a/sessions']) {
      assert.equal((await getDocs(collection(db, path))).size, 0);
    }
  });
});
test('four-pair runtime works with emulator caching; not an uncached24-call guarantee', async () => {
  await addShow();
  for (let i = 1; i <= 4; i++) await book(customer, `booking-${i}`, [i]);
  await markDeleting(); await assertSucceeds(deletePairs(vendor, ['booking-1','booking-2','booking-3','booking-4']));
});
test('documented schema limitation: parent deletion cannot prove arbitrary children empty', async () => {
  await addShow(); await book(); await markDeleting();
  await deleteDoc(doc(vendor, 'showImages/show-a'));
  await assertSucceeds(deleteDoc(doc(vendor, 'shows/show-a')));
  await admin(async (db) => assert.equal((await getDoc(doc(db, sessionPath))).exists(), true));
});
test('profile create/get/update are owner-scoped and enrollment cannot be forged', async () => {
  await assertSucceeds(setDoc(doc(customer, 'users/customer-a'), {
    email:'customer-a@example.test', createdAt:serverTimestamp(), displayName:'Customer A',
  }));
  await assertSucceeds(getDoc(doc(customer, 'users/customer-a')));
  await assertSucceeds(updateDoc(doc(customer, 'users/customer-a'), {displayName:'New name'}));
  await assertFails(getDoc(doc(databaseFor('customer-b'), 'users/customer-a')));
  await assertFails(updateDoc(doc(customer, 'users/customer-a'), {role:'vendor'}));
  await assertFails(setDoc(doc(customer, 'vendorDevices/customer-a'), {enabled:true,vendorId:'vendor-a'}));
  await assertSucceeds(getDoc(doc(vendor, 'vendorDevices/vendor-device')));
  await assertFails(getDoc(doc(customer, 'vendorDevices/vendor-device')));
  await assertFails(getDocs(collection(vendor, 'vendorDevices')));
  await assertFails(setDoc(doc(customer,'unexpected/document'), {x:1}));
  await assertFails(getDoc(doc(customer,'unexpected/document')));
});
