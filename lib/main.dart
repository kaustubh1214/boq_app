import 'package:flutter/material.dart';

import 'data.dart';
import 'login.dart';
import 'manager.dart';
import 'site.dart';
import 'widgets.dart';

void main() => runApp(const BoqApp());

class BoqApp extends StatefulWidget {
  const BoqApp({super.key});

  @override
  State<BoqApp> createState() => _BoqAppState();
}

class _BoqAppState extends State<BoqApp> {
  final store = DemoStore();

  @override
  Widget build(BuildContext context) {
    return Scope(
      store: store,
      child: MaterialApp(
        title: 'AV BOQ',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Root(),
      ),
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    switch (s.role) {
      case null:
        return const LoginScreen();
      case Role.siteUser:
        return const SiteShell();
      case Role.storeManager:
        return const ManagerShell();
    }
  }
}
