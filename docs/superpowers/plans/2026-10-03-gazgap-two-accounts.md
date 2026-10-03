# GazGap Two Equal-Rights Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace GazGap's single-account Firestore access rule with one that recognizes exactly two accounts (pilote + administrateur/technique), both with identical rights, instead of accepting any authenticated Firebase user.

**Architecture:** This is a config-only delta on top of the already-shipped GazGap app (14 prior tasks, all merged to `main`). No Flutter code changes: `AuthService`, `AppGate`, and `PlanningScreen` never branch on *which* account is signed in, only *whether* one is. The only artifact that encodes "how many accounts" is `firestore.rules`, where `request.auth != null` becomes `request.auth.uid in [UID_PILOTE, UID_ADMIN]`. `scripts/bootstrap-user.js` already takes `--email` as a parameter and needs no code change to be run twice.

**Tech Stack:** Firestore Security Rules (no new app dependencies).

**Spec:** `docs/superpowers/specs/2026-10-03-gazgap-app-design.md` (amended: §"Décisions structurantes" → Comptes, §"Hors périmètre", §1.1, §4 — all updated from "un seul compte" to "deux comptes, droits identiques")

## Global Constraints

- Droits strictement identiques entre les deux comptes — pas de matrice de droits, pas de champ de rôle, pas de collection `users` (spec §1.1, §"Hors périmètre").
- UID codés en dur dans `firestore.rules`, pas dans une collection Firestore (spec §4) — même philosophie que les hélicos `H1`/`H2` codés en dur dans l'app.
- Pas de Cloud Functions, pas d'écran de gestion des comptes (spec, Hors périmètre).
- La création réelle des deux comptes et le déploiement des règles touchent le projet Firebase **en production** (`gazgap-7eb3a`, pas de séparation dev/prod) — gated, nécessite confirmation explicite de l'utilisateur, ce n'est pas une tâche TDD.

## Review Focus

- Un troisième compte Firebase Auth (par exemple auto-inscrit, puisque l'auto-inscription email/mot de passe est activée par défaut) ne doit **jamais** satisfaire la règle une fois les deux UID pinnés — seuls les deux UID exacts doivent passer. Pas de test automatisé possible ici (pas d'émulateur Firestore dans ce projet, par choix explicite du spec) ; à vérifier manuellement en Task 3 avant le déploiement réel, en relisant la règle écrite en Task 1 caractère par caractère contre la spec.
- Les deux comptes doivent avoir des droits strictement identiques : aucune branche de code, aucune règle, ne doit distinguer `UID_PILOTE` de `UID_ADMIN`. Si une différence apparaît dans l'implémentation, c'est un défaut (couvert par la relecture de Task 1, pas par un test automatisé).
- Le placeholder des UID doit être impossible à déployer par erreur sans les avoir remplacés : la Task 1 doit rendre ce risque visible (commentaire explicite + valeurs reconnaissables comme non réelles), pas silencieux.

---

## Task 1: Pin `firestore.rules` to two accounts

**Files:**
- Modify: `firestore.rules`

**Interfaces:** Aucune — fichier de configuration, pas de code Dart consommé ni produit.

- [ ] **Step 1: Lire le fichier actuel**

```bash
cat /home/cedric/StudioProjects/gazgap/firestore.rules
```

Expected:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Un seul compte existera jamais côté client : l'authentification suffit.
    match /flights/{id} {
      allow read, write: if request.auth != null;
    }

    // Tout le reste : refusé (pas de users/profiles/aircraft/settings).
    match /{document=**} { allow read, write: if false; }
  }
}
```

- [ ] **Step 2: Remplacer la règle par la version à deux comptes**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Exactement deux comptes, droits identiques (pilote + administrateur/
    // technique) : pas de matrice de droits, juste ces deux UID. Remplacer
    // les deux valeurs ci-dessous par les UID réels avant tout déploiement
    // (voir Task 3) — tant qu'elles gardent ce préfixe, le déploiement doit
    // être refusé en revue.
    function isPiloteOuAdmin() {
      return request.auth != null &&
        request.auth.uid in [
          'REMPLACER_PAR_UID_PILOTE',
          'REMPLACER_PAR_UID_ADMIN'
        ];
    }

    match /flights/{id} {
      allow read, write: if isPiloteOuAdmin();
    }

    // Tout le reste : refusé (pas de users/profiles/aircraft/settings).
    match /{document=**} { allow read, write: if false; }
  }
}
```

