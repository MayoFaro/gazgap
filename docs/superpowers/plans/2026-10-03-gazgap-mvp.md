# GazGap MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the GazGap Flutter app (Android + web) letting the single pilot plan, edit, delete and change the status of helicopter flights, writing directly to Firestore so the future AppGAP bridge can read `flights`.

**Architecture:** A deliberately thin app mirroring the sibling `UlmGap` project's patterns (same `AppServices` InheritedWidget, same `AuthService`/Gate split) but stripped to the spec's KISS requirements: no Cloud Functions, no multi-user rights, two hard-coded helicopters, direct client writes to a single `flights` collection.

**Tech Stack:** Flutter 3.32.8 via `fvm`, `firebase_core`/`cloud_firestore`/`firebase_auth`, `intl`, Firebase project `gazgap-7eb3a` (already created, has one registered Android app).

**Spec:** `docs/superpowers/specs/2026-10-03-gazgap-app-design.md`

**Decision made with the user before this plan:** the spec's `flights` model only has a `start` timestamp, no end/duration — but the Planning screen must warn on schedule overlap for the same helicopter. The user chose to add a non-contract field `dureeMinutes` (int, default 60) to `flights`, used only to compute `end = start + dureeMinutes` for the overlap check. This field is **not** one of the `(contrat)` fields in spec §1.1 — the future AppGAP bridge is not required to read it.

## Global Constraints

- Flutter **3.32.8** via `fvm` (`fvm flutter`, `fvm dart`), Dart SDK `^3.8.1`.
- Platforms: **Android et web uniquement** (pas d'iOS).
- **Un seul projet Firebase** (`gazgap-7eb3a`): pas de `--dart-define=ENV`, pas de flavors Android, pas de `firebase_options_dev.dart`/`_prod.dart`.
- **Écritures directes depuis le client**, sécurisées par les règles Firestore. **Pas de Cloud Functions pour le CRUD.**
- Comptes: **un seul compte** Firebase Auth e-mail/mot de passe, créé à la main, pas d'inscription libre.
- Hélicos: **2, fixes**, codés en dur dans l'app (`H1`/`H2`), pas de collection Firestore dédiée.
- Champs **(contrat)** de `flights` (`helicoId`, `start`, `destination`, `remarque`, `statut`): noms et sens figés — ne jamais les renommer, le futur pont AppGAP les lit tels quels.
- Principe **KISS**, plus strict qu'UlmGap: pas de matrice de droits, pas d'équipage, pas de carburant, pas de finances.
- Tests: `fvm flutter test && fvm flutter analyze`. **Pas de tests d'intégration** pour le code qui parle réellement à Firebase (`FirebaseAuthService`, `FirebaseFlightApi`) — seule la logique pure (modèles, overlap, messages d'erreur) est couverte par des tests unitaires ; les écrans sont couverts par des tests widget utilisant des doublures (`FakeAuthService`, `FakeFlightApi`).

## Review Focus

- Un avertissement de chevauchement ne doit apparaître **que** entre deux vols du **même hélico** et **ni l'un ni l'autre `annule`** — deux vols sur des hélicos différents, ou impliquant un vol annulé, ne doivent jamais se signaler. (Task 5, re-exercé en Task 12.)
- Supprimer ou annuler le vol responsable d'un chevauchement doit faire disparaître l'avertissement sur l'autre vol dès que le flux Firestore réémet la liste. (Task 12.)
- Soumettre le formulaire avec une destination vide, une date/heure non parsable ou une durée nulle/négative doit bloquer l'enregistrement avec un message visible, sans jamais écrire de données invalides. (Task 11.)
- Un échec d'écriture Firestore (création, modification, suppression, changement de statut) doit afficher un message, pas planter l'écran ni laisser un bouton bloqué en état "occupé". (Task 12.)
- Une connexion avec un mauvais mot de passe doit afficher un message en français sans faire planter l'écran de connexion. (Task 9.)

---

## Task 1: Scaffold du projet Flutter

**Files:**
- Create: `pubspec.yaml` (généré puis ajusté), `.fvmrc`, `analysis_options.yaml`, `.gitignore`, `android/`, `web/`, `lib/main.dart` (généré, sera remplacé en Task 13), `test/widget_test.dart` (généré, sera supprimé)
- Modify: `android/app/build.gradle.kts` (applicationId/namespace)

**Interfaces:** Aucune — tâche d'infrastructure, rien à consommer ni à produire pour les tâches suivantes à part l'arborescence du projet.

- [ ] **Step 1: Épingler la version Flutter**

```bash
cd /home/cedric/StudioProjects/gazgap
fvm use 3.32.8 --force
```

Expected: crée `.fvmrc` avec `{"flutter":"3.32.8"}` et un lien `.fvm/`.

- [ ] **Step 2: Créer le projet Flutter dans le repo existant**

```bash
fvm flutter create --platforms=android,web --org com.gazgap --project-name gazgap .
```

Expected: génère `lib/main.dart`, `pubspec.yaml`, `android/`, `web/`, `test/widget_test.dart` sans toucher à `docs/` ni `.git/`.

- [ ] **Step 3: Faire correspondre l'`applicationId` Android à l'app déjà enregistrée dans Firebase**

Le projet Firebase `gazgap-7eb3a` a déjà une app Android enregistrée avec le package `com.gazgap.gap` (vérifié via `firebase apps:sdkconfig`). `flutter create --org com.gazgap --project-name gazgap` produit `com.gazgap.gazgap` — à corriger pour que `flutterfire configure` (Task 2) réutilise l'app existante au lieu d'en créer une en double.

Dans `android/app/build.gradle.kts`, remplacer :
```kotlin
namespace = "com.gazgap.gazgap"
...
applicationId = "com.gazgap.gazgap"
```
par :
```kotlin
namespace = "com.gazgap.gap"
...
applicationId = "com.gazgap.gap"
```

- [ ] **Step 4: Nettoyer le squelette généré**

Supprimer `test/widget_test.dart` (contenu par défaut, sans rapport avec l'app) :

```bash
rm test/widget_test.dart
```

- [ ] **Step 5: Vérifier que le projet s'analyse sans erreur**

```bash
fvm flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold du projet Flutter GazGap (android+web)"
```

---

## Task 2: Intégration Firebase (projet unique, pas de flavors)

**Files:**
- Modify: `pubspec.yaml` (dépendances)
- Create: `lib/firebase_options.dart` (généré par `flutterfire configure`), `firebase.json`, `.firebaserc`, `firestore.rules`, `firestore.indexes.json`

**Interfaces:**
- Produces: `DefaultFirebaseOptions.currentPlatform` (classe générée, consommée par `lib/main.dart` en Task 13).

- [ ] **Step 1: Ajouter les dépendances Firebase et utilitaires**

Dans `pubspec.yaml`, sous `dependencies:` :

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.15.0
  cloud_firestore: ^6.10.0
  firebase_auth: ^6.7.0
  intl: ^0.20.2
  flutter_localizations:
    sdk: flutter
```

et sous `dev_dependencies:` (en plus de ce que `flutter create` a déjà mis) :

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

```bash
fvm flutter pub get
```

Expected: `pubspec.lock` mis à jour, pas d'erreur de résolution.

- [ ] **Step 2: Générer `firebase_options.dart` pour le projet unique `gazgap-7eb3a`**

```bash
flutterfire configure \
  --project=gazgap-7eb3a \
  --platforms=android,web \
  --android-package-name=com.gazgap.gap \
  --out=lib/firebase_options.dart \
  --yes
```

Expected: réutilise l'app Android déjà enregistrée (`com.gazgap.gap`), crée une app Web dans le projet Firebase si elle n'existe pas encore, écrit `lib/firebase_options.dart` avec une seule classe `DefaultFirebaseOptions` (pas de `_dev`/`_prod`). Ajoute aussi `firebase_core` à `pubspec.yaml` s'il ne l'a pas déjà détecté (sans effet, déjà présent).

- [ ] **Step 3: Écrire la configuration Firebase du projet**

Create `.firebaserc`:
```json
{
  "projects": {
    "default": "gazgap-7eb3a"
  }
}
```

Create `firestore.indexes.json`:
```json
{
  "indexes": [],
  "fieldOverrides": []
}
```

Create `firebase.json`:
```json
{
  "firestore": {
    "database": "(default)",
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{ "source": "**", "destination": "/index.html" }]
  },
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "ui": { "enabled": false }
  }
}
```

Create `firestore.rules`:
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

- [ ] **Step 4: Vérifier que l'app compile toujours**

```bash
fvm flutter analyze
```

Expected: `No issues found!` (le `lib/main.dart` généré par `flutter create` ne référence pas encore `firebase_options.dart` — c'est normal, il sera remplacé en Task 13).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: configuration Firebase (projet unique gazgap-7eb3a)"
```

