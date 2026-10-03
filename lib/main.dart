import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/auth_service.dart';
import 'data/flight_api.dart';
import 'data/services.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(AppServices(
    auth: FirebaseAuthService(),
    flights: FirebaseFlightApi(),
    child: const GazGapApp(),
  ));
}
