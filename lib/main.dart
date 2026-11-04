import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/feed_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(
    ChangeNotifierProvider.value(
      value: state..init(),
      child: const SortApp(),
    ),
  );
}

class SortApp extends StatelessWidget {
  const SortApp({super.key});

  static const seed = Color(0xFF1F6F5C); // calm green-teal

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sortapp',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: Consumer<AppState>(
        builder: (context, state, _) {
          if (!state.ready) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return state.settings.onboarded
              ? const FeedScreen()
              : const OnboardingScreen();
        },
      ),
    );
  }
}
