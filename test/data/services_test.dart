import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/services.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('AppServices.of expose auth et flights', (tester) async {
    final auth = FakeAuthService();
    final flights = FakeFlightApi();
    late AppServices services;
    await tester.pumpWidget(AppServices(
      auth: auth,
      flights: flights,
      child: Builder(builder: (context) {
        services = AppServices.of(context);
        return const SizedBox();
      }),
    ));
    expect(services.auth, auth);
    expect(services.flights, flights);
  });
}
