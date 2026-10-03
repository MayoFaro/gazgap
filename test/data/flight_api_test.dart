import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/flight_api.dart';

void main() {
  test('FlightApiFailure.toString renvoie le message', () {
    expect(const FlightApiFailure('Écriture impossible.').toString(), 'Écriture impossible.');
  });
}