---

## Task 3: Hélicos fixes

**Files:**
- Create: `lib/core/helicos.dart`
- Test: `test/core/helicos_test.dart`

**Interfaces:**
- Produces: `enum Helico { h1, h2 }` avec `id` (String, `'H1'`/`'H2'`), `label` (String) ; `Helico.fromId(String?) → Helico?`.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/core/helicos_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/core/helicos.dart';

void main() {
  test('fromId : retrouve H1 et H2', () {
    expect(Helico.fromId('H1'), Helico.h1);
    expect(Helico.fromId('H2'), Helico.h2);
  });

  test('fromId : code inconnu ou null renvoie null', () {
    expect(Helico.fromId('H3'), isNull);
    expect(Helico.fromId(null), isNull);
  });

  test('id et label sont distincts pour chaque hélico', () {
    expect(Helico.h1.id, 'H1');
    expect(Helico.h2.id, 'H2');
    expect(Helico.h1.label, isNot(Helico.h2.label));
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

```bash
fvm flutter test test/core/helicos_test.dart
```

Expected: FAIL — `package:gazgap/core/helicos.dart` introuvable.

- [ ] **Step 3: Implémenter**

```dart
// lib/core/helicos.dart
// Deux hélicos fixes. Seul endroit où vivent id et libellé : les renommer ne
// touche pas aux données (seul `id` est stocké dans Firestore).
enum Helico {
  h1('H1', 'Hélico H1'),
  h2('H2', 'Hélico H2');

  const Helico(this.id, this.label);

  final String id;
  final String label;

  static Helico? fromId(String? id) {
    for (final h in values) {
      if (h.id == id) return h;
    }
    return null;
  }
}
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

```bash
fvm flutter test test/core/helicos_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/helicos.dart test/core/helicos_test.dart
git commit -m "feat: hélicos fixes H1/H2"
```

---

## Task 4: Modèle de vol (`Flight`, `FlightStatus`, `FlightDraft`)

**Files:**
- Create: `lib/data/flight.dart`
- Test: `test/data/flight_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces: `enum FlightStatus { planifie, realise, annule }` avec `code` (String) et `FlightStatus.fromCode(String?)`; `class Flight` avec champs `id, helicoId, start, destination, remarque, statut, dureeMinutes` et getter `end`; `Flight.fromMap(String id, Map<String,dynamic> m)`; `class FlightDraft` avec champs `helicoId, start, destination, remarque, dureeMinutes` et `toFields() → Map<String,dynamic>` (sans `statut`, géré par `FlightApi`).

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/data/flight_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/flight.dart';

void main() {
  test('FlightStatus.fromCode : codes connus et inconnu', () {
    expect(FlightStatus.fromCode('planifie'), FlightStatus.planifie);
    expect(FlightStatus.fromCode('realise'), FlightStatus.realise);
    expect(FlightStatus.fromCode('annule'), FlightStatus.annule);
    expect(FlightStatus.fromCode('xyz'), FlightStatus.planifie);
    expect(FlightStatus.fromCode(null), FlightStatus.planifie);
  });

  test('Flight.fromMap : champs du contrat, dureeMinutes par défaut à 60', () {
    final f = Flight.fromMap('f1', {
      'helicoId': 'H1',
      'start': Timestamp.fromDate(DateTime(2026, 10, 12, 9)),
      'destination': 'Lomé',
      'remarque': 'RAS',
      'statut': 'planifie',
    });
    expect(f.id, 'f1');
    expect(f.helicoId, 'H1');
    expect(f.start, DateTime(2026, 10, 12, 9));
    expect(f.destination, 'Lomé');
    expect(f.remarque, 'RAS');
    expect(f.statut, FlightStatus.planifie);
    expect(f.dureeMinutes, 60);
  });

  test('Flight.end = start + dureeMinutes', () {
    final f = Flight.fromMap('f1', {
      'helicoId': 'H1',
      'start': Timestamp.fromDate(DateTime(2026, 10, 12, 9)),
      'statut': 'planifie',
      'dureeMinutes': 90,
    });
    expect(f.end, DateTime(2026, 10, 12, 10, 30));
  });

  test('FlightDraft.toFields : destination et remarque nettoyées, start en Timestamp', () {
    final d = FlightDraft(
      helicoId: 'H2',
      start: DateTime(2026, 10, 13, 9),
      destination: ' Lomé ',
      remarque: ' RAS ',
      dureeMinutes: 45,
    );
    expect(d.toFields(), {
      'helicoId': 'H2',
      'start': Timestamp.fromDate(DateTime(2026, 10, 13, 9)),
      'destination': 'Lomé',
      'remarque': 'RAS',
      'dureeMinutes': 45,
    });
  });

  test('FlightDraft.dureeMinutes par défaut à 60', () {
    final d = FlightDraft(
      helicoId: 'H1',
      start: DateTime(2026, 10, 13, 9),
      destination: 'X',
      remarque: '',
    );
    expect(d.dureeMinutes, 60);
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

```bash
fvm flutter test test/data/flight_test.dart
```

Expected: FAIL — `package:gazgap/data/flight.dart` introuvable.

- [ ] **Step 3: Implémenter**

```dart
// lib/data/flight.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum FlightStatus {
  planifie('planifie'),
  realise('realise'),
  annule('annule');

  const FlightStatus(this.code);
  final String code;

  static FlightStatus fromCode(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => FlightStatus.planifie);
}

DateTime _date(Object? v) => v is Timestamp
    ? v.toDate()
    : v is DateTime
        ? v
        : DateTime.fromMillisecondsSinceEpoch(0);

/// `flights/{id}`. Champs marqués (contrat) dans la spec : helicoId, start,
/// destination, remarque, statut — le futur pont AppGAP les lit tels quels,
/// ne jamais renommer. `dureeMinutes` n'est PAS un champ contrat : ajouté
/// uniquement pour calculer la fenêtre horaire de l'avertissement de
/// chevauchement (décision prise avec l'utilisateur, hors spec initiale).
class Flight {
  const Flight({
    required this.id,
    required this.helicoId,
    required this.start,
    required this.destination,
    required this.remarque,
    required this.statut,
    required this.dureeMinutes,
  });

  final String id;
  final String helicoId;
  final DateTime start;
  final String destination;
  final String remarque;
  final FlightStatus statut;
  final int dureeMinutes;

  DateTime get end => start.add(Duration(minutes: dureeMinutes));

  factory Flight.fromMap(String id, Map<String, dynamic> m) => Flight(
        id: id,
        helicoId: (m['helicoId'] as String?) ?? '',
        start: _date(m['start']),
        destination: (m['destination'] as String?) ?? '',
        remarque: (m['remarque'] as String?) ?? '',
        statut: FlightStatus.fromCode(m['statut'] as String?),
        dureeMinutes: (m['dureeMinutes'] as num?)?.toInt() ?? 60,
      );
}

/// Saisie du formulaire, envoyée à FlightApi.create / update.
class FlightDraft {
  const FlightDraft({
    required this.helicoId,
    required this.start,
    required this.destination,
    required this.remarque,
    this.dureeMinutes = 60,
  });

  final String helicoId;
  final DateTime start;
  final String destination;
  final String remarque;
  final int dureeMinutes;

  Map<String, dynamic> toFields() => {
        'helicoId': helicoId,
        'start': Timestamp.fromDate(start),
        'destination': destination.trim(),
        'remarque': remarque.trim(),
        'dureeMinutes': dureeMinutes,
      };
}
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

```bash
fvm flutter test test/data/flight_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/flight.dart test/data/flight_test.dart
git commit -m "feat: modèle Flight / FlightStatus / FlightDraft"
```

---

## Task 5: Détection de chevauchement

**Files:**
- Create: `lib/core/overlap.dart`
- Test: `test/core/overlap_test.dart`

**Interfaces:**
- Consumes: `Flight`, `FlightStatus` (Task 4).
- Produces: `bool flightsOverlap(Flight a, Flight b)`; `List<Flight> overlapsFor(Flight target, List<Flight> all)`.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/core/overlap_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/flight.dart';
import 'package:gazgap/core/overlap.dart';

Flight _f(String id, String helicoId, DateTime start,
        {int dureeMinutes = 60, FlightStatus statut = FlightStatus.planifie}) =>
    Flight(
      id: id,
      helicoId: helicoId,
      start: start,
      destination: 'X',
      remarque: '',
      statut: statut,
      dureeMinutes: dureeMinutes,
    );

void main() {
  test('même hélico, fenêtres qui se recoupent : chevauchement', () {
    final a = _f('a', 'H1', DateTime(2026, 10, 12, 9), dureeMinutes: 60);
    final b = _f('b', 'H1', DateTime(2026, 10, 12, 9, 30), dureeMinutes: 60);
    expect(flightsOverlap(a, b), isTrue);
    expect(flightsOverlap(b, a), isTrue);
  });

  test('même hélico, bout à bout exact : pas de chevauchement', () {
    final a = _f('a', 'H1', DateTime(2026, 10, 12, 9), dureeMinutes: 60);
    final b = _f('b', 'H1', DateTime(2026, 10, 12, 10), dureeMinutes: 60);
    expect(flightsOverlap(a, b), isFalse);
  });

  test('hélicos différents, même horaire : pas de chevauchement', () {
    final a = _f('a', 'H1', DateTime(2026, 10, 12, 9));
    final b = _f('b', 'H2', DateTime(2026, 10, 12, 9));
    expect(flightsOverlap(a, b), isFalse);
  });

  test('un des deux vols annulé : pas de chevauchement signalé', () {
    final a = _f('a', 'H1', DateTime(2026, 10, 12, 9));
    final b = _f('b', 'H1', DateTime(2026, 10, 12, 9, 15), statut: FlightStatus.annule);
    expect(flightsOverlap(a, b), isFalse);
  });

  test('un vol ne se chevauche jamais avec lui-même', () {
    final a = _f('a', 'H1', DateTime(2026, 10, 12, 9));
    expect(flightsOverlap(a, a), isFalse);
  });

  test('overlapsFor : ne renvoie que les vols en conflit', () {
    final target = _f('a', 'H1', DateTime(2026, 10, 12, 9));
    final conflict = _f('b', 'H1', DateTime(2026, 10, 12, 9, 30));
    final other = _f('c', 'H2', DateTime(2026, 10, 12, 9));
    expect(overlapsFor(target, [target, conflict, other]), [conflict]);
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

```bash
fvm flutter test test/core/overlap_test.dart
```

Expected: FAIL — `package:gazgap/core/overlap.dart` introuvable.

- [ ] **Step 3: Implémenter**

```dart
// lib/core/overlap.dart
import '../data/flight.dart';

/// Chevauchement d'horaire entre deux vols du même hélico (spec §2, écran
/// Planning) : avertissement non bloquant, jamais une interdiction. Un vol
/// `annule` ne retient pas l'hélico et n'est jamais signalé.
bool flightsOverlap(Flight a, Flight b) {
  if (a.id == b.id) return false;
  if (a.helicoId != b.helicoId) return false;
  if (a.statut == FlightStatus.annule || b.statut == FlightStatus.annule) {
    return false;
  }
  return a.start.isBefore(b.end) && b.start.isBefore(a.end);
}

List<Flight> overlapsFor(Flight target, List<Flight> all) =>
    all.where((f) => flightsOverlap(target, f)).toList();
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

```bash
fvm flutter test test/core/overlap_test.dart
```

Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/overlap.dart test/core/overlap_test.dart
git commit -m "feat: détection de chevauchement d'horaire par hélico"
```

---

## Task 6: Service d'authentification

**Files:**
- Create: `lib/data/auth_service.dart`
- Test: `test/data/auth_service_test.dart`

**Interfaces:**
- Produces: `class AuthSnapshot { uid, email }`; `class AuthFailure implements Exception { message }`; `String authErrorMessage(String code)`; `abstract class AuthService { Stream<AuthSnapshot?> changes(); Future<void> signIn(String,String); Future<void> signOut(); Future<void> sendPasswordReset(String); }`; `class FirebaseAuthService implements AuthService`.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/data/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/auth_service.dart';

void main() {
  test('authErrorMessage : codes connus et inconnu', () {
    expect(authErrorMessage('wrong-password'), 'E-mail ou mot de passe incorrect.');
    expect(authErrorMessage('user-not-found'), 'E-mail ou mot de passe incorrect.');
    expect(authErrorMessage('invalid-credential'), 'E-mail ou mot de passe incorrect.');
    expect(authErrorMessage('user-disabled'), 'Ce compte est désactivé.');
    expect(authErrorMessage('too-many-requests'), 'Trop de tentatives. Réessayez plus tard.');
    expect(authErrorMessage('network-request-failed'), 'Pas de connexion réseau.');
    expect(authErrorMessage('xyz'), 'Connexion impossible (xyz).');
  });

  test('AuthFailure.toString renvoie le message', () {
    expect(const AuthFailure('oups').toString(), 'oups');
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

```bash
fvm flutter test test/data/auth_service_test.dart
```

Expected: FAIL — `package:gazgap/data/auth_service.dart` introuvable.

- [ ] **Step 3: Implémenter**

```dart
// lib/data/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthSnapshot {
  const AuthSnapshot({required this.uid, required this.email});
  final String uid;
  final String email;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String authErrorMessage(String code) {
  switch (code) {
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-credential':
    case 'invalid-email':
      return 'E-mail ou mot de passe incorrect.';
    case 'user-disabled':
      return 'Ce compte est désactivé.';
    case 'too-many-requests':
      return 'Trop de tentatives. Réessayez plus tard.';
    case 'network-request-failed':
      return 'Pas de connexion réseau.';
    default:
      return 'Connexion impossible ($code).';
  }
}

/// Un seul compte existera jamais côté client (spec) : pas de notion de
/// vérification d'e-mail ni de document users à surveiller, contrairement à
/// UlmGap.
abstract class AuthService {
  Stream<AuthSnapshot?> changes();
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  @override
  Stream<AuthSnapshot?> changes() => _auth
      .authStateChanges()
      .map((u) => u == null ? null : AuthSnapshot(uid: u.uid, email: u.email ?? ''));

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    }
  }
}
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

```bash
fvm flutter test test/data/auth_service_test.dart
```

Expected: PASS (2 tests). `FirebaseAuthService` n'est pas testé ici — il parle réellement à Firebase, hors périmètre des tests unitaires (contrainte globale).

- [ ] **Step 5: Commit**

```bash
git add lib/data/auth_service.dart test/data/auth_service_test.dart
git commit -m "feat: service d'authentification (compte unique)"
```

---

## Task 7: API de vols (écriture directe Firestore)

**Files:**
- Create: `lib/data/flight_api.dart`
- Test: `test/data/flight_api_test.dart`

**Interfaces:**
- Consumes: `Flight`, `FlightStatus`, `FlightDraft` (Task 4).
- Produces: `class FlightApiFailure implements Exception { message }`; `abstract class FlightApi { Stream<List<Flight>> watchAll(); Future<void> create(FlightDraft); Future<void> update(String id, FlightDraft); Future<void> setStatus(String id, FlightStatus); Future<void> delete(String id); }`; `class FirebaseFlightApi implements FlightApi`.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/data/flight_api_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/flight_api.dart';

void main() {
  test('FlightApiFailure.toString renvoie le message', () {
    expect(const FlightApiFailure('Écriture impossible.').toString(), 'Écriture impossible.');
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

```bash
fvm flutter test test/data/flight_api_test.dart
```

Expected: FAIL — `package:gazgap/data/flight_api.dart` introuvable.

- [ ] **Step 3: Implémenter**

```dart
// lib/data/flight_api.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'flight.dart';

class FlightApiFailure implements Exception {
  const FlightApiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Écritures directes depuis le client (spec : pas de Cloud Functions pour
/// le CRUD), sécurisées uniquement par firestore.rules.
abstract class FlightApi {
  /// Tous les vols (à venir et passés), triés par départ.
  Stream<List<Flight>> watchAll();
  Future<void> create(FlightDraft draft);
  Future<void> update(String id, FlightDraft draft);
  Future<void> setStatus(String id, FlightStatus statut);
  Future<void> delete(String id);
}

class FirebaseFlightApi implements FlightApi {
  FirebaseFlightApi([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _flights => _db.collection('flights');

  @override
  Stream<List<Flight>> watchAll() => _flights
      .orderBy('start')
      .snapshots()
      .map((q) => q.docs.map((d) => Flight.fromMap(d.id, d.data())).toList());

  @override
  Future<void> create(FlightDraft draft) async {
    try {
      await _flights.add({
        ...draft.toFields(),
        'statut': FlightStatus.planifie.code,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw FlightApiFailure(e.message ?? 'Écriture impossible.');
    }
  }

  @override
  Future<void> update(String id, FlightDraft draft) async {
    try {
      await _flights.doc(id).update({
        ...draft.toFields(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw FlightApiFailure(e.message ?? 'Écriture impossible.');
    }
  }

  @override
  Future<void> setStatus(String id, FlightStatus statut) async {
    try {
      await _flights.doc(id).update({
        'statut': statut.code,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw FlightApiFailure(e.message ?? 'Écriture impossible.');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _flights.doc(id).delete();
    } on FirebaseException catch (e) {
      throw FlightApiFailure(e.message ?? 'Suppression impossible.');
    }
  }
}
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

```bash
fvm flutter test test/data/flight_api_test.dart
```

Expected: PASS (1 test). `FirebaseFlightApi` n'est pas testé ici (contrainte globale) — il sera exercé manuellement en Task 15 via l'émulateur ou le vrai projet.

- [ ] **Step 5: Commit**

```bash
git add lib/data/flight_api.dart test/data/flight_api_test.dart
git commit -m "feat: API de vols, écriture directe Firestore"
```

---

## Task 8: Services de l'app + doublures de test

**Files:**
- Create: `lib/data/services.dart`, `test/support/fakes.dart`
- Test: `test/data/services_test.dart`

**Interfaces:**
- Consumes: `AuthService`, `AuthSnapshot`, `AuthFailure` (Task 6) ; `FlightApi`, `Flight`, `FlightDraft`, `FlightStatus`, `FlightApiFailure` (Task 4, 7).
- Produces: `class AppServices extends InheritedWidget { auth, flights }` avec `AppServices.of(context)`; `class FakeAuthService implements AuthService` (avec `emit(AuthSnapshot?)`, `calls`, `failWith`); `class FakeFlightApi implements FlightApi` (avec `emit(List<Flight>)`, `calls`, `failWith`); `Flight testFlight({...})` (fabrique de test).

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/data/services_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/services.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('AppServices.of expose auth et flights', (tester) async {
    final auth = FakeAuthService();
    final flights = FakeFlightApi();
    late AppServices services;
    await tester.pumpWidget(AppServices(
      auth: auth,
      flights: flights,
      child: Builder(builder: (context) {
        services = AppServices.of(context);
        return const SizedBox();
      }),
    ));
    expect(services.auth, auth);
    expect(services.flights, flights);
  });
}
```

Cette tâche crée aussi `test/support/fakes.dart` (infrastructure de test, pas de cycle rouge/vert dédié — sa correction se vérifie par le test ci-dessus et par toutes les tâches suivantes qui l'utilisent) :

```dart
// test/support/fakes.dart
import 'dart:async';

import 'package:gazgap/data/auth_service.dart';
import 'package:gazgap/data/flight.dart';
import 'package:gazgap/data/flight_api.dart';

class FakeAuthService implements AuthService {
  final _ctrl = StreamController<AuthSnapshot?>.broadcast();
  AuthSnapshot? current;
  final calls = <String>[];
  String? failWith;

  void emit(AuthSnapshot? s) {
    current = s;
    _ctrl.add(s);
  }

  @override
  Stream<AuthSnapshot?> changes() async* {
    yield current;
    yield* _ctrl.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn:$email');
    if (failWith != null) throw AuthFailure(failWith!);
  }

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset:$email');
}

class FakeFlightApi implements FlightApi {
  final _ctrl = StreamController<List<Flight>>.broadcast();
  List<Flight> current = const [];
  final calls = <String>[];
  String? failWith;

  void emit(List<Flight> flights) {
    current = flights;
    _ctrl.add(flights);
  }

  @override
  Stream<List<Flight>> watchAll() async* {
    yield current;
    yield* _ctrl.stream;
  }

  @override
  Future<void> create(FlightDraft draft) async {
    calls.add('create:${draft.helicoId}:${draft.destination}');
    if (failWith != null) throw FlightApiFailure(failWith!);
  }

  @override
  Future<void> update(String id, FlightDraft draft) async {
    calls.add('update:$id:${draft.destination}');
    if (failWith != null) throw FlightApiFailure(failWith!);
  }

  @override
  Future<void> setStatus(String id, FlightStatus statut) async {
    calls.add('setStatus:$id:${statut.code}');
    if (failWith != null) throw FlightApiFailure(failWith!);
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (failWith != null) throw FlightApiFailure(failWith!);
  }
}

Flight testFlight({
  String id = 'f1',
  String helicoId = 'H1',
  DateTime? start,
  String destination = 'Lomé',
  String remarque = '',
  FlightStatus statut = FlightStatus.planifie,
  int dureeMinutes = 60,
}) =>
    Flight(
      id: id,
      helicoId: helicoId,
      start: start ?? DateTime(2026, 10, 12, 9),
      destination: destination,
      remarque: remarque,
      statut: statut,
      dureeMinutes: dureeMinutes,
    );
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

```bash
fvm flutter test test/data/services_test.dart
```

Expected: FAIL — `package:gazgap/data/services.dart` introuvable.

- [ ] **Step 3: Implémenter `lib/data/services.dart`**

```dart
// lib/data/services.dart
import 'package:flutter/widgets.dart';

import 'auth_service.dart';
import 'flight_api.dart';

/// Services de l'app, injectés à la racine (doublures en test).
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.auth,
    required this.flights,
    required super.child,
  });

  final AuthService auth;
  final FlightApi flights;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServices>()!;

  @override
  bool updateShouldNotify(AppServices old) =>
      auth != old.auth || flights != old.flights;
}
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

```bash
fvm flutter test test/data/services_test.dart
```

Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/data/services.dart test/support/fakes.dart test/data/services_test.dart
git commit -m "feat: AppServices + doublures de test"
```

---

## Task 9: Écrans d'authentification (connexion + porte d'accès)

**Files:**
- Create: `lib/features/auth/login_screen.dart`, `lib/features/auth/gate.dart`, `lib/app.dart`
- Test: `test/features/auth/login_screen_test.dart`, `test/features/auth/gate_test.dart`, `test/app_test.dart`

**Interfaces:**
- Consumes: `AppServices` (Task 8), `AuthService`, `AuthSnapshot`, `AuthFailure` (Task 6), `FakeAuthService`, `FakeFlightApi` (Task 8).
- Produces: `class LoginScreen extends StatefulWidget`; `enum GateState { signedOut, ready }`, `GateState gateFor(AuthSnapshot? auth)`, `class AppGate extends StatefulWidget`; `class GazGapApp extends StatelessWidget`. `AppGate` montre `PlanningScreen` (Task 12) quand prêt — import circulaire évité car `gate.dart` importe `planning_screen.dart`, créé juste après dans ce même repo (le fichier est créé vide/minimal avant ce commit si besoin, voir Step 3b).

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
// test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/services.dart';
import 'package:gazgap/features/auth/login_screen.dart';

import '../../support/fakes.dart';

Widget host(FakeAuthService auth) => AppServices(
      auth: auth,
      flights: FakeFlightApi(),
      child: const MaterialApp(home: LoginScreen()),
    );

void main() {
  testWidgets('connexion : appelle signIn avec l\'e-mail nettoyé', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(host(auth));
    await tester.enterText(find.byKey(const Key('email')), ' pilote@gap.fr ');
    await tester.enterText(find.byKey(const Key('password')), 'secret');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(auth.calls, ['signIn:pilote@gap.fr']);
  });

  testWidgets('échec : message affiché', (tester) async {
    final auth = FakeAuthService()..failWith = 'E-mail ou mot de passe incorrect.';
    await tester.pumpWidget(host(auth));
    await tester.enterText(find.byKey(const Key('email')), 'pilote@gap.fr');
    await tester.enterText(find.byKey(const Key('password')), 'x');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
  });
}
```

```dart
// test/features/auth/gate_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/auth_service.dart';
import 'package:gazgap/data/services.dart';
import 'package:gazgap/features/auth/gate.dart';

import '../../support/fakes.dart';

void main() {
  test('gateFor : non connecté', () => expect(gateFor(null), GateState.signedOut));
  test('gateFor : connecté', () {
    expect(gateFor(const AuthSnapshot(uid: 'u1', email: 'a@b.fr')), GateState.ready);
  });

  testWidgets('AppGate : affiche Connexion puis Planning selon le flux auth', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(AppServices(
      auth: auth,
      flights: FakeFlightApi(),
      child: const MaterialApp(home: AppGate()),
    ));
    await tester.pump();
    expect(find.text('Se connecter'), findsOneWidget);

    auth.emit(const AuthSnapshot(uid: 'u1', email: 'pilote@gap.fr'));
    await tester.pump();
    expect(find.text('GazGap — Planning'), findsOneWidget);
  });
}
```

```dart
// test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/app.dart';
import 'package:gazgap/data/services.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('GazGapApp non connecté : affiche l\'écran de connexion', (tester) async {
    await tester.pumpWidget(AppServices(
      auth: FakeAuthService(),
      flights: FakeFlightApi(),
      child: const GazGapApp(),
    ));
    await tester.pump();
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer les tests, vérifier qu'ils échouent**

```bash
fvm flutter test test/features/auth/login_screen_test.dart test/features/auth/gate_test.dart test/app_test.dart
```

Expected: FAIL — `package:gazgap/features/auth/login_screen.dart` (et `gate.dart`, `app.dart`) introuvables.

- [ ] **Step 3: Implémenter `lib/features/auth/login_screen.dart`**

```dart
// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppServices.of(context).auth;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('GazGap', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                TextField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                ),
                const SizedBox(height: 16),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_message!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => auth.signIn(_email.text.trim(), _password.text)),
                  child: const Text('Se connecter'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          final email = _email.text.trim();
                          if (email.isEmpty) {
                            setState(() => _message = 'Saisissez d\'abord votre e-mail.');
                            return;
                          }
                          _run(() async {
                            await auth.sendPasswordReset(email);
                            if (mounted) {
                              setState(() => _message = 'Lien envoyé à $email.');
                            }
                          });
                        },
                  child: const Text('Mot de passe oublié ?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3b: Créer un `PlanningScreen` minimal temporaire**

`gate.dart` (Step 3c) doit importer l'écran Planning. Il sera réellement implémenté en Task 12 ; pour garder chaque tâche indépendamment testable dans l'ordre du plan, créer ici une version minimale qui porte déjà le titre attendu par le test `gate_test.dart` :

```dart
// lib/features/planning/planning_screen.dart
import 'package:flutter/material.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('GazGap — Planning')));
  }
}
```

(Task 12 remplacera entièrement ce fichier.)

- [ ] **Step 3c: Implémenter `lib/features/auth/gate.dart`**

```dart
// lib/features/auth/gate.dart
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/services.dart';
import '../planning/planning_screen.dart';
import 'login_screen.dart';

enum GateState { signedOut, ready }

GateState gateFor(AuthSnapshot? auth) => auth == null ? GateState.signedOut : GateState.ready;

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  Stream<AuthSnapshot?>? _authStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authStream ??= AppServices.of(context).auth.changes();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSnapshot?>(
      stream: _authStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return gateFor(snap.data) == GateState.ready
            ? const PlanningScreen()
            : const LoginScreen();
      },
    );
  }
}
```

- [ ] **Step 3d: Implémenter `lib/app.dart`**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/auth/gate.dart';

const Color kBrandColor = Color(0xFF00695C);

class GazGapApp extends StatelessWidget {
  const GazGapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GazGap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: kBrandColor, useMaterial3: true),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppGate(),
    );
  }
}
```

- [ ] **Step 4: Lancer les tests, vérifier qu'ils passent**

```bash
fvm flutter test test/features/auth/login_screen_test.dart test/features/auth/gate_test.dart test/app_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart lib/features/auth/login_screen.dart lib/features/auth/gate.dart \
        lib/features/planning/planning_screen.dart \
        test/features/auth/login_screen_test.dart test/features/auth/gate_test.dart test/app_test.dart
git commit -m "feat: écrans de connexion et porte d'accès"
```

---

## Task 10: Carte de vol (`FlightTile`)

**Files:**
- Create: `lib/features/planning/flight_tile.dart`
- Test: `test/features/planning/flight_tile_test.dart`

**Interfaces:**
- Consumes: `Flight`, `FlightStatus` (Task 4), `Helico` (Task 3).
- Produces: `class FlightTile extends StatelessWidget` avec `flight`, `hasOverlap`, `onTap` ; clé `Key('flight-${flight.id}')` sur le `ListTile`, `Key('overlap-warning')` sur l'icône d'avertissement quand affichée.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/features/planning/flight_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/flight.dart';
import 'package:gazgap/features/planning/flight_tile.dart';

Flight _f({FlightStatus statut = FlightStatus.planifie, String remarque = ''}) => Flight(
      id: 'f1',
      helicoId: 'H1',
      start: DateTime(2026, 10, 12, 9, 5),
      destination: 'Lomé',
      remarque: remarque,
      statut: statut,
      dureeMinutes: 60,
    );

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('affiche hélico, date/heure et destination', (tester) async {
    await tester.pumpWidget(host(FlightTile(flight: _f(), hasOverlap: false, onTap: () {})));
    expect(find.textContaining('12/10/2026 09:05'), findsOneWidget);
    expect(find.textContaining('Lomé'), findsOneWidget);
    expect(find.text('H1'), findsOneWidget);
  });

  testWidgets('affiche le statut et la remarque si présente', (tester) async {
    await tester.pumpWidget(host(
        FlightTile(flight: _f(remarque: 'RAS'), hasOverlap: false, onTap: () {})));
    expect(find.textContaining('Planifié'), findsOneWidget);
    expect(find.textContaining('RAS'), findsOneWidget);
  });

  testWidgets('icône de chevauchement visible seulement si hasOverlap', (tester) async {
    await tester.pumpWidget(host(FlightTile(flight: _f(), hasOverlap: true, onTap: () {})));
    expect(find.byKey(const Key('overlap-warning')), findsOneWidget);

    await tester.pumpWidget(host(FlightTile(flight: _f(), hasOverlap: false, onTap: () {})));
    expect(find.byKey(const Key('overlap-warning')), findsNothing);
  });

  testWidgets('onTap déclenché au tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
        host(FlightTile(flight: _f(), hasOverlap: false, onTap: () => tapped = true)));
    await tester.tap(find.byKey(const Key('flight-f1')));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

```bash
fvm flutter test test/features/planning/flight_tile_test.dart
```

Expected: FAIL — `package:gazgap/features/planning/flight_tile.dart` introuvable.

- [ ] **Step 3: Implémenter**

```dart
// lib/features/planning/flight_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/helicos.dart';
import '../../data/flight.dart';

final _fmt = DateFormat('dd/MM/yyyy HH:mm');

class FlightTile extends StatelessWidget {
  const FlightTile({
    super.key,
    required this.flight,
    required this.hasOverlap,
    required this.onTap,
  });

  final Flight flight;
  final bool hasOverlap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final helico = Helico.fromId(flight.helicoId);
    return ListTile(
      key: Key('flight-${flight.id}'),
      onTap: onTap,
      leading: CircleAvatar(child: Text(helico?.id ?? '?')),
      title: Text('${_fmt.format(flight.start)} — ${flight.destination}'),
      subtitle: Text(flight.remarque.isEmpty
          ? _statusLabel(flight.statut)
          : '${_statusLabel(flight.statut)} · ${flight.remarque}'),
      trailing: hasOverlap
          ? const Icon(Icons.warning_amber, color: Colors.orange, key: Key('overlap-warning'))
          : null,
    );
  }
}

String _statusLabel(FlightStatus s) => switch (s) {
      FlightStatus.planifie => 'Planifié',
      FlightStatus.realise => 'Réalisé',
      FlightStatus.annule => 'Annulé',
    };
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

```bash
fvm flutter test test/features/planning/flight_tile_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/planning/flight_tile.dart test/features/planning/flight_tile_test.dart
git commit -m "feat: carte de vol (FlightTile)"
```

---

## Task 11: Formulaire de vol (`FlightFormDialog`)

**Files:**
- Create: `lib/features/planning/flight_form_dialog.dart`
- Test: `test/features/planning/flight_form_dialog_test.dart`

**Interfaces:**
- Consumes: `Helico` (Task 3), `Flight`, `FlightDraft` (Task 4).
- Produces: `class FlightFormDialog extends StatefulWidget { Flight? initial }` — se ferme via `Navigator.pop(context, draft)` (un `FlightDraft`) au succès, ou `Navigator.pop(context)` (null) à l'annulation. Clés : `Key('helico')`, `Key('date')`, `Key('time')`, `Key('duree')`, `Key('destination')`, `Key('remarque')`.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/features/planning/flight_form_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/flight.dart';
import 'package:gazgap/features/planning/flight_form_dialog.dart';

Future<T?> openDialog<T>(WidgetTester tester, Widget dialog) async {
  T? result;
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
    return ElevatedButton(
      onPressed: () async {
        result = await showDialog<T>(context: context, builder: (_) => dialog);
      },
      child: const Text('ouvrir'),
    );
  })));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('création : destination et champs remplis renvoient un FlightDraft', (tester) async {
    FlightDraft? draft;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () async {
          draft = await showDialog<FlightDraft>(
              context: context, builder: (_) => const FlightFormDialog());
        },
        child: const Text('ouvrir'),
      );
    })));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('destination')), 'Lomé');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(draft, isNotNull);
    expect(draft!.helicoId, 'H1');
    expect(draft!.destination, 'Lomé');
    expect(draft!.dureeMinutes, 60);
  });

  testWidgets('destination vide : bloque la soumission', (tester) async {
    FlightDraft? draft;
    var popped = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () async {
          draft = await showDialog<FlightDraft>(
              context: context, builder: (_) => const FlightFormDialog());
          popped = true;
        },
        child: const Text('ouvrir'),
      );
    })));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(popped, isFalse);
    expect(draft, isNull);
    expect(find.text('Destination requise'), findsOneWidget);
  });

  testWidgets('durée nulle : bloque la soumission', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showDialog<FlightDraft>(
            context: context, builder: (_) => const FlightFormDialog()),
        child: const Text('ouvrir'),
      );
    })));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('destination')), 'Lomé');
    await tester.enterText(find.byKey(const Key('duree')), '0');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Durée invalide'), findsOneWidget);
  });

  testWidgets('modification : préremplit avec le vol existant', (tester) async {
    final existing = Flight(
      id: 'f1',
      helicoId: 'H2',
      start: DateTime(2026, 10, 12, 9, 30),
      destination: 'Kara',
      remarque: 'RAS',
      statut: FlightStatus.planifie,
      dureeMinutes: 45,
    );
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showDialog<FlightDraft>(
            context: context, builder: (_) => FlightFormDialog(initial: existing)),
        child: const Text('ouvrir'),
      );
    })));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Kara'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('12/10/2026'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

