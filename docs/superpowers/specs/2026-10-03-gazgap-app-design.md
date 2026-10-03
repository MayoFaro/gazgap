# GazGap : application de planification des vols hélicoptères

## Contexte / problème

Deux hélicoptères sont exploités par un pilote **externe au GAP**, qui ne doit
**jamais** accéder à AppGAP (même raison de sécurité que pour UlmGap). La
planification de ces vols se fait donc dans une **application séparée**,
GazGap, avec son propre repo (`gazgap`, déjà créé sur GitHub, actuellement
vide) et son propre projet Firebase. AppGAP viendra plus tard lire ce
planning via un pont, chantier séparé non traité ici (cf. plan 6 d'UlmGap
pour le même schéma).

GazGap a un seul utilisateur. C'est délibérément plus simple qu'UlmGap : pas
de matrice de droits, pas d'équipage, pas de carburant, pas de finances.

## Objectif

Permettre à l'unique pilote de **planifier**, **modifier**, **supprimer** des
vols (date, heure, hélico, destination, remarque) et de marquer leur statut
(`planifie` / `realise` / `annule`), en exposant ces données dans un format
stable que le futur pont AppGAP pourra lire.

## Décisions structurantes

| Sujet | Décision |
|---|---|
| Repo | Dédié (`gazgap`), nouveau projet Flutter, même version que UlmGap (3.32.8 via fvm) sauf besoin contraire |
| Plateformes | Android et web uniquement (pas d'iOS) |
| Firebase | **Un seul projet**, pas de séparation dev/prod — disproportionné pour une app de cette taille |
| Écritures | **Directes depuis le client**, sécurisées par les règles Firestore. Pas de Cloud Functions pour le CRUD |
| Comptes | Un seul compte, créé à la main (Firebase Auth e-mail/mot de passe), pas d'inscription libre |
| Hélicos | 2, fixes, codés en dur dans l'app (pas de collection Firestore dédiée) |
| Principe | KISS, plus strict encore que pour UlmGap vu le besoin réel |

## Hors périmètre

- Gestion d'équipage, de carburant, de budget ou de finances.
- Matrice de droits / plusieurs utilisateurs : un seul compte existera.
- Le pont lui-même : la lecture du planning par AppGAP et son insertion dans
  le planning AppGAP sont un chantier séparé, dans le repo AppGAP (comme le
  plan 6 d'UlmGap). Ce projet se limite à exposer des données lisibles par ce
  futur pont.
- iOS.
- Toute remontée d'information d'AppGAP vers GazGap.

---

## 1. Modèle de données (Firestore)

### 1.1 `flights/{id}`, écrit directement par le client

Les champs marqués **(contrat)** sont ceux que le futur pont AppGAP lira :
ni leur nom ni leur sens ne doivent changer sans mettre à jour ce pont. Le
pont lit **tous les statuts**, y compris `annule` — AppGAP applique sa propre
logique selon le statut, ce n'est pas à GazGap de filtrer.

| Champ | Type | Contenu |
|---|---|---|
| `helicoId` **(contrat)** | string | `H1` ou `H2`, identifiants fixes définis dans le code |
| `start` **(contrat)** | timestamp | Jour et heure de départ prévus (un seul champ, pas de `date` séparée) |
| `destination` **(contrat)** | string | Texte libre |
| `remarque` **(contrat)** | string | Texte libre |
| `statut` **(contrat)** | string | `planifie` / `realise` / `annule` |
| `createdAt` / `updatedAt` | timestamp | Horodatage technique |

Pas de collection `users`, `profiles`, `aircraft` ni `settings` : un seul
compte, deux hélicos fixes, aucun tarif à gérer.

### 1.2 Hélicos

Deux hélicos fixes (identifiant, nom/immatriculation) définis dans un seul
fichier de l'app (ex. `lib/core/helicos.dart`), sur le modèle de
`lib/core/profiles.dart` dans UlmGap. Aucun écran d'administration.

## 2. Écrans

- **Connexion** : e-mail / mot de passe.
- **Planning** : liste ou vue calendaire des vols à venir (et passés),
  création / modification / suppression d'un vol, changement de statut
  (`realise` / `annule`). Un avertissement non bloquant signale un
  chevauchement d'horaire sur le même hélico ; ce n'est pas une interdiction,
  l'utilisateur reste seul juge.

## 3. Pont AppGAP (contrat de données, hors implémentation)

GazGap n'implémente pas le pont : exactement comme UlmGap→AppGAP, c'est
AppGAP qui viendra lire directement le Firestore de GazGap (rôle IAM
`roles/datastore.viewer` accordé au compte de service des Functions AppGAP
sur le projet `gazgap`), pas GazGap qui pousse les données. L'octroi du rôle
IAM est une étape de déploiement, pas du code, et reste **hors scope** de ce
projet — à documenter comme « à reprendre » une fois GazGap en production.

Contrat exposé : collection `flights`, champs listés en §1.1, tous statuts
inclus.

## 4. Architecture technique

- Nouveau projet Flutter dans le repo `gazgap` (actuellement vide), même
  toolchain qu'UlmGap (`fvm flutter`/`fvm dart`).
- **Un seul projet Firebase** : pas de `--dart-define=ENV`, pas de flavors
  Android, pas de distinction dev/prod.
- Règles Firestore : lecture/écriture de `flights` réservée à l'utilisateur
  authentifié (`request.auth != null` suffit puisqu'un seul compte existera
  jamais côté client).
- Pas de Cloud Functions métier. Un script ponctuel (à la main, hors app)
  peut créer l'unique compte Firebase Auth, sur le modèle de
  `bootstrap-admin.js` dans UlmGap, mais simplifié (pas de rôle admin à
  distinguer).

## 5. Tests

TDD comme pour UlmGap : `fvm flutter test && fvm flutter analyze`. Pas de
tests d'intégration Functions, puisqu'il n'y a pas de Functions métier à
tester.
