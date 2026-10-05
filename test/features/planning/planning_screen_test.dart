import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'gazgap',
        packageName: 'gazgap',
        version: '1.2.3',
        buildNumber: '4',
        buildSignature: '',
      ));

  testWidgets('version affichée dans la barre de titre', (tester) async {
    await tester.pumpWidget(host(FakeFlightApi()));
    await tester.pump();
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('v1.2.3+4')), findsOneWidget);
  });

  testWidgets('liste vide : message dédié par colonne', (tester) async {
    final flights = FakeFlightApi();
    await tester.pumpWidget(host(flights));
    await tester.pump();
    expect(find.text('Aucun vol pour Hélico H1.'), findsOneWidget);
    expect(find.text('Aucun vol pour Hélico H2.'), findsOneWidget);
  });

  testWidgets('vols H1 et H2 affichés dans des colonnes séparées (H1 à gauche)', (tester) async {
    final a = testFlight(id: 'a', helicoId: 'H1', destination: 'A');
    final b = testFlight(id: 'b', helicoId: 'H2', destination: 'B');
    final flights = FakeFlightApi()..emit([a, b]);
    await tester.pumpWidget(host(flights));
    await tester.pump();

    final xA = tester.getCenter(find.byKey(const Key('flight-a'))).dx;
    final xB = tester.getCenter(find.byKey(const Key('flight-b'))).dx;
    expect(xA, lessThan(xB));
  });

  testWidgets('erreur du flux Firestore : message affiché, pas confondu avec une liste vide', (tester) async {
    final flights = FakeFlightApi();
    await tester.pumpWidget(host(flights));
    await tester.pump();

    flights.emitError('permission-denied');
    await tester.pump();

    expect(find.text('Aucun vol planifié.'), findsNothing);
    expect(find.textContaining('Impossible de charger le planning'), findsOneWidget);
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

  testWidgets('création avec "Les deux" : un create par hélico', (tester) async {
    final flights = FakeFlightApi();
    await tester.pumpWidget(host(flights));
    await tester.tap(find.byKey(const Key('add-flight')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('destination')), 'Kara');
    await tester.tap(find.byKey(const Key('helico')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Les deux'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(flights.calls.toSet(), {'create:H1:Kara', 'create:H2:Kara'});
    expect(flights.calls.length, 2);
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

  testWidgets('le bandeau d\'erreur disparaît après une action réussie', (tester) async {
    final flights = FakeFlightApi()
      ..emit([testFlight(id: 'f1')])
      ..failWith = 'Hors ligne.';
    await tester.pumpWidget(host(flights));
    await tester.pump();

    await tester.tap(find.byKey(const Key('flight-f1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marquer réalisé'));
    await tester.pumpAndSettle();
    expect(find.text('Hors ligne.'), findsOneWidget);

    flights.failWith = null;
    await tester.tap(find.byKey(const Key('flight-f1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marquer réalisé'));
    await tester.pumpAndSettle();

    expect(find.text('Hors ligne.'), findsNothing);
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
