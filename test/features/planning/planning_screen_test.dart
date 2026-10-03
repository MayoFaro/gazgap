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
