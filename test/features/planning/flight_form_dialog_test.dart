import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/flight.dart';
import 'package:gazgap/features/planning/flight_form_dialog.dart';

Future<T?> openDialog<T>(WidgetTester tester, Widget dialog) async {
  T? result;
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
    return ElevatedButton(
      onPressed: () async {
        result = await showDialog<T>(context: context, builder: (_) => dialog);
      },
      child: const Text('ouvrir'),
    );
  })));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('création : destination et champs remplis renvoient un FlightDraft', (tester) async {
    FlightDraft? draft;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () async {
          draft = await showDialog<FlightDraft>(
              context: context, builder: (_) => const FlightFormDialog());
        },
        child: const Text('ouvrir'),
      );
    })));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('destination')), 'Lomé');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(draft, isNotNull);
    expect(draft!.helicoId, 'H1');
    expect(draft!.destination, 'Lomé');
    expect(draft!.dureeMinutes, 60);
  });

  testWidgets('destination vide : bloque la soumission', (tester) async {
    FlightDraft? draft;
    var popped = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () async {
          draft = await showDialog<FlightDraft>(
              context: context, builder: (_) => const FlightFormDialog());
          popped = true;
        },
        child: const Text('ouvrir'),
      );
    })));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(popped, isFalse);
    expect(draft, isNull);
    expect(find.text('Destination requise'), findsOneWidget);
  });

  testWidgets('durée nulle : bloque la soumission', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showDialog<FlightDraft>(
            context: context, builder: (_) => const FlightFormDialog()),
        child: const Text('ouvrir'),
      );
    })));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('destination')), 'Lomé');
    await tester.enterText(find.byKey(const Key('duree')), '0');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Durée invalide'), findsOneWidget);
  });

  testWidgets('heure hors plage : bloque la soumission sans décaler la date', (tester) async {
    FlightDraft? draft;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () async {
          draft = await showDialog<FlightDraft>(
              context: context, builder: (_) => const FlightFormDialog());
        },
        child: const Text('ouvrir'),
      );
    })));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('destination')), 'Lomé');
    await tester.enterText(find.byKey(const Key('time')), '25:70');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(draft, isNull);
    expect(find.text('Heure invalide'), findsOneWidget);
  });

  testWidgets('modification : préremplit avec le vol existant', (tester) async {
    final existing = Flight(
      id: 'f1',
      helicoId: 'H2',
      start: DateTime(2026, 10, 12, 9, 30),
      destination: 'Kara',
      remarque: 'RAS',
      statut: FlightStatus.planifie,
      dureeMinutes: 45,
    );
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showDialog<FlightDraft>(
            context: context, builder: (_) => FlightFormDialog(initial: existing)),
        child: const Text('ouvrir'),
      );
    })));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Kara'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('12/10/2026'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
  });
}
