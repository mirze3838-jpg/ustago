const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Look for service account key
let keyPath = null;
const possibleKeys = [
  './serviceAccountKey.json',
  '../serviceAccountKey.json',
  'C:/Users/Acer/.gemini/antigravity/scratch/ustago/serviceAccountKey.json'
];
for (const p of possibleKeys) {
  if (fs.existsSync(p)) { keyPath = p; break; }
}

if (!keyPath) {
  console.log('No serviceAccountKey.json found directly. Checking other locations...');
  // Let's check environment or existing keys
} else {
  admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(keyPath))) });
  const db = admin.firestore();
  async function clean() {
    const snap = await db.collection('posts').get();
    console.log('Found posts count:', snap.size);
    for (const doc of snap.docs) {
      console.log('Deleting post doc:', doc.id, doc.data().title || doc.data().description);
      await doc.ref.delete();
    }
    console.log('All posts deleted successfully!');
  }
  clean().catch(console.error);
}
