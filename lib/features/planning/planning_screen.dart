import 'package:flutter/material.dart';

import '../../core/helicos.dart';
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
      if (mounted) setState(() => _error = null);
    } on FlightApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    final drafts = await showDialog<List<FlightDraft>>(
      context: context,
      builder: (_) => const FlightFormDialog(),
    );
    if (drafts == null) return;
    for (final draft in drafts) {
      await _run(() => _api.create(draft));
    }
  }

  Future<void> _edit(Flight flight) async {
    final drafts = await showDialog<List<FlightDraft>>(
      context: context,
      builder: (_) => FlightFormDialog(initial: flight),
    );
    if (drafts != null) await _run(() => _api.update(flight.id, drafts.single));
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

  Widget _buildColumn(Helico helico, List<Flight> allFlights) {
    final flights = allFlights.where((f) => f.helicoId == helico.id).toList();
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              helico.label,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: flights.isEmpty
                ? Center(child: Text('Aucun vol pour ${helico.label}.'))
                : ListView.builder(
                    itemCount: flights.length,
                    itemBuilder: (context, i) {
                      final f = flights[i];
                      return FlightTile(
                        flight: f,
                        hasOverlap: overlapsFor(f, allFlights).isNotEmpty,
                        onTap: () => _openActions(f),
                      );
                    },
                  ),
          ),
        ],
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
          if (snap.hasError) {
            return const Center(child: Text('Impossible de charger le planning.'));
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildColumn(Helico.h1, flights),
                    const VerticalDivider(width: 1),
                    _buildColumn(Helico.h2, flights),
                  ],
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