```bash
fvm flutter test test/features/planning/flight_form_dialog_test.dart
```

Expected: FAIL — `package:gazgap/features/planning/flight_form_dialog.dart` introuvable.

- [ ] **Step 3: Implémenter**

```dart
// lib/features/planning/flight_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/helicos.dart';
import '../../data/flight.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

DateTime? _parseDate(String s) {
  try {
    return _dateFmt.parseStrict(s.trim());
  } catch (_) {
    return null;
  }
}

class FlightFormDialog extends StatefulWidget {
  const FlightFormDialog({super.key, this.initial});

  final Flight? initial;

  @override
  State<FlightFormDialog> createState() => _FlightFormDialogState();
}

class _FlightFormDialogState extends State<FlightFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late Helico _helico;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _duree;
  late final TextEditingController _destination;
  late final TextEditingController _remarque;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _helico = Helico.fromId(f?.helicoId) ?? Helico.h1;
    final start = f?.start ?? DateTime.now();
    _date = TextEditingController(text: _dateFmt.format(start));
    _time = TextEditingController(text: _fmtTime(start));
    _duree = TextEditingController(text: '${f?.dureeMinutes ?? 60}');
    _destination = TextEditingController(text: f?.destination ?? '');
    _remarque = TextEditingController(text: f?.remarque ?? '');
  }

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    _duree.dispose();
    _destination.dispose();
    _remarque.dispose();
    super.dispose();
  }

  DateTime? _parseStart() {
    final d = _parseDate(_date.text);
    if (d == null) return null;
    final parts = _time.text.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(d.year, d.month, d.day, h, m);
  }

  Future<void> _pickDate() async {
    final start = _parseStart() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(start.year - 1),
      lastDate: DateTime(start.year + 2),
    );
    if (picked != null) setState(() => _date.text = _dateFmt.format(picked));
  }

  Future<void> _pickTime() async {
    final start = _parseStart() ?? DateTime.now();
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay(hour: start.hour, minute: start.minute));
    if (picked != null) {
      setState(() => _time.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final start = _parseStart();
    if (start == null) return;
    Navigator.of(context).pop(FlightDraft(
      helicoId: _helico.id,
      start: start,
      destination: _destination.text,
      remarque: _remarque.text,
      dureeMinutes: int.tryParse(_duree.text.trim()) ?? 60,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouveau vol' : 'Modifier le vol'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Helico>(
                key: const Key('helico'),
                value: _helico,
                decoration: const InputDecoration(labelText: 'Hélico'),
                items: Helico.values
                    .map((h) => DropdownMenuItem(value: h, child: Text(h.label)))
                    .toList(),
                onChanged: (h) => setState(() => _helico = h!),
              ),
              TextFormField(
                key: const Key('date'),
                controller: _date,
                decoration: InputDecoration(
                  labelText: 'Date (jj/mm/aaaa)',
                  suffixIcon:
                      IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
                ),
                validator: (v) => _parseDate(v ?? '') == null ? 'Date invalide' : null,
              ),
              TextFormField(
                key: const Key('time'),
                controller: _time,
                decoration: InputDecoration(
                  labelText: 'Heure (hh:mm)',
                  suffixIcon:
                      IconButton(icon: const Icon(Icons.access_time), onPressed: _pickTime),
                ),
                validator: (v) => _parseStart() == null ? 'Heure invalide' : null,
              ),
              TextFormField(
                key: const Key('duree'),
                controller: _duree,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Durée (minutes)'),
                validator: (v) =>
                    (int.tryParse(v?.trim() ?? '') ?? 0) > 0 ? null : 'Durée invalide',
              ),
              TextFormField(
                key: const Key('destination'),
                controller: _destination,
                decoration: const InputDecoration(labelText: 'Destination'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Destination requise' : null,
              ),
              TextFormField(
                key: const Key('remarque'),
                controller: _remarque,
                decoration: const InputDecoration(labelText: 'Remarque'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

```bash
fvm flutter test test/features/planning/flight_form_dialog_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/planning/flight_form_dialog.dart test/features/planning/flight_form_dialog_test.dart
git commit -m "feat: formulaire de vol (création/modification)"
```

---

## Task 12: Écran Planning (liste, CRUD, statuts, avertissement de chevauchement)

**Files:**
- Modify: `lib/features/planning/planning_screen.dart` (remplace la version minimale de Task 9)
- Test: `test/features/planning/planning_screen_test.dart`

**Interfaces:**
- Consumes: `AppServices` (Task 8), `FlightApi`, `FlightApiFailure` (Task 7), `Flight`, `FlightStatus`, `FlightDraft` (Task 4), `overlapsFor` (Task 5), `FlightTile` (Task 10), `FlightFormDialog` (Task 11), `FakeFlightApi`, `testFlight` (Task 8).
- Produces: `class PlanningScreen extends StatefulWidget` (sans paramètres). Clés : `Key('add-flight')` (FAB), `Key('signout')` (bouton de déconnexion dans l'AppBar).

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/features/planning/planning_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/flight.dart';
import 'package:gazgap/data/services.dart';
import 'package:gazgap/features/planning/planning_screen.dart';

import '../../support/fakes.dart';

Widget host(FakeFlightApi flights, {FakeAuthService? auth}) => AppServices(
      auth: auth ?? FakeAuthService(),
      flights: flights,
      child: const MaterialApp(home: PlanningScreen()),
    );

void main() {
  testWidgets('liste vide : message dédié', (tester) async {
    final flights = FakeFlightApi();
    await tester.pumpWidget(host(flights));
    await tester.pump();
    expect(find.text('Aucun vol planifié.'), findsOneWidget);
  });

  testWidgets('affiche les vols reçus du flux', (tester) async {
    final flights = FakeFlightApi()..emit([testFlight(id: 'f1', destination: 'Lomé')]);
    await tester.pumpWidget(host(flights));
    await tester.pump();
    expect(find.textContaining('Lomé'), findsOneWidget);
  });

  testWidgets('deux vols du même hélico qui se recoupent : avertissement sur les deux', (tester) async {
    final a = testFlight(id: 'a', helicoId: 'H1', start: DateTime(2026, 10, 12, 9));
    final b = testFlight(id: 'b', helicoId: 'H1', start: DateTime(2026, 10, 12, 9, 30));
    final flights = FakeFlightApi()..emit([a, b]);
    await tester.pumpWidget(host(flights));
    await tester.pump();
    expect(find.byKey(const Key('overlap-warning')), findsNWidgets(2));
  });

  testWidgets('annuler le vol en conflit fait disparaître l\'avertissement', (tester) async {
    final a = testFlight(id: 'a', helicoId: 'H1', start: DateTime(2026, 10, 12, 9));
    final b = testFlight(id: 'b', helicoId: 'H1', start: DateTime(2026, 10, 12, 9, 30));
    final flights = FakeFlightApi()..emit([a, b]);
    await tester.pumpWidget(host(flights));
    await tester.pump();
    expect(find.byKey(const Key('overlap-warning')), findsNWidgets(2));

    flights.emit([a, testFlight(id: 'b', helicoId: 'H1', start: DateTime(2026, 10, 12, 9, 30), statut: FlightStatus.annule)]);
    await tester.pump();
    expect(find.byKey(const Key('overlap-warning')), findsNothing);
  });

  testWidgets('création : ouvre le formulaire et appelle create', (tester) async {
    final flights = FakeFlightApi();
    await tester.pumpWidget(host(flights));
    await tester.tap(find.byKey(const Key('add-flight')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('destination')), 'Kara');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(flights.calls, ['create:H1:Kara']);
  });

  testWidgets('échec d\'écriture : message affiché, pas de crash', (tester) async {
    final flights = FakeFlightApi()..failWith = 'Hors ligne.';
    await tester.pumpWidget(host(flights));
    await tester.tap(find.byKey(const Key('add-flight')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('destination')), 'Kara');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Hors ligne.'), findsOneWidget);
  });

  testWidgets('suppression : confirmation puis appel delete', (tester) async {
    final flights = FakeFlightApi()..emit([testFlight(id: 'f1')]);
    await tester.pumpWidget(host(flights));
    await tester.pump();

    await tester.tap(find.byKey(const Key('flight-f1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(flights.calls, ['delete:f1']);
  });

  testWidgets('marquer réalisé : appelle setStatus', (tester) async {
    final flights = FakeFlightApi()..emit([testFlight(id: 'f1')]);
    await tester.pumpWidget(host(flights));
    await tester.pump();

    await tester.tap(find.byKey(const Key('flight-f1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marquer réalisé'));
    await tester.pumpAndSettle();

    expect(flights.calls, ['setStatus:f1:realise']);
  });

  testWidgets('déconnexion : appelle signOut', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(host(FakeFlightApi(), auth: auth));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signout')));
    await tester.pump();
    expect(auth.calls, ['signOut']);
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

```bash
fvm flutter test test/features/planning/planning_screen_test.dart
```

Expected: FAIL — le `PlanningScreen` minimal de Task 9 n'a ni FAB, ni liste, ni actions.

- [ ] **Step 3: Implémenter**

```dart
// lib/features/planning/planning_screen.dart
import 'package:flutter/material.dart';

