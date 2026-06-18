import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

// Theme state

class ThemeNotifier extends ChangeNotifier {
  static const String _key = 'theme_mode';

  ThemeMode _mode;
  ThemeNotifier(this._mode);

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }

  static Future<ThemeNotifier> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key) ?? 'light';
    return ThemeNotifier(stored == 'dark' ? ThemeMode.dark : ThemeMode.light);
  }
}

late ThemeNotifier themeNotifier;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterLocalization.instance.ensureInitialized();

  tz.initializeTimeZones();
  tz.setLocalLocation(
    tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
  );

  await NotificationService.instance.initNotification();
  await NotificationService.instance.loadTasksAndScheduleNotifications();

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;

  themeNotifier = await ThemeNotifier.load();

  runApp(MyApp(showOnboarding: !onboardingDone));
}

class MyApp extends StatefulWidget {
  final bool showOnboarding;
  const MyApp({super.key, required this.showOnboarding});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeNotifier.mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: widget.showOnboarding ? const OnboardingPage() : const HomePage(),
    );
  }
}
