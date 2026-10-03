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
