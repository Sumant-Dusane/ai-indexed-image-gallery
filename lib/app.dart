import 'package:ai_gallery/app_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return AppStartup(
      child: MaterialApp.router(
        routerConfig: router,
        theme: _lightTheme(),
        darkTheme: _darkTheme(),
        themeMode: ThemeMode.system,
      ),
    );
  }
}

ThemeData _lightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorSchemeSeed: Colors.blue,
  );
}

ThemeData _darkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorSchemeSeed: Colors.blue,
  );
}
