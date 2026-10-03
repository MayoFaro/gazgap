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