- [ ] **Step 3: Écrire le fichier**

```bash
cat > /home/cedric/StudioProjects/gazgap/firestore.rules << 'EOF'
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Exactement deux comptes, droits identiques (pilote + administrateur/
    // technique) : pas de matrice de droits, juste ces deux UID. Remplacer
    // les deux valeurs ci-dessous par les UID réels avant tout déploiement
    // (voir Task 3) — tant qu'elles gardent ce préfixe, le déploiement doit
    // être refusé en revue.
    function isPiloteOuAdmin() {
      return request.auth != null &&
        request.auth.uid in [
          'REMPLACER_PAR_UID_PILOTE',
          'REMPLACER_PAR_UID_ADMIN'
        ];
    }

    match /flights/{id} {
      allow read, write: if isPiloteOuAdmin();
    }

    // Tout le reste : refusé (pas de users/profiles/aircraft/settings).
    match /{document=**} { allow read, write: if false; }
  }
}
EOF
```

- [ ] **Step 4: Relire le fichier écrit, le comparer caractère par caractère au bloc du Step 2**

```bash
cat /home/cedric/StudioProjects/gazgap/firestore.rules
```

Expected: identique au bloc du Step 2. C'est la seule vérification possible ici — pas d'émulateur Firestore dans ce projet (spec : pas de tests d'intégration), donc pas de `firebase emulators:exec` à lancer. La vérification comportementale réelle (un troisième compte est bien refusé) aura lieu une fois les UID réels en place, lors du déploiement gated en Task 3.

- [ ] **Step 5: Vérifier que le reste du projet est toujours sain**

```bash
cd /home/cedric/StudioProjects/gazgap && fvm flutter analyze && fvm flutter test
```

Expected: `No issues found!`, tous les tests passent (ce fichier n'est pas Dart, donc ces commandes ne le couvrent pas directement — elles confirment juste qu'aucun autre fichier n'a été touché par erreur).

- [ ] **Step 6: Commit**

```bash
git add firestore.rules
git commit -m "feat: règles Firestore pinnées sur deux comptes (placeholders UID)"
```

---

## Task 2: Corriger le commentaire d'en-tête de `scripts/bootstrap-user.js`

**Files:**
- Modify: `scripts/bootstrap-user.js:1-3`

**Interfaces:** Aucune — le script garde exactement la même signature CLI (`--project`, `--email`) et le même comportement ; seul son commentaire d'en-tête est corrigé pour ne plus dire « le compte unique ».

- [ ] **Step 1: Lire l'en-tête actuel**

```bash
sed -n '1,3p' /home/cedric/StudioProjects/gazgap/scripts/bootstrap-user.js
```

Expected:
```js
// Crée (ou retrouve) le compte unique du pilote GazGap. Usage :
//   node bootstrap-user.js --project gazgap-7eb3a --email pilote@x.fr
// Identifiants : gcloud auth application-default login (compte propriétaire du projet).
```

- [ ] **Step 2: Corriger**

Remplacer la première ligne par :
```js
// Crée (ou retrouve) un compte GazGap (pilote OU administrateur — même
// script, lancé une fois par compte ; les deux ont des droits identiques).
// Usage :
```

- [ ] **Step 3: Vérifier le résultat**

```bash
sed -n '1,4p' /home/cedric/StudioProjects/gazgap/scripts/bootstrap-user.js
```

Expected:
```js
// Crée (ou retrouve) un compte GazGap (pilote OU administrateur — même
// script, lancé une fois par compte ; les deux ont des droits identiques).
// Usage :
//   node bootstrap-user.js --project gazgap-7eb3a --email pilote@x.fr
```

- [ ] **Step 4: Commit**

```bash
git add scripts/bootstrap-user.js
git commit -m "docs: bootstrap-user.js sert aux deux comptes, pas à un compte unique"
```

---

## Task 3: Mise en service — créer les deux comptes réels et déployer la règle pinnée

**Files:** aucun fichier nouveau — exécution d'actions contre le projet Firebase réel `gazgap-7eb3a`, et édition finale de `firestore.rules` avec les vrais UID.

**⚠️ Ces actions modifient un système partagé réel (le projet Firebase de production, qui n'a pas de séparation dev/prod). Demander confirmation explicite à l'utilisateur avant de les exécuter, en lui demandant les deux adresses e-mail (pilote et administrateur) si elles ne sont pas déjà connues.** C'est la même étape que l'ancienne « Task 15 » du plan précédent (déploiement des règles + création du compte), simplement étendue à deux comptes.

- [ ] **Step 1: Créer le compte pilote**

```bash
cd /home/cedric/StudioProjects/gazgap/scripts
node bootstrap-user.js --project gazgap-7eb3a --email <email-du-pilote>
```

Expected: affiche `Compte créé : <email> (uid ...)` et un lien de définition de mot de passe. **Noter cet UID.**

- [ ] **Step 2: Créer le compte administrateur**

```bash
node bootstrap-user.js --project gazgap-7eb3a --email <email-de-l-administrateur>
cd ..
```

Expected: même sortie, UID différent. **Noter cet UID.**

- [ ] **Step 3: Remplacer les deux placeholders dans `firestore.rules` par les UID réels**

Éditer `firestore.rules` : remplacer `'REMPLACER_PAR_UID_PILOTE'` par l'UID noté au Step 1, et `'REMPLACER_PAR_UID_ADMIN'` par l'UID noté au Step 2.

- [ ] **Step 4: Relire la règle finale avant déploiement**

```bash
cat /home/cedric/StudioProjects/gazgap/firestore.rules
```

Expected : aucune occurrence de `REMPLACER_PAR_UID` ne subsiste ; les deux UID présents sont ceux notés aux Steps 1 et 2, et aucun autre.

- [ ] **Step 5: Commit la règle finale (sans les placeholders)**

```bash
git add firestore.rules
git commit -m "chore: UID réels dans firestore.rules (pilote + administrateur)"
```

- [ ] **Step 6: Déployer les règles**

```bash
firebase deploy --only firestore:rules --project gazgap-7eb3a
```

Expected: `+  firestore: released rules firestore.rules to cloud.firestore`.

- [ ] **Step 7: Vérification manuelle de bout en bout**

```bash
fvm flutter run -d chrome
```

Se connecter avec le compte pilote (après avoir défini le mot de passe via le lien reçu au Step 1), créer un vol. Se déconnecter, se connecter avec le compte administrateur (mot de passe défini via le lien du Step 2), vérifier que le même vol est visible et modifiable.

- [ ] **Step 8 (recommandé, repris de la revue finale du plan précédent) : désactiver l'auto-inscription**

Dans la console Firebase (Authentication → Settings → User actions), désactiver « Enable create (sign-up) ». Sans cette étape, l'auto-inscription reste possible mais n'a plus d'effet sur `flights` (la règle ne reconnaît que les deux UID pinnés) — l'étape reste recommandée en défense en profondeur, pas strictement nécessaire pour la sécurité des données.

---

## Self-Review (effectuée par l'auteur du plan)

**Couverture de la spec :** §"Décisions structurantes" (Comptes, deux comptes droits identiques) → Task 1 (règle) + Task 3 (comptes réels) ; §"Hors périmètre" (pas de matrice de droits) → respecté, aucune des deux tâches n'introduit de rôle ou de collection `users` ; §1.1 (UID codés en dur, pas de collection) → Task 1 ; §4 (règle pinnée sur deux UID, script réutilisé sans changement de code) → Tasks 1, 2, 3.

**Pas de changement d'app Flutter** : confirmé par relecture de `lib/data/auth_service.dart`, `lib/features/auth/gate.dart`, `lib/features/planning/planning_screen.dart` — aucun ne lit `request.auth.uid` ni ne branche sur l'identité du compte connecté, donc rien à modifier côté app.

**Hors scope confirmé par la spec, non traité** : écran de gestion des comptes, champ de rôle, collection `users` — explicitement exclus.
