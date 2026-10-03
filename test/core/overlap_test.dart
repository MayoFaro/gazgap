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
