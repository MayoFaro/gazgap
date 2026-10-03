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
