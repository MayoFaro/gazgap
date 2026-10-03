import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/auth_service.dart';
import 'package:gazgap/data/services.dart';
import 'package:gazgap/features/auth/gate.dart';

import '../../support/fakes.dart';

void main() {
  test('gateFor : non connecté', () => expect(gateFor(null), GateState.signedOut));
  test('gateFor : connecté', () {
    expect(gateFor(const AuthSnapshot(uid: 'u1', email: 'a@b.fr')), GateState.ready);
  });

  testWidgets('AppGate : affiche Connexion puis Planning selon le flux auth', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(AppServices(
      auth: auth,
      flights: FakeFlightApi(),
      child: const MaterialApp(home: AppGate()),
    ));
    await tester.pump();
    expect(find.text('Se connecter'), findsOneWidget);

    auth.emit(const AuthSnapshot(uid: 'u1', email: 'pilote@gap.fr'));
    await tester.pump();
    expect(find.text('GazGap — Planning'), findsOneWidget);
  });
}
