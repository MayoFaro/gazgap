import 'package:flutter/widgets.dart';

import 'auth_service.dart';
import 'flight_api.dart';

/// Services de l'app, injectés à la racine (doublures en test).
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.auth,
    required this.flights,
    required super.child,
  });

  final AuthService auth;
  final FlightApi flights;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServices>()!;

  @override
  bool updateShouldNotify(AppServices old) =>
      auth != old.auth || flights != old.flights;
}
