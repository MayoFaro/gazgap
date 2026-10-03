import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/app.dart';
import 'package:gazgap/data/services.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('GazGapApp non connecté : affiche l\'écran de connexion', (tester) async {
    await tester.pumpWidget(AppServices(
      auth: FakeAuthService(),
      flights: FakeFlightApi(),
      child: const GazGapApp(),
    ));
    await tester.pump();
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
