import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: paper,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: paper,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const BoqApp());
}

class BoqApp extends StatelessWidget {
  const BoqApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: gold, primary: ink, surface: paper, error: danger);
    return MaterialApp(
      title: 'AV BOQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(backgroundColor: paper, foregroundColor: ink, elevation: 0, scrolledUnderElevation: 0),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: paper,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: hairline),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: hairline)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: hairline)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: gold, width: 2)),
        ),
      ),
      home: const Shell(),
    );
  }
}
