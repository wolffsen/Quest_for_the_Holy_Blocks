import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/game/ui/main_menu_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Force portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: CosmicBlockBlastApp()));
}

class CosmicBlockBlastApp extends StatelessWidget {
  const CosmicBlockBlastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quest for the Holy Blocks',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC778),
          brightness: Brightness.dark,
        ).copyWith(
          secondary: const Color(0xFFFF8BA7),
          surface: const Color(0xFF261746),
        ),
        scaffoldBackgroundColor: const Color(0xFF1B1037),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            foregroundColor: Colors.black87,
            backgroundColor: const Color(0xFFFFC778),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF8BA7),
            side: const BorderSide(color: Color(0xFFFF8BA7)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const MainMenuPage(),
    );
  }
}
