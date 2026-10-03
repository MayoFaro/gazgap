import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/services.dart';
import '../planning/planning_screen.dart';
import 'login_screen.dart';

enum GateState { signedOut, ready }

GateState gateFor(AuthSnapshot? auth) => auth == null ? GateState.signedOut : GateState.ready;

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  Stream<AuthSnapshot?>? _authStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authStream ??= AppServices.of(context).auth.changes();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSnapshot?>(
      stream: _authStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return gateFor(snap.data) == GateState.ready
            ? const PlanningScreen()
            : const LoginScreen();
      },
    );
  }
}
