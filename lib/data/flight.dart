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
