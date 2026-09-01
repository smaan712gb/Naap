import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'features/home/home_screen.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final state = AppState()..hydrate();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const NaapApp()),
  );
  // On-device smoke gate (AWS Device Farm) greps the device log for this
  // marker: it proves the Dart engine booted and the first frame rendered.
  binding.addPostFrameCallback((_) {
    debugPrint('NAAPSMOKE_BOOT_OK: first frame rendered');
  });
}

const kNaapGreen = Color(0xFF1B4D3E);
const kNaapGold = Color(0xFFC9A227);

class NaapApp extends StatelessWidget {
  const NaapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kNaapGreen,
          primary: kNaapGreen,
          secondary: kNaapGold,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kNaapGreen,
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kNaapGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
