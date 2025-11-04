const admin = require("firebase-admin");

// Load the service account JSON
const serviceAccount = require("./serviceAccount.json"); // rename to match your file name

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function setAdmin() {
  const uid = "fFISSLIjX4W9EqfzqMSmapWPKzT2"; // get this from Firebase Auth → Users
  await admin.auth().setCustomUserClaims(uid, { admin: true });
  console.log("✅ Admin claim set for:", uid);
}

setAdmin();
