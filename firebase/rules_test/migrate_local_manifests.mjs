import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, collectionGroup, getDocs, updateDoc } from 'firebase/firestore';
import { pathToFileURL } from 'node:url';

// Run with writers paused. Inspect the entire inventory before applying any update.
export async function migrateLocalManifests(db, apply = false) {
  const shows = await getDocs(collection(db, 'shows'));
  const slots = new Map(shows.docs.map(show => [show.id, []]));
  for (const child of (await getDocs(collectionGroup(db, 'sessions'))).docs) {
    const parent = child.ref.parent.parent;
    if (parent?.parent.path !== 'shows' || !slots.has(parent.id)) {
      throw new Error('Orphan or unexpected session: ' + child.ref.path);
    }
    const time = child.data().time;
    if (typeof time !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(time) ||
        child.id !== time.replace(':', '')) throw new Error('Invalid session: ' + child.ref.path);
    slots.get(parent.id).push(child.id);
  }
  const changes = [];
  for (const show of shows.docs) {
    const { status, sessionIds } = show.data();
    const children = slots.get(show.id).sort();
    const ids = sessionIds === undefined ? children : sessionIds;
    if (!['active', 'deleting'].includes(status) || !Array.isArray(ids) ||
        ids.length > 5 || (status === 'active' && ids.length !== children.length) ||
        (status === 'active' && !ids.length) || new Set(ids).size !== ids.length ||
        !ids.every(id => typeof id === 'string' && /^([01]\d|2[0-3])[0-5]\d$/.test(id)) ||
        !children.every(id => ids.includes(id))) throw new Error('Review show: ' + show.id);
    if (sessionIds === undefined) changes.push([show.ref, children]);
  }
  if (apply) {
    for (const [ref, sessionIds] of changes) await updateDoc(ref, {sessionIds});
  }
  return changes.map(([ref]) => ref.id);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const environment = await initializeTestEnvironment({
    projectId: 'demo-arenapass', firestore: {host: '127.0.0.1', port: 8180},
  });
  try {
    await environment.withSecurityRulesDisabled(async context => {
      console.log(await migrateLocalManifests(context.firestore(), process.argv[2] === '--apply'));
    });
  } finally {
    await environment.cleanup();
  }
}
