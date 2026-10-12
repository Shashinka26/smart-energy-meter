import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'widgets/auth_gate.dart';
import 'services/usage_notification_service.dart';
import 'theme/app_theme.dart';

/// Release APK sideload builds use debug App Check so you can register
/// the token once in Firebase Console → App Check → Debug tokens.
const _useDebugAppCheck = bool.fromEnvironment(
  'USE_DEBUG_APP_CHECK',
  defaultValue: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    androidProvider: _useDebugAppCheck || kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    webProvider: WebDebugProvider(),
  );

  await UsageNotificationService.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const SmartEnergyApp());
}

class SmartEnergyApp extends StatelessWidget {
  const SmartEnergyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Energy',
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}
