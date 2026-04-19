import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'pages/home_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterLocalization.instance.ensureInitialized();

  NotificationService.instance.initNotification();

  tz.initializeTimeZones();

  NotificationService.instance.LoadTasksAndScheduleNotifications();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'GB'), // 🇬🇧 Monday-first week
  supportedLocales: const [
    Locale('en', 'GB'),
  ],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
      home: HomePage(),
    );
  }
}