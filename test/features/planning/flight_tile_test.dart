import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/flight.dart';
import 'package:gazgap/features/planning/flight_tile.dart';

Flight _f({FlightStatus statut = FlightStatus.planifie, String remarque = ''}) => Flight(
      id: 'f1',
      helicoId: 'H1',
      start: DateTime(2026, 10, 12, 9, 5),
      destination: 'Lomé',
      remarque: remarque,
      statut: statut,
      dureeMinutes: 60,
    );

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('affiche hélico, date/heure et destination', (tester) async {
    await tester.pumpWidget(host(FlightTile(flight: _f(), hasOverlap: false, onTap: () {})));
    expect(find.textContaining('12/10/2026 09:05'), findsOneWidget);
    expect(find.textContaining('Lomé'), findsOneWidget);
    expect(find.text('H1'), findsOneWidget);
  });

  testWidgets('affiche le statut et la remarque si présente', (tester) async {
    await tester.pumpWidget(host(
        FlightTile(flight: _f(remarque: 'RAS'), hasOverlap: false, onTap: () {})));
    expect(find.textContaining('Planifié'), findsOneWidget);
    expect(find.textContaining('RAS'), findsOneWidget);
  });

  testWidgets('icône de chevauchement visible seulement si hasOverlap', (tester) async {
    await tester.pumpWidget(host(FlightTile(flight: _f(), hasOverlap: true, onTap: () {})));
    expect(find.byKey(const Key('overlap-warning')), findsOneWidget);

    await tester.pumpWidget(host(FlightTile(flight: _f(), hasOverlap: false, onTap: () {})));
    expect(find.byKey(const Key('overlap-warning')), findsNothing);
  });

  testWidgets('onTap déclenché au tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
        host(FlightTile(flight: _f(), hasOverlap: false, onTap: () => tapped = true)));
    await tester.tap(find.byKey(const Key('flight-f1')));
    expect(tapped, isTrue);
  });
}
