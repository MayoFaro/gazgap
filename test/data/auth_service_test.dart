import 'package:flutter_test/flutter_test.dart';
import 'package:gazgap/data/auth_service.dart';

void main() {
  test('authErrorMessage : codes connus et inconnu', () {
    expect(authErrorMessage('wrong-password'), 'E-mail ou mot de passe incorrect.');
    expect(authErrorMessage('user-not-found'), 'E-mail ou mot de passe incorrect.');
    expect(authErrorMessage('invalid-credential'), 'E-mail ou mot de passe incorrect.');
    expect(authErrorMessage('user-disabled'), 'Ce compte est désactivé.');
    expect(authErrorMessage('too-many-requests'), 'Trop de tentatives. Réessayez plus tard.');
    expect(authErrorMessage('network-request-failed'), 'Pas de connexion réseau.');
    expect(authErrorMessage('xyz'), 'Connexion impossible (xyz).');
  });

  test('AuthFailure.toString renvoie le message', () {
    expect(const AuthFailure('oups').toString(), 'oups');
  });
}
