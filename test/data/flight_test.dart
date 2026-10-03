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