import '../../core/overlap.dart';
import '../../data/flight.dart';
import '../../data/flight_api.dart';
import '../../data/services.dart';
import 'flight_form_dialog.dart';
import 'flight_tile.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  Stream<List<Flight>>? _flightsStream;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _flightsStream ??= AppServices.of(context).flights.watchAll();
  }

  FlightApi get _api => AppServices.of(context).flights;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FlightApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    final draft = await showDialog<FlightDraft>(
      context: context,
      builder: (_) => const FlightFormDialog(),
    );
    if (draft != null) await _run(() => _api.create(draft));
  }

  Future<void> _edit(Flight flight) async {
    final draft = await showDialog<FlightDraft>(
      context: context,
      builder: (_) => FlightFormDialog(initial: flight),
    );
    if (draft != null) await _run(() => _api.update(flight.id, draft));
  }

  Future<void> _delete(Flight flight) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce vol ?'),
        content: Text(flight.destination),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed == true) await _run(() => _api.delete(flight.id));
  }

  void _openActions(Flight flight) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.of(ctx).pop();
                _edit(flight);
              },
            ),
            if (flight.statut != FlightStatus.realise)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Marquer réalisé'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _run(() => _api.setStatus(flight.id, FlightStatus.realise));
                },
              ),
            if (flight.statut != FlightStatus.annule)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Marquer annulé'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _run(() => _api.setStatus(flight.id, FlightStatus.annule));
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Supprimer'),
              onTap: () {
                Navigator.of(ctx).pop();
                _delete(flight);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GazGap — Planning'),
        actions: [
          IconButton(
            key: const Key('signout'),
            icon: const Icon(Icons.logout),
            onPressed: () => AppServices.of(context).auth.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Flight>>(
        stream: _flightsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final flights = snap.data ?? const [];
          return Column(
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.all(8),
                  child: Text(_error!),
                ),
              Expanded(
                child: flights.isEmpty
                    ? const Center(child: Text('Aucun vol planifié.'))
                    : ListView.builder(
                        itemCount: flights.length,
                        itemBuilder: (context, i) {
                          final f = flights[i];
                          return FlightTile(
                            flight: f,
                            hasOverlap: overlapsFor(f, flights).isNotEmpty,
                            onTap: () => _openActions(f),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-flight'),
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

```bash
fvm flutter test test/features/planning/planning_screen_test.dart
```

Expected: PASS (9 tests).

- [ ] **Step 5: Relancer toute la suite**

```bash
fvm flutter test
fvm flutter analyze
```

Expected: tous les tests passent, `No issues found!` (le `gate_test.dart` de Task 9 doit toujours passer : `PlanningScreen` a toujours son `AppBar` titré `GazGap — Planning`).

- [ ] **Step 6: Commit**

```bash
git add lib/features/planning/planning_screen.dart test/features/planning/planning_screen_test.dart
git commit -m "feat: écran Planning complet (CRUD, statuts, avertissement de chevauchement)"
```

---

## Task 13: Point d'entrée de l'app

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `DefaultFirebaseOptions.currentPlatform` (Task 2), `GazGapApp` (Task 9), `FirebaseAuthService` (Task 6), `FirebaseFlightApi` (Task 7), `AppServices` (Task 8).

- [ ] **Step 1: Remplacer `lib/main.dart`**

```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/auth_service.dart';
import 'data/flight_api.dart';
import 'data/services.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(AppServices(
    auth: FirebaseAuthService(),
    flights: FirebaseFlightApi(),
    child: const GazGapApp(),
  ));
}
```

Pas de test automatisé possible ici (point d'entrée réel, contacte Firebase) — vérification par analyse statique et lancement manuel.

- [ ] **Step 2: Vérifier l'ensemble du projet**

```bash
fvm flutter analyze
fvm flutter test
```

Expected: `No issues found!`, tous les tests passent.

- [ ] **Step 3: Lancement manuel (web, émulateur ou projet réel selon ce qui est déjà configuré)**

```bash
fvm flutter run -d chrome
```

Expected: l'app démarre, affiche l'écran de connexion. (Se connecter nécessite un compte existant — voir Task 15 pour le créer.)

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: point d'entrée, câblage Firebase réel"
```

---

## Task 14: Script de création du compte unique (écrit, pas exécuté)

**Files:**
- Create: `scripts/package.json`, `scripts/bootstrap-user.js`

**Interfaces:** Aucune — script Node.js autonome, hors de l'app Flutter.

- [ ] **Step 1: Créer `scripts/package.json`**

```json
{
  "name": "gazgap-scripts",
  "private": true,
  "dependencies": {
    "firebase-admin": "^13.0.0"
  }
}
```

- [ ] **Step 2: Créer `scripts/bootstrap-user.js`**

```js
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
```

- [ ] **Step 3: Installer les dépendances (local, sans effet sur le projet Firebase)**

```bash
cd scripts && npm install && cd ..
```

Expected: `scripts/node_modules/` créé, pas d'appel réseau vers Firebase à ce stade.

- [ ] **Step 4: Ajouter `scripts/node_modules/` au `.gitignore`**

Vérifier que `.gitignore` (généré par `flutter create`, racine du repo) contient une entrée couvrant `scripts/node_modules/` ; sinon l'ajouter.

- [ ] **Step 5: Commit**

**⚠️ Ce script n'est volontairement PAS exécuté contre le vrai projet ici** — l'exécuter crée un vrai compte Firebase Auth sur `gazgap-7eb3a`. Son exécution est la première étape de Task 15, qui demande explicitly confirmation avant de la lancer.

```bash
git add scripts/package.json scripts/bootstrap-user.js .gitignore
git commit -m "chore: script de création du compte pilote (non exécuté)"
```

---

## Task 15: Mise en service (déploiement des règles + création du compte réel)

**Files:** aucun fichier nouveau — exécution d'actions contre le projet Firebase réel `gazgap-7eb3a`.

**⚠️ Les deux étapes ci-dessous modifient un système partagé réel (le projet Firebase de production, qui n'a pas de séparation dev/prod). Demander confirmation explicite à l'utilisateur avant de les exécuter, séparément, en lui indiquant l'adresse e-mail à utiliser pour le compte pilote.**

- [ ] **Step 1: Déployer les règles Firestore**

```bash
firebase deploy --only firestore:rules --project gazgap-7eb3a
```

Expected: `+  firestore: released rules firestore.rules to cloud.firestore`.

- [ ] **Step 2: Créer le compte pilote**

Demander à l'utilisateur l'adresse e-mail du pilote, puis :

```bash
cd scripts
node bootstrap-user.js --project gazgap-7eb3a --email <email-du-pilote>
cd ..
```

Expected: affiche `Compte créé : <email> (uid ...)` et un lien de définition de mot de passe à transmettre au pilote.

- [ ] **Step 3: Vérification manuelle de bout en bout**

```bash
fvm flutter run -d chrome
```

Se connecter avec le compte créé (après avoir défini le mot de passe via le lien), créer un vol, vérifier qu'il apparaît dans la [console Firestore](https://console.firebase.google.com/project/gazgap-7eb3a/firestore) sous `flights/{id}` avec les champs `helicoId`, `start`, `destination`, `remarque`, `statut`, `dureeMinutes`, `createdAt`, `updatedAt`.

- [ ] **Step 4: Déployer le web (optionnel, si un hébergement est souhaité maintenant)**

```bash
fvm flutter build web
firebase deploy --only hosting --project gazgap-7eb3a
```

Cette étape aussi modifie un système partagé réel (site public) — demander confirmation séparément ; elle peut être reportée après la validation manuelle de l'app.

---

## Self-Review (effectuée par l'auteur du plan)

**Couverture de la spec :** Modèle de données §1.1 → Task 4 (+ Task 2 pour les règles) ; Hélicos §1.2 → Task 3 ; Écran Connexion §2 → Task 9 ; Écran Planning (CRUD, statuts, avertissement) §2 → Tasks 10-12 ; Pont AppGAP §3 → hors implémentation par design (documenté dans le plan comme hors scope, règles IAM citées dans la spec comme étape de déploiement future) ; Architecture technique §4 (projet unique, pas de Functions, règles Firestore, script de compte) → Tasks 1, 2, 7, 14, 15 ; Tests §5 → chaque tâche, contrainte globale.

**Champs non couverts par la spec d'origine :** `dureeMinutes`, ajouté avec l'accord explicite de l'utilisateur pour permettre le calcul de chevauchement — documenté en tête de plan et dans le commentaire de `lib/data/flight.dart`.

**Hors scope confirmé par la spec, non traité :** octroi du rôle IAM `roles/datastore.viewer` au compte de service AppGAP (étape de déploiement dans le repo AppGAP, pas dans ce plan) ; iOS ; gestion d'équipage/carburant/finances ; matrice de droits.
