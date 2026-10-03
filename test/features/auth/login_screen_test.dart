import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/services.dart';
import 'package:gazgap/features/auth/login_screen.dart';

import '../../support/fakes.dart';

Widget host(FakeAuthService auth) => AppServices(
      auth: auth,
      flights: FakeFlightApi(),
      child: const MaterialApp(home: LoginScreen()),
    );

void main() {
  testWidgets('connexion : appelle signIn avec l\'e-mail nettoyé', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(host(auth));
    await tester.enterText(find.byKey(const Key('email')), ' pilote@gap.fr ');
    await tester.enterText(find.byKey(const Key('password')), 'secret');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(auth.calls, ['signIn:pilote@gap.fr']);
  });

  testWidgets('échec : message affiché', (tester) async {
    final auth = FakeAuthService()..failWith = 'E-mail ou mot de passe incorrect.';
    await tester.pumpWidget(host(auth));
    await tester.enterText(find.byKey(const Key('email')), 'pilote@gap.fr');
    await tester.enterText(find.byKey(const Key('password')), 'x');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
  });
}
