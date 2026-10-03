// Crée (ou retrouve) le compte unique du pilote GazGap. Usage :
//   node bootstrap-user.js --project gazgap-7eb3a --email pilote@x.fr
// Identifiants : gcloud auth application-default login (compte propriétaire du projet).
const admin = require("firebase-admin");

const arg = (k) => {
  const i = process.argv.indexOf(`--${k}`);
  return i > 0 ? process.argv[i + 1] : undefined;
};
const projectId = arg("project");
const email = (arg("email") || "").trim().toLowerCase();
if (!projectId || !email) {
  console.error("Usage : --project <id> --email <e-mail>");
  process.exit(1);
}

admin.initializeApp({ projectId });

(async () => {
  const auth = admin.auth();
  let uid;
  try {
    uid = (await auth.getUserByEmail(email)).uid;
    console.log(`Compte existant : ${email} (uid ${uid}).`);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    uid = (await auth.createUser({ email })).uid;
    console.log(`Compte créé : ${email} (uid ${uid}).`);
  }
  const link = await auth.generatePasswordResetLink(email);
  console.log(`Lien pour définir le mot de passe : ${link}`);
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
