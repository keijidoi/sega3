import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sega3/ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const Sega3App());
}

class Sega3App extends StatelessWidget {
  const Sega3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEGA Mark III Emulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
