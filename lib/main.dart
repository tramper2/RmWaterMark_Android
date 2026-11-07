import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1E26),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const CleanMarkApp());
}

class CleanMarkApp extends StatelessWidget {
  const CleanMarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '워터마크 지우개',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFFF43F5E),
          surface: Color(0xFF1A1E26),
        ),
        scaffoldBackgroundColor: const Color(0xFF121418),
      ),
      home: const HomeScreen(),
    );
  }
}
