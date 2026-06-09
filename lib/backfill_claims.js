const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function backfillClaims() {
  console.log('Starting claim backfill...');
  const snap = await db.collection('users').get();
  console.log(`Found ${snap.docs.length} users.`);

  let success = 0, skipped = 0, failed = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const uid = doc.id;
    const role = data.role;

    if (!role || !['client', 'fundi', 'admin'].includes(role)) {
      console.log(`SKIP ${uid} — no valid role (role=${role})`);
      skipped++;
      continue;
    }

    try {
      await auth.setCustomUserClaims(uid, { role });
      console.log(`OK   ${uid} → role=${role}`);
      success++;
    } catch (err) {
      console.log(`FAIL ${uid} — ${err.message}`);
      failed++;
    }
  }

  console.log('');
  console.log('===== DONE =====');
  console.log(`Success: ${success}`);
  console.log(`Skipped: ${skipped}`);
  console.log(`Failed:  ${failed}`);
  process.exit(0);
}

backfillClaims().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});