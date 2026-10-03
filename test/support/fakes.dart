import 'dart:async';

import 'package:gazgap/data/auth_service.dart';
import 'package:gazgap/data/flight.dart';
import 'package:gazgap/data/flight_api.dart';

class FakeAuthService implements AuthService {
  final _ctrl = StreamController<AuthSnapshot?>.broadcast();
  AuthSnapshot? current;
  final calls = <String>[];
  String? failWith;

  void emit(AuthSnapshot? s) {
    current = s;
    _ctrl.add(s);
  }

  @override
  Stream<AuthSnapshot?> changes() async* {
    yield current;
    yield* _ctrl.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn:$email');
    if (failWith != null) throw AuthFailure(failWith!);
  }

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset:$email');
}

class FakeFlightApi implements FlightApi {
  final _ctrl = StreamController<List<Flight>>.broadcast();
  List<Flight> current = const [];
  final calls = <String>[];
  String? failWith;

  void emit(List<Flight> flights) {
    current = flights;
    _ctrl.add(flights);
  }

  void emitError(Object error) => _ctrl.addError(error);

  @override
  Stream<List<Flight>> watchAll() async* {
    yield current;
    yield* _ctrl.stream;
  }

  @override
  Future<void> create(FlightDraft draft) async {
    calls.add('create:${draft.helicoId}:${draft.destination}');
    if (failWith != null) throw FlightApiFailure(failWith!);
  }

  @override
  Future<void> update(String id, FlightDraft draft) async {
    calls.add('update:$id:${draft.destination}');
    if (failWith != null) throw FlightApiFailure(failWith!);
  }

  @override
  Future<void> setStatus(String id, FlightStatus statut) async {
    calls.add('setStatus:$id:${statut.code}');
    if (failWith != null) throw FlightApiFailure(failWith!);
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (failWith != null) throw FlightApiFailure(failWith!);
  }
}

Flight testFlight({
  String id = 'f1',
  String helicoId = 'H1',
  DateTime? start,
  String destination = 'Lomé',
  String remarque = '',
  FlightStatus statut = FlightStatus.planifie,
  int dureeMinutes = 60,
}) =>
    Flight(
      id: id,
      helicoId: helicoId,
      start: start ?? DateTime(2026, 10, 12, 9),
      destination: destination,
      remarque: remarque,
      statut: statut,
      dureeMinutes: dureeMinutes,
    );
