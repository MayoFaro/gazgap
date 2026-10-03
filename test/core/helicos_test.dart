import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/core/helicos.dart';

void main() {
  test('fromId : retrouve H1 et H2', () {
    expect(Helico.fromId('H1'), Helico.h1);
    expect(Helico.fromId('H2'), Helico.h2);
  });

  test('fromId : code inconnu ou null renvoie null', () {
    expect(Helico.fromId('H3'), isNull);
    expect(Helico.fromId(null), isNull);
  });

  test('id et label sont distincts pour chaque hélico', () {
    expect(Helico.h1.id, 'H1');
    expect(Helico.h2.id, 'H2');
    expect(Helico.h1.label, isNot(Helico.h2.label));
  });
}
